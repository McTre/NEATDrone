extends RefCounted
## Shared deterministic simulation for the playable arena and headless tests.
## Only observations() provides information to the robot policy.

const SIZE = Vector2(900, 580)
const ROBOT_RADIUS = 11.0
const PLAYER_RADIUS = 12.0
const ROBOT_SPEED = 115.0
const ROBOT_TURN_SPEED = TAU * 1.5 # 540 degrees/second; half-turn takes 1/3 s.
const ROBOT_ACCELERATION = 1200.0
const PLAYER_SPEED = 225.0
const SENSOR_RANGE = 110.0
const ALERT_RADIUS = 65.0
const STEP = 1.0 / 60.0
const EPISODE_SECONDS = 16.0
const VISION_RANGE = 300.0
const PROJECTILE_RANGE = 300.0
const BULLET_SPEED = 700.0
const DEATH_PENALTY = -35.0
const HIT_PENALTY = -12.0
const NAVIGATION_WEIGHT = 0.08
const RoomLayout = preload("res://scripts/room_layout.gd")
var room_layout = false
var entry_index = 0
var room_index = 0

var walls: Array[Rect2] = [
	Rect2(260, 100, 28, 145), Rect2(612, 335, 28, 145),
	Rect2(410, 265, 80, 30),
]
var robots: Array = []
var bullets: Array = []
var player = Vector2(450, 450)
var player_health = 100.0
var aim = Vector2.UP
var alert = Vector2(450, 150)
var alert_active = false
var lab = false
var elapsed = 0.0
var shoot_cooldown = 0.0
var melee_cooldown = 0.0
var melee_flash = 0.0
var contact_cooldown = 0.0
var kills = 0
var initial_population = 0
var vision_range = VISION_RANGE
var vision_enabled = false
var blind_test = false
var player_path: Array = []
var path_index = 0
var projectiles_enabled = false
var projectile_blind_test = false
var firing_trial = false
var fire_interval = 0.28

func setup(genomes: Array, target: Vector2, spawn: Vector2 = Vector2(-1, -1), laboratory: bool = false) -> void:
	room_layout = false
	walls.assign([Rect2(260, 100, 28, 145), Rect2(612, 335, 28, 145), Rect2(410, 265, 80, 30)])
	robots.clear()
	bullets.clear()
	alert = target
	lab = laboratory
	alert_active = laboratory
	elapsed = 0.0
	player = Vector2(450, 450)
	player_health = 100.0
	shoot_cooldown = 0.0
	melee_cooldown = 0.0
	melee_flash = 0.0
	contact_cooldown = 0.0
	kills = 0
	initial_population = genomes.size()
	vision_range = VISION_RANGE
	vision_enabled = not genomes.is_empty() and genomes[0].input_ids.size() > 9
	projectiles_enabled = not genomes.is_empty() and genomes[0].input_ids.size() > 13
	projectile_blind_test = false
	firing_trial = false
	blind_test = false
	player_path = []
	path_index = 0
	for i in range(genomes.size()):
		var position = spawn
		if position.x < 0:
			var side = i % 4
			var fraction = float(i / 4 + 1) / (ceili(genomes.size() / 4.0) + 1)
			match side:
				0: position = Vector2(25, lerpf(35, SIZE.y - 35, fraction))
				1: position = Vector2(SIZE.x - 25, lerpf(35, SIZE.y - 35, fraction))
				2: position = Vector2(lerpf(35, SIZE.x - 35, fraction), 25)
				3: position = Vector2(lerpf(35, SIZE.x - 35, fraction), SIZE.y - 25)
		if not lab:
			position = free_robot_spawn(position)
		robots.append({"genome": genomes[i], "position": position, "velocity": Vector2.ZERO,
			"heading": Vector2.RIGHT, "health": 2.0, "reached": false,
			"start_distance": position.distance_to(alert), "wall_time": 0.0,
			"contact_timer": 0.0, "contacts": 0, "visible_time": 0.0,
			"shots": [], "hits": 0, "lifetime": 0.0, "best_edge": -1.0, "search_cells": {},
			"parts": {"survival": 0.0, "progress": 0.0, "arrival": 0.0,
				"damage": 0.0, "wall": 0.0, "death": 0.0, "pursuit": 0.0,
				"search": 0.0, "injury": 0.0}})

