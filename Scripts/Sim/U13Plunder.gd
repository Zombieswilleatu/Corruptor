extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const VERSION: String = "U13_PROFANE_PILLAGE_V1"

static func configure(world: Dictionary) -> void:
	world.data["plunder"] = {"version": VERSION, "resolved_round": 0, "results": [null, null]}

static func enabled(world: Dictionary) -> bool:
	var state = world.data.get("plunder")
	return typeof(state) == TYPE_DICTIONARY and state.get("version") == VERSION

static func zone_id(pid: int) -> String:
	return "castle_zone:%d" % pid

static func castleless(world: Dictionary, pid: int) -> bool:
	for row in world.entities.entities:
		if row.owner == pid and Structures.targetable(row):
			return false
	return true

static func eligible(castle: Dictionary, pid: int) -> bool:
	return Structures.targetable(castle) and castle.owner == pid and castle.attributes.status == "standing" and castle.attributes.integrity == castle.attributes.max_integrity

static func valid(world: Dictionary) -> bool:
	var state = world.data.get("plunder")
	if typeof(state) != TYPE_DICTIONARY or state.get("version") != VERSION or not Data.is_integer(state.get("resolved_round")) or state.resolved_round < 0:
		return false
	if typeof(state.get("results")) != TYPE_ARRAY or state.results.size() != 2:
		return false
	for pid in [0, 1]:
		var result = state.results[pid]
		if result == null:
			continue
		if typeof(result) != TYPE_DICTIONARY or result.size() != 6 or result.get("action") not in ["Profane", "Pillage"] or typeof(result.get("success")) != TYPE_BOOL or typeof(result.get("target_id")) != TYPE_STRING or result.target_id.is_empty() or not Data.is_integer(result.get("round")) or result.get("round") != state.resolved_round or state.resolved_round == 0:
			return false
		if not Data.is_integer(result.get("soul_gain")) or not Data.is_integer(result.get("tear_gain")):
			return false
		if result.get("soul_gain") != (1 if result.action == "Pillage" and result.success else 0) or result.get("tear_gain") != (1 if result.action == "Profane" and result.success else 0):
			return false
	return true

static func event(kind: String, data: Dictionary) -> Dictionary:
	var fact: Dictionary = {"type": kind, "text": "", "data": data}
	return {"event": fact, "views": [fact, fact]}

static func record(world: Dictionary, pid: int, round_number: int, action: String, target_id: String, success: bool) -> void:
	world.data.plunder.results[pid] = {"action": action, "round": round_number, "target_id": target_id, "success": success, "soul_gain": 1 if action == "Pillage" and success else 0, "tear_gain": 1 if action == "Profane" and success else 0}

static func profane(world: Dictionary, context: Dictionary, pid: int, order: Dictionary) -> Dictionary:
	var ids = Ids.new()
	ids.restore(world.entities)
	var castle: Dictionary = ids.get_entity(order.target_id)
	var success: bool = eligible(castle, pid)
	if success:
		castle.attributes.integrity = 0
		castle.attributes.status = "profaned"
		castle.attributes.artillery_target = ""
		ids.update(castle.id, pid, castle.attributes)
		world.entities = ids.snapshot()
	record(world, pid, context.round, "Profane", order.target_id, success)
	return {"action": "resolved", "world": world, "events": [event("PROFANE_RESOLVED", {"player_id": pid, "round": context.round, "target_id": order.target_id, "profaned": success, "tear_pending": success, "reason": "" if success else "target_no_longer_eligible"})]}

static func clear_castle_sigils(world: Dictionary, round_number: int) -> Array:
	var events: Array = []
	for pid in [0, 1]:
		if castleless(world, pid) and world.data.sigils[pid].Castle != "":
			world.data.sigils[pid].Castle = ""
			events.append(event("SIGIL_REMOVED", {"player_id": pid, "round": round_number, "lane": "Castle", "reason": "no_active_castles"}))
	return events

# End of ordinary combat, after both players act, before Post-Resolution 10A.
static func finish(world: Dictionary, round_number: int) -> Array:
	var events: Array = []
	for pid in [0, 1]:
		var result = world.data.plunder.results[pid]
		if result != null and result.tear_gain == 1:
			world.players[pid].resources.personal_tears += 1
			var veil: int = int(world.data.neutral_tears) + int(world.players[0].resources.personal_tears) + int(world.players[1].resources.personal_tears)
			events.append(event("PERSONAL_TEAR_CREATED", {"player_id": pid, "round": round_number, "source": "Profane", "castle_id": result.target_id, "amount": 1, "veil_after": veil}))
	world.data.plunder.resolved_round = round_number
	events.append_array(clear_castle_sigils(world, round_number))
	return events

static func snapshot_valid(context: Dictionary) -> bool:
	var world: Dictionary = context.world
	var state: Dictionary = world.data.plunder
	var after: bool = context.next_hook_index > Timeline.hook_rank(Timeline.COMBAT_RESOLUTION)
	if state.resolved_round != context.round - (0 if after else 1):
		return false
	var order: Dictionary = context.order
	var pid: int = context.player_id
	if context.next_hook_index > Timeline.hook_rank(Timeline.PRESENT_PUBLIC_STATE) and order.get("action") == "Siege" and order.get("target_id") == zone_id(1 - pid) and not castleless(context.presentation_world, 1 - pid):
		return false
	if context.next_hook_index > Timeline.hook_rank(Timeline.PRESENT_PUBLIC_STATE) and order.get("action") == "Profane":
		var source = Ids.new()
		source.restore(context.presentation_world.entities)
		if not eligible(source.get_entity(order.get("target_id", "")), pid):
			return false
	if not after:
		return true
	var result = state.results[pid]
	if result == null:
		return order.get("action") != "Profane"
	if result.target_id != order.get("target_id") or ("Profane" if result.action == "Profane" else "Siege") != order.get("action"):
		return false
	if result.action == "Profane" and result.success:
		var ids = Ids.new()
		ids.restore(world.entities)
		var castle: Dictionary = ids.get_entity(result.target_id)
		if castle.is_empty() or castle.owner != pid or castle.attributes.status != "profaned":
			return false
	return true
