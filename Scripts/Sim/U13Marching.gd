class_name U13Marching
extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const VERSION: String = "U13_MARCHING_V1"
const LANE_FP: int = 2400
const TICKS: int = 200
const LANES: Array = ["Lord", "Castle"]
const SUITS: Array = ["Butcher", "Penitent", "Vulture", "Wright"]
# Extracted from MarchingEngine.STANDARD_STATS, not the legacy launch engine.
const STATS: Dictionary = {
	"Butcher": {"attack": 3, "armor": 1, "regen": 1, "step_fp": 4, "armor_bypass": false},
	"Penitent": {"attack": 1, "armor": 3, "regen": 2, "step_fp": 3, "armor_bypass": false},
	"Vulture": {"attack": 2, "armor": 1, "regen": 1, "step_fp": 6, "armor_bypass": true},
	"Wright": {"attack": 2, "armor": 2, "regen": 1, "step_fp": 4, "armor_bypass": false}
}


static func profile(
	suit: String, lane: String, player_id: int, birth: int, ready: int
) -> Dictionary:
	var attributes: Dictionary = STATS[suit].duplicate(true)
	attributes["suit"] = suit
	attributes["lane"] = lane
	attributes["hp"] = 5
	attributes["max_hp"] = 5
	attributes["birth_round"] = birth
	attributes["movement_ready_round"] = ready
	attributes["x_fp"] = 0 if player_id == 0 else LANE_FP
	attributes["direction"] = 1 if player_id == 0 else -1
	attributes["waiting"] = false
	attributes["waiting_since_round"] = 0
	return attributes


static func valid(world: Dictionary) -> bool:
	for field in ["marching_round", "marching_regen_round"]:
		if not Data.is_integer(world.data.get(field, 0)) or world.data.get(field, 0) < 0:
			return false
	for entity in world.entities.entities:
		if entity.kind != "marcher":
			continue
		var a: Dictionary = entity.attributes
		if entity.owner not in [0, 1] or a.get("suit") not in SUITS or a.get("lane") not in LANES:
			return false
		for field in [
			"hp",
			"max_hp",
			"attack",
			"armor",
			"regen",
			"step_fp",
			"birth_round",
			"movement_ready_round",
			"x_fp",
			"direction",
			"waiting_since_round"
		]:
			if not Data.is_integer(a.get(field)):
				return false
		if (
			a.hp < 1
			or a.hp > a.max_hp
			or a.max_hp > 1000000
			or a.attack < 1
			or a.attack > 1000000
			or a.armor < 0
			or a.armor > 1000000
			or a.regen < 0
			or a.regen > 1000000
			or a.step_fp < 0
			or a.step_fp > LANE_FP
			or a.x_fp < 0
			or a.x_fp > LANE_FP
			or a.birth_round < 0
			or a.movement_ready_round < a.birth_round
			or a.waiting_since_round < 0
			or a.direction != (1 if entity.owner == 0 else -1)
			or typeof(a.get("waiting")) != TYPE_BOOL
			or typeof(a.get("armor_bypass")) != TYPE_BOOL
		):
			return false
		if a.waiting and a.waiting_since_round < 1:
			return false
	return true


static func regenerate(context: Dictionary) -> Dictionary:
	var world: Dictionary = context.world.duplicate(true)
	if context.hook != Timeline.ROUND_START_AUTOMATIC or not valid(world):
		return Data.invalid("marching_regen_context_invalid")
	if world.data.get("marching_regen_round", 0) >= context.round:
		return Data.invalid("marching_regen_already_applied")
	var entities = Ids.new()
	entities.restore(world.entities)
	var events: Array = []
	for unit in world.entities.entities:
		if unit.kind != "marcher" or unit.attributes.waiting:
			continue
		var before: int = unit.attributes.hp
		unit.attributes.hp = mini(unit.attributes.max_hp, before + int(unit.attributes.regen))
		entities.update(unit.id, unit.owner, unit.attributes)
		if unit.attributes.hp != before:
			events.append(
				public_event(
					"MARCHER_REGENERATED",
					{
						"entity_id": unit.id,
						"before": before,
						"after": unit.attributes.hp,
						"round": context.round,
						"hook": context.hook
					}
				)
			)
	world.entities = entities.snapshot()
	world.data["marching_regen_round"] = context.round
	return {"action": "resolved", "world": world, "events": events}


