extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Neat = preload("res://scripts/neat.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sim = Sim.new()
	var genome = Neat.new(42, 4).population[0]
	sim.setup([genome], Vector2(450, 150), Vector2(400, 60), true)
	sim.bullets.append({"position": Vector2(100, 60), "velocity": Vector2.RIGHT * Sim.BULLET_SPEED, "life": 1.8, "remaining": Sim.BULLET_RANGE})
	sim.advance_shots(sim.bullets, sim.robots, 0.34)
	assert(is_equal_approx(sim.bullets[0].position.x, 338))
	sim.advance_shots(sim.bullets, sim.robots, 0.1)
	assert(sim.bullets.is_empty() and sim.robots[0].health == 3, "Last step must stop at range instead of overshooting into target")
	sim.robots[0].position = Vector2(360, 60) # Near surface is within 250 pixels.
	for shot in range(3):
		sim.bullets.append({"position": Vector2(100, 60), "velocity": Vector2.RIGHT * Sim.BULLET_SPEED, "life": 1.8})
		sim.advance_shots(sim.bullets, sim.robots, 1)
		assert(sim.robots[0].health == 2 - shot)
	assert(sim.kills == 1)
	var scene = load("res://scenes/arena.tscn").instantiate()
	scene.report_path = "user://combat_rules.csv"
	root.add_child(scene)
	scene.set_process(false)
	scene.sim.elapsed = 10000
	assert(not scene.wave_complete(), "Elapsed time cannot end combat")
	for i in range(scene.sim.robots.size() - 1):
		scene.sim.hurt_robot(scene.sim.robots[i], Sim.ROBOT_HEALTH)
	assert(not scene.wave_complete(), "Last survivor keeps the wave alive")
	scene.sim.hurt_robot(scene.sim.robots[-1], Sim.ROBOT_HEALTH)
	assert(scene.wave_complete())
	scene.laboratory = true
	scene.reset_population()
	scene.sim.elapsed = Sim.EPISODE_SECONDS
	assert(scene.wave_complete(), "Lab trials still need a fixed evaluation duration")
	print("COMBAT RULES: exact projectile range, three-hit health, elimination-only combat and timed training passed")
	quit()
