extends SceneTree

const Neat = preload("res://scripts/neat.gd")
const Sim = preload("res://scripts/simulation.gd")
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var neat = Neat.new(42, 8)
	neat.unlock_vision()
	var inputs = PackedFloat64Array([0, 0, 0, 1, 0, 0.5, 0, 0, 1, 1, 0, 0.5, 1])
	var before: Vector2 = neat.population[0].activate(inputs)
	neat.unlock_projectiles()
	inputs.append_array(PackedFloat64Array([1, 0, 0.5, -1, 0, 1]))
	check(neat.population[0].activate(inputs).is_equal_approx(before), "Upgrade must preserve existing policy")
	neat.unlock_projectiles()
	check(neat.population[0].input_ids.size() == 19, "Repeated upgrade must keep 19 inputs")
	neat.evolve([1, 2, 3, 4, 5, 6, 7, 8])
	for genome in neat.population:
		check(genome.input_ids.size() == 19 and genome.activate(inputs).is_finite(), "Offspring retain projectile inputs")
	var sim = Sim.new()
	sim.setup([neat.population[0]], Vector2(150, 100), Vector2(100, 100), true)
	var robot = sim.robots[0]
	check(sim.observations(robot).slice(13) == PackedFloat64Array([0, 0, 0, 0, 0, 0]), "No bullet must yield zero observations")
	sim.bullets.append({"position": Vector2(160, 100), "velocity": Vector2(-700, 0), "life": 1.0})
	var sensed = sim.observations(robot)
	check(sensed[13] == 1 and is_equal_approx(sensed[15], 0.2) and sensed[16] == -1 and sensed[18] == 1, "Sensor reports relative position and actual bullet velocity")
	sim.projectile_blind_test = true
	check(sim.observations(robot).slice(13) == PackedFloat64Array([0, 0, 0, 0, 0, 0]), "Ablation zeroes projectile observations")
	sim.projectile_blind_test = false
	sim.bullets[0].position = Vector2(401, 100)
	check(sim.perceived_projectile(robot) == null, "Range limits vision")
	robot.position = Vector2(240, 150)
	sim.bullets[0].position = Vector2(310, 150)
	check(sim.perceived_projectile(robot) == null, "Walls occlude bullets")
	sim.bullets.append({"position": Vector2(240, 240), "velocity": Vector2.UP * 700, "life": 1.0})
	check(sim.perceived_projectile(robot).position == Vector2(240, 240), "Select nearest visible bullet, ignoring nearer occluded bullet")
	sim.firing_trial = true
	check(sim.perceived_projectile(robot) == null, "Private trials must not expose other bullets")
	sim.firing_trial = false
	robot.position = Vector2(90, 100)
	sim.score_navigation(robot, Vector2(20, 100), false)
	var progress: float = robot.parts.progress
	robot.position = sim.alert
	sim.score_navigation(robot, Vector2(90, 100), false)
	check(robot.parts.progress == progress, "Moving from boundary to center earns no approach reward")
	var search: float = robot.parts.search
	sim.score_navigation(robot, sim.alert, false)
	check(robot.parts.search == search and robot.parts.arrival == 5, "Standing still cannot repeat search or arrival rewards")
	robot.position = Vector2(20, 100)
	sim.score_navigation(robot, sim.alert, false)
	robot.position = sim.alert
	sim.score_navigation(robot, Vector2(20, 100), false)
	check(robot.parts.progress == progress and robot.parts.search == search, "Repeating a route cannot farm progress or explored cells")
	sim.setup([neat.population[0]], Vector2(150, 100), Vector2(100, 100), true)
	robot = sim.robots[0]
	sim.score_navigation(robot, Vector2(20, 100), true)
	check(robot.parts.progress == 0 and robot.parts.search == 0 and robot.parts.arrival == 0, "Player visibility suppresses navigation rewards")
	sim.hurt_robot(robot, 1)
	check(robot.parts.injury == -12 and sim.kills == 0, "Nonfatal hit penalizes fitness immediately")
	sim.hurt_robot(robot, 1)
	check(robot.health == 1 and sim.kills == 0, "Two shots must leave one health point")
	sim.hurt_robot(robot, 1)
	check(robot.parts.injury + robot.parts.death == -71 and sim.kills == 1, "Third shot kills and outweighs maximum navigation rewards")
	sim.hurt_robot(robot, 1)
	check(robot.parts.injury == -36 and sim.kills == 1, "Death is scored only once")
	var still = neat.population[0].copy()
	for gene in still.genes:
		gene.weight = 0.0
	still.compile()
	sim.setup([still, still.copy()], Vector2(150, 100), Vector2(100, 100), true)
	sim.player = Vector2(180, 100)
	sim.firing_trial = true
	for tick in range(45):
		sim.step(Sim.STEP)
	check(sim.kills == 2 and sim.robots[0].hits == 3 and sim.robots[1].hits == 3, "Overlapping lab robots each receive independent gunfire")
	check(sim.metrics().survival_rate == 0 and sim.metrics().survival_seconds > 0, "Combat metrics measure actual survival")
	print("PROJECTILE TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
