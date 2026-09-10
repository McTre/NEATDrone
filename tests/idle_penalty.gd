extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Neat = preload("res://scripts/neat.gd")
func _initialize() -> void:
	var sim = Sim.new()
	var neat = Neat.new(42, 4)
	sim.setup([neat.population[0]], Vector2(300, 60), Vector2(100, 60), true)
	var robot = sim.robots[0]
	var position: Vector2 = robot.position
	var genes = robot.genome.genes.duplicate(true)
	sim.score_idle(robot, 2, true, false)
	assert(robot.parts.idle == 0, "Grace period must not penalize brief stops")
	sim.score_idle(robot, 1, true, false)
	assert(robot.parts.idle == -3)
	for tick in range(60):
		robot.position = position + Vector2(5 if tick % 2 == 0 else -5, 0)
		sim.score_idle(robot, Sim.STEP, true, false)
	assert(is_equal_approx(robot.parts.idle, -6), "Small oscillations cannot reset stagnation")
	robot.position = position + Vector2(30, 0)
	sim.score_idle(robot, Sim.STEP, true, false)
	assert(robot.idle_seconds == 0)
	for reason in [0, 1]:
		sim.score_idle(robot, 20, reason == 1, reason == 1)
		assert(is_equal_approx(robot.parts.idle, -6), "No objective, queueing or attacking must be exempt")
	assert(robot.genome.genes == genes, "Fitness cannot directly rewrite current policy")
	assert(robot.velocity == Vector2.ZERO, "Scoring must not introduce an escape movement")
	# Real simulation integration: an inactive policy at an active signal is penalized.
	for gene in robot.genome.genes:
		gene.weight = 0
	robot.genome.compile()
	sim.setup([robot.genome], Vector2(300, 60), Vector2(100, 60), true)
	for tick in range(240):
		sim.step(Sim.STEP)
	assert(is_equal_approx(sim.robots[0].parts.idle, -6))
	assert(sim.robots[0].position == Vector2(100, 60))
	var moving = robot.genome.copy()
	for gene in moving.genes:
		if gene.from == 9 and gene.to == 10:
			gene.weight = 1
	moving.compile()
	sim.setup([moving, robot.genome], Vector2(300, 60), Vector2(100, 60))
	sim.robots[1].position = Vector2(122, 60)
	sim.alert_active = true
	for tick in range(240):
		sim.step(Sim.STEP)
	assert(sim.robots[0].parts.idle == 0, "Actual collision queue must be exempt")
	assert(sim.robots[1].parts.idle < -5, "Idle leader must still receive the penalty")
	sim.setup([robot.genome], Vector2(300, 60), Vector2(450, 450))
	sim.alert_active = true
	for tick in range(240):
		sim.step(Sim.STEP)
	assert(sim.robots[0].parts.idle == 0 and sim.robots[0].contacts > 0, "Active contact attacks are not idling")
	print("IDLE PENALTY: grace, stationary policy, jitter, progress reset, exemptions and no automatic movement passed")
	quit()
