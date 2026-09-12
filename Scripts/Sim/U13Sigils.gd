extends RefCounted

const Plunder = preload("res://Scripts/Sim/U13Plunder.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Stats = preload("res://Scripts/Sim/U13LordStats.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const VERSION: String = "U13_SIGIL_LIFECYCLE_V1"
const LANES: Array = ["Lord", "Castle"]

static func configure(world: Dictionary) -> void:
	world.data["sigil_lifecycle"] = {"version": VERSION, "aged_round": 0, "created_round": 0}
	world.data.sigils = [{"Lord": "", "Castle": ""}, {"Lord": "", "Castle": ""}]

static func valid(world: Dictionary) -> bool:
	var state = world.data.get("sigil_lifecycle")
	return typeof(state) == TYPE_DICTIONARY and state.get("version") == VERSION and Data.is_integer(state.get("aged_round")) and state.aged_round >= 0 and Data.is_integer(state.get("created_round")) and state.created_round >= 0

static func event(type: String, details: Dictionary) -> Dictionary:
	var row: Dictionary = {"type": type, "text": "Sigil " + details.get("state_label", "updated") + ".", "data": details}
	return {"event": row, "views": [row, row]}

static func on_hook(context: Dictionary) -> Dictionary:
	if context.hook not in [Timeline.ROUND_START_AUTOMATIC, Timeline.COMMITMENT_REVEAL]:
		return {"action": "resolved", "world": context.world, "events": []}
	if not valid(context.world):
		return Data.invalid("sigil_lifecycle_invalid")
	var world: Dictionary = context.world.duplicate(true)
	var events: Array = []
	var state: Dictionary = world.data.sigil_lifecycle
	if context.hook == Timeline.ROUND_START_AUTOMATIC:
		if state.aged_round != context.round - 1:
			return Data.invalid("sigil_age_clock_invalid")
		for pid in [0, 1]:
			for lane in LANES:
				var before: String = world.data.sigils[pid][lane]
				if before.is_empty():
					continue
				var after: String = "flipped" if before == "fresh" else ""
				world.data.sigils[pid][lane] = after
				events.append(event("SIGIL_AGED", {"player_id": pid, "lane": lane, "round": context.round, "before": before, "after": after, "state_label": "decaying" if after == "flipped" else "expired"}))
		state.aged_round = context.round
	else:
		if state.created_round != context.round - 1 or state.aged_round != context.round:
			return Data.invalid("sigil_creation_clock_invalid")
		var ids = Ids.new()
		if ids.restore(world.entities).action == "invalid":
			return Data.invalid("sigil_entities_invalid")
		for pid in [0, 1]:
			var order: Dictionary = context.combat_orders[pid]
			if order.get("action") != "Ward":
				continue
			var lane: String = order.lane
			if lane not in LANES:
				return Data.invalid("sigil_lane_invalid")
			if lane == "Castle" and Plunder.enabled(world) and Plunder.castleless(world, pid):
				continue
			var before: String = world.data.sigils[pid][lane]
			world.data.sigils[pid][lane] = "fresh"
			var actor: Dictionary = ids.get_entity(world.players[pid].lord_entity_id)
			var threat_before = Stats.threat_value(actor)
			var threat_after = threat_before
			if lane == "Lord" and threat_before != null:
				threat_after = maxi(0, int(threat_before) - 1)
				actor.attributes["threat"] = threat_after
				if ids.update(actor.id, pid, actor.attributes).action == "invalid":
					return Data.invalid("sigil_threat_update_invalid")
			events.append(event("SIGIL_CREATED", {"player_id": pid, "lane": lane, "round": context.round, "before": before, "after": "fresh", "state_label": "fresh", "threat_before": threat_before, "threat_after": threat_after}))
		world.entities = ids.snapshot()
		state.created_round = context.round
	return {"action": "resolved", "world": world, "events": events}
