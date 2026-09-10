extends SceneTree
const Neat = preload("res://scripts/neat.gd")
const Training = preload("res://scripts/training.gd")
const Sim = preload("res://scripts/simulation.gd")
const CASES = [
	[Vector2(100, 60), Vector2(60, 60), Vector2(175, 60), [Vector2(250, 60), Vector2(150, 60)]],
	[Vector2(800, 520), Vector2(840, 520), Vector2(725, 520), [Vector2(650, 520), Vector2(750, 520)]],
	[Vector2(760, 150), Vector2(760, 100), Vector2(760, 230), [Vector2(760, 310), Vector2(760, 200)]],
	[Vector2(140, 430), Vector2(140, 480), Vector2(140, 350), [Vector2(140, 270), Vector2(140, 380)]],
]
const HOLDOUT = [
	[Vector2(300, 60), Vector2(250, 60), Vector2(390, 60), [Vector2(440, 60), Vector2(350, 60)]],
	[Vector2(570, 520), Vector2(620, 520), Vector2(480, 520), [Vector2(420, 520), Vector2(530, 520)]],
	[Vector2(800, 300), Vector2(800, 340), Vector2(800, 210), [Vector2(800, 140), Vector2(800, 260)]],
	[Vector2(100, 260), Vector2(100, 210), Vector2(100, 350), [Vector2(100, 410), Vector2(100, 300)]],
]

func _initialize() -> void:
	call_deferred("run")

static func balanced_starters(population: Array) -> Array:
	var arrivals: Array = []
	var attacks: Array = []
	arrivals.resize(population.size())
	attacks.resize(population.size())
	arrivals.fill(0)
	attacks.fill(0)
	var sim = Sim.new()
	for scenario in Training.TRAIN_CASES:
		sim.setup(population, scenario[1], scenario[0], true)
		sim.blind_test = true
		sim.player = Vector2(-1000, -1000)
		for tick in range(960):
			sim.step(Sim.STEP)
		for i in range(population.size()):
			arrivals[i] += 1 if sim.robots[i].reached else 0
	for scenario in CASES:
		Training.setup_vision(sim, population, scenario)
		sim.vision_range = 120
		for tick in range(960):
			sim.step(Sim.STEP)
		for i in range(population.size()):
			attacks[i] += 1 if sim.robots[i].contacts > 0 else 0
	var accepted: Array = []
	for i in range(population.size()):
		if arrivals[i] >= 3 and attacks[i] >= 3:
			accepted.append(population[i])
	print("BALANCED STARTERS: %d / %d meet both 3-of-4 training criteria" % [accepted.size(), population.size()])
	assert(not accepted.is_empty())
	return accepted

func run() -> void:
	var neat = Neat.new(42, 32)
	assert(neat.load_navigation(JSON.parse_string(FileAccess.get_file_as_string("res://assets/navigation.json"))))
	neat.unlock_vision()
	neat.long_vision_enabled = false
	var report = {"seed": 42, "population": 32, "generations": 40,
		"before_navigation": Training.evaluate(neat.population, Training.HOLDOUT_CASES).metrics,
		"before_attack": Training.evaluate(neat.population, HOLDOUT, false, 120).metrics, "training": []}
	for iteration in range(40):
		var nav = Training.evaluate(neat.population, Training.TRAIN_CASES)
		var attack = Training.evaluate(neat.population, CASES, false, 120)
		var scores: Array = []
		for i in range(neat.population_size):
			# Balance many repeat contacts against a single navigation arrival.
			scores.append(nav.scores[i] + attack.scores[i] * 0.2)
		neat.evolve(scores)
		report.training.append({"generation": iteration + 1, "arrival": nav.metrics.arrival_rate,
			"contact": attack.metrics.contact_rate, "best": neat.last_best})
		print("BASIC %d arrival=%.1f%% contact=%.1f%% best=%.2f" % [iteration + 1, nav.metrics.arrival_rate * 100, attack.metrics.contact_rate * 100, neat.last_best])
		await process_frame
	neat.population = balanced_starters(neat.population)
	report.accepted_starters = neat.population.size()
	report.after_navigation = Training.evaluate(neat.population, Training.HOLDOUT_CASES).metrics
	report.after_attack = Training.evaluate(neat.population, HOLDOUT, false, 120).metrics
	FileAccess.open("res://assets/basic.json", FileAccess.WRITE).store_string(JSON.stringify(neat.navigation_snapshot(true)))
	FileAccess.open("res://build/basic-training.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("BASIC HOLDOUT: ", report.after_navigation, report.after_attack)
	quit()
