extends Node2D

const Neat = preload("res://scripts/neat.gd")
const Sim = preload("res://scripts/simulation.gd")
const Training = preload("res://scripts/training.gd")
const UpgradeScreen = preload("res://scripts/upgrade_screen.gd")
var upgrade_screen = null
var upgrade_training_reports: Array = []
const ORIGIN = Vector2(28, 124)
const INK = Color("d5e5ea")
const MUTED = Color("78929e")
const CYAN = Color("60e4d1")
const AMBER = Color("ffbe70")

var evolution = Neat.new()
var sim = Sim.new()
var font = ThemeDB.fallback_font
var laboratory = false
var paused = false
var sensors = false
var speed = 1
@export var seed_value = 42
@export_range(4, 128) var population_size = 48
@export_range(4, 16) var combat_enemies = 8
@export var pretrained_movement = true
@export_range(0, 100) var vision_generation = 6 # 0 disables scheduled upgrade.
@export_range(0, 100) var projectile_generation = 10
var vision_requested = false
var projectile_requested = false
var deployment = false
var trial = 0
var totals: Array = []
var history: Array = []
var last_metrics: Dictionary = {}
var selected = 0
var banner = "Enter the cyan circle to trigger a facility alert."
var report_path = "user://latest_run.csv"
var wave = 1
var simulation_debt = 0.0
var observed_speed = 0.0
var frame_ms = 16.7
var frame_clock = 0
var measured_time = 0.0
var measured_simulation = 0.0
const FRAME_SIMULATION_BUDGET_US = 6000
var text_labels: Array[Label] = []
var text_index = 0
var text_offset = Vector2.ZERO
var next_text_update = 0
var update_text = true
var robot_texture: ImageTexture

func _ready() -> void:
	var sprite = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(32):
			var point = Vector2(x + 0.5, y + 0.5) - Vector2(16, 16)
			var radius = point.length()
			var ring = clampf(1.5 - absf(radius - 11.0), 0, 1)
			var dot = clampf(3.0 - radius, 0, 1)
			var nose = clampf(1.5 - absf(point.y), 0, 1) if point.x >= 0 and point.x <= 13 else 0.0
			sprite.set_pixel(x, y, Color(1, 1, 1, maxf(ring, maxf(dot, nose))))
	robot_texture = ImageTexture.create_from_image(sprite)
	DisplayServer.window_set_title("NEATDrone | Learning Lab")
	reset_population()
	if OS.has_feature("web"):
		paused = true
		banner = "Click the game, then SPACE to start. WASD: move / mouse: aim / T: learning lab."

func reset_population() -> void:
	upgrade_training_reports.clear()
	if is_instance_valid(upgrade_screen):
		upgrade_screen.queue_free()
	upgrade_screen = null
	simulation_debt = 0.0
	evolution = Neat.new(seed_value, population_size if laboratory else combat_enemies)
	if not laboratory and pretrained_movement:
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/basic.json"))
		if not data is Dictionary or not evolution.load_navigation(data):
			push_warning("Basic behavior starter could not be loaded; using a fresh population")
	if not laboratory and not evolution.vision_enabled:
		evolution.unlock_vision()
		evolution.long_vision_enabled = false
	if vision_generation == 1:
		evolution.unlock_vision()
	if projectile_generation == 1:
		evolution.unlock_projectiles()
	history.clear()
	last_metrics.clear()
	wave = 1
	trial = 0
	paused = false
	deployment = false
	vision_requested = false
	projectile_requested = false
	totals.resize(evolution.population_size)
	totals.fill(0.0)
	var report = FileAccess.open(report_path, FileAccess.WRITE)
	if report:
		report.store_line("generation,mode,stage,best_fitness,mean_fitness,arrival_rate,wall_seconds,progress_px,species,contact_rate,contacts,hits,survival_seconds,survival_rate")
	begin_wave()

