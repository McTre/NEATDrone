extends RefCounted
## Small feed-forward NEAT: historical markings, topology mutations,
## compatibility species, fitness sharing, crossover and species elitism.

const INPUT_COUNT = 9
const OUTPUT_IDS = [10, 11]
const FIRST_HIDDEN = 12
const COMPATIBILITY = 2.4

class Genome:
	extends RefCounted
	var nodes: Dictionary = {} # ID -> feed-forward depth
	var genes: Array = [] # historical innovation, endpoints, weight, enabled
	var fitness: float = 0.0
	var species: int = 0
	var order: Array = []
	var incoming: Dictionary = {}
	var values: PackedFloat64Array = []

	func copy():
		var result = get_script().new()
		result.nodes = nodes.duplicate()
		result.genes = genes.duplicate(true)
		result.fitness = fitness
		result.species = species
		result.compile()
		return result

	func compile() -> void:
		order = nodes.keys()
		order.sort_custom(func(a, b): return nodes[a] < nodes[b])
		incoming.clear()
		var max_id = 11
		for id in order:
			max_id = maxi(max_id, id)
			incoming[id] = []
		for gene in genes:
			if gene.enabled:
				incoming[gene.to].append(gene)
		values.resize(max_id + 1)

	func activate(inputs: PackedFloat64Array) -> Vector2:
		for i in range(INPUT_COUNT):
			values[i] = inputs[i]
		values[9] = 1.0 # bias, not a world observation
		for id in order:
			if id <= 9:
				continue
			var total = 0.0
			for gene in incoming[id]:
				total += values[gene.from] * gene.weight
			values[id] = tanh(total)
		return Vector2(values[10], values[11]).limit_length()

var rng = RandomNumberGenerator.new()
var population: Array = []
var generation = 1
var population_size = 48
var innovations: Dictionary = {}
var splits: Dictionary = {}
var next_innovation = 0
var next_node = FIRST_HIDDEN
var species_serial = 0
var species_records: Array = []
var champion = null
var last_best = 0.0
var last_average = 0.0

func _init(seed_value: int = 42, count: int = 48) -> void:
	rng.seed = seed_value
	population_size = maxi(4, count)
	for i in range(population_size):
		var genome = Genome.new()
		for id in range(FIRST_HIDDEN):
			genome.nodes[id] = 0.0 if id <= 9 else 1.0
		for source in range(10):
			for dest in OUTPUT_IDS:
				genome.genes.append(connection(source, dest, rng.randfn(0.0, 0.65)))
		genome.compile()
		population.append(genome)
	assign_species()

func connection(source: int, dest: int, weight: float) -> Dictionary:
	var key = "%d:%d" % [source, dest]
	if not innovations.has(key):
		innovations[key] = next_innovation
		next_innovation += 1
	return {"innovation": innovations[key], "from": source, "to": dest,
		"weight": weight, "enabled": true}

func add_node(genome) -> void:
	var candidates = genome.genes.filter(func(g): return g.enabled)
	if candidates.is_empty():
		return
	var gene = candidates[rng.randi_range(0, candidates.size() - 1)]
	if not splits.has(gene.innovation):
		splits[gene.innovation] = next_node
		next_node += 1
	var node_id: int = splits[gene.innovation]
	if genome.nodes.has(node_id):
		return
	gene.enabled = false
	genome.nodes[node_id] = (genome.nodes[gene.from] + genome.nodes[gene.to]) * 0.5
	genome.genes.append(connection(gene.from, node_id, 1.0))
	genome.genes.append(connection(node_id, gene.to, gene.weight))

func add_connection(genome) -> void:
	var ids = genome.nodes.keys()
	for attempt in range(24):
		var source: int = ids[rng.randi_range(0, ids.size() - 1)]
		var dest: int = ids[rng.randi_range(0, ids.size() - 1)]
		if genome.nodes[source] >= genome.nodes[dest]:
			continue # No recurrent links in this POC.
		var exists = false
		for gene in genome.genes:
			if gene.from == source and gene.to == dest:
				exists = true
				if not gene.enabled:
					gene.enabled = true
					return
		if not exists:
			genome.genes.append(connection(source, dest, rng.randfn()))
			return

func mutate(genome) -> void:
	for gene in genome.genes:
		if rng.randf() < 0.8:
			gene.weight = clampf(gene.weight + rng.randfn(0.0, 0.3), -6.0, 6.0)
		if rng.randf() < 0.025:
			gene.weight = rng.randfn()
	if rng.randf() < 0.12:
		add_node(genome)
	if rng.randf() < 0.2:
		add_connection(genome)
	genome.compile()

