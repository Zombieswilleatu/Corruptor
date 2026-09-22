extends RefCounted

# Full-game adapter of the lane runner's protected recruitment and release rule.
# Each lane has its own tray. Power-created units retain their power's timing.
const VERSION: String = "U13_GAME_STAGING_V3_CAP"
const MANUAL_VERSION: String = "U13_GAME_STAGING_V2_MANUAL"
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
	return world.get("data", {}).get("game_staging", {}).get("version") in [VERSION, MANUAL_VERSION, LEGACY_VERSION]

static func rows(world: Dictionary) -> Array:
	var result: Array = []
	for state in world.get("data", {}).get("game_staging", {}).get("lanes", {}).values():
		result.append_array(state.units)
	return result

static func order_valid(world: Dictionary, order: Dictionary) -> bool:
	if order.has("staging_ids"):
		if not order.has("staging") or typeof(order.staging_ids) != TYPE_DICTIONARY: return false
		for lane in order.staging_ids:
			if lane not in LANES or typeof(order.staging_ids[lane]) != TYPE_ARRAY: return false
			var seen: Dictionary = {}
			for id in order.staging_ids[lane]:
				if typeof(id) != TYPE_STRING or seen.has(id): return false
				seen[id] = true
	if not order.has("staging"): return true
	if not enabled(world) or typeof(order.staging) != TYPE_DICTIONARY: return false
	for lane in order.staging:
		if lane not in LANES or order.staging[lane] not in MODES: return false
	return true

static func lane_world(world: Dictionary, lane: String) -> Dictionary:
	return {"entities": {"entities": world.entities.entities.filter(func(u): return u.kind == "marcher" and u.attributes.lane == lane)}, "data": {"marcher_staging": world.data.game_staging.lanes[lane]}}

# Oldest eligible bodies leave first; a new body never bypasses its birth hold.
static func make_room(temporary: Dictionary, pid: int, number: int, incoming: int) -> Array:
	var tray: Dictionary = temporary.data.marcher_staging
	var needed: int = maxi(0, Lane.rows(temporary, pid).size() + mini(incoming, int(tray.capacity)) - int(tray.capacity))
	if needed == 0: return []
	var ready: Array = Lane.eligible(temporary, pid, number)
	ready.sort_custom(func(a, b): return a.attributes.staged_round < b.attributes.staged_round if a.attributes.staged_round != b.attributes.staged_round else a.id < b.id)
	var chosen: Array = ready.slice(0, needed)
	Lane.deploy(temporary, chosen, number)
	return chosen.map(func(u): return u.id)

static func overflow_event(lane: String, pid: int, number: int, ids: Array) -> Dictionary:
	return Marching.public_event("STAGING_OVERFLOW_RELEASED", {"round": number, "lane": lane, "player_id": pid, "unit_ids": ids, "capacity": 15})

static func upgrade_if_bounded(world: Dictionary) -> void:
	for tray in world.data.game_staging.lanes.values():
		for pid in [0, 1]:
			if tray.units.filter(func(u): return u.owner == pid).size() > int(tray.capacity): return
	for tray in world.data.game_staging.lanes.values():
		if not tray.has("march_round"): tray["march_round"] = [0, 0]
	world.data.game_staging.version = VERSION

# Repair oversized V1/V2 saves at the first eligible boundary, without deleting
# existing reserves or rejecting a historical save merely for the former bug.
static func enforce_capacity(world: Dictionary, number: int) -> Array:
	var events: Array = []
	for lane in LANES:
		var temporary: Dictionary = lane_world(world, lane)
		for pid in [number % 2, 1 - number % 2]:
			var released: Array = make_room(temporary, pid, number, 0)
			if not released.is_empty(): events.append(overflow_event(lane, pid, number, released))
		world.entities.entities = world.entities.entities.filter(func(u): return u.kind != "marcher" or u.attributes.lane != lane) + temporary.entities.entities
	world.entities.entities.sort_custom(func(a, b): return a.id < b.id)
	upgrade_if_bounded(world)
	return events

