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
	for i in range(16):
		policies.append(Policy.new())
	var entries = {}
	var rooms = {}
	for wave in range(1, 33):
		sim.setup_combat(policies, 42, wave)
		entries[sim.entry_index] = true
		rooms[sim.room_index] = true
		var entry: int = sim.entry_index
		var room: int = sim.room_index
		assert(not sim.blocked(sim.player, Sim.PLAYER_RADIUS))
		assert(not sim.blocked(sim.alert, Sim.ALERT_RADIUS), "Alert circle must fit in its room")
		for robot in sim.robots:
			assert(not Rect2(Vector2.ZERO, Sim.SIZE).has_point(robot.position))
			assert(robot.incoming)
		sim.setup_combat(policies, 42, wave)
		assert(sim.entry_index == entry and sim.room_index == room, "Wave draws must be reproducible")
		for policy in policies:
			policy.direction = Sim.RoomLayout.DIRECTIONS[entry]
		for tick in range(240):
			sim.step(Sim.STEP)
			for i in range(sim.robots.size()):
				var robot = sim.robots[i]
				if Rect2(Vector2.ONE * Sim.ROBOT_RADIUS, Sim.SIZE - Vector2.ONE * Sim.ROBOT_RADIUS * 2).has_point(robot.position):
					assert(not sim.blocked(robot.position, Sim.ROBOT_RADIUS))
				for j in range(i):
					assert(robot.position.distance_to(sim.robots[j].position) >= 22 - 0.001)
		for robot in sim.robots:
			assert(not robot.incoming, "Whole swarm must be able to enter its shared doorway")
	assert(entries.size() == 4 and rooms.size() == 4)
	sim.setup(policies, Vector2(450, 150), Vector2(100, 100), true)
	assert(not sim.room_layout and sim.walls.size() == 3, "Lab retains its independent layout")
	print("ROOM LAYOUT: four entrances/rooms, deterministic waves, hidden spawns, non-overlapping ingress and lab reset passed")
	quit()
