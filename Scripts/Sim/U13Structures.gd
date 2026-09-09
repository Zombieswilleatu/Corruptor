extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const PROFILE: String = "U13_CORE_ARTILLERY_COMBAT_V1"
const FLOOR: int = 7
const DAMAGE: int = 2


static func attributes(engine: bool, integrity: int = 21) -> Dictionary:
	return {
		"combat_profile": "siege_engine" if engine else "plain_integrity",
		"status": "standing" if integrity > 0 else "defunct",
		"integrity": integrity,
		"max_integrity": 21,
		"base_max_integrity": 21,
		"artillery_target": "",
		"artillery_acquisitions": 0
	}


static func valid(world: Dictionary) -> bool:
	var entities = Ids.new()
	if entities.restore(world.entities).action == "invalid":
		return false
	if (
		not Data.is_integer(world.data.get("artillery_round", 0))
		or world.data.get("artillery_round", 0) < 0
	):
		return false
	for castle in world.entities.entities:
		if castle.kind != "castle":
			continue
		var a: Dictionary = castle.attributes
		if (
			castle.owner not in [0, 1]
			or a.get("combat_profile") not in ["plain_integrity", "siege_engine"]
		):
			return false
		for key in ["integrity", "max_integrity", "base_max_integrity", "artillery_acquisitions"]:
			if not Data.is_integer(a.get(key)) or a[key] < 0:
				return false
		if a.base_max_integrity < FLOOR or a.base_max_integrity > 1000000:
			return false
		var ceiling: int = (
			int(a.base_max_integrity) - (5 if world.data.breach_lord == "Deimos" else 0)
		)
		if a.max_integrity != ceiling or a.integrity > ceiling:
			return false
		if a.get("status") not in ["standing", "defunct", "ruined", "profaned"]:
			return false
		if (a.status == "standing") != (a.integrity > 0):
			return false
		if typeof(a.get("artillery_target")) != TYPE_STRING:
			return false
		if not a.artillery_target.is_empty():
			var target: Dictionary = entities.get_entity(a.artillery_target)
			if (
				target.is_empty()
				or target.kind != "castle"
				or target.owner != 1 - int(castle.owner)
			):
				return false
		if (
			a.combat_profile != "siege_engine"
			and (not a.artillery_target.is_empty() or a.artillery_acquisitions != 0)
		):
			return false
	return true


# Protected construction never grants Castle effects and cannot be targeted.
# Legacy profiles have no lifecycle field and retain their established behavior.
static func targetable(castle: Dictionary) -> bool:
	return (
		not castle.is_empty()
		and castle.kind == "castle"
		and castle.attributes.get("status") in ["standing", "defunct"]
		and castle.attributes.get("construction_state", "active") == "active"
	)


# The opt-in Development profile retains the old following-round Repair lock.
# Reconstruction is a Construct action and uses its own admission rules.
static func note_integrity_loss(castle: Dictionary, before: int, round_number: int) -> void:
	var a: Dictionary = castle.attributes
	if a.has("construction_state") and before >= FLOOR and a.integrity < FLOOR:
		a["repair_lock_until_round"] = maxi(
			int(a.get("repair_lock_until_round", 0)), round_number + 1
		)


static func operational(castle: Dictionary) -> bool:
	return (
		not castle.is_empty()
		and castle.kind == "castle"
		and castle.attributes.get("status") == "standing"
		and castle.attributes.get("construction_state", "active") == "active"
		and int(castle.attributes.get("integrity", 0)) >= FLOOR
	)


static func sync_breach(raw: Dictionary) -> Dictionary:
	var world: Dictionary = raw.duplicate(true)
	var entities = Ids.new()
	entities.restore(world.entities)
	var events: Array = []
	for castle in entities.snapshot().entities:
		if castle.kind != "castle":
			continue
		var a: Dictionary = castle.attributes
		var ceiling: int = (
			int(a.base_max_integrity) - (5 if world.data.breach_lord == "Deimos" else 0)
		)
		if a.max_integrity == ceiling:
			continue
		a.max_integrity = ceiling
		# Removing a temporary ceiling never restores lost Integrity.
		a.integrity = mini(int(a.integrity), ceiling)
		if a.get("construction_state") == "building" and a.integrity == ceiling:
			a.construction_state = "active"
			if world.data.construction_targets[castle.owner] == castle.id:
				world.data.construction_targets[castle.owner] = ""
			events.append(
				public_event(
					"CASTLE_ACTIVATED",
					{
						"player_id": castle.owner,
						"castle_id": castle.id,
						"before": a.integrity,
						"after": a.integrity,
						"automatic": true,
						"reason": "construction_reached_changed_ceiling"
					}
				)
			)
		entities.update(castle.id, castle.owner, a)
		events.append(
			public_event(
				"CASTLE_CEILING_CHANGED",
				{"castle_id": castle.id, "max_integrity": ceiling, "integrity": a.integrity}
			)
		)
	world.entities = entities.snapshot()
	return {"action": "resolved", "world": world, "events": events}