func setup_combat(genomes: Array, seed_value: int, wave: int) -> void:
	var layout_rng = RandomNumberGenerator.new()
	layout_rng.seed = seed_value * 1000003 + wave * 7919
	var entrance = layout_rng.randi_range(0, 3)
	var room = layout_rng.randi_range(0, 3)
	setup(genomes, RoomLayout.ALERTS[room])
	room_layout = true
	entry_index = entrance
	room_index = room
	walls.assign(RoomLayout.WALLS)
	player = Vector2(450, 290)
	var direction: Vector2 = RoomLayout.DIRECTIONS[entry_index]
	var doorway: Vector2 = RoomLayout.ENTRIES[entry_index]
	for i in range(robots.size()):
		var robot = robots[i]
		robot.position = doorway - direction * (35.0 + (i / 2) * 32.0) + direction.orthogonal() * (-14.0 if i % 2 == 0 else 14.0)
		robot.heading = direction
		robot.incoming = true
		robot.entry_distance = 44.0 + (ceili(robots.size() / 2.0) - 1 - i / 2) * 32.0
		robot.start_distance = robot.position.distance_to(alert)

func enter_arena(robot: Dictionary, delta: float) -> void:
	var direction: Vector2 = RoomLayout.DIRECTIONS[entry_index]
	var candidate: Vector2 = robot.position + direction * ROBOT_SPEED * delta
	if robot_space_free(candidate, robot):
		robot.position = candidate
		robot.velocity = direction * ROBOT_SPEED
	# The hidden entry corridor uses fixed ingress; NEAT takes over inside.
	if (robot.position - RoomLayout.ENTRIES[entry_index]).dot(direction) >= robot.entry_distance:
		robot.incoming = false
		robot.velocity = Vector2.ZERO

func robot_space_free(point: Vector2, except_robot = null) -> bool:
	for other in robots:
		if other == except_robot or other.health <= 0:
			continue
		if point.distance_squared_to(other.position) < pow(ROBOT_RADIUS * 2, 2) - 0.0001:
			return false
	return true

func free_robot_spawn(point: Vector2) -> Vector2:
	if not blocked(point, ROBOT_RADIUS) and robot_space_free(point):
		return point
	for ring in range(1, 42):
		for direction in range(32):
			var candidate = point + Vector2.from_angle(direction * TAU / 32) * ring * ROBOT_RADIUS * 2
			if not blocked(candidate, ROBOT_RADIUS) and robot_space_free(candidate):
				return candidate
	push_error("No free drone spawn found")
	return point

func steer_robot(robot: Dictionary, output: Vector2, delta: float) -> Vector2:
	var velocity: Vector2 = robot.velocity.move_toward(output * ROBOT_SPEED, ROBOT_ACCELERATION * delta)
	if velocity.length_squared() > 0.01:
		var angle = robot.heading.angle_to(velocity)
		robot.heading = robot.heading.rotated(clampf(angle, -ROBOT_TURN_SPEED * delta, ROBOT_TURN_SPEED * delta)).normalized()
	return velocity * delta

func move_robot(robot: Dictionary, displacement: Vector2) -> Vector2:
	if lab:
		return move_body(robot.position, displacement, ROBOT_RADIUS)
	var point: Vector2 = robot.position
	var slices = maxi(1, ceili(displacement.length() / (ROBOT_RADIUS * 0.5)))
	var increment = displacement / slices
	for slice in range(slices):
		# Slide along free axes; never push another drone through walls.
		for axis in range(2):
			var candidate = point
			candidate[axis] += increment[axis]
			if not blocked(candidate, ROBOT_RADIUS) and robot_space_free(candidate, robot):
				point = candidate
	return point

func perceived_projectile(robot: Dictionary):
	if not projectiles_enabled or projectile_blind_test:
		return null
	var nearest = null
	var nearest_distance = PROJECTILE_RANGE * PROJECTILE_RANGE
	var candidates: Array = robot.shots if firing_trial else bullets
	for bullet in candidates:
		var offset: Vector2 = bullet.position - robot.position
		var distance = offset.length_squared()
		if distance <= nearest_distance:
			var length = sqrt(distance)
			if ray_distance(robot.position, offset.normalized(), length) >= length - 0.001:
				nearest = bullet
				nearest_distance = distance
	return nearest

