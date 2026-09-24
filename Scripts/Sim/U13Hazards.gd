extends RefCounted

const Embolden = preload("res://Scripts/Sim/U13Embolden.gd")

const Incoming = preload("res://Scripts/Sim/U13IncomingDamage.gd")

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const VERSION: String = "U13_DISCRETE_HAZARDS_V2_CASTLE"


static func target_valid(target: Dictionary, owner: int, world: Dictionary = {}) -> bool:
	if target.get("kind") == "lane":
		return target.size() == 2 and target.get("lane") in Marching.LANES
	if target.get("kind") != "castle" or target.size() != 2 or typeof(target.get("entity_id")) != TYPE_STRING or target.entity_id.is_empty():
		return false
	if world.is_empty():
		return true
	for entity in world.entities.entities:
		if entity.id == target.entity_id:
			return entity.kind == "castle" and entity.owner == 1 - owner
	return false


# One discrete pulse; lifetime, scheduling and repetition belong to the match
# and persistent registries. Physical membership is sampled now, on both sides.
static func pulse(
	context: Dictionary, active: Dictionary, pulse_id: String, reaction: Callable, enemy_bonus: int = 0
) -> Dictionary:
	var world: Dictionary = context.world.duplicate(true)
	var target: Dictionary = active.target
	var intensity: int = int(active.stages[active.stage_index].intensity)
	if (
		not target_valid(target, active.declaration.player_id, world)
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
			and not entity.attributes.get("flying", false)
		):
			ids.append(entity.id)
		elif target.kind == "castle" and entity.id == target.entity_id and Structures.targetable(entity) and entity.attributes.integrity > 0:
			ids.append(entity.id)
	ids.sort()
	var events: Array = []
	for entity_id in ids:
		var entities = Ids.new()
		entities.restore(world.entities)
		var entity: Dictionary = entities.get_entity(entity_id)
		var absorbed = 0
		var hit: Dictionary = {}
		if target.kind == "castle":
			var command_id: String = Data.instance_id("hazard_hit", pulse_id, entity_id)
			var event_id: String = Data.instance_id("battle", str(context.round), command_id)
			if world.data.get("battle_commands", {}).has(event_id):
				return Data.invalid("battle_command_already_applied")
			var castle_intensity: int = intensity + (enemy_bonus if entity.owner != active.declaration.player_id else 0)
			var dealt = mini(int(entity.attributes.integrity), castle_intensity)
			hit = {"castle_damage": dealt, "destroyed": dealt == entity.attributes.integrity, "owner": entity.owner}
			var damaged: Dictionary = Structures.breach_damage(world, entity_id, world.players[active.declaration.player_id].lord_entity_id, castle_intensity, pulse_id, context, reaction, "scorch")
			if damaged.action == "invalid":
				return damaged
			world = damaged.world
			var commands: Dictionary = world.data.get("battle_commands", {})
			commands[event_id] = true
			world.data["battle_commands"] = commands
			events.append_array(damaged.events)
		else:
			var friendly: bool = entity.owner == active.declaration.player_id
			var base_damage: int = maxi(0, intensity - int(friendly) + (0 if friendly else enemy_bonus))
			var amount = Incoming.apply(entity.attributes, base_damage, Incoming.phase_clock(world, int(context.round)))
			absorbed = min(entity.attributes.armor, amount)
			entity.attributes.armor -= absorbed
			entities.update(entity.id, entity.owner, entity.attributes)
			world.entities = entities.snapshot()
			var command: Dictionary = {"command_id": Data.instance_id("hazard_hit", pulse_id, entity_id), "target_id": entity_id, "kind": "marcher_damage", "damage": amount - absorbed, "cause": "hazard"}
			var applied: Dictionary = Battle.apply(world, command, context.round, context.hook)
			if applied.action == "invalid":
				return applied
			world = applied.world
			events.append({"event": applied.event, "views": [applied.event, applied.event]})
			var reacted: Dictionary = reaction.call(world, applied.event, context.seed, context.player_order)
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
				}.merged(hit)
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