func begin_wave() -> void:
	selected = 0
	if laboratory:
		if evolution.projectiles_enabled:
			Training.setup_fire(sim, evolution.population, Training.FIRE_CASES[trial])
			banner = "Gunfire lab: player beside alert area. Bullets shown for selected robot. C: combat test."
		elif evolution.long_vision_enabled:
			Training.setup_vision(sim, evolution.population, Training.VISION_CASES[trial])
			banner = "Vision lab: moving target, independent contact scores. C: try this population in combat."
		else:
			var scenario = Training.TRAIN_CASES[trial]
			sim.setup(evolution.population, scenario[1], scenario[0], true)
			banner = "Navigation lab. Vision unlocks at generation %d. V: request upgrade sooner." % vision_generation
	else:
		var active: Array = []
		var count = mini(combat_enemies, evolution.population.size())
		var offset = ((wave - 1) * count) % evolution.population.size() if deployment else 0
		for i in range(count):
			active.append(evolution.population[(offset + i) % evolution.population.size()])
		sim.setup(active, Vector2(450, 150))
		banner = "Enter the cyan circle to trigger a facility alert. V: request vision at next generation."
		if evolution.pretrained_generations > 0:
			banner = "%d robots with pretrained search and pursuit. Short-range vision online; V: extend range." % count
		if deployment:
			banner = "Trained population test — evolution frozen. C: return to laboratory."
		elif evolution.long_vision_enabled:
			banner = "Vision online. P: request projectile sensing at the next generation."
		if evolution.projectiles_enabled and not deployment:
			banner = "Projectile vision online: visible bullet direction, distance and velocity. No automatic dodge."

	sim.vision_range = Sim.VISION_RANGE if evolution.long_vision_enabled else 120.0

func finish_wave() -> void:
	if is_instance_valid(upgrade_screen):
		return
	if deployment:
		wave += 1
		begin_wave()
		return
	var scores = sim.scores()
	var divisor = Training.TRAIN_CASES.size() if laboratory else 1
	for i in range(scores.size()):
		totals[i] += scores[i] / divisor
	var metrics = sim.metrics()
	for key in metrics:
		last_metrics[key] = last_metrics.get(key, 0.0) + metrics[key] / divisor
	trial += 1
	wave += 1
	var upgraded = false
	if trial >= divisor:
		var evaluated_generation = evolution.generation
		evolution.evolve(totals)
		history.append({"best": evolution.last_best, "mean": evolution.last_average})
		if history.size() > 60:
			history.pop_front()
		var report = FileAccess.open(report_path, FileAccess.READ_WRITE)
		if report:
			report.seek_end()
			report.store_line("%d,%s,%s,%.3f,%.3f,%.4f,%.3f,%.3f,%d,%.4f,%.3f,%.3f,%.3f,%.4f" % [evaluated_generation,
				"lab" if laboratory else "combat", stage_name(), evolution.last_best, evolution.last_average,
				last_metrics.arrival_rate, last_metrics.wall_seconds, last_metrics.progress_px,
				evolution.species_records.size(), last_metrics.contact_rate, last_metrics.contacts,
				last_metrics.hits, last_metrics.survival_seconds, last_metrics.survival_rate])
		if not evolution.long_vision_enabled and (vision_requested or (vision_generation > 0 and evolution.generation >= vision_generation)):
			evolution.unlock_vision()
			upgraded = true
			vision_requested = false
			history.clear()
		if not evolution.projectiles_enabled and (projectile_requested or (projectile_generation > 0 and evolution.long_vision_enabled and evolution.generation >= projectile_generation)):
			evolution.unlock_projectiles()
			upgraded = true
			projectile_requested = false
			vision_requested = false
			history.clear()
		trial = 0
		totals.fill(0.0)
		last_metrics.clear()
	if upgraded:
		upgrade_screen = UpgradeScreen.new()
		upgrade_screen.z_index = 10
		add_child(upgrade_screen)
		upgrade_screen.start(evolution, evolution.projectiles_enabled, sim.kills)
		upgrade_screen.completed.connect(finish_upgrade)
		simulation_debt = 0.0
	else:
		begin_wave()

