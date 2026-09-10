extends Node2D
## A timed presentation with an isolated, read-only rehearsal of the upgraded policy.
## No scores or mutations from this preview enter the live population.
signal completed
const Sim = preload("res://scripts/simulation.gd")
const Training = preload("res://scripts/training.gd")
const DURATION = 10.0
const CYAN = Color("60e4d1")
const MUTED = Color("78929e")
var elapsed = 0.0
var rehearsal = Sim.new()
var genomes: Array = []
var projectile = false
var trials = 0
var ticks = 0
var contacts = 0
var hits = 0
var fields: Array[Label] = []
var refresh = 0.0

func start(population: Array, bullets: bool, losses: int) -> void:
	projectile = bullets
	for genome in population:
		genomes.append(genome.copy())
	setup_trial()
	add_text(Vector2(64, 45), "MASTER AI / INTERNAL COMMAND CHANNEL", 16, CYAN)
	add_text(Vector2(64, 94), "ADAPTATION PROTOCOL", 38, Color.WHITE)
	add_text(Vector2(64, 145), "COMBAT SUSPENDED  /  REINFORCEMENTS ON HOLD", 14, MUTED)
	add_text(Vector2(64, 200), "01 / FIELD ASSESSMENT", 14, MUTED)
	add_text(Vector2(64, 235), "Unit losses recorded: %d. Previous engagement archived." % losses, 18, Color.WHITE)
	add_text(Vector2(64, 270), "Our units must account for incoming fire." if projectile else "Area coordinates alone are insufficient for target acquisition.", 18, Color.WHITE)
	add_text(Vector2(64, 316), "02 / AUTHORIZED RESPONSE", 14, MUTED)
	add_text(Vector2(64, 353), "TRACK THE FIRE. MAINTAIN PRESSURE." if projectile else "ACQUIRE THE INTRUDER. CLOSE THE DISTANCE.", 22, CYAN)
	add_text(Vector2(64, 389), "Projectile tracking package authorized." if projectile else "Optical tracking package authorized.", 17, Color.WHITE)
	add_text(Vector2(64, 455), "", 22, CYAN) # 9: current phase
	add_text(Vector2(64, 498), "", 15, MUTED) # 10: phase trail
	add_text(Vector2(64, 600), "", 16, CYAN) # 11: progress
	add_text(Vector2(830, 200), "03 / SIMULATION FEED", 14, MUTED)
	add_text(Vector2(830, 495), "", 15, CYAN) # 13: measured telemetry
	add_text(Vector2(830, 527), "", 15, MUTED) # 14
	add_text(Vector2(830, 559), "", 15, MUTED) # 15
	add_text(Vector2(64, 706), "The next wave will receive the new sensor package.", 18, Color.WHITE)
	add_text(Vector2(64, 741), "AUTOMATIC RESUME WHEN READY", 13, MUTED)
	update_labels()

func add_text(pos: Vector2, value: String, size: int, color: Color) -> void:
	var label = Label.new()
	label.position = pos
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	fields.append(label)

func setup_trial() -> void:
	if projectile:
		Training.setup_fire(rehearsal, genomes, Training.FIRE_CASES[trials % Training.FIRE_CASES.size()])
	else:
		Training.setup_vision(rehearsal, genomes, Training.VISION_CASES[trials % Training.VISION_CASES.size()])

func advance(delta: float) -> void:
	elapsed = minf(DURATION, elapsed + delta)
	# Yield to rendering every frame, including on slower browsers.
	var deadline = Time.get_ticks_usec() + 2500
	if elapsed < DURATION - 1.0:
		while Time.get_ticks_usec() < deadline:
			rehearsal.step(Sim.STEP)
			ticks += 1
			if rehearsal.elapsed >= 4.0 or rehearsal.alive_count() == 0:
				for robot in rehearsal.robots:
					contacts += robot.contacts
					hits += robot.hits
				trials += 1
				setup_trial()
	refresh -= delta
	if refresh <= 0:
		refresh = 0.1
		update_labels()
	queue_redraw()
	if elapsed >= DURATION:
		completed.emit()

func update_labels() -> void:
	var phases = ["UPLOADING NEW SCHEMATICS...", "REWRITING BATTLE CODE...", "SIMULATING...", "COMPUTING...", "READY"]
	var phase = 0 if elapsed < 2 else (1 if elapsed < 4 else (2 if elapsed < 7 else (3 if elapsed < 9 else 4)))
	fields[9].text = phases[phase]
	fields[10].text = "SCHEMATICS  /  INTEGRATION  /  SIMULATION  /  VERIFICATION"
	fields[11].text = "DEPLOYMENT SEQUENCE   %03d%%" % roundi(minf(1, elapsed / 9.0) * 100)
	fields[13].text = "Simulated time       %.1f s" % (ticks * Sim.STEP)
	fields[14].text = "Completed trials     %d" % trials
	fields[15].text = "Contacts %d   /   Hits received %d" % [contacts, hits]

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color("080e16"))
	for y in range(0, 800, 32):
		draw_line(Vector2(0, y), Vector2(1280, y), Color("0e1b25"))
	draw_rect(Rect2(38, 174, 747, 464), Color("101c27"))
	draw_rect(Rect2(806, 174, 432, 464), Color("101c27"))
	draw_rect(Rect2(64, 552, 687, 16), Color("20343e"))
	draw_rect(Rect2(64, 552, 687 * minf(1, elapsed / 9.0), 16), CYAN)
	var origin = Vector2(830, 244)
	var scale_value = 0.42
	draw_rect(Rect2(origin, Sim.SIZE * scale_value), Color("080e16"))
	for wall in rehearsal.walls:
		draw_rect(Rect2(origin + wall.position * scale_value, wall.size * scale_value), MUTED)
	draw_arc(origin + rehearsal.alert * scale_value, Sim.ALERT_RADIUS * scale_value, 0, TAU, 32, Color("31584e"))
	draw_circle(origin + rehearsal.player * scale_value, 5, CYAN)
	for robot in rehearsal.robots:
		if robot.health > 0:
			draw_circle(origin + robot.position * scale_value, 3, Color("ffbe70"))
	if projectile and not rehearsal.robots.is_empty():
		for bullet in rehearsal.robots[0].shots:
			draw_circle(origin + bullet.position * scale_value, 1.5, Color.WHITE)
