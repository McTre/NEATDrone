extends Node2D

const Neat = preload("res://scripts/neat.gd")
const Sim = preload("res://scripts/simulation.gd")
const Training = preload("res://scripts/training.gd")
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
var trial = 0
var totals: Array = []
var history: Array = []
var last_metrics: Dictionary = {}
var selected = 0
var banner = "Enter the cyan circle to trigger a facility alert."
var report_path = "user://latest_run.csv"
var wave = 1

func _ready() -> void:
	DisplayServer.window_set_title("NEATDrone | Stage A — Learning Lab")
	reset_population()

func reset_population() -> void:
	evolution = Neat.new(seed_value, population_size)
	history.clear()
	last_metrics.clear()
	wave = 1
	trial = 0
	paused = false
	totals.resize(evolution.population_size)
	totals.fill(0.0)
	var report = FileAccess.open(report_path, FileAccess.WRITE)
	if report:
		report.store_line("generation,mode,best_fitness,mean_fitness,arrival_rate,wall_seconds,progress_px,species")
	begin_wave()

func begin_wave() -> void:
	selected = 0
	if laboratory:
		var scenario = Training.TRAIN_CASES[trial]
		sim.setup(evolution.population, scenario[1], scenario[0], true)
		banner = "Laboratory: equal trials for every genome. Weapons disabled."
	else:
		sim.setup(evolution.population, Vector2(450, 150))
		banner = "Enter the cyan circle to trigger a facility alert."

func finish_wave() -> void:
	var scores = sim.scores()
	var divisor = Training.TRAIN_CASES.size() if laboratory else 1
	for i in range(scores.size()):
		totals[i] += scores[i] / divisor
	var metrics = sim.metrics()
	for key in metrics:
		last_metrics[key] = last_metrics.get(key, 0.0) + metrics[key] / divisor
	trial += 1
	wave += 1
	if trial >= divisor:
		var evaluated_generation = evolution.generation
		evolution.evolve(totals)
		history.append({"best": evolution.last_best, "mean": evolution.last_average})
		if history.size() > 60:
			history.pop_front()
		var report = FileAccess.open(report_path, FileAccess.READ_WRITE)
		if report:
			report.seek_end()
			report.store_line("%d,%s,%.3f,%.3f,%.4f,%.3f,%.3f,%d" % [evaluated_generation,
				"lab" if laboratory else "combat", evolution.last_best, evolution.last_average,
				last_metrics.arrival_rate, last_metrics.wall_seconds, last_metrics.progress_px,
				evolution.species_records.size()])
		trial = 0
		totals.fill(0.0)
		last_metrics.clear()
	begin_wave()

func _physics_process(_delta: float) -> void:
	if not paused and (laboratory or sim.player_health > 0):
		var movement = Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		for tick in range(speed):
			sim.step(Sim.STEP, movement, get_global_mouse_position() - ORIGIN,
				Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
			if sim.player_health <= 0 and not laboratory:
				banner = "SIGNAL LOST — N: evaluate wave and continue / R: fresh population"
				break
			if sim.elapsed >= Sim.EPISODE_SECONDS or sim.alive_count() == 0:
				finish_wave()
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_SPACE:
			paused = not paused
		KEY_F1:
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
		KEY_1:
			speed = 1
		KEY_2:
			speed = 4
		KEY_3:
			speed = 8
		KEY_TAB:
			selected = (selected + 1) % sim.robots.size()
		KEY_F5:
			save_champion()
		KEY_F9:
			seed_value += 1
			reset_population()

func save_champion(path: String = "user://champion.json") -> void:
	if evolution.champion == null:
		banner = "Finish one generation before exporting a champion."
		return
	var genome = evolution.champion
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"generation": evolution.generation - 1,
			"seed": seed_value, "fitness": genome.fitness, "nodes": genome.nodes,
			"genes": genome.genes, "inputs": Neat.INPUT_COUNT}, "\t"))
		banner = "Champion exported to: " + OS.get_user_data_dir()

