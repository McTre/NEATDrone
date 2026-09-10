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

static func evaluate(genomes: Array, cases: Array = TRAIN_CASES) -> Dictionary:
	var totals: Array = []
	totals.resize(genomes.size())
	totals.fill(0.0)
	var summary = {"arrival_rate": 0.0, "wall_seconds": 0.0, "progress_px": 0.0, "fitness": 0.0}
	var sim = Sim.new()
	for trial in cases:
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
