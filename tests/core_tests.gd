extends SceneTree

const Neat = preload("res://scripts/neat.gd")
const Sim = preload("res://scripts/simulation.gd")
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
	var neat = Neat.new(123, 12)
	var same_seed = Neat.new(123, 12)
	check(neat.population[0].genes == same_seed.population[0].genes, "Seed must reproduce initial genomes")
	var parent = neat.population[0]
	var copy = parent.copy()
	copy.genes[0].weight += 1
	check(copy.genes[0].weight != parent.genes[0].weight, "Genome copies must not share genes")
	# Force the same ancestral split in two genomes: node and link innovations align.
	var a = parent.copy()
	var b = parent.copy()
	neat.rng.seed = 99
	neat.add_node(a)
	neat.rng.seed = 99
	neat.add_node(b)
	check(a.nodes == b.nodes and a.genes == b.genes, "Same connection split must reuse historical markings")
	check(a.nodes.size() == 13, "Add-node mutation must change network topology")
	a.compile()
	var hidden_id = neat.next_node - 1
	check(a.nodes[hidden_id] > 0 and a.nodes[hidden_id] < 1, "Hidden node must be between input and output")
	a.fitness = 10
	b.fitness = 0
	b.genes[0].weight = -5
	var child = neat.crossover(a, b)
	check(child.nodes.size() == a.nodes.size(), "Crossover retains fitter parent's structure")
	for i in range(60):
		neat.mutate(child)
	var valid = true
	var ids = {}
	for gene in child.genes:
		valid = valid and child.nodes.has(gene.from) and child.nodes.has(gene.to)
		valid = valid and child.nodes[gene.from] < child.nodes[gene.to]
		valid = valid and not ids.has(gene.innovation)
		ids[gene.innovation] = true
	check(valid, "Repeated structural mutations must preserve a valid acyclic graph with unique innovations")
	var inputs = PackedFloat64Array([0, 0, 0, 1, 0, 0.5, 0, 0, 1])
	check(child.activate(inputs).is_finite(), "Mutated network must return finite outputs")
	check(child.activate(inputs).length() <= 1.000001, "Robot outputs must obey speed limit")
	var scores: Array = []
	for i in range(neat.population.size()):
		scores.append(float(i - 20)) # Negative fitness must still permit reproduction.
	var elite_genes: Array = neat.population[-1].genes.duplicate(true)
	neat.evolve(scores)
	check(neat.population.size() == 12, "Evolution must retain configured population size")
	check(neat.population[0].genes == elite_genes, "Champion must survive unchanged")
	check(neat.generation == 2 and neat.last_best == -9, "Generation metrics must correspond to evaluated population")

	var sim = Sim.new()
	sim.setup([parent], Vector2(450, 150), Vector2(100, 100))
	var robot = sim.robots[0]
	var blind = sim.observations(robot)
	sim.player = Vector2(123, 456)
	sim.bullets.append({"position": Vector2(110, 110), "velocity": Vector2.RIGHT, "life": 1.0})
	check(sim.observations(robot) == blind, "Stage A observations must not leak player/projectile truth")
	check(blind[3] == 0 and blind[4] == 0 and blind[5] == 0 and blind[8] == 0, "Inactive alert must provide no target")
	sim.player = sim.alert
	sim.step(Sim.STEP)
	check(sim.alert_active, "Player entering alert area must activate signal")
	var target = sim.alert
	sim.player = Vector2(800, 500)
	sim.step(Sim.STEP)
	check(sim.alert == target, "Facility signal must not track the player's position")
	check(sim.move_body(Vector2(20, 20), Vector2(-300, 0), 11).x >= 11, "Bodies cannot cross arena boundaries")
	check(sim.move_body(Vector2(240, 150), Vector2(300, 0), 11).x < 260, "Fast bodies cannot tunnel through walls")
	check(absf(sim.ray_distance(Vector2(240, 150), Vector2.RIGHT) - 20) < 0.01, "Wall sensors must report actual ray distance")
	check(sim.ray_distance(Vector2(50, 50), Vector2.RIGHT) == Sim.SENSOR_RANGE, "Empty ray must return its maximum range")

	# Disable robot movement for isolated combat and fitness checks.
	var still = parent.copy()
	for gene in still.genes:
		gene.weight = 0.0
	still.compile()
	sim.setup([still], Vector2(450, 150), Vector2(530, 450))
	sim.step(Sim.STEP, Vector2.ZERO, Vector2(530, 450), true)
	for i in range(10):
		sim.step(Sim.STEP)
	check(sim.robots[0].health == 1, "Bullet must damage robot exactly once")
	sim.robots[0].position = Vector2(490, 450)
	sim.step(Sim.STEP, Vector2.ZERO, Vector2(530, 450), false, true)
	check(sim.kills == 1 and sim.robots[0].parts.death == -6, "Melee kill must count once and record death fitness")
	sim.hurt_robot(sim.robots[0], 2)
	check(sim.kills == 1, "Dead robots must not be counted twice")
	sim.setup([still], Vector2(450, 150), Vector2(305, 150))
	sim.player = Vector2(240, 150)
	sim.step(Sim.STEP, Vector2.ZERO, Vector2(305, 150), true, true)
	for i in range(20):
		sim.step(Sim.STEP)
	check(sim.robots[0].health == 2, "Walls must block bullets and melee")
	sim.setup([still], Vector2(450, 150), Vector2(450, 450))
	sim.step(Sim.STEP)
	check(sim.player_health == 90 and sim.robots[0].parts.damage == 8, "Physical contact must damage player and reward robot")
	sim.step(Sim.STEP)
	check(sim.player_health == 90, "Contact damage must respect cooldown")
	sim.setup([still], Vector2(450, 150), Vector2(450, 150), true)
	sim.step(Sim.STEP)
	var arrival: float = sim.robots[0].parts.arrival
	sim.step(Sim.STEP)
	check(arrival > 0 and sim.robots[0].parts.arrival == arrival, "Arrival bonus must be paid once per trial")
	print("CORE TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
