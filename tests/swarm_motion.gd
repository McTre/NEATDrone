extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
class Policy extends RefCounted:
	var input_ids: Array = range(9)
	var direction = Vector2.RIGHT
	func activate(_inputs):
		return direction

func _initialize() -> void:
	var sim = Sim.new()
	var policies: Array = []
	for i in range(12):
		policies.append(Policy.new())
	sim.setup(policies, Vector2(150, 60), Vector2(100, 60))
	for tick in range(300):
		for i in range(policies.size()):
			policies[i].direction = sim.robots[i].position.direction_to(Vector2(240, 150))
		sim.step(Sim.STEP)
		for i in range(sim.robots.size()):
			assert(not sim.blocked(sim.robots[i].position, Sim.ROBOT_RADIUS))
			for j in range(i):
				assert(sim.robots[i].position.distance_to(sim.robots[j].position) >= 2 * Sim.ROBOT_RADIUS - 0.001, "Swarm must occupy separate space, including near walls")
	sim.setup([policies[0]], Vector2(150, 60), Vector2(100, 60), true)
	var robot = sim.robots[0]
	robot.velocity = Vector2.RIGHT * Sim.ROBOT_SPEED
	var displacement = sim.steer_robot(robot, Vector2.LEFT, Sim.STEP)
	assert(absf(Vector2.RIGHT.angle_to(robot.heading)) <= Sim.ROBOT_TURN_SPEED * Sim.STEP + 0.00001)
	assert(displacement.x > 0, "A full-speed reversal must brake before changing travel direction")
	assert((displacement / Sim.STEP - robot.velocity).length() <= Sim.ROBOT_ACCELERATION * Sim.STEP + 0.001)
	sim.setup([policies[0], policies[1]], Vector2(150, 60), Vector2(100, 60))
	sim.robots[1].position = Vector2(122, 60)
	policies[0].direction = Vector2.RIGHT
	policies[1].direction = Vector2.LEFT
	for tick in range(60):
		sim.step(Sim.STEP)
	assert(sim.robots[0].parts.wall == 0 and sim.robots[1].parts.wall == 0, "Another drone is not a wall fitness penalty")
	sim.hurt_robot(sim.robots[1], 2)
	assert(sim.robot_space_free(Vector2(122, 60), sim.robots[0]), "Dead drones must not block the swarm")
	sim.setup([policies[0], policies[1]], Vector2(150, 60), Vector2(100, 60), true)
	assert(sim.robots[0].position == sim.robots[1].position, "Independent lab trials may share coordinates")
	print("SWARM MOTION: turn/acceleration limits, dense swarm, walls, spawn separation, dead bodies and independent trials passed")
	quit()