# A complete phase is one owner transaction. Save/replay boundaries are hooks,
# not renderer frames. The tape carries integer tick positions for presentation.
static func resolve(context: Dictionary, reaction: Callable) -> Dictionary:
	var world: Dictionary = context.world.duplicate(true)
	if context.hook != Timeline.MARCHING or not valid(world) or not reaction.is_valid():
		return Data.invalid("marching_context_invalid")
	if world.data.get("marching_round", 0) >= context.round:
		return Data.invalid("marching_already_applied")
	var entities = Ids.new()
	entities.restore(world.entities)
	var events: Array = [
		public_event(
			"MARCHING_STARTED",
			{
				"round": context.round,
				"hook": context.hook,
				"ticks": TICKS,
				"units": _units(entities)
			}
		)
	]
	for tick in range(TICKS):
		for unit in _units(entities):
			var a: Dictionary = unit.attributes
			if not a.waiting and a.movement_ready_round <= context.round:
				a.x_fp = clampi(int(a.x_fp) + int(a.direction) * int(a.step_fp), 0, LANE_FP)
				entities.update(unit.id, unit.owner, a)
		for lane in LANES:
			var contacts: int = 0
			while true:
				var left: Dictionary = _front(entities, 0, lane, context, tick, contacts)
				var right: Dictionary = _front(entities, 1, lane, context, tick, contacts)
				if (
					left.is_empty()
					or right.is_empty()
					or left.attributes.x_fp < right.attributes.x_fp
				):
					break
				if contacts >= 256:
					return Data.invalid("marching_contact_limit")
				var before: Array = [left.duplicate(true), right.duplicate(true)]
				var x_fp: int = (int(left.attributes.x_fp) + int(right.attributes.x_fp)) >> 1
				var exchanges: Array = []
				for exchange in range(64):
					# Baseline simultaneous exchange: capture attacks before either death.
					_attack(
						left.attributes, int(right.attributes.attack), right.attributes.armor_bypass
					)
					_attack(
						right.attributes, int(left.attributes.attack), left.attributes.armor_bypass
					)
					exchanges.append(
						{
							"hp": [left.attributes.hp, right.attributes.hp],
							"armor": [left.attributes.armor, right.attributes.armor]
						}
					)
					if left.attributes.hp == 0 or right.attributes.hp == 0:
						break
				if left.attributes.hp > 0 and right.attributes.hp > 0:
					return Data.invalid("marching_exchange_limit")
				for unit in [left, right]:
					if unit.attributes.hp == 0:
						entities.retire(unit.id)
					else:
						unit.attributes.x_fp = x_fp
						entities.update(unit.id, unit.owner, unit.attributes)
				var duel_id: String = Data.instance_id(
					"duel", str(context.round), "%d:%s:%d" % [tick, lane, contacts]
				)
				events.append(
					public_event(
						"MARCHER_CLASH",
						{
							"event_id": duel_id,
							"round": context.round,
							"hook": context.hook,
							"tick": tick,
							"lane": lane,
							"x_fp": x_fp,
							"units": before,
							"exchanges": exchanges
						}
					)
				)
				world.entities = entities.snapshot()
				# Both deaths are installed first; attribution survives mutual destruction.
				# Resolve simultaneous kill rewards in explicit player priority order.
				for attacker_id in context.player_order:
					var victim_id: int = 1 - int(attacker_id)
					var victims: Array = [left, right]
					if victims[victim_id].attributes.hp != 0:
						continue
					var fact: Dictionary = {
						"type": "MARCHER_DEFEATED",
						"text": "",
						"data":
						{
							"event_id": Data.instance_id("kill", duel_id, str(victim_id)),
							"round": context.round,
							"hook": context.hook,
							"tick": tick,
							"victim": before[victim_id],
							"attacker": before[attacker_id],
							"cause": "combat"
						}
					}
					events.append({"event": fact, "views": [fact, fact]})
					var reacted = reaction.call(world, fact, context.seed, context.player_order)
					if typeof(reacted) != TYPE_DICTIONARY or reacted.get("action") != "resolved":
						return Data.invalid("marching_reaction_invalid")
					world = reacted.world
					events.append_array(reacted.events)
				entities.restore(world.entities)
				contacts += 1
			# Arrivals happen after contacts, never grant a Tear, and retain identity.
			for unit in _units(entities):
				var a: Dictionary = unit.attributes
				if a.lane != lane or a.waiting or a.x_fp != (LANE_FP if unit.owner == 0 else 0):
					continue
				a.waiting = true
				a.waiting_since_round = context.round
				entities.update(unit.id, unit.owner, a)
				events.append(
					public_event(
						"MARCHER_WAITING",
						{
							"entity_id": unit.id,
							"round": context.round,
							"hook": context.hook,
							"tick": tick,
							"lane": lane,
							"x_fp": a.x_fp
						}
					)
				)
	world.entities = entities.snapshot()
	world.data["marching_round"] = context.round
	events.append(
		public_event(
			"MARCHING_FINISHED",
			{
				"round": context.round,
				"hook": context.hook,
				"ticks": TICKS,
				"units": _units(entities)
			}
		)
	)
	return {"action": "resolved", "world": world, "events": events}


static func _units(entities) -> Array:
	var result: Array = []
	for entity in entities.snapshot().entities:
		if entity.kind == "marcher":
			result.append(entity)
	return result


static func _front(
	entities, player_id: int, lane: String, context: Dictionary, tick: int, duel: int
) -> Dictionary:
	var candidates: Array = []
	var progress: int = -1
	for unit in _units(entities):
		if unit.owner != player_id or unit.attributes.lane != lane:
			continue
		var current: int = (
			int(unit.attributes.x_fp) if player_id == 0 else LANE_FP - int(unit.attributes.x_fp)
		)
		if current > progress:
			candidates = [unit]
			progress = current
		elif current == progress:
			candidates.append(unit)
	if candidates.is_empty():
		return {}
	if candidates.size() == 1:
		return candidates[0]
	# Registry snapshot is sorted by immutable ID. Insertion order cannot reroll ties.
	var key: String = Data.instance_id("front", str(context.round), "%d:%s:%d" % [tick, lane, duel])
	var roll: Dictionary = Rng.draw(
		context.seed, key, "FRONT:" + str(player_id), 0, candidates.size()
	)
	return candidates[int(roll.value)]


static func _attack(target: Dictionary, amount: int, bypass: bool) -> void:
	var remaining: int = maxi(1, amount)
	if not bypass:
		var absorbed: int = mini(int(target.armor), remaining)
		target.armor -= absorbed
		remaining -= absorbed
	target.hp = maxi(0, int(target.hp) - remaining)


static func public_event(kind: String, details: Dictionary) -> Dictionary:
	var event: Dictionary = {"type": kind, "text": "", "data": details}
	return {"event": event, "views": [event, event]}
