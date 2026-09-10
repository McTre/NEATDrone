extends RefCounted
## Fixed training curriculum, with separate unseen start/target combinations
## for reporting generalization. Every genome faces exactly the same trials.
const Sim = preload("res://scripts/simulation.gd")
const TRAIN_CASES = [
	[Vector2(70, 70), Vector2(780, 260)],
	[Vector2(830, 510), Vector2(120, 320)],
	[Vector2(760, 75), Vector2(180, 480)],
	[Vector2(140, 505), Vector2(740, 95)],
]
const HOLDOUT_CASES = [
	[Vector2(65, 290), Vector2(790, 140)],
	[Vector2(835, 280), Vector2(110, 440)],
	[Vector2(450, 45), Vector2(450, 515)],
	[Vector2(450, 530), Vector2(450, 65)],
	[Vector2(80, 515), Vector2(780, 80)],
	[Vector2(820, 60), Vector2(110, 495)],
]
const VISION_CASES = [
	[Vector2(80, 60), Vector2(220, 130), Vector2(200, 60), [Vector2(470, 60), Vector2(200, 60)]],
	[Vector2(820, 520), Vector2(680, 450), Vector2(700, 520), [Vector2(430, 520), Vector2(700, 520)]],
	[Vector2(830, 90), Vector2(720, 190), Vector2(730, 130), [Vector2(730, 320), Vector2(730, 80)]],
	[Vector2(70, 490), Vector2(180, 390), Vector2(170, 430), [Vector2(170, 250), Vector2(170, 490)]],
]
const VISION_HOLDOUT = [
	[Vector2(500, 70), Vector2(380, 140), Vector2(370, 70), [Vector2(120, 70), Vector2(500, 70)]],
	[Vector2(400, 530), Vector2(550, 470), Vector2(540, 530), [Vector2(800, 530), Vector2(400, 530)]],
	[Vector2(760, 390), Vector2(790, 240), Vector2(800, 270), [Vector2(800, 65), Vector2(800, 410)]],
	[Vector2(80, 180), Vector2(130, 290), Vector2(100, 300), [Vector2(100, 500), Vector2(100, 140)]],
	[Vector2(330, 200), Vector2(470, 250), Vector2(450, 340), [Vector2(550, 340), Vector2(550, 200), Vector2(350, 200), Vector2(350, 340)]],
	[Vector2(570, 390), Vector2(680, 350), Vector2(710, 380), [Vector2(710, 500), Vector2(550, 500), Vector2(550, 300), Vector2(710, 300)]],
]
const FIRE_CASES = [
	[Vector2(80, 70), Vector2(420, 100), Vector2(510, 100), 0.28],
	[Vector2(820, 510), Vector2(480, 510), Vector2(390, 510), 0.28],
	[Vector2(760, 70), Vector2(760, 350), Vector2(760, 440), 0.28],
	[Vector2(140, 510), Vector2(140, 230), Vector2(140, 140), 0.28],
]
const FIRE_HOLDOUT = [
	[Vector2(70, 520), Vector2(390, 510), Vector2(480, 510), 0.24],
	[Vector2(820, 65), Vector2(510, 65), Vector2(420, 65), 0.32],
	[Vector2(80, 70), Vector2(80, 330), Vector2(100, 420), 0.24],
	[Vector2(820, 510), Vector2(820, 260), Vector2(800, 170), 0.32],
]

static func setup_fire(sim, genomes: Array, scenario: Array, blind: bool = false) -> void:
	sim.setup(genomes, scenario[1], scenario[0], true)
	sim.player = scenario[2]
	sim.firing_trial = true
	sim.fire_interval = scenario[3]
	sim.projectile_blind_test = blind

static func setup_vision(sim, genomes: Array, scenario: Array, blind: bool = false) -> void:
	sim.setup(genomes, scenario[1], scenario[0], true)
	sim.player = scenario[2]
	sim.player_path = scenario[3].duplicate()
	sim.blind_test = blind

static func evaluate(genomes: Array, cases: Array = TRAIN_CASES, blind: bool = false) -> Dictionary:
	var totals: Array = []
	totals.resize(genomes.size())
	totals.fill(0.0)
	var summary = {"arrival_rate": 0.0, "wall_seconds": 0.0, "progress_px": 0.0, "fitness": 0.0,
		"contact_rate": 0.0, "contacts": 0.0, "visible_seconds": 0.0,
		"hits": 0.0, "survival_seconds": 0.0, "survival_rate": 0.0, "search_reward": 0.0}
	var sim = Sim.new()
	for trial in cases:
		if trial.size() > 2 and not trial[3] is Array:
			setup_fire(sim, genomes, trial, blind)
		elif trial.size() > 2:
			setup_vision(sim, genomes, trial, blind)
		else:
			sim.setup(genomes, trial[1], trial[0], true)
		for tick in range(roundi(Sim.EPISODE_SECONDS / Sim.STEP)):
			sim.step(Sim.STEP)
		var scores = sim.scores()
		for i in range(totals.size()):
			totals[i] += scores[i] / cases.size()
		var metrics = sim.metrics()
		for key in summary:
			summary[key] += metrics[key] / cases.size()
	return {"scores": totals, "metrics": summary}
