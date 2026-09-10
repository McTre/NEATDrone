extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/arena.tscn").instantiate()
	scene.report_path = "user://scene_smoke.csv"
	root.add_child(scene)
	await process_frame
	scene.paused = true
	# Exercise a complete lab generation, combat restart and debug rendering.
	scene.laboratory = true
	scene.reset_population()
	scene.paused = true
	for i in range(4):
		scene.sim.step(1.0 / 60.0)
		scene.finish_wave()
	assert(scene.evolution.generation == 2)
	assert(scene.history.size() == 1)
	scene.save_champion("user://scene_smoke_champion.json")
	assert(FileAccess.file_exists("user://scene_smoke_champion.json"))
	assert(FileAccess.get_file_as_string(scene.report_path).split("\n", false).size() == 2)
	scene.laboratory = false
	scene.reset_population()
	scene.paused = true
	scene.sensors = true
	scene.sim.player = scene.sim.alert
	scene.sim.step(1.0 / 60.0)
	scene.vision_requested = true
	scene.finish_wave()
	assert(scene.evolution.vision_enabled)
	assert(scene.sim.observations(scene.sim.robots[0]).size() == 13)
	var event = InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_C
	scene.laboratory = true
	var generation: int = scene.evolution.generation
	scene._unhandled_key_input(event)
	assert(scene.deployment and not scene.laboratory)
	scene.finish_wave()
	assert(scene.evolution.generation == generation)
	scene._unhandled_key_input(event)
	assert(scene.laboratory and not scene.deployment)
	scene.sim.step(1.0 / 60.0)
	scene.queue_redraw()
	await process_frame
	await process_frame
	if "--screenshot" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var screenshot = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
		assert(screenshot.save_png("res://reports/arena.png") == OK)
	print("SCENE SMOKE: evolution, vision upgrade, trained combat, telemetry, export and drawing passed")
	quit()
