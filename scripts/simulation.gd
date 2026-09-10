extends RefCounted
## Shared deterministic simulation for the playable arena and headless tests.
## Only observations() provides information to the robot policy.

const SIZE = Vector2(900, 580)
const ROBOT_RADIUS = 11.0
const PLAYER_RADIUS = 12.0
const ROBOT_SPEED = 115.0
const PLAYER_SPEED = 225.0
const SENSOR_RANGE = 110.0
const ALERT_RADIUS = 65.0
const STEP = 1.0 / 60.0
const EPISODE_SECONDS = 16.0
const VISION_RANGE = 300.0

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
var vision_enabled = false
var blind_test = false
var player_path: Array = []
var path_index = 0

func setup(genomes: Array, target: Vector2, spawn: Vector2 = Vector2(-1, -1), laboratory: bool = false) -> void:
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
	vision_enabled = not genomes.is_empty() and genomes[0].input_ids.size() > 9
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
		robots.append({"genome": genomes[i], "position": position, "velocity": Vector2.ZERO,
			"heading": Vector2.RIGHT, "health": 2.0, "reached": false,
			"start_distance": position.distance_to(alert), "wall_time": 0.0,
			"contact_timer": 0.0, "contacts": 0, "visible_time": 0.0,
			"parts": {"survival": 0.0, "progress": 0.0, "arrival": 0.0,
				"damage": 0.0, "wall": 0.0, "death": 0.0, "pursuit": 0.0}})

func sees_player(robot: Dictionary) -> bool:
	if not vision_enabled or blind_test:
		return false
	var offset: Vector2 = player - robot.position
	var distance = offset.length()
	return distance <= VISION_RANGE and ray_distance(robot.position, offset.normalized(), distance) >= distance - 0.001

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
	var heading: Vector2 = robot.heading
	for direction in [heading, heading.rotated(-PI / 2), heading.rotated(PI / 2)]:
		inputs.append(1.0 - clampf((ray_distance(robot.position, direction) - ROBOT_RADIUS) / SENSOR_RANGE, 0, 1))
	var target_vector: Vector2 = alert - robot.position if alert_active else Vector2.ZERO
	var target_direction = target_vector.normalized()
	inputs.append(target_direction.x)
	inputs.append(target_direction.y)
	inputs.append(target_vector.length() / SIZE.length())
	inputs.append(robot.velocity.x / ROBOT_SPEED)
	inputs.append(robot.velocity.y / ROBOT_SPEED)
	inputs.append(1.0 if alert_active else 0.0)
	if vision_enabled:
		var visible = sees_player(robot)
		var offset: Vector2 = player - robot.position if visible else Vector2.ZERO
		inputs.append(offset.normalized().x)
		inputs.append(offset.normalized().y)
		inputs.append(offset.length() / VISION_RANGE)
		inputs.append(1.0 if visible else 0.0)
	return inputs

func hurt_robot(robot: Dictionary, amount: float) -> void:
	if robot.health <= 0:
		return
	robot.health -= amount
	if robot.health <= 0:
		robot.parts.death = -6.0
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
	if lab and vision_enabled:
		move_training_player(delta)
	if not lab and player_health > 0:
		player = move_body(player, movement.limit_length() * PLAYER_SPEED * delta, PLAYER_RADIUS)
		if player.distance_to(alert) <= ALERT_RADIUS:
			alert_active = true # Latched area sighting; never follows player.
		if aim_at.distance_to(player) > 1:
			aim = player.direction_to(aim_at)
		if shooting and shoot_cooldown <= 0:
			bullets.append({"position": player, "velocity": aim * 700.0, "life": 1.8})
			shoot_cooldown = 0.14
		if melee and melee_cooldown <= 0:
			melee_cooldown = 0.55
			melee_flash = 0.14
			for robot in robots:
				var direction: Vector2 = robot.position - player
				if direction.length() < 64 and direction.normalized().dot(aim) > 0.25:
					if ray_distance(player, direction.normalized(), direction.length()) >= direction.length() - 0.01:
						hurt_robot(robot, 2.0)
	for robot in robots:
		if robot.health <= 0:
			continue
		var output: Vector2 = robot.genome.activate(observations(robot))
		var before: Vector2 = robot.position
		var visible = sees_player(robot)
		robot.position = move_body(before, output * ROBOT_SPEED * delta, ROBOT_RADIUS)
		robot.velocity = (robot.position - before) / delta
		if output.length_squared() > 0.01:
			robot.heading = output.normalized()
		robot.parts.survival += delta * 0.08
		if visible:
			robot.visible_time += delta
			robot.parts.pursuit += (before.distance_to(player) - robot.position.distance_to(player)) * 0.15
		if alert_active:
			# Signed potential difference, so cycling cannot farm progress.
			robot.parts.progress += (before.distance_to(alert) - robot.position.distance_to(alert)) * 0.10
			if not robot.reached and robot.position.distance_to(alert) <= ALERT_RADIUS:
				robot.reached = true
				robot.parts.arrival = 35.0 + 15.0 * maxf(0, 1.0 - elapsed / EPISODE_SECONDS)
		var requested_distance = output.length() * ROBOT_SPEED * delta
		if requested_distance > 0.1 and before.distance_to(robot.position) < requested_distance * 0.35:
			robot.wall_time += delta
			robot.parts.wall -= delta * 2.0
		robot.contact_timer = maxf(0, robot.contact_timer - delta)
		var touching = robot.position.distance_to(player) < ROBOT_RADIUS + PLAYER_RADIUS
		if lab and vision_enabled and touching and robot.contact_timer <= 0:
			# Each genome has an independent contact clock and invulnerable target.
			# One genome cannot steal another genome's evaluation opportunities.
			robot.contacts += 1
			robot.parts.damage += 8.0
			robot.contact_timer = 0.45
		if not lab and player_health > 0 and contact_cooldown <= 0 and touching:
			player_health = maxf(0, player_health - 10)
			robot.contacts += 1
			robot.parts.damage += 8.0
			contact_cooldown = 0.45
	for index in range(bullets.size() - 1, -1, -1):
		var bullet = bullets[index]
		var start: Vector2 = bullet.position
		var finish: Vector2 = start + bullet.velocity * delta
		var length = start.distance_to(finish)
		var nearest = ray_distance(start, bullet.velocity.normalized(), length) / length
		var wall_hit = nearest < 1.0
		var victim = null
		for robot in robots:
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
			bullets.remove_at(index)
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
	for robot in robots:
		reached += 1 if robot.reached else 0
		wall_time += robot.wall_time
		progress += robot.parts.progress / 0.10
		score += fitness(robot)
		contacted += 1 if robot.contacts > 0 else 0
		contacts += robot.contacts
		visible_time += robot.visible_time
	var count = maxi(1, robots.size())
	return {"arrival_rate": float(reached) / count, "wall_seconds": wall_time / count,
		"progress_px": progress / count, "fitness": score / count,
		"contact_rate": float(contacted) / count, "contacts": float(contacts) / count,
		"visible_seconds": visible_time / count}