func score_navigation(robot: Dictionary, before: Vector2, visible: bool) -> void:
	if not alert_active:
		return
	var edge_before = maxf(0, before.distance_to(alert) - ALERT_RADIUS)
	var edge_after = maxf(0, robot.position.distance_to(alert) - ALERT_RADIUS)
	if robot.best_edge < 0:
		robot.best_edge = edge_before
	var improvement = maxf(0, robot.best_edge - edge_after)
	robot.best_edge = minf(robot.best_edge, edge_after)
	if not visible:
		# Reward first-time progress to the boundary, never to the center.
		robot.parts.progress = minf(30.0, robot.parts.progress + improvement * NAVIGATION_WEIGHT)
	if edge_after == 0.0:
		if not robot.reached:
			robot.reached = true
			robot.parts.arrival = 0.0 if visible else 5.0
		if not visible:
			var cell = Vector2i((robot.position - alert + Vector2.ONE * ALERT_RADIUS) / 25.0)
			if not robot.search_cells.has(cell):
				robot.search_cells[cell] = true
				robot.parts.search = minf(8.0, robot.parts.search + 0.5)

func sees_player(robot: Dictionary) -> bool:
	if not vision_enabled or blind_test:
		return false
	var offset: Vector2 = player - robot.position
	var distance = offset.length()
	return distance <= vision_range and ray_distance(robot.position, offset.normalized(), distance) >= distance - 0.001

func move_training_player(delta: float) -> void:
	if player_path.is_empty():
		return
	var target: Vector2 = player_path[path_index]
	var offset = target - player
	var travel = minf(65.0 * delta, offset.length())
	player = move_body(player, offset.normalized() * travel, PLAYER_RADIUS)
	if player.distance_to(target) < 2:
		path_index = (path_index + 1) % player_path.size()

func blocked(point: Vector2, radius: float) -> bool:
	if point.x < radius or point.y < radius or point.x > SIZE.x - radius or point.y > SIZE.y - radius:
		return true
	for wall in walls:
		var nearest = Vector2(clampf(point.x, wall.position.x, wall.end.x), clampf(point.y, wall.position.y, wall.end.y))
		if point.distance_squared_to(nearest) < radius * radius:
			return true
	return false

func move_body(point: Vector2, displacement: Vector2, radius: float) -> Vector2:
	# Collision resolves penetration only. No steering, turn-away or pathfinder.
	if displacement == Vector2.ZERO:
		return point
	var slices = maxi(1, ceili(displacement.length() / (radius * 0.5)))
	var increment = displacement / slices
	for i in range(slices):
		var candidate = point + Vector2(increment.x, 0)
		if not blocked(candidate, radius):
			point = candidate
		candidate = point + Vector2(0, increment.y)
		if not blocked(candidate, radius):
			point = candidate
	return point

func ray_box(origin: Vector2, direction: Vector2, box: Rect2, maximum: float) -> float:
	var near = 0.0
	var far = maximum
	for axis in range(2):
		if absf(direction[axis]) < 0.000001:
			if origin[axis] < box.position[axis] or origin[axis] > box.end[axis]:
				return maximum
		else:
			var a = (box.position[axis] - origin[axis]) / direction[axis]
			var b = (box.end[axis] - origin[axis]) / direction[axis]
			near = maxf(near, minf(a, b))
			far = minf(far, maxf(a, b))
			if near > far:
				return maximum
	return near

func ray_distance(origin: Vector2, direction: Vector2, maximum: float = SENSOR_RANGE) -> float:
	var result = maximum
	if direction.x > 0.000001:
		result = minf(result, (SIZE.x - origin.x) / direction.x)
	elif direction.x < -0.000001:
		result = minf(result, -origin.x / direction.x)
	if direction.y > 0.000001:
		result = minf(result, (SIZE.y - origin.y) / direction.y)
	elif direction.y < -0.000001:
		result = minf(result, -origin.y / direction.y)
	for wall in walls:
		result = minf(result, ray_box(origin, direction, wall, maximum))
	return maxf(0.0, result)

