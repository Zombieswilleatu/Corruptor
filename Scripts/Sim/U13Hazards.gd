extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const VERSION: String = "U13_DISCRETE_HAZARDS_V1"


static func target_valid(target: Dictionary, owner: int) -> bool:
	if target.get("lane") not in Marching.LANES:
		return false
	if target.get("kind") == "lane":
		return target.size() == 2
	return (
		target.size() == 3
		and target.get("kind") == "guard"
		and Data.is_integer(target.get("player_id"))
		and target.player_id == 1 - owner
	)


# One discrete pulse; lifetime, scheduling and repetition belong to the match
# and persistent registries. Physical membership is sampled now, on both sides.
static func pulse(
	context: Dictionary, active: Dictionary, pulse_id: String, reaction: Callable
) -> Dictionary:
	var world: Dictionary = context.world.duplicate(true)
	var target: Dictionary = active.target
	var intensity: int = int(active.stages[active.stage_index].intensity)
	if (
		not target_valid(target, active.declaration.player_id)
		or intensity < 1
		or not reaction.is_valid()
	):
		return Data.invalid("hazard_pulse_invalid")
	var ids: Array = []
	for entity in world.entities.entities:
		if (
			target.kind == "lane"
			and entity.kind == "marcher"
			and entity.attributes.lane == target.lane
		):
			ids.append(entity.id)
		elif (
			target.kind == "guard"
			and entity.kind == "card"
			and entity.owner == target.player_id
			and entity.attributes.get("role") == "guard"
			and entity.attributes.get("lane") == target.lane
			and entity.attributes.value <= intensity
		):
			ids.append(entity.id)
	ids.sort()
	var events: Array = []
	for entity_id in ids:
		var entities = Ids.new()
		entities.restore(world.entities)
		var entity: Dictionary = entities.get_entity(entity_id)
		var command: Dictionary = {
			"command_id": Data.instance_id("hazard_hit", pulse_id, entity_id),
			"target_id": entity_id,
			"kind": "defeat_guard"
		}
		var absorbed: int = 0
		if target.kind == "lane":
			absorbed = mini(int(entity.attributes.armor), intensity)
			entity.attributes.armor -= absorbed
			entities.update(entity.id, entity.owner, entity.attributes)
			world.entities = entities.snapshot()
			command.merge(
				{"kind": "marcher_damage", "damage": intensity - absorbed, "cause": "hazard"}, true
			)
		var applied: Dictionary = Battle.apply(world, command, context.round, context.hook)
		if applied.action == "invalid":
			return applied
		world = applied.world
		events.append({"event": applied.event, "views": [applied.event, applied.event]})
		var reacted: Dictionary = reaction.call(
			world, applied.event, context.seed, context.player_order
		)
		if reacted.action == "invalid":
			return reacted
		world = reacted.world
		events.append_array(reacted.events)
		events.append(
			Marching.public_event(
				"HAZARD_HIT",
				{
					"effect_id": active.effect_id,
					"pulse_id": pulse_id,
					"entity_id": entity_id,
					"intensity": intensity,
					"armor_absorbed": absorbed,
					"round": context.round,
					"hook": context.hook
				}
			)
		)
	events.append(
		Marching.public_event(
			"HAZARD_PULSED",
			{
				"effect_id": active.effect_id,
				"power_id": active.declaration.power_id,
				"player_id": active.declaration.player_id,
				"target": target,
				"intensity": intensity,
				"pulse_id": pulse_id,
				"affected_ids": ids,
				"round": context.round,
				"hook": context.hook
			}
		)
	)
	return {"action": "resolved", "world": world, "events": events}