static func capture(world: Dictionary, events: Array, number: int) -> Array:
	if not enabled(world): return []
	var ids: Array = []
	for row in events:
		if row.event.type == "MARCHER_SPAWNED": ids.append(row.event.data.id)
	var stored: Array = []
	var rejected: Array = []
	var additions: Array = []
	for lane in LANES:
		var temporary: Dictionary = lane_world(world, lane)
		for pid in [number % 2, 1 - number % 2]:
			var incoming: Array = temporary.entities.entities.filter(func(u): return u.id in ids and u.owner == pid)
			# A chosen grimoire gets room before ordinary recruitment. Stable IDs
			# settle ties, independently of registry or input-event ordering.
			incoming.sort_custom(func(a, b): return a.attributes.has("monster_id") if a.attributes.has("monster_id") != b.attributes.has("monster_id") else a.id < b.id)
			var released: Array = make_room(temporary, pid, number, incoming.size())
			if not released.is_empty(): additions.append(overflow_event(lane, pid, number, released))
			var room: int = maxi(0, int(temporary.data.marcher_staging.capacity) - Lane.rows(temporary, pid).size())
			var admitted: Array = incoming.slice(0, room).map(func(u): return u.id)
			var excess: Array = incoming.slice(room).map(func(u): return u.id)
			Lane.store_units(temporary, admitted, number)
			stored.append_array(admitted)
			rejected.append_array(excess)
			if not excess.is_empty(): additions.append(Marching.public_event("STAGING_RECRUITMENT_CAPPED", {"round": number, "lane": lane, "player_id": pid, "count": excess.size(), "capacity": 15}))
			temporary.entities.entities = temporary.entities.entities.filter(func(u): return u.id not in excess)
		world.entities.entities = world.entities.entities.filter(func(u): return u.kind != "marcher" or u.attributes.lane != lane) + temporary.entities.entities
	# Rejected births are not battlefield deaths or successful summons.
	events.assign(events.filter(func(row): return row.event.type != "MARCHER_SPAWNED" or row.event.data.id not in rejected))
	for row in events:
		if row.event.type == "MONSTER_SUMMONED":
			for fact in [row.event] + row.views:
				fact.data.unit_ids = fact.data.unit_ids.filter(func(id): return id not in rejected)
	events.assign(events.filter(func(row): return row.event.type != "MONSTER_SUMMONED" or not row.event.data.unit_ids.is_empty()))
	if not stored.is_empty(): additions.append(Marching.public_event("RECRUITS_STAGED", {"round": number, "unit_ids": stored}))
	world.entities.entities.sort_custom(func(a, b): return a.id < b.id)
	upgrade_if_bounded(world)
	return additions

static func release_due(world: Dictionary, number: int) -> Array:
	if not enabled(world): return []
	var events: Array = enforce_capacity(world, number)
	for lane in LANES:
		var temporary: Dictionary = lane_world(world, lane)
		var tray: Dictionary = temporary.data.marcher_staging
		var due: Array = tray.get("march_round", [0, 0]).duplicate()
		if not due.any(func(n): return int(n) > 0 and int(n) <= number): continue
		var decisions: Array = []
		for pid in [0, 1]:
			decisions.append({"owner": pid, "release": int(due[pid]) > 0 and int(due[pid]) <= number, "reason": "Waiting for MARCH.", "force": 0, "pressure": 0, "released": 0, "overflow": 0})
		for pid in [number % 2, 1 - number % 2]:
			if not decisions[pid].release: continue
			var chosen: Array = Lane.eligible(temporary, pid, number)
			Lane.deploy(temporary, chosen, number)
			decisions[pid].released = chosen.size()
			decisions[pid].reason = "MARCH: staged group deployed at round opening."
			due[pid] = 0
		tray["march_round"] = due
		tray.decisions = decisions
		world.entities.entities = world.entities.entities.filter(func(u): return u.kind != "marcher" or u.attributes.lane != lane) + temporary.entities.entities
		events.append(Marching.public_event("STAGING_RELEASE", {"round": number, "lane": lane, "decisions": decisions.duplicate(true)}))
	world.entities.entities.sort_custom(func(a, b): return a.id < b.id)
	return events

