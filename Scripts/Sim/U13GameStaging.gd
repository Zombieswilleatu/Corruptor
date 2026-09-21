extends RefCounted

# Full-game adapter of the lane runner's protected recruitment and release rule.
# Each lane has its own tray. Power-created units retain their power's timing.
const VERSION: String = "U13_GAME_STAGING_V2_MANUAL"
const LEGACY_VERSION: String = "U13_GAME_STAGING_V1"
const Lane = preload("res://Scripts/Sim/U13LaneStaging.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const LANES: Array = ["Lord", "Castle"]
# Auto is accepted only to load older carts; it now means no command.
const MODES: Array = ["Auto", "Hold", "March"]

static func configure(world: Dictionary) -> void:
	var state: Dictionary = {"version": VERSION, "lanes": {}}
	for lane in LANES:
		var temporary: Dictionary = {"data": {}}
		Lane.configure(temporary, 15)
		state.lanes[lane] = temporary.data.marcher_staging
		state.lanes[lane]["march_round"] = [0, 0]
	world.data["game_staging"] = state

static func enabled(world: Dictionary) -> bool:
	return world.get("data", {}).get("game_staging", {}).get("version") in [VERSION, LEGACY_VERSION]

static func rows(world: Dictionary) -> Array:
	var result: Array = []
	for state in world.get("data", {}).get("game_staging", {}).get("lanes", {}).values():
		result.append_array(state.units)
	return result

static func order_valid(world: Dictionary, order: Dictionary) -> bool:
	if not order.has("staging"): return true
	if not enabled(world) or typeof(order.staging) != TYPE_DICTIONARY: return false
	for lane in order.staging:
		if lane not in LANES or order.staging[lane] not in MODES: return false
	return true

static func lane_world(world: Dictionary, lane: String) -> Dictionary:
	return {"entities": {"entities": world.entities.entities.filter(func(u): return u.kind == "marcher" and u.attributes.lane == lane)}, "data": {"marcher_staging": world.data.game_staging.lanes[lane]}}

static func capture(world: Dictionary, events: Array, number: int) -> Array:
	if not enabled(world): return []
	var ids: Array = []
	for row in events:
		if row.event.type == "MARCHER_SPAWNED": ids.append(row.event.data.id)
	var stored: Array = []
	for lane in LANES:
		var temporary: Dictionary = lane_world(world, lane)
		var selected: Array = temporary.entities.entities.filter(func(u): return u.id in ids).map(func(u): return u.id)
		Lane.store_units(temporary, selected, number)
		stored.append_array(selected)
	world.entities.entities = world.entities.entities.filter(func(u): return u.id not in stored)
	return [] if stored.is_empty() else [Marching.public_event("RECRUITS_STAGED", {"round": number, "unit_ids": stored})]

static func prepare(world: Dictionary, number: int, orders: Array) -> Array:
	if not enabled(world): return []
	var events: Array = []
	world.data.game_staging.version = VERSION
	for lane in LANES:
		var temporary: Dictionary = lane_world(world, lane)
		var tray: Dictionary = temporary.data.marcher_staging
		if not tray.has("march_round"): tray["march_round"] = [0, 0]
		if tray.prepared_round >= number: continue
		var due: Array = tray.get("march_round", [0, 0]).duplicate()
		var decisions: Array = []
		for pid in [0, 1]:
			var release: bool = int(due[pid]) > 0 and int(due[pid]) <= number
			decisions.append({"owner": pid, "release": release, "reason": "Waiting for MARCH.", "force": 0, "pressure": 0, "released": 0, "overflow": 0})
		# Release last round's command; this round's recruits belong to the next wave.
		for pid in [number % 2, 1 - number % 2]:
			if decisions[pid].release:
				var chosen: Array = Lane.eligible(temporary, pid, number)
				Lane.deploy(temporary, chosen, number)
				decisions[pid].released = chosen.size()
				decisions[pid].reason = "MARCH: staged group deployed."
				due[pid] = 0
			if orders[pid].get("staging", {}).get(lane, "Hold") == "March":
				due[pid] = number + 1
				decisions[pid].reason += " March scheduled for round %d." % (number + 1)
		tray["march_round"] = due
		tray.decisions = decisions
		tray.prepared_round = number
		world.entities.entities = world.entities.entities.filter(func(u): return u.kind != "marcher" or u.attributes.lane != lane) + temporary.entities.entities
		events.append(Marching.public_event("STAGING_RELEASE", {"round": number, "lane": lane, "decisions": decisions.duplicate(true)}))
	world.entities.entities.sort_custom(func(a, b): return a.id < b.id)
	return events

# Bots submit the same explicit next-round command as the human. Their decision
# uses only their reserves and public lane positions, never the sealed enemy cart.
static func bot_order(view: Dictionary, number: int, pid: int) -> Dictionary:
	if not view.has("game_staging"): return {}
	var result: Dictionary = {}
	for lane in LANES:
		var tray: Dictionary = view.game_staging.lanes[lane]
		var temporary: Dictionary = {"data": {"marcher_staging": tray}, "entities": {"entities": view.entities.filter(func(u): return u.kind == "marcher" and u.attributes.lane == lane)}}
		# All current reserves will be eligible when this command takes effect.
		if Lane.decision(temporary, pid, number + 1, "Auto").release: result[lane] = "March"
	return result

static func valid(world: Dictionary) -> bool:
	# Older saves keep their existing deployment contract.
	if not world.data.has("game_staging"): return true
	if not enabled(world): return false
	var state: Dictionary = world.data.game_staging
	if typeof(state.get("lanes")) != TYPE_DICTIONARY or state.lanes.size() != 2: return false
	var combined: Dictionary = {"data": world.data, "entities": world.entities.duplicate()}
	combined.entities.entities = world.entities.entities.duplicate()
	var seen: Dictionary = {}
	for row in world.entities.entities: seen[row.id] = true
	for lane in LANES:
		var tray = state.lanes.get(lane)
		if typeof(tray) != TYPE_DICTIONARY or tray.get("version") != Lane.VERSION or tray.get("capacity") != 15: return false
		if not Data.is_integer(tray.get("prepared_round")) or tray.prepared_round < 0 or typeof(tray.get("decisions")) != TYPE_ARRAY or typeof(tray.get("units")) != TYPE_ARRAY: return false
		var due = tray.get("march_round", [0, 0])
		if typeof(due) != TYPE_ARRAY or due.size() != 2: return false
		for value in due:
			if not Data.is_integer(value) or (value != 0 and value != tray.prepared_round + 1): return false
		if state.version == VERSION and not tray.has("march_round"): return false
		for unit in tray.units:
			if typeof(unit) != TYPE_DICTIONARY or unit.get("kind") != "marcher" or typeof(unit.get("attributes")) != TYPE_DICTIONARY: return false
			var a: Dictionary = unit.attributes
			if seen.has(unit.get("id")) or a.get("lane") != lane or not Data.is_integer(a.get("staged_round")) or a.staged_round < 1: return false
			if a.get("birth_round") != a.staged_round or a.get("movement_ready_round") != a.staged_round + 1 or a.get("waiting") != false or a.has("deployed_round"): return false
			seen[unit.get("id")] = true
			combined.entities.entities.append(unit)
	combined.entities.entities.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	var registry = Marching.Ids.new()
	return registry.restore(combined.entities).action != "invalid" and Marching.valid(combined)
