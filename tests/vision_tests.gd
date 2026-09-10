extends SceneTree

const Neat = preload("res://scripts/neat.gd")
const Sim = preload("res://scripts/simulation.gd")
const Training = preload("res://scripts/training.gd")
var failures = 0
var checks = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var neat = Neat.new(77, 8)
	neat.add_node(neat.population[0])
	neat.population[0].compile()
	var before_nodes: Dictionary = neat.population[0].nodes.duplicate()
	var old_observations = PackedFloat64Array([0.2, 0.5, 0.8, 0.6, 0.4, 0.3, 0.1, 0.2, 1])
	var before_output = neat.population[0].activate(old_observations)
	neat.unlock_vision()
	var extended = old_observations.duplicate()
	extended.append_array(PackedFloat64Array([0.9, -0.6, 0.2, 1]))
	check(neat.population[0].activate(extended).is_equal_approx(before_output), "Upgrade must preserve policy even when the new sensor sees a player")
	check(neat.population[0].nodes.size() == before_nodes.size() + 4, "Upgrade adds four inputs without overwriting evolved hidden nodes")
	var preserved = true
	for id in before_nodes:
		preserved = preserved and neat.population[0].nodes[id] == before_nodes[id]
	check(preserved, "Existing node IDs and depths must survive upgrade")
	var count: int = neat.population[0].genes.size()
	neat.unlock_vision()
	check(neat.population[0].genes.size() == count, "Upgrade must be idempotent")
	check(neat.population[0].copy().input_ids == neat.population[0].input_ids, "Copies must preserve input schema")
	var scores: Array = []
	scores.resize(8)
	scores.fill(1.0)
	neat.evolve(scores)
	for genome in neat.population:
		check(genome.input_ids.size() == 13 and genome.activate(extended).is_finite(), "Offspring must retain the upgraded schema")

	var sim = Sim.new()
	sim.setup([neat.population[0]], Vector2(450, 150), Vector2(100, 100), true)
	var robot = sim.robots[0]
	sim.player = Vector2(180, 100)
	check(sim.sees_player(robot), "Unoccluded nearby player must be visible")
	var observations = sim.observations(robot)
	check(observations.size() == 13 and observations[9] == 1 and observations[12] == 1, "Vision inputs must describe relative direction and visibility")
	sim.player = Vector2(500, 100)
	check(sim.observations(robot).slice(9) == PackedFloat64Array([0, 0, 0, 0]), "Out-of-range player must leave no coordinates in inputs")
	robot.position = Vector2(240, 150)
	sim.player = Vector2(310, 150)
	check(not sim.sees_player(robot), "Wall must occlude nearby player")
	var hidden = sim.observations(robot)
	sim.player = Vector2(320, 180)
	check(sim.observations(robot) == hidden, "Movement behind an opaque wall must not leak into observations")
	robot.position = Vector2(100, 100)
	sim.player = Vector2(180, 100)
	check(sim.observations(robot)[12] == 1, "Vision must reacquire after line of sight returns")
	sim.blind_test = true
	check(sim.observations(robot).slice(9) == PackedFloat64Array([0, 0, 0, 0]), "Blind ablation must keep network schema but zero all vision observations")

	var still = neat.population[0].copy()
	for gene in still.genes:
		gene.weight = 0.0
	still.compile()
	sim.setup([still, still.copy()], Vector2(450, 150), Vector2(450, 450), true)
	sim.step(Sim.STEP)
	check(sim.robots[0].contacts == 1 and sim.robots[1].contacts == 1, "Lab genomes must not compete for the target's contact cooldown")
	check(sim.player_health == 100 and sim.metrics().contact_rate == 1, "Lab target must stay invulnerable while contacts are measured")
	check(sim.robots[0].parts.pursuit == 0, "Stationary robot must not earn pursuit progress")
	sim.step(Sim.STEP)
	check(sim.robots[0].contacts == 1, "Lab contact clock must rate-limit repeated hits")
	for scenario in Training.VISION_CASES + Training.VISION_HOLDOUT:
		Training.setup_vision(sim, [still], scenario)
		var start: Vector2 = sim.player
		for tick in range(120):
			sim.step(Sim.STEP)
		check(sim.player.distance_to(start) > 30 and not sim.blocked(sim.player, Sim.PLAYER_RADIUS), "Every moving-target trial must actually move without penetrating walls")
	print("VISION TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