func finish_upgrade() -> void:
	var report = {"stage": stage_name(), "generations": upgrade_screen.completed_generations,
		"trials": upgrade_screen.trials, "simulated_seconds": upgrade_screen.ticks * Sim.STEP,
		"results": upgrade_screen.results.duplicate(true)}
	upgrade_training_reports.append(report)
	print("UPGRADE TRAINING: ", JSON.stringify(report))
	if upgrade_screen.completed_generations > 0:
		var live_generation = evolution.generation
		evolution = upgrade_screen.learner
		# Training generations do not advance the wave-based hardware schedule.
		evolution.generation = live_generation
		evolution.reset_evaluation()
	upgrade_screen.queue_free()
	upgrade_screen = null
	simulation_debt = 0.0
	next_text_update = 0
	begin_wave()

func stage_name() -> String:
	return "projectiles" if evolution.projectiles_enabled else ("vision" if evolution.long_vision_enabled else ("short_vision" if evolution.vision_enabled else "navigation"))

func _process(delta: float) -> void:
	var now = Time.get_ticks_usec()
	var real_delta = (now - frame_clock) / 1000000.0 if frame_clock else delta
	frame_clock = now
	frame_ms = lerpf(frame_ms, real_delta * 1000.0, 0.1)
	measured_time += real_delta
	if is_instance_valid(upgrade_screen):
		upgrade_screen.advance(minf(real_delta, 0.1))
		return
	if not paused and (laboratory or sim.player_health > 0):
		# Fixed simulation ticks, but a bounded amount of work per rendered frame.
		# Never multiply accelerated training by Godot's physics catch-up loop.
		simulation_debt = minf(simulation_debt + minf(real_delta, 0.1) * speed, Sim.STEP * speed * 2)
		var movement = Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		while simulation_debt >= Sim.STEP:
			simulation_debt -= Sim.STEP
			sim.step(Sim.STEP, movement, get_global_mouse_position() - ORIGIN,
				Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
			measured_simulation += Sim.STEP
			if sim.player_health <= 0 and not laboratory:
				banner = "SIGNAL LOST — N: evaluate wave and continue / R: fresh population"
				break
			if sim.elapsed >= Sim.EPISODE_SECONDS or sim.alive_count() == 0:
				finish_wave()
				if is_instance_valid(upgrade_screen):
					break
			if Time.get_ticks_usec() - now >= FRAME_SIMULATION_BUDGET_US:
				break
	else:
		simulation_debt = 0.0
	if measured_time >= 0.5:
		observed_speed = measured_simulation / measured_time
		measured_simulation = 0.0
		measured_time = 0.0
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(upgrade_screen):
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_SPACE:
			paused = not paused
		KEY_F1, KEY_H:
			sensors = not sensors
		KEY_R:
			reset_population()
		KEY_N:
			if not laboratory:
				finish_wave()
		KEY_T:
			laboratory = not laboratory
			speed = 8 if laboratory else 1
			reset_population() # Never mix different evaluation objectives.
		KEY_V:
			if not evolution.long_vision_enabled and not deployment:
				vision_requested = true
				banner = "Vision upgrade queued for the next generation. Current trials will finish first."
		KEY_P:
			if not evolution.projectiles_enabled and not deployment:
				projectile_requested = true
				banner = "Projectile vision queued for the next generation (includes player vision)."
		KEY_C:
			if laboratory or deployment:
				deployment = not deployment
				laboratory = not deployment
				speed = 1 if deployment else 8
				trial = 0
				totals.fill(0.0)
				last_metrics.clear()
				begin_wave()
		KEY_1:
			speed = 1
		KEY_2:
			speed = 4
		KEY_3:
			speed = 8
		KEY_TAB, KEY_Q:
			selected = (selected + 1) % sim.robots.size()
		KEY_F5, KEY_E:
			save_champion()
		KEY_F9, KEY_G:
			seed_value += 1
			reset_population()

func save_champion(path: String = "user://champion.json") -> void:
	if evolution.champion == null:
		banner = "Finish one generation before exporting a champion."
		return
	var genome = evolution.champion
	var json = JSON.stringify({"generation": evolution.generation - 1,
		"seed": seed_value, "fitness": genome.fitness, "nodes": genome.nodes,
		"genes": genome.genes, "inputs": genome.input_ids.size(),
		"input_ids": genome.input_ids, "vision": evolution.vision_enabled, "vision_range": sim.vision_range,
		"projectiles": evolution.projectiles_enabled,
		"upgrade_training": upgrade_training_reports}, "\t")
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(json.to_utf8_buffer(), "neatdrone-champion.json", "application/json")
		banner = "Champion downloaded as neatdrone-champion.json."
		return
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json)
		banner = "Champion exported to: " + OS.get_user_data_dir()

