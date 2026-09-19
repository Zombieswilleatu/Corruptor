extends RefCounted

# Sandbox scheduling only. Workers own their inputs and return data plus a
# private replay; they never touch the scene tree or decide when a round starts.
const Sim = preload("res://Scripts/Sim/U13LaneSandbox.gd")
const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")

static func commit(sim, inputs: Dictionary) -> Dictionary:
	var outcomes: Array = []
	for request in inputs.pending:
		outcomes.append(sim.spawn(request.name, request.owner, request.center, request.turret))
	var wave: Dictionary = sim.random_waves(inputs.owners)
	sim.prepare_releases(inputs.releases)
	if wave.action == "invalid": return wave
	if sim.units().is_empty() and sim.staged_units().is_empty() and inputs.owners.is_empty():
		return {"action": "idle", "reason": "Spawn units or enable random spawns for either side first.", "outcomes": outcomes}
	return {"action": "committed", "outcomes": outcomes}

static func resolve(world: Dictionary, seed_value: String, round_number: int) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = Sim.resolve_round(world, seed_value, round_number)
	if result.get("action") != "resolved": return result
	var playback = Playback.new()
	if not playback.build(result.events.map(func(row): return row.event)):
		return {"action": "invalid", "reason": "playback unavailable"}
	return {"action": "prepared", "result": result, "playback": playback, "prepare_ms": (Time.get_ticks_usec() - started) / 1000.0}

static func next_interval(candidate, finished: Dictionary, inputs: Dictionary) -> Dictionary:
	# finished.world is copied BEFORE starting this worker: finish mutates it,
	# and the visible arena may reach its own boundary while we are still busy.
	candidate.finish(finished)
	var committed: Dictionary = commit(candidate, inputs)
	var packet: Dictionary = resolve(candidate.world, candidate.seed_value, candidate.round_number) if committed.action == "committed" else committed
	packet["sim"] = candidate
	packet["outcomes"] = committed.get("outcomes", [])
	return packet