static func prepare(world: Dictionary, number: int, orders: Array) -> Array:
	if not enabled(world): return []
	var events: Array = enforce_capacity(world, number)
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
		# Normally released at round opening. Retain this catch-up for saves
		# made by older builds after opening but before marching.
		for pid in [number % 2, 1 - number % 2]:
			if decisions[pid].release:
				var chosen: Array = Lane.eligible(temporary, pid, number)
				Lane.deploy(temporary, chosen, number)
				decisions[pid].released = chosen.size()
				decisions[pid].reason = "MARCH: staged group deployed."
				due[pid] = 0
			if orders[pid].get("staging", {}).get(lane, "Hold") == "March":
				var chosen: Array = Lane.eligible(temporary, pid, number)
				if orders[pid].get("staging_ids", {}).has(lane):
					chosen = chosen.filter(func(u): return u.id in orders[pid].staging_ids[lane])
				Lane.deploy(temporary, chosen, number)
				decisions[pid].release = not chosen.is_empty()
				decisions[pid].released += chosen.size()
				decisions[pid].reason = "MARCH: visible reserves deployed; new recruits stay staged."
		tray["march_round"] = due
		tray.decisions = decisions
		tray.prepared_round = number
		world.entities.entities = world.entities.entities.filter(func(u): return u.kind != "marcher" or u.attributes.lane != lane) + temporary.entities.entities
		events.append(Marching.public_event("STAGING_RELEASE", {"round": number, "lane": lane, "decisions": decisions.duplicate(true)}))
	world.entities.entities.sort_custom(func(a, b): return a.id < b.id)
	return events

# Bots submit the same current-round command as the human. Their decision
# uses only their reserves and public lane positions, never the sealed enemy cart.
static func bot_order(view: Dictionary, number: int, pid: int) -> Dictionary:
	if not view.has("game_staging"): return {}
	var result: Dictionary = {}
	for lane in LANES:
		var tray: Dictionary = view.game_staging.lanes[lane]
		var temporary: Dictionary = {"data": {"marcher_staging": tray}, "entities": {"entities": view.entities.filter(func(u): return u.kind == "marcher" and u.attributes.lane == lane)}}
		# Only reserves visible before this round are eligible.
		if Lane.decision(temporary, pid, number, "Auto").release: result[lane] = "March"
	return result

static func valid(world: Dictionary) -> bool:
	# Older saves keep their existing deployment contract.
	if not world.data.has("game_staging"): return true
	if not enabled(world): return false
	for key in ["marching_clock", "opening_marching_round"]:
		if world.data.has(key) and (not Data.is_integer(world.data[key]) or world.data[key] < 0): return false
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
		if state.version in [VERSION, MANUAL_VERSION] and not tray.has("march_round"): return false
		var counts: Array = [0, 0]
		for unit in tray.units:
			if typeof(unit) != TYPE_DICTIONARY or unit.get("kind") != "marcher" or typeof(unit.get("attributes")) != TYPE_DICTIONARY: return false
			if unit.get("owner") not in [0, 1]: return false
			counts[int(unit.owner)] += 1
			if state.version == VERSION and counts[int(unit.owner)] > 15: return false
			var a: Dictionary = unit.attributes
			if seen.has(unit.get("id")) or a.get("lane") != lane or not Data.is_integer(a.get("staged_round")) or a.staged_round < 1: return false
			if a.get("birth_round") != a.staged_round or a.get("movement_ready_round") != a.staged_round + 1 or a.get("waiting") != false or a.has("deployed_round"): return false
			seen[unit.get("id")] = true
			combined.entities.entities.append(unit)
	combined.entities.entities.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	var registry = Marching.Ids.new()
	return registry.restore(combined.entities).action != "invalid" and Marching.valid(combined)
