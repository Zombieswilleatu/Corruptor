extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const VERSION: String = "U13_ROUT_V1"


static func valid_attributes(a: Dictionary) -> bool:
	if not a.has("rout_round"):
		return not a.has("rout_effect_id")
	return (
		Data.is_integer(a.rout_round)
		and a.rout_round > 0
		and typeof(a.get("rout_effect_id")) == TYPE_STRING
		and not a.rout_effect_id.is_empty()
	)


static func retreating(a: Dictionary, round_number: int) -> bool:
	return a.get("rout_round", -1) == round_number


static func recovering(a: Dictionary, round_number: int) -> bool:
	return a.get("rout_round", -2) == round_number - 1


# Odd fixed-point speeds alternate halves over the even 200-tick phase.
# Base step and ownership direction are never rewritten.
static func speed(a: Dictionary, round_number: int, clock: int) -> int:
	var base: int = int(a.step_fp)
	return ((base >> 1) + ((base & 1) * (clock & 1))) if recovering(a, round_number) else base


static func apply(record: Dictionary, context: Dictionary) -> Dictionary:
	var world: Dictionary = context.world.duplicate(true)
	var source: Dictionary = record.declaration
	var entities = Ids.new()
	entities.restore(world.entities)
	var affected: Array = []
	var lifetime_id: String = Data.instance_id("persistent", source.declaration_id, source.power_id)
	for unit in entities.snapshot().entities:
		if (
			unit.kind != "marcher"
			or unit.owner != 1 - int(source.player_id)
			or unit.attributes.lane != source.target.lane
		):
			continue
		unit.attributes["rout_round"] = context.round
		unit.attributes["rout_effect_id"] = lifetime_id
		# Waiters leave the enemy gate and become ordinary marching bodies again.
		unit.attributes.waiting = false
		unit.attributes.waiting_since_round = 0
		unit.attributes.contact_tick = -1
		entities.update(unit.id, unit.owner, unit.attributes)
		affected.append(unit.id)
	world.entities = entities.snapshot()
	return {
		"action": "resolved",
		"persistent_payload": {"affected_ids": affected.duplicate()},
		"world": world,
		"events":
		[
			{
				"type": "ROUT_APPLIED",
				"text": "",
				"data":
				{
					"player_id": source.player_id,
					"round": context.round,
					"lane": source.target.lane,
					"affected_ids": affected,
					"effect_id": lifetime_id,
					"recovery_round": int(context.round) + 1
				}
			}
		]
	}


# Step 2 owns the phase change, alongside the shared persistent/cooldown clocks.
static func advance(context: Dictionary) -> Dictionary:
	var world: Dictionary = context.world.duplicate(true)
	var entities = Ids.new()
	entities.restore(world.entities)
	var events: Array = []
	for unit in entities.snapshot().entities:
		if unit.kind != "marcher" or not unit.attributes.has("rout_round"):
			continue
		var age: int = int(context.round) - int(unit.attributes.rout_round)
		if age < 1:
			continue
		var event: Dictionary = {
			"type": "ROUT_RECOVERING" if age == 1 else "ROUT_ENDED",
			"text": "",
			"data":
			{
				"entity_id": unit.id,
				"round": context.round,
				"effect_id": unit.attributes.rout_effect_id
			}
		}
		events.append({"event": event, "views": [event, event]})
		if age >= 2:
			unit.attributes.erase("rout_round")
			unit.attributes.erase("rout_effect_id")
			entities.update(unit.id, unit.owner, unit.attributes)
	world.entities = entities.snapshot()
	return {"action": "resolved", "world": world, "events": events}


static func snapshot_valid(context: Dictionary) -> bool:
	var active_by_id: Dictionary = {}
	var live: Dictionary = {}
	for unit in context.world.entities.entities:
		if unit.kind == "marcher":
			live[unit.id] = unit
	for active in context.get("persistent_effects", []):
		if active.declaration.power_id != "Rout":
			continue
		var members = active.payload.get("affected_ids")
		if active.payload.size() != 1 or typeof(members) != TYPE_ARRAY:
			return false
		var seen: Dictionary = {}
		for id in members:
			if (
				typeof(id) != TYPE_STRING
				or seen.has(id)
				or id not in context.world.entities.used_ids
				or not id.begins_with("u13_entity_marcher:")
			):
				return false
			seen[id] = true
			if live.has(id) and live[id].attributes.get("rout_effect_id") != active.effect_id:
				return false
		active_by_id[active.effect_id] = active
	for unit in live.values():
		if not unit.attributes.has("rout_round"):
			continue
		var effect_id: String = unit.attributes.rout_effect_id
		if not active_by_id.has(effect_id):
			return false
		var active: Dictionary = active_by_id[effect_id]
		if (
			unit.id not in active.payload.affected_ids
			or active.activated_round != unit.attributes.rout_round
		):
			return false
		var applied: int = int(unit.attributes.rout_round)
		var age: int = int(context.round) - applied
		if age < 0 or age > 2:
			return false
		if (
			age == 0
			and (
				context.next_hook_index
				<= Timeline.hook_rank(Timeline.POST_RESOLUTION_MOVEMENT_STATE)
			)
		):
			return false
		if (
			age == 2
			and context.next_hook_index > Timeline.hook_rank(Timeline.PERSISTENT_ADVANCEMENT)
		):
			return false
	return true