func distance(a, b) -> float:
	var by_id = {}
	var max_a = -1
	var max_b = -1
	for gene in a.genes:
		by_id[gene.innovation] = gene
		max_a = maxi(max_a, gene.innovation)
	for gene in b.genes:
		max_b = maxi(max_b, gene.innovation)
	var matching = 0
	var weight_difference = 0.0
	var excess = 0
	var disjoint = 0
	for gene in b.genes:
		if by_id.has(gene.innovation):
			matching += 1
			weight_difference += absf(gene.weight - by_id[gene.innovation].weight)
			by_id.erase(gene.innovation)
		elif gene.innovation > max_a:
			excess += 1
		else:
			disjoint += 1
	for id in by_id:
		if id > max_b:
			excess += 1
		else:
			disjoint += 1
	var normalizer = float(maxi(a.genes.size(), b.genes.size()))
	if normalizer < 20:
		normalizer = 1.0
	return (excess + disjoint) / normalizer + 1.5 * weight_difference / maxi(1, matching)

func assign_species() -> void:
	for record in species_records:
		record.members = []
	for genome in population:
		var found = false
		for record in species_records:
			if distance(genome, record.representative) < COMPATIBILITY:
				record.members.append(genome)
				genome.species = record.id
				found = true
				break
		if not found:
			species_serial += 1
			genome.species = species_serial
			species_records.append({"id": species_serial, "representative": genome.copy(),
				"members": [genome], "best": -INF, "stale": 0})
	species_records = species_records.filter(func(s): return not s.members.is_empty())
	for record in species_records:
		record.representative = record.members[0].copy()

func crossover(a, b):
	if b.fitness > a.fitness:
		var temporary = a
		a = b
		b = temporary
	# Disjoint/excess genes come from the fitter parent; ties choose a parent
	# randomly in the caller. Matching genes align by historical innovation.
	var child = a.copy()
	var other = {}
	for gene in b.genes:
		other[gene.innovation] = gene
	for gene in child.genes:
		if other.has(gene.innovation):
			var mate = other[gene.innovation]
			if rng.randf() < 0.5:
				gene.weight = mate.weight
			if not gene.enabled or not mate.enabled:
				gene.enabled = rng.randf() >= 0.75
	child.compile()
	return child

func tournament(members: Array):
	var selected = members[rng.randi_range(0, members.size() - 1)]
	for i in range(2):
		var candidate = members[rng.randi_range(0, members.size() - 1)]
		if candidate.fitness > selected.fitness:
			selected = candidate
	return selected

func evolve(scores: Array) -> void:
	assert(scores.size() == population.size())
	last_average = 0.0
	var minimum = INF
	for i in range(population.size()):
		population[i].fitness = scores[i]
		last_average += scores[i] / population.size()
		minimum = minf(minimum, scores[i])
	var ranked = population.duplicate()
	ranked.sort_custom(func(a, b): return a.fitness > b.fitness)
	champion = ranked[0].copy()
	last_best = champion.fitness
	var eligible: Array = []
	var total_weight = 0.0
	for record in species_records:
		record.members.sort_custom(func(a, b): return a.fitness > b.fitness)
		var best: float = record.members[0].fitness
		if best > record.best + 0.01:
			record.best = best
			record.stale = 0
		else:
			record.stale += 1
		if record.stale >= 15 and record.id != champion.species:
			continue
		var weight = 0.0
		for member in record.members:
			weight += (member.fitness - minimum + 1.0) / record.members.size()
		record.weight = weight
		total_weight += weight
		eligible.append(record)
	var offspring: Array = [champion.copy()]
	# Retain an elite from each surviving species, while always preserving
	# the population champion, independent of structural mutations.
	for record in eligible:
		if record.id != champion.species and offspring.size() < population_size:
			offspring.append(record.members[0].copy())
	while offspring.size() < population_size:
		var pick = rng.randf() * total_weight
		var selected = eligible[-1]
		for record in eligible:
			pick -= record.weight
			if pick <= 0:
				selected = record
				break
		var pool: Array = selected.members.slice(0, maxi(1, ceili(selected.members.size() * 0.5)))
		var parent = tournament(pool)
		var child = crossover(parent, tournament(pool)) if rng.randf() < 0.75 else parent.copy()
		mutate(child)
		offspring.append(child)
	population = offspring
	generation += 1
	assign_species()