func observations(robot: Dictionary) -> PackedFloat64Array:
	var inputs = PackedFloat64Array()
	inputs.resize(19 if projectiles_enabled else (13 if vision_enabled else 9))
	var heading: Vector2 = robot.heading
	var position: Vector2 = robot.position
	inputs[0] = 1.0 - clampf((ray_distance(position, heading) - ROBOT_RADIUS) / SENSOR_RANGE, 0, 1)
	inputs[1] = 1.0 - clampf((ray_distance(position, heading.rotated(-PI / 2)) - ROBOT_RADIUS) / SENSOR_RANGE, 0, 1)
	inputs[2] = 1.0 - clampf((ray_distance(position, heading.rotated(PI / 2)) - ROBOT_RADIUS) / SENSOR_RANGE, 0, 1)
	# Direct visual evidence takes priority over the stale area report.
	# This gates observations only; movement still comes from the network.
	var player_visible = sees_player(robot)
	var signal_available = alert_active and not player_visible
	var target_vector: Vector2 = alert - robot.position if signal_available else Vector2.ZERO
	var target_direction = target_vector.normalized()
	inputs[3] = target_direction.x
	inputs[4] = target_direction.y
	inputs[5] = target_vector.length() / SIZE.length()
	inputs[6] = robot.velocity.x / ROBOT_SPEED
	inputs[7] = robot.velocity.y / ROBOT_SPEED
	inputs[8] = 1.0 if signal_available else 0.0
	if vision_enabled:
		var visible = sees_player(robot)
		var offset: Vector2 = player - robot.position if visible else Vector2.ZERO
		var direction = offset.normalized()
		inputs[9] = direction.x
		inputs[10] = direction.y
		inputs[11] = offset.length() / VISION_RANGE
		inputs[12] = 1.0 if visible else 0.0
	if projectiles_enabled:
		var bullet = perceived_projectile(robot)
		if bullet != null:
			var offset: Vector2 = bullet.position - position
			var direction = offset.normalized()
			inputs[13] = direction.x
			inputs[14] = direction.y
			inputs[15] = offset.length() / PROJECTILE_RANGE
			inputs[16] = clampf(bullet.velocity.x / BULLET_SPEED, -1, 1)
			inputs[17] = clampf(bullet.velocity.y / BULLET_SPEED, -1, 1)
			inputs[18] = 1.0
	return inputs

func hurt_robot(robot: Dictionary, amount: float) -> void:
	if robot.health <= 0:
		return
	robot.health -= amount
	robot.hits += 1
	robot.parts.injury += HIT_PENALTY * amount
	if robot.health <= 0:
		robot.parts.death = DEATH_PENALTY
		kills += 1

