extends "res://Scripts/Sim/U13BoardSession.gd"

# Opt-in visual stress fixture. All movement and fighting use the real owner.
const Baseline = preload("res://Scripts/Sim/U13SmokeSession.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const DENSE_SEED: String = "u13_dense_board_v1"
const COUNT: int = 48


func reset(scenario: int = 0) -> Dictionary:
	if scenario != 0:
		return Data.invalid("dense_scenario_invalid")
	var world: Dictionary = Baseline._initial_world()
	var ids = Ids.new()
	var restored: Dictionary = ids.restore(world.entities)
	if restored.action == "invalid":
		return restored
	for index in range(COUNT):
		var owner: int = index % 2
		var suit: String = Marching.SUITS[(index >> 1) % 4]
		var attributes: Dictionary = Marching.profile(suit, "Castle", owner, 0, 1)
		var made: Dictionary = ids.create("marcher", "dense:opening", index, owner, attributes)
		if made.action == "invalid":
			return made
		var placed: Dictionary = Marching.place_spawn(ids, made.entity.id, DENSE_SEED)
		if placed.action == "invalid":
			return placed
	# Translate after placing every unit so spacing sees the entire spawn group.
	# Bring opposing fronts closer for contact during the first playback.
	for unit in ids.snapshot().entities:
		if unit.kind != "marcher":
			continue
		unit.attributes.x_fp += 900 if unit.owner == 0 else -900
		var moved: Dictionary = ids.update(unit.id, unit.owner, unit.attributes)
		if moved.action == "invalid":
			return moved
	world.entities = ids.snapshot()
	var content = Gremory.new()
	var candidate = content.create_combat_match()
	var started: Dictionary = candidate.start(DENSE_SEED, world, [0, 1])
	if started.action == "invalid":
		return started
	_owner = candidate
	_scenario = 0
	_lane = "Castle"
	_last_marching = []
	_powers = []
	_order = {}
	_opponent = {}
	return _to_planning()


func random_opponent_plan() -> Dictionary:
	# Keep the measured opening population fixed: no extra summons or commitments.
	# These empty submissions still pass normal owner legality and resolution.
	return {"powers": [], "order": {}}