# Admission only. U13Construction owns costs, action limits and progress.
# This eligibility query never mutates or grants a free build.
static func reconstruction_eligibility(
	world: Dictionary, player_id: int, castle_id: String
) -> Dictionary:
	if player_id not in [0, 1]:
		return Data.invalid("reconstruction_player_invalid")
	var entities = Ids.new()
	entities.restore(world.entities)
	var castle: Dictionary = entities.get_entity(castle_id)
	if castle.is_empty() or castle.kind != "castle" or castle.owner != player_id:
		return Data.invalid("reconstruction_target_invalid")
	var player: Dictionary = world.players[player_id]
	var lord: Dictionary = entities.get_entity(player.lord_entity_id)
	if player.lord_id != "Deimos" or not lord.attributes.alive:
		return Data.invalid("war_foundry_unavailable")
	if castle.attributes.combat_profile != "siege_engine" or castle.attributes.status != "ruined":
		return Data.invalid("war_foundry_requires_ruined_engine")
	return {"action": "eligible", "requires_normal_construction": true, "castle_id": castle.id}


static func normal_fire(context: Dictionary, reaction: Callable) -> Dictionary:
	if context.hook != Timeline.POST_REPAIR_ARTILLERY:
		return Data.invalid("artillery_wrong_hook")
	var world: Dictionary = context.world.duplicate(true)
	if world.data.get("artillery_round", 0) >= context.round:
		return Data.invalid("artillery_already_fired")
	var events: Array = []
	for player_id in context.player_order:
		var ids: Array = []
		for castle in world.entities.entities:
			if (
				castle.kind == "castle"
				and castle.owner == player_id
				and castle.attributes.combat_profile == "siege_engine"
			):
				ids.append(castle.id)
		ids.sort()
		for engine_id in ids:
			var fired: Dictionary = fire(
				world,
				engine_id,
				context.seed,
				context.round,
				"normal",
				reaction,
				context.player_order
			)
			if fired.action == "invalid":
				return fired
			world = fired.world
			events.append_array(fired.events)
	world.data["artillery_round"] = context.round
	return {"action": "resolved", "world": world, "events": events}


static func fire(
	raw: Dictionary,
	engine_id: String,
	seed_value: String,
	round_number: int,
	shot: String,
	reaction: Callable,
	player_order: Array
) -> Dictionary:
	var world: Dictionary = raw.duplicate(true)
	var entities = Ids.new()
	entities.restore(world.entities)
	var engine: Dictionary = entities.get_entity(engine_id)
	if (
		engine.is_empty()
		or engine.kind != "castle"
		or engine.attributes.combat_profile != "siege_engine"
	):
		return Data.invalid("artillery_engine_missing")
	var events: Array = []
	if not operational(engine):
		return {"action": "resolved", "world": world, "events": events}
	var target: Dictionary = entities.get_entity(engine.attributes.artillery_target)
	if not targetable(target):
		var targets: Array = []
		for castle in entities.snapshot().entities:
			if (
				castle.kind == "castle"
				and castle.owner == 1 - int(engine.owner)
				and targetable(castle)
			):
				targets.append(castle.id)
		targets.sort()
		if targets.is_empty():
			engine.attributes.artillery_target = ""
			entities.update(engine.id, engine.owner, engine.attributes)
			world.entities = entities.snapshot()
			events.append(
				public_event(
					"ARTILLERY_NO_TARGET",
					{"engine_id": engine.id, "round": round_number, "shot": shot}
				)
			)
			return {"action": "resolved", "world": world, "events": events}
		var roll: Dictionary = Rng.draw(
			seed_value,
			engine.id,
			"ARTILLERY_TARGET",
			int(engine.attributes.artillery_acquisitions),
			targets.size()
		)
		target = entities.get_entity(targets[int(roll.value)])
		engine.attributes.artillery_target = target.id
		engine.attributes.artillery_acquisitions += 1
		entities.update(engine.id, engine.owner, engine.attributes)
		events.append(
			public_event(
				"ARTILLERY_TARGET_ACQUIRED",
				{"engine_id": engine.id, "target_id": target.id, "round": round_number}
			)
		)
	var target_before: Dictionary = target.attributes.duplicate(true)
	var before: int = int(target.attributes.integrity)
	var damage: int = mini(before, DAMAGE)
	world.entities = entities.snapshot()
	if before <= DAMAGE:
		var command: Dictionary = {
			"command_id": Data.instance_id("artillery", engine.id, shot),
			"kind": "ruin_castle",
			"target_id": target.id,
			"player_id": engine.owner,
			"source_id": engine.id,
			"cause": "artillery"
		}
		var changed: Dictionary = Battle.apply(
			world, command, round_number, Timeline.POST_REPAIR_ARTILLERY
		)
		if changed.action == "invalid":
			return changed
		world = changed.world
		events.append(public_event(changed.event.type, changed.event.data))
		if world.data.get("castle_tear_round", 0) != round_number:
			world.data.neutral_tears += 1
			world.data["castle_tear_round"] = round_number
			events.append(
				public_event(
					"NEUTRAL_TEAR_CREATED",
					{"amount": 1, "source": "CastleDestruction", "round": round_number}
				)
			)
		var reacted: Dictionary = reaction.call(world, changed.event, seed_value, player_order)
		if reacted.action == "invalid":
			return reacted
		world = reacted.world
		events.append_array(reacted.events)
	else:
		target.attributes.integrity = before - damage
		note_integrity_loss(target, before, round_number)
		entities.update(target.id, target.owner, target.attributes)
		world.entities = entities.snapshot()
	var target_after: Dictionary = {}
	for entity in world.entities.entities:
		if entity.id == target.id:
			target_after = entity.attributes.duplicate(true)
			break
	events.append(
		public_event(
			"ARTILLERY_FIRED",
			{
				"round": round_number,
				"player_id": engine.owner,
				"engine_id": engine.id,
				"target_id": target.id,
				"shot": shot,
				"damage": damage,
				"destroyed": before <= DAMAGE,
				"target_before": target_before,
				"target_after": target_after
			}
		)
	)
	return {"action": "resolved", "world": world, "events": events}


