extends SceneTree

const Neat = preload("res://scripts/neat.gd")
const Training = preload("res://scripts/training.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var generations = 30
	var seed_value = 42
	var count = 48
	var output = "res://reports/benchmark.json"
	var vision = false
	var snapshot_path = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--generations="):
			generations = maxi(1, argument.get_slice("=", 1).to_int())
		elif argument.begins_with("--seed="):
			seed_value = argument.get_slice("=", 1).to_int()
		elif argument.begins_with("--population="):
			count = maxi(4, argument.get_slice("=", 1).to_int())
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument == "--stage=vision":
			vision = true
		elif argument.begins_with("--save-navigation="):
			snapshot_path = argument.trim_prefix("--save-navigation=")
	var evolution = Neat.new(seed_value, count)
	if vision:
		evolution.unlock_vision()
	var training_cases = Training.VISION_CASES if vision else Training.TRAIN_CASES
	var holdout_cases = Training.VISION_HOLDOUT if vision else Training.HOLDOUT_CASES
	var baseline = Training.evaluate(evolution.population, holdout_cases)
	var rows: Array = []
	var initial_champion_holdout: Dictionary = {}
	var final_champion_holdout: Dictionary = {}
	var started = Time.get_ticks_msec()
	for generation in range(generations):
		var result = Training.evaluate(evolution.population, training_cases)
		evolution.evolve(result.scores)
		var row = result.metrics.duplicate()
		row.generation = generation + 1
		row.best = evolution.last_best
		row.species = evolution.species_records.size()
		row.champion_nodes = evolution.champion.nodes.size()
		rows.append(row)
		if generation == 0:
			initial_champion_holdout = Training.evaluate([evolution.champion], holdout_cases).metrics
		print("GEN %02d best=%7.2f mean=%7.2f arrival=%5.1f%% wall=%4.1fs species=%d nodes=%d" % [
			generation + 1, row.best, row.fitness, row.arrival_rate * 100, row.wall_seconds, row.species, row.champion_nodes])
		if vision:
			print("  CONTACT %.1f%%  hits/bot %.2f" % [row.contact_rate * 100, row.contacts])
		await process_frame
	final_champion_holdout = Training.evaluate([evolution.champion], holdout_cases).metrics
	var final_population = Training.evaluate(evolution.population, holdout_cases)
	var report = {"seed": seed_value, "population": count, "generations": generations,
		"stage": "vision" if vision else "navigation",
		"baseline_population_holdout": baseline.metrics, "initial_champion_holdout": initial_champion_holdout,
		"final_champion_holdout": final_champion_holdout, "final_population_holdout": final_population.metrics,
		"training": rows, "elapsed_seconds": (Time.get_ticks_msec() - started) / 1000.0}
	if vision:
		report.blind_population_holdout = Training.evaluate(evolution.population, holdout_cases, true).metrics
		print("HOLDOUT vision disabled:   ", report.blind_population_holdout)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Could not write benchmark report: " + output)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	print("HOLDOUT baseline population: ", baseline.metrics)
	print("HOLDOUT initial champion:   ", initial_champion_holdout)
	print("HOLDOUT final champion:     ", final_champion_holdout)
	print("HOLDOUT final population:   ", final_population.metrics)
	print("REPORT ", ProjectSettings.globalize_path(output))
	if not snapshot_path.is_empty():
		if vision:
			push_error("Navigation snapshots must not contain vision training")
			quit(1)
			return
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(snapshot_path.get_base_dir()))
		var snapshot = FileAccess.open(snapshot_path, FileAccess.WRITE)
		if snapshot == null:
			quit(1)
			return
		snapshot.store_string(JSON.stringify(evolution.navigation_snapshot()))
		print("NAVIGATION SNAPSHOT ", snapshot_path)
	quit()