func label_at(position: Vector2, text: String, size: int = 16, color: Color = INK) -> void:
	# Labels retain shaped glyphs and draw commands between updates. Calling
	# draw_string for every HUD line each frame reshaped the entire Web HUD.
	if text_index == text_labels.size():
		var node = Label.new()
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_theme_font_override("font", font)
		add_child(node)
		text_labels.append(node)
	var node = text_labels[text_index]
	node.visible = true
	if update_text or node.text.is_empty():
		node.text = text
		node.position = position + text_offset - Vector2(0, font.get_ascent(size))
		node.add_theme_font_size_override("font_size", size)
		node.modulate = color
	text_index += 1

func stat(y: float, title: String, value: String, color: Color = INK) -> void:
	label_at(Vector2(974, y), title, 13, MUTED)
	label_at(Vector2(1208 - font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x, y + 1), value, 19, color)

func _draw() -> void:
	text_index = 0
	text_offset = Vector2.ZERO
	update_text = Time.get_ticks_msec() >= next_text_update
	if update_text:
		next_text_update = Time.get_ticks_msec() + 100
	draw_rect(Rect2(0, 0, 1280, 800), Color("080e16"))
	label_at(Vector2(28, 39), "NEAT / DRONE", 27, CYAN)
	label_at(Vector2(28, 64), "EVOLUTION OBSERVATORY / " + stage_name().to_upper(), 12, MUTED)
	label_at(Vector2(570, 38), "PROJECTILE VISION" if evolution.projectiles_enabled else ("VISUAL PURSUIT" if evolution.long_vision_enabled else ("SHORT SIGHT / 120 PX" if evolution.vision_enabled else "AREA SEARCH")), 18)
	label_at(Vector2(570, 61), "%d observations / 2 outputs / learned movement" % evolution.population[0].input_ids.size(), 13, MUTED)
	draw_rect(Rect2(1044, 22, 188, 40), Color("132d30"))
	label_at(Vector2(1058, 48), "POPULATION TEST" if deployment else ("LABORATORY" if laboratory else "LIVE COMBAT"), 16, CYAN)
	label_at(Vector2(28, 103), "01  /  TEST CHAMBER", 14, MUTED)
	label_at(Vector2(535, 103), "%s   %d FPS   %.1fx / %dx   SEED %d" % ["PAUSED" if paused else "RUNNING", roundi(1000.0 / maxf(1, frame_ms)), observed_speed, speed, seed_value], 13, AMBER if paused else MUTED)

	draw_set_transform(ORIGIN)
	text_offset = ORIGIN
	draw_rect(Rect2(Vector2.ZERO, Sim.SIZE), Color("0d1822"))
	for x in range(0, 901, 30):
		draw_line(Vector2(x, 0), Vector2(x, Sim.SIZE.y), Color("14232d"))
	for y in range(0, 581, 30):
		draw_line(Vector2(0, y), Vector2(Sim.SIZE.x, y), Color("14232d"))
	draw_rect(Rect2(Vector2.ZERO, Sim.SIZE), Color("385463"), false, 2)
	var alert_color = CYAN if sim.alert_active else Color("436860")
	draw_circle(sim.alert, Sim.ALERT_RADIUS, Color(alert_color, 0.07))
	draw_arc(sim.alert, Sim.ALERT_RADIUS, 0, TAU, 64, alert_color, 1.5, true)
	draw_line(sim.alert - Vector2(10, 0), sim.alert + Vector2(10, 0), alert_color)
	draw_line(sim.alert - Vector2(0, 10), sim.alert + Vector2(0, 10), alert_color)
	label_at(sim.alert + Vector2(-49, -77), "AREA SIGNAL" if sim.alert_active else "ENTER TO ALERT", 11, alert_color)
	for wall in sim.walls:
		draw_rect(Rect2(wall.position + Vector2(4, 5), wall.size), Color("060d14"))
		draw_rect(wall, Color("293d4b"))
		draw_rect(wall, Color("47606c"), false, 1)
		for y in range(int(wall.position.y + 7), int(wall.end.y), 12):
			draw_line(Vector2(wall.position.x + 5, y), Vector2(wall.end.x - 5, y), Color("334c59"))
	for i in range(sim.robots.size()):
		var robot = sim.robots[i]
		var pos: Vector2 = robot.position
		if robot.health <= 0:
			draw_line(pos - Vector2(4, 4), pos + Vector2(4, 4), Color("45505a"))
			draw_line(pos - Vector2(4, -4), pos + Vector2(4, -4), Color("45505a"))
			continue
		var color = Color.from_hsv(fmod(robot.genome.species * 0.137 + 0.04, 1.0), 0.48, 0.94)
		draw_set_transform(ORIGIN + pos, robot.heading.angle())
		draw_texture(robot_texture, Vector2(-16, -16), color)
		draw_set_transform(ORIGIN)
		if robot.health < 2:
			draw_line(pos + Vector2(-6, 16), pos + Vector2(0, 16), AMBER, 2)
		if selected == i:
			draw_arc(pos, 17, 0, TAU, 28, Color(INK, 0.6), 1, true)
			if sensors:
				var observed_bullet = sim.perceived_projectile(robot)
				if observed_bullet != null:
					draw_line(pos, observed_bullet.position, AMBER, 2, true)
					draw_line(observed_bullet.position, observed_bullet.position + observed_bullet.velocity * 0.05, AMBER, 2, true)
				if sim.vision_enabled:
					for segment in range(96):
						var a = pos + Vector2.from_angle(segment * TAU / 96) * sim.vision_range
						var b = pos + Vector2.from_angle((segment + 1) * TAU / 96) * sim.vision_range
						if Rect2(Vector2.ZERO, Sim.SIZE).has_point(a) and Rect2(Vector2.ZERO, Sim.SIZE).has_point(b):
							draw_line(a, b, Color(CYAN, 0.12), 1, true)
					if sim.sees_player(robot):
						draw_line(pos, sim.player, CYAN, 2, true)
				for direction in [robot.heading, robot.heading.rotated(-PI / 2), robot.heading.rotated(PI / 2)]:
					draw_line(pos, pos + direction * sim.ray_distance(pos, direction), Color(AMBER, 0.55), 1, true)
				if sim.alert_active:
					draw_line(pos, sim.alert, Color(CYAN, 0.28), 1, true)
	var displayed_bullets: Array = sim.robots[selected].shots if sim.firing_trial else sim.bullets
	for bullet in displayed_bullets:
		draw_line(bullet.position - bullet.velocity.normalized() * 9, bullet.position, INK, 2.5, true)
	if not laboratory or sim.vision_enabled:
		var player_color = CYAN if sim.player_health > 0 else MUTED
		draw_circle(sim.player, 19, Color(player_color, 0.08))
		draw_circle(sim.player, Sim.PLAYER_RADIUS, player_color)
		draw_line(sim.player, sim.player + sim.aim * 23, INK, 5, true)
		draw_circle(sim.player, 5, Color("0d1822"))
		if sim.melee_flash > 0:
			draw_arc(sim.player, 58, sim.aim.angle() - 1.3, sim.aim.angle() + 1.3, 24, CYAN, 5, true)
	draw_set_transform(Vector2.ZERO)
	text_offset = Vector2.ZERO

	draw_rect(Rect2(950, 86, 282, 618), Color("101c27"))
	label_at(Vector2(974, 113), "02  /  POPULATION", 14, MUTED)
	stat(151, "GENERATION", "%03d" % evolution.generation, CYAN)
	stat(185, "WAVE / TRIAL", "%d / %d" % [wave, trial + 1])
	stat(219, "ACTIVE / POPULATION", "%d / %d" % [sim.alive_count(), evolution.population_size])
	stat(253, "SPECIES", str(evolution.species_records.size()))
	stat(287, "TIME LEFT", "%.1fs" % maxf(0, Sim.EPISODE_SECONDS - sim.elapsed))
	stat(321, "PLAYER HP", "—" if laboratory else "%d" % sim.player_health, CYAN if sim.player_health > 30 else AMBER)
	draw_line(Vector2(974, 341), Vector2(1208, 341), Color("29404e"))
	stat(369, "LAST BEST", "%.1f" % evolution.last_best, AMBER)
	stat(401, "LAST MEAN", "%.1f" % evolution.last_average, CYAN)
	draw_chart(Rect2(974, 420, 234, 68))
	var metrics = sim.metrics()
	stat(518, "SURVIVING" if sim.projectiles_enabled else ("CONTACT (NOW)" if sim.vision_enabled else "ARRIVED (NOW)"), "%d%%" % ((metrics.survival_rate if sim.projectiles_enabled else (metrics.contact_rate if sim.vision_enabled else metrics.arrival_rate)) * 100), CYAN)
	if sim.projectiles_enabled:
		stat(550, "HITS / CONTACT", "%.1f / %.0f%%" % [metrics.hits, metrics.contact_rate * 100])
	else:
		stat(550, "WALL TIME / BOT", "%.1fs" % metrics.wall_seconds)
	var chosen = sim.robots[selected]
	label_at(Vector2(974, 587), "BOT %02d / SPECIES %d" % [selected + 1, chosen.genome.species], 13, MUTED)
	label_at(Vector2(974, 611), "%d nodes · %d links · %s" % [chosen.genome.nodes.size(), chosen.genome.genes.size(), "SEES" if sim.sees_player(chosen) else "—"], 12)
	label_at(Vector2(974, 637), "Move %+.1f Arr %+.0f Search %+.1f" % [chosen.parts.progress, chosen.parts.arrival, chosen.parts.search], 11, CYAN)
	label_at(Vector2(974, 658), "Hit %+.0f Death %+.0f Dmg %+.0f" % [chosen.parts.injury, chosen.parts.death, chosen.parts.damage], 11, AMBER)
	label_at(Vector2(974, 680), "Chase %+.1f Wall %+.1f Alive %+.1f" % [chosen.parts.pursuit, chosen.parts.wall, chosen.parts.survival], 10, MUTED)

	label_at(Vector2(28, 732), banner, 14, CYAN if sim.player_health > 0 else AMBER)
	label_at(Vector2(28, 760), "WASD  move     LMB  shoot     RMB  melee     SPACE  pause     T  lab / combat (reset)     1 / 2 / 3  speed", 13, INK)
	label_at(Vector2(28, 785), "V  vision   P  projectile vision   C  lab / combat   H  sensors   Q  bot   N  next   R  reset   G  seed   E  export", 13, MUTED)
	for i in range(text_index, text_labels.size()):
		text_labels[i].visible = false

func draw_chart(rect: Rect2) -> void:
	draw_rect(rect, Color("0b151f"))
	if history.size() < 2:
		label_at(rect.position + Vector2(12, 38), "Awaiting evaluated generations", 12, MUTED)
		return
	var low = 0.0
	var high = 1.0
	for entry in history:
		low = minf(low, entry.mean)
		high = maxf(high, entry.best)
	for key in ["best", "mean"]:
		var points = PackedVector2Array()
		for i in range(history.size()):
			points.append(rect.position + Vector2(float(i) / (history.size() - 1) * rect.size.x,
				rect.size.y - (history[i][key] - low) / (high - low) * rect.size.y))
		draw_polyline(points, AMBER if key == "best" else CYAN, 1.5, true)