func segment_circle(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> float:
	var delta = finish - start
	var offset = start - center
	var a = delta.length_squared()
	var c = offset.length_squared() - radius * radius
	if c <= 0:
		return 0.0
	if a < 0.000001:
		return INF
	var b = offset.dot(delta)
	var discriminant = b * b - a * c
	if discriminant < 0:
		return INF
	var fraction = (-b - sqrt(discriminant)) / a
	return fraction if fraction >= 0 and fraction <= 1 else INF

func step(delta: float, movement: Vector2 = Vector2.ZERO, aim_at: Vector2 = Vector2.ZERO, shooting: bool = false, melee: bool = false) -> void:
	elapsed += delta
	shoot_cooldown = maxf(0, shoot_cooldown - delta)
	melee_cooldown = maxf(0, melee_cooldown - delta)
	melee_flash = maxf(0, melee_flash - delta)
	contact_cooldown = maxf(0, contact_cooldown - delta)
	if firing_trial and shoot_cooldown <= 0:
		for robot in robots:
			if robot.health > 0:
				robot.shots.append({"position": player, "velocity": player.direction_to(robot.position) * BULLET_SPEED, "life": 1.8})
		shoot_cooldown = fire_interval
	if lab and vision_enabled:
		move_training_player(delta)
	if not lab and player_health > 0:
		player = move_body(player, movement.limit_length() * PLAYER_SPEED * delta, PLAYER_RADIUS)
		if player.distance_to(alert) <= ALERT_RADIUS:
			alert_active = true # Latched area sighting; never follows player.
		if aim_at.distance_to(player) > 1:
			aim = player.direction_to(aim_at)
		if shooting and shoot_cooldown <= 0:
			bullets.append({"position": player, "velocity": aim * BULLET_SPEED, "life": 1.8})
			shoot_cooldown = 0.14
		if melee and melee_cooldown <= 0:
			melee_cooldown = 0.55
			melee_flash = 0.14
			for robot in robots:
				if robot.get("incoming", false) and not Rect2(Vector2.ZERO, SIZE).has_point(robot.position):
					continue
				var direction: Vector2 = robot.position - player
				if direction.length() < 64 and direction.normalized().dot(aim) > 0.25:
					if ray_distance(player, direction.normalized(), direction.length()) >= direction.length() - 0.01:
						hurt_robot(robot, 2.0)
	for robot in robots:
		if robot.health <= 0:
			continue
		if robot.get("incoming", false):
			enter_arena(robot, delta)
			continue
		var inputs = observations(robot)
		var output: Vector2 = robot.genome.activate(inputs)
		var before: Vector2 = robot.position
		var visible = vision_enabled and inputs[12] > 0.0
		var displacement = steer_robot(robot, output, delta)
		var wall_position = move_body(before, displacement, ROBOT_RADIUS)
		robot.position = wall_position if lab else move_robot(robot, displacement)
		robot.velocity = (robot.position - before) / delta
		robot.parts.survival += delta * 0.08
		robot.lifetime += delta
		if visible:
			robot.visible_time += delta
			robot.parts.pursuit = clampf(robot.parts.pursuit + (before.distance_to(player) - robot.position.distance_to(player)) * 0.35, -60, 60)
		score_navigation(robot, before, visible)
		var requested_distance = displacement.length()
		if requested_distance > 0.1 and before.distance_to(wall_position) < requested_distance * 0.35:
			robot.wall_time += delta
			robot.parts.wall -= delta * 2.0
		robot.contact_timer = maxf(0, robot.contact_timer - delta)
		var touching = robot.position.distance_to(player) < ROBOT_RADIUS + PLAYER_RADIUS
		if lab and vision_enabled and touching and robot.contact_timer <= 0:
			# Each genome has an independent contact clock and invulnerable target.
			# One genome cannot steal another genome's evaluation opportunities.
			robot.contacts += 1
			robot.parts.damage += 16.0
			robot.contact_timer = 0.45
		if firing_trial:
			advance_shots(robot.shots, [robot], delta)
		if not lab and player_health > 0 and contact_cooldown <= 0 and touching:
			player_health = maxf(0, player_health - 10)
			robot.contacts += 1
			robot.parts.damage += 16.0
			contact_cooldown = 0.45
	advance_shots(bullets, robots, delta)

func advance_shots(shots: Array, targets: Array, delta: float) -> void:
	for index in range(shots.size() - 1, -1, -1):
		var bullet = shots[index]
		var start: Vector2 = bullet.position
		var finish: Vector2 = start + bullet.velocity * delta
		var length = start.distance_to(finish)
		var nearest = ray_distance(start, bullet.velocity.normalized(), length) / maxf(length, 0.000001)
		var wall_hit = nearest < 1.0
		var victim = null
		for robot in targets:
			if robot.health <= 0:
				continue
			var hit = segment_circle(start, finish, robot.position, ROBOT_RADIUS + 2)
			if hit < nearest:
				nearest = hit
				victim = robot
		bullet.life -= delta
		if victim != null:
			hurt_robot(victim, 1.0)
		if victim != null or wall_hit or bullet.life <= 0:
			shots.remove_at(index)
		else:
			bullet.position = finish

func fitness(robot: Dictionary) -> float:
	var total = 0.0
	for value in robot.parts.values():
		total += value
	return total

func scores() -> Array:
	return robots.map(func(robot): return fitness(robot))

func alive_count() -> int:
	return robots.size() - kills

func metrics() -> Dictionary:
	var reached = 0
	var wall_time = 0.0
	var progress = 0.0
	var score = 0.0
	var contacted = 0
	var contacts = 0
	var visible_time = 0.0
	var hits = 0
	var lifetime = 0.0
	var search = 0.0
	for robot in robots:
		reached += 1 if robot.reached else 0
		wall_time += robot.wall_time
		progress += robot.parts.progress / NAVIGATION_WEIGHT
		score += fitness(robot)
		contacted += 1 if robot.contacts > 0 else 0
		contacts += robot.contacts
		visible_time += robot.visible_time
		hits += robot.hits
		lifetime += robot.lifetime
		search += robot.parts.search
	var count = maxi(1, robots.size())
	return {"arrival_rate": float(reached) / count, "wall_seconds": wall_time / count,
		"progress_px": progress / count, "fitness": score / count,
		"contact_rate": float(contacted) / count, "contacts": float(contacts) / count,
		"visible_seconds": visible_time / count, "hits": float(hits) / count,
		"survival_seconds": lifetime / count, "survival_rate": float(alive_count()) / count,
		"search_reward": search / count}