# Shared environmental structure-damage path. Protected builds are ignored;
# destruction keeps instance identity, emits the normal fact/Tear and runs Lord
# reactions, but has no attacking player to credit with Souls or Spoils of War.
static func breach_damage(
	raw: Dictionary,
	castle_id: String,
	source_id: String,
	damage: int,
	entry_id: String,
	context: Dictionary,
	reaction: Callable
) -> Dictionary:
	if damage < 0:
		return Data.invalid("castle_damage_invalid")
	var world: Dictionary = raw.duplicate(true)
	var entities = Ids.new()
	entities.restore(world.entities)
	var castle: Dictionary = entities.get_entity(castle_id)
	var source: Dictionary = entities.get_entity(source_id)
	if (
		source.is_empty()
		or source.kind != "lord"
		or source.attributes.get("alive", true)
		or source.attributes.get("lord_id") != world.data.breach_lord
	):
		return Data.invalid("castle_hazard_source_invalid")
	var events: Array = []
	if not targetable(castle) or castle.attributes.integrity <= 0 or damage == 0:
		return {"action": "resolved", "world": world, "events": events}
	var before: int = int(castle.attributes.integrity)
	var dealt: int = mini(before, damage)
	if dealt == before:
		var changed: Dictionary = Battle.apply(
			world,
			{
				"command_id": Data.instance_id("breach_damage", entry_id, castle_id),
				"kind": "ruin_castle_hazard",
				"target_id": castle_id,
				"source_id": source_id,
				"cause": "breach"
			},
			context.round,
			context.hook
		)
		if changed.action == "invalid":
			return changed
		world = changed.world
		events.append(public_event(changed.event.type, changed.event.data))
		if world.data.get("castle_tear_round", 0) != context.round:
			world.data.neutral_tears += 1
			world.data["castle_tear_round"] = context.round
			events.append(
				public_event(
					"NEUTRAL_TEAR_CREATED",
					{"amount": 1, "source": "CastleDestruction", "round": context.round}
				)
			)
		var reacted: Dictionary = reaction.call(
			world, changed.event, context.seed, context.player_order
		)
		if reacted.action == "invalid":
			return reacted
		world = reacted.world
		events.append_array(reacted.events)
	else:
		castle.attributes.integrity = before - dealt
		note_integrity_loss(castle, before, context.round)
		entities.update(castle.id, castle.owner, castle.attributes)
		world.entities = entities.snapshot()
	events.append(
		public_event(
			"CASTLE_DAMAGED",
			{
				"castle_id": castle_id,
				"source_id": source_id,
				"source": "TheStonesForget",
				"cause": "breach",
				"round": context.round,
				"damage": dealt,
				"integrity": before - dealt,
				"destroyed": dealt == before
			}
		)
	)
	return {"action": "resolved", "world": world, "events": events}


static func public_event(type: String, data: Dictionary) -> Dictionary:
	var event: Dictionary = {"type": type, "text": "", "data": data}
	return {"event": event, "views": [event, event]}
