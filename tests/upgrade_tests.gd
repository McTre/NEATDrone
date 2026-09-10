extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.report_path = "user://upgrade_test.csv"
	root.add_child(arena)
	arena.set_process(false)
	for projectile in [false, true]:
		if projectile:
			arena.projectile_requested = true
		else:
			arena.vision_requested = true
		arena.finish_wave()
		assert(is_instance_valid(arena.upgrade_screen))
		var screen = arena.upgrade_screen
		var elapsed: float = arena.sim.elapsed
		var generation: int = arena.evolution.generation
		var genes = arena.evolution.population[0].genes.duplicate(true)
		var event = InputEventKey.new()
		event.physical_keycode = KEY_N
		event.pressed = true
		arena._unhandled_key_input(event)
		arena.finish_wave()
		for tick in range(30):
			screen.advance(1.0 / 60)
		assert(arena.sim.elapsed == elapsed, "Live combat must remain frozen")
		assert(arena.evolution.generation == generation, "Input must not evolve during transition")
		assert(arena.evolution.population[0].genes == genes, "Preview must not mutate live genomes")
		assert(screen.ticks > 0, "Telemetry must come from a running simulation")
		assert(screen.projectile == projectile)
		# Complete training deterministically, independent of machine speed.
		for tick in range(1920):
			screen.training_step()
		assert(screen.completed_generations >= 2, "Complete trial sets must evolve")
		assert(screen.results.size() == screen.completed_generations)
		assert(arena.evolution.population[0].genes == genes, "Training remains isolated until deployment")
		var trained = screen.learner
		var trained_genes = trained.population.map(func(genome): return genome.genes.duplicate(true))
		var completed: int = screen.completed_generations
		# An unfinished trial cannot breed or change the committed population.
		screen.setup_trial()
		screen.training_step()
		assert(screen.completed_generations == completed)
		if projectile and "--screenshot" in OS.get_cmdline_user_args():
			screen.elapsed = 5.0
			screen.update_labels()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/upgrade-screen.png")
		screen.advance(15.0)
		assert(arena.upgrade_screen == null)
		assert(arena.evolution == trained, "Next wave must use the trained evolution state")
		assert(arena.evolution.generation == generation, "Training must preserve upgrade schedule")
		assert(arena.evolution.champion == null, "Training fitness must not be exported as combat fitness")
		for i in range(trained_genes.size()):
			assert(arena.sim.robots[i].genome.genes == trained_genes[i])
		assert(arena.sim.elapsed == 0, "Next wave starts fresh without catch-up ticks")
		assert(arena.sim.observations(arena.sim.robots[0]).size() == (19 if projectile else 13))
	arena.finish_wave()
	assert(arena.upgrade_screen == null, "Already installed upgrades must not repeat")
	print("UPGRADE TESTS: isolated evolution, complete evaluations, trained deployment, upgrade schedule and resume passed")
	quit()
