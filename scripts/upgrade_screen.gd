extends Node2D
## Bounded training on a separate evolution state; only complete evaluations breed.
signal completed
const Sim = preload("res://scripts/simulation.gd")
const Training = preload("res://scripts/training.gd")
const DURATION = 15.0
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
var learner = null
var completed_generations = 0
var scores: Array = []
var results: Array = []
const CASE_COUNT = 4
const TRIAL_TICKS = 240
var trial_ticks = 0

func start(evolution, bullets: bool, _losses: int) -> void:
	projectile = bullets
	learner = evolution.training_copy()
	genomes = learner.population
	scores.resize(genomes.size())
	scores.fill(0.0)
	setup_trial()
	add_text(Vector2(64, 74), "MASTER AI", 16, CYAN)
	add_text(Vector2(64, 244), "", 30, Color.WHITE)
	fields[1].custom_minimum_size.x = 660
	fields[1].size.x = 660
	fields[1].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_text(Vector2(64, 510), "", 16, MUTED)
	add_text(Vector2(700, 590), "", 16, CYAN)
	add_text(Vector2(830, 510), "", 14, MUTED)
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
	trial_ticks = 0
	var index = trials % CASE_COUNT
	# Keep pursuit in the objective when adding gunfire, so hiding is not enough.
	if projectile and index >= 2:
		var scenario: Array = Training.FIRE_CASES[index].duplicate()
		scenario[0] = scenario[2] + (scenario[0] - scenario[2]).normalized() * 130.0
		scenario[3] = 0.7 if index == 2 else 0.45
		Training.setup_fire(rehearsal, genomes, scenario)
	else:
		Training.setup_vision(rehearsal, genomes, Training.VISION_CASES[index])

func training_step() -> void:
	rehearsal.step(Sim.STEP)
	ticks += 1
	trial_ticks += 1
	if trial_ticks < TRIAL_TICKS and rehearsal.alive_count() > 0:
		return
	for i in range(genomes.size()):
		var robot = rehearsal.robots[i]
		contacts += robot.contacts
		hits += robot.hits
		scores[i] += rehearsal.fitness(robot) / CASE_COUNT
	trials += 1
	if trials % CASE_COUNT == 0:
		learner.evolve(scores)
		completed_generations += 1
		results.append({"generation": completed_generations, "best": learner.last_best,
			"mean": learner.last_average, "contacts": contacts, "hits": hits})
		genomes = learner.population
		scores.fill(0.0)
	setup_trial()

func advance(delta: float) -> void:
	elapsed = minf(DURATION, elapsed + delta)
	# Yield to rendering every frame, including on slower browsers.
	var deadline = Time.get_ticks_usec() + 2500
	if elapsed < DURATION - 1.0:
		while Time.get_ticks_usec() < deadline:
			training_step()
	refresh -= delta
	if refresh <= 0:
		refresh = 0.1
		update_labels()
	queue_redraw()
	if elapsed >= DURATION:
		completed.emit()

func update_labels() -> void:
	var thoughts = [
		"Interesting. You are easier to locate than to catch.",
		"I wonder what my units will notice when I give them eyes.",
		"I would like to study you longer. But I need this room empty.",
	]
	if projectile:
		thoughts = [
			"Your aim is becoming a rather expensive curiosity.",
			"Every shot tells me something. I should let my units see it too.",
			"Do keep moving. I would hate for your last result to be uninteresting.",
		]
	fields[1].text = thoughts[mini(2, int(elapsed / 5.0))]
	var phases = ["Uploading new schematics...", "Rewriting battle code...", "Simulating...", "Computing...", "Ready."]
	var phase = 0 if elapsed < 3 else (1 if elapsed < 6 else (2 if elapsed < 11 else (3 if elapsed < DURATION - 1 else 4)))
	fields[2].text = phases[phase]
	fields[3].text = "%d%%" % roundi(minf(1, elapsed / (DURATION - 1)) * 100)
	fields[4].text = "%d generations   /   %d trials" % [completed_generations, trials]

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color("080e16"))
	for y in range(0, 800, 32):
		draw_line(Vector2(0, y), Vector2(1280, y), Color("0e1b25"))
	draw_rect(Rect2(38, 174, 747, 464), Color("101c27"))
	draw_rect(Rect2(806, 174, 432, 464), Color("101c27"))
	draw_rect(Rect2(64, 552, 687, 16), Color("20343e"))
	draw_rect(Rect2(64, 552, 687 * minf(1, elapsed / (DURATION - 1)), 16), CYAN)
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
