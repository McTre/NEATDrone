extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.report_path = "user://ota_test.csv"
	root.add_child(arena)
	arena.set_process(false)
	arena.sim.player = Vector2(450, 350)
	arena.finish_wave()
	assert(arena.sim.player == Vector2(450, 350), "Wave transition must preserve player position")
	var wave: int = arena.wave
	for tick in range(899):
		arena.advance_combat_events(Sim.STEP)
	assert(arena.sim.robots.size() == 8)
	arena.advance_combat_events(Sim.STEP)
	assert(arena.sim.robots.size() == 9 and arena.sim.robots[-1].incoming)
	assert(arena.sim.robots[-1].heading == Sim.RoomLayout.DIRECTIONS[arena.sim.entry_index])
	var survivor = arena.sim.robots[0]
	survivor.health = 1
	survivor.velocity = Vector2(4, 7)
	survivor.parts.idle = -30
	var position: Vector2 = survivor.position
	var heading: Vector2 = survivor.heading
	var old_genome = survivor.genome
	arena.sim.hurt_robot(arena.sim.robots[1], 3)
	for tick in range(2699):
		arena.advance_combat_events(Sim.STEP)
	assert(survivor.genome == old_genome, "No early OTA before 60 seconds")
	var scores = arena.combat_scores()
	var expected = 0.0
	for score in scores:
		expected += score / scores.size()
	arena.advance_combat_events(Sim.STEP)
	assert(is_equal_approx(arena.evolution.last_average, expected), "OTA selection includes the dead drone and idle penalties")
	assert(survivor.genome != old_genome and survivor.updated_seconds == 2)
	assert(survivor.health == 1 and survivor.position == position and survivor.heading == heading)
	assert(survivor.velocity == Vector2(4, 7))
	assert(survivor.parts.idle == 0 and arena.sim.robots[1].evaluation_slot == -1)
	assert(arena.sim.robots[1].health == 0, "OTA must not resurrect dead drones")
	assert(arena.sim.initial_population == 12 and arena.wave == wave)
	assert(arena.sim.alive_count() == 11)
	for score in arena.combat_scores():
		assert(score == 0, "Old penalties must not be scored again")
	# Last kill wins over a reinforcement due on the same tick.
	for robot in arena.sim.robots:
		arena.sim.hurt_robot(robot, 3)
	arena.next_reinforcement = arena.combat_clock + Sim.STEP
	arena.advance_combat_events(Sim.STEP)
	assert(arena.wave_complete() and arena.sim.alive_count() == 0)
	arena.finish_wave()
	assert(arena.sim.robots.size() == 8 and arena.sim.player == Vector2(450, 350))
	# Position must survive the hardware intermission too.
	arena.vision_requested = true
	arena.finish_wave()
	assert(arena.upgrade_screen != null)
	arena.upgrade_screen.advance(15)
	assert(arena.sim.player == Vector2(450, 350))
	print("OTA TESTS: exact 15/60-second events, dead scores, physical state, new brains, wave priority and player position passed")
	quit()
