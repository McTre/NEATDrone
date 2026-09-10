extends SceneTree
const Neat = preload("res://scripts/neat.gd")
const Training = preload("res://scripts/training.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/navigation.json"))
	var starter = Neat.new(42, 8)
	assert(starter.load_navigation(data))
	assert(starter.population.size() == 8 and starter.generation == 1)
	assert(starter.pretrained_generations == 30 and not starter.vision_enabled)
	var repeated = Neat.new(42, 8)
	assert(repeated.load_navigation(data))
	for i in range(8):
		assert(starter.population[i].genes == repeated.population[i].genes)
		assert(starter.population[i].input_ids.size() == 9)
	# Keep startup validation independent from the offline selection task.
	var baseline = Training.evaluate(Neat.new(42, 8).population, Training.HOLDOUT_CASES)
	var pretrained = Training.evaluate(starter.population, Training.HOLDOUT_CASES)
	assert(pretrained.metrics.arrival_rate > baseline.metrics.arrival_rate)
	var before: Dictionary = starter.population[0].nodes.duplicate()
	starter.unlock_vision()
	assert(starter.population[0].input_ids.size() == 13)
	for id in before:
		assert(starter.population[0].nodes[id] == before[id])
	starter.evolve(pretrained.scores)
	assert(starter.population.size() == 8 and starter.generation == 2)
	for genome in starter.population:
		assert(genome.activate(PackedFloat64Array([0, 0, 0, 1, 0, 0.5, 0, 0, 1, 0, 0, 0, 0])).is_finite())
	var report = {"seed": 42, "active_robots": 8, "offline_generations": 30,
		"fresh_start": baseline.metrics, "pretrained_start": pretrained.metrics}
	var file = FileAccess.open("res://build/pretrained-start.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report, "\t"))
	print("PRETRAINED START: ", report)
	print("Snapshot loading, deterministic selection, navigation-only schema and continued evolution passed")
	quit()