func label_at(position: Vector2, text: String, size: int = 16, color: Color = INK) -> void:
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func stat(y: float, title: String, value: String, color: Color = INK) -> void:
	label_at(Vector2(974, y), title, 13, MUTED)
	label_at(Vector2(1208 - font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x, y + 1), value, 19, color)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color("080e16"))
	label_at(Vector2(28, 39), "NEAT / DRONE", 27, CYAN)
	label_at(Vector2(28, 64), "EVOLUTION OBSERVATORY     /     STAGE A", 12, MUTED)
	label_at(Vector2(570, 38), "ALERT NAVIGATION", 18)
	label_at(Vector2(570, 61), "9 observations  /  2 movement outputs  /  no vision", 13, MUTED)
	draw_rect(Rect2(1044, 22, 188, 40), Color("132d30"))
	label_at(Vector2(1058, 48), "LABORATORY" if laboratory else "LIVE COMBAT", 18, CYAN)
	label_at(Vector2(28, 103), "01  /  TEST CHAMBER", 14, MUTED)
	label_at(Vector2(638, 103), "%s    %dx    SEED %d" % ["PAUSED" if paused else "RUNNING", speed, seed_value], 14, AMBER if paused else MUTED)

	draw_set_transform(ORIGIN)
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
		draw_circle(pos, Sim.ROBOT_RADIUS, Color("17232d"))
		draw_arc(pos, Sim.ROBOT_RADIUS, 0, TAU, 20, color, 1.5, true)
		draw_line(pos, pos + robot.heading * 13, color, 2, true)
		draw_circle(pos, 2.5, color)
		if robot.health < 2:
			draw_line(pos + Vector2(-6, 16), pos + Vector2(0, 16), AMBER, 2)
		if selected == i:
			draw_arc(pos, 17, 0, TAU, 28, Color(INK, 0.6), 1, true)
			if sensors:
				for direction in [robot.heading, robot.heading.rotated(-PI / 2), robot.heading.rotated(PI / 2)]:
					draw_line(pos, pos + direction * sim.ray_distance(pos, direction), Color(AMBER, 0.55), 1, true)
				if sim.alert_active:
					draw_line(pos, sim.alert, Color(CYAN, 0.28), 1, true)
	for bullet in sim.bullets:
		draw_line(bullet.position - bullet.velocity.normalized() * 9, bullet.position, INK, 2.5, true)
	if not laboratory:
		var player_color = CYAN if sim.player_health > 0 else MUTED
		draw_circle(sim.player, 19, Color(player_color, 0.08))
		draw_circle(sim.player, Sim.PLAYER_RADIUS, player_color)
		draw_line(sim.player, sim.player + sim.aim * 23, INK, 5, true)
		draw_circle(sim.player, 5, Color("0d1822"))
		if sim.melee_flash > 0:
			draw_arc(sim.player, 58, sim.aim.angle() - 1.3, sim.aim.angle() + 1.3, 24, CYAN, 5, true)
	draw_set_transform(Vector2.ZERO)

	draw_rect(Rect2(950, 86, 282, 618), Color("101c27"))
	label_at(Vector2(974, 113), "02  /  POPULATION", 14, MUTED)
	stat(151, "GENERATION", "%03d" % evolution.generation, CYAN)
	stat(185, "WAVE / TRIAL", "%d / %d" % [wave, trial + 1])
	stat(219, "ALIVE / TOTAL", "%d / %d" % [sim.alive_count(), evolution.population_size])
	stat(253, "SPECIES", str(evolution.species_records.size()))
	stat(287, "TIME LEFT", "%.1fs" % maxf(0, Sim.EPISODE_SECONDS - sim.elapsed))
	stat(321, "PLAYER HP", "—" if laboratory else "%d" % sim.player_health, CYAN if sim.player_health > 30 else AMBER)
	draw_line(Vector2(974, 341), Vector2(1208, 341), Color("29404e"))
	stat(369, "LAST BEST", "%.1f" % evolution.last_best, AMBER)
	stat(401, "LAST MEAN", "%.1f" % evolution.last_average, CYAN)
	draw_chart(Rect2(974, 420, 234, 68))
	var metrics = sim.metrics()
	stat(518, "ARRIVED (NOW)", "%d%%" % (metrics.arrival_rate * 100), CYAN)
	stat(550, "WALL TIME / BOT", "%.1fs" % metrics.wall_seconds)
	var chosen = sim.robots[selected]
	label_at(Vector2(974, 587), "BOT %02d / SPECIES %d" % [selected + 1, chosen.genome.species], 13, MUTED)
	label_at(Vector2(974, 611), "%d nodes  ·  %d links" % [chosen.genome.nodes.size(), chosen.genome.genes.size()], 14)
	label_at(Vector2(974, 637), "Progress %+.1f   Arrival %+.1f" % [chosen.parts.progress, chosen.parts.arrival], 12, CYAN)
	label_at(Vector2(974, 658), "Wall %+.1f   Damage %+.1f" % [chosen.parts.wall, chosen.parts.damage], 12, AMBER)
	label_at(Vector2(974, 680), "Alive %+.1f   Death %+.1f" % [chosen.parts.survival, chosen.parts.death], 12, MUTED)

	label_at(Vector2(28, 732), banner, 14, CYAN if sim.player_health > 0 else AMBER)
	label_at(Vector2(28, 760), "WASD  move     LMB  shoot     RMB  melee     SPACE  pause     T  lab / combat (reset)     1 / 2 / 3  speed", 13, INK)
	label_at(Vector2(28, 785), "F1  sensors     TAB  inspect bot     N  next combat wave     R  restart     F9  new seed     F5  export champion", 13, MUTED)

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
