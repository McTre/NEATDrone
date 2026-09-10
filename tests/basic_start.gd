extends SceneTree
const Neat = preload("res://scripts/neat.gd")
const Sim = preload("res://scripts/simulation.gd")
const Training = preload("res://scripts/training.gd")
const Basic = preload("res://tests/train_basic.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var neat = Neat.new(42, 8)
	assert(neat.load_navigation(JSON.parse_string(FileAccess.get_file_as_string("res://assets/basic.json"))))
	assert(neat.vision_enabled and not neat.long_vision_enabled and not neat.projectiles_enabled)
	var sim = Sim.new()
	sim.setup(neat.population, Vector2(150, 60), Vector2(100, 60), true)
	sim.vision_range = 120
	sim.player = Vector2(219, 60)
	assert(sim.sees_player(sim.robots[0]))
	assert(sim.observations(sim.robots[0])[8] == 0, "Visible target takes priority over area report")
	sim.player = Vector2(221, 60)
	assert(not sim.sees_player(sim.robots[0]))
	assert(sim.observations(sim.robots[0])[8] == 1, "Area report returns after losing sight")
	sim.robots[0].position = Vector2(240, 150)
	sim.player = Vector2(310, 150)
	assert(not sim.sees_player(sim.robots[0]), "Short sight must respect walls")
	var ids = neat.population[0].input_ids.duplicate()
	var genes = neat.population[0].genes.duplicate(true)
	neat.unlock_vision()
	assert(neat.long_vision_enabled and neat.population[0].input_ids == ids)
	assert(neat.population[0].genes == genes, "Range upgrade must preserve learned policy")
	var old = Neat.new(42, 8)
	assert(old.load_navigation(JSON.parse_string(FileAccess.get_file_as_string("res://assets/navigation.json"))))
	old.unlock_vision()
	var before = Training.evaluate(old.population, Basic.HOLDOUT, false, 120).metrics
	var after = Training.evaluate(neat.population, Basic.HOLDOUT, false, 120).metrics
	var navigation = Training.evaluate(neat.population, Training.HOLDOUT_CASES).metrics
	print("STARTER CHECK: contact=", after.contact_rate, " arrival=", navigation.arrival_rate)
	assert(after.contact_rate > before.contact_rate, "Starter must improve held-out pursuit")
	assert(after.contact_rate >= 0.75, "Starter must reliably reach a nearby unarmed target")
	assert(navigation.arrival_rate >= 0.75, "Starter must retain useful navigation")
	var report = {"seed": 42, "robots": 8, "old_attack": before, "new_attack": after, "navigation": navigation}
	FileAccess.open("res://build/basic-start.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("BASIC START: ", report)
	quit()
