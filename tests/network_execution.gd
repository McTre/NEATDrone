extends SceneTree
const Neat = preload("res://scripts/neat.gd")

func reference(genome, inputs: PackedFloat64Array) -> Vector2:
	var values = {9: 1.0}
	for i in range(inputs.size()):
		values[genome.input_ids[i]] = inputs[i]
	for id in genome.order:
		if genome.nodes[id] == 0.0:
			continue
		var total = 0.0
		for gene in genome.genes:
			if gene.enabled and gene.to == id:
				total += values[gene.from] * gene.weight
		values[id] = tanh(total)
	return Vector2(values[10], values[11]).limit_length()

func _initialize() -> void:
	var neat = Neat.new(91, 8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 313
	var checks = 0
	for pass_index in range(40):
		if pass_index == 20:
			neat.unlock_vision()
		for genome in neat.population:
			neat.mutate(genome)
			var inputs = PackedFloat64Array()
			for id in genome.input_ids:
				inputs.append(rng.randf_range(-1, 1))
			if not genome.activate(inputs).is_equal_approx(reference(genome, inputs)):
				push_error("Compiled network changed the genome's output")
				quit(1)
				return
			checks += 1
	print("NETWORK EXECUTION: %d reference comparisons passed, including topology mutations and vision upgrade" % checks)
	quit()
