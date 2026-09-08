class_name U13Marching
extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const VERSION: String = "U13_MARCHING_SPATIAL_V2"
const LANE_FP: int = 2400
const TICKS: int = 200
# Initial spatial tuning, in the same fixed-point units as forward distance.
const WIDTH_FP: int = 600
const CONTACT_FP: int = 180
const CENTER_GAP_FP: int = 84
const SPAWN_DEPTH_FP: int = 120
const EXCHANGE_TICKS: int = 8
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
	attributes["y_fp"] = WIDTH_FP >> 1
	attributes["contact_tick"] = -1
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
			"y_fp",
			"contact_tick",
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
			or a.y_fp < 0
			or a.y_fp > WIDTH_FP
			or a.contact_tick < -1
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
	return _valid_duels(world)


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


# Whole phase remains atomic. Active duels and contact tickets persist across
# round boundaries; frame rate never supplies positions, joins, or damage.
static func resolve(context: Dictionary, reaction: Callable) -> Dictionary:
	var world: Dictionary = context.world.duplicate(true)
	if context.hook != Timeline.MARCHING or not valid(world) or not reaction.is_valid():
		return Data.invalid("marching_context_invalid")
	if world.data.get("marching_round", 0) >= context.round:
		return Data.invalid("marching_already_applied")
	var entities = Ids.new()
	entities.restore(world.entities)
	var duels: Dictionary = world.data.get("marching_duels", {}).duplicate(true)
	var events: Array = [
		public_event(
			"MARCHING_STARTED",
			{
				"round": context.round,
				"hook": context.hook,
				"ticks": TICKS,
				"model": VERSION,
				"units": _units(entities)
			}
		)
	]
	var tape_bases: Dictionary = {}
	for unit in _units(entities):
		tape_bases[unit.id] = unit
	for tick in range(TICKS):
		var clock: int = int(context.round) * TICKS + tick
		# A prior hook may consume a waiting participant or retire an entity.
		for lane in duels.keys():
			if not _duel_alive(duels[lane], entities):
				events.append(
					public_event(
						"MARCHER_DUEL_INTERRUPTED",
						{"event_id": duels[lane].id, "round": context.round, "tick": tick}
					)
				)
				duels.erase(lane)
		_move(entities, duels, context, clock)
		for lane in LANES:
			if not duels.has(lane):
				var pair: Array = _contact_pair(entities, lane, context, clock)
				if not pair.is_empty():
					var id: String = Data.instance_id(
						"spatial_duel", str(clock), JSON.stringify([pair[0].id, pair[1].id])
					)
					duels[lane] = {
						"id": id,
						"units": pair.duplicate(true),
						"exchanges": [],
						"round": context.round,
						"tick": tick,
						"next_tick": clock
					}
					events.append(
						public_event(
							"MARCHER_CONTACT",
							{
								"event_id": id,
								"round": context.round,
								"tick": tick,
								"lane": lane,
								"units": pair.duplicate(true)
							}
						)
					)
			if not duels.has(lane) or int(duels[lane].next_tick) > clock:
				continue
			var duel: Dictionary = duels[lane]
			var left: Dictionary = entities.get_entity(duel.units[0].id)
			var right: Dictionary = entities.get_entity(duel.units[1].id)
			_attack(left.attributes, int(right.attributes.attack), right.attributes.armor_bypass)
			_attack(right.attributes, int(left.attributes.attack), left.attributes.armor_bypass)
			duel.exchanges.append(
				{
					"hp": [left.attributes.hp, right.attributes.hp],
					"armor": [left.attributes.armor, right.attributes.armor]
				}
			)
			duel.next_tick = clock + EXCHANGE_TICKS
			for unit in [left, right]:
				if unit.attributes.hp == 0:
					entities.retire(unit.id)
				else:
					entities.update(unit.id, unit.owner, unit.attributes)
			if left.attributes.hp > 0 and right.attributes.hp > 0:
				if duel.exchanges.size() >= 64:
					return Data.invalid("marching_exchange_limit")
				continue
			duels.erase(lane)
			events.append(
				public_event(
					"MARCHER_CLASH",
					{
						"event_id": duel.id,
						"round": context.round,
						"hook": context.hook,
						"tick": duel.tick,
						"start_round": duel.round,
						"end_tick": tick,
						"lane": lane,
						"x_fp":
						(
							(
								int(duel.units[0].attributes.x_fp)
								+ int(duel.units[1].attributes.x_fp)
							)
							>> 1
						),
						"units": duel.units,
						"exchanges": duel.exchanges
					}
				)
			)
			world.entities = entities.snapshot()
			for attacker_id in context.player_order:
				var victim_id: int = 1 - int(attacker_id)
				var fighters: Array = [left, right]
				if fighters[victim_id].attributes.hp != 0:
					continue
				var fact: Dictionary = {
					"type": "MARCHER_DEFEATED",
					"text": "",
					"data":
					{
						"event_id": Data.instance_id("kill", duel.id, str(victim_id)),
						"round": context.round,
						"hook": context.hook,
						"tick": tick,
						"victim": duel.units[victim_id],
						"attacker": duel.units[attacker_id],
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
		# Contact takes precedence over arrival, including a waiting gate defender.
		var arrival_rows: Array = _units(entities)
		for unit in arrival_rows:
			var attributes: Dictionary = unit.attributes
			if attributes.waiting or _busy(unit.id, duels) or _touches_enemy(unit, arrival_rows):
				continue
			if attributes.x_fp == (LANE_FP if unit.owner == 0 else 0):
				attributes.waiting = true
				attributes.waiting_since_round = context.round
				entities.update(unit.id, unit.owner, attributes)
				events.append(
					public_event(
						"MARCHER_WAITING",
						{
							"entity_id": unit.id,
							"round": context.round,
							"hook": context.hook,
							"tick": tick,
							"lane": attributes.lane,
							"x_fp": attributes.x_fp,
							"y_fp": attributes.y_fp
						}
					)
				)
		var active: Array = []
		for lane in LANES:
			if duels.has(lane):
				for unit in duels[lane].units:
					active.append(unit.id)
		events.append(
			public_event(
				"MARCHING_TICK",
				{
					"round": context.round,
					"tick": tick,
					"unit_format": "attribute_delta_v1",
					"units": _tick_units(entities, tape_bases),
					"clash": active
				}
			)
		)
	world.entities = entities.snapshot()
	world.data["marching_duels"] = duels
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


# Each row is relative to the phase-start unit, never to a preceding tick.
# Keep commonly inspected dynamic coordinates/vitals explicit. Immutable origin,
# source IDs and unchanged stats are already present in MARCHING_STARTED.
static func _tick_units(entities, bases: Dictionary) -> Array:
	var result: Array = []
	for unit in _units(entities):
		if not bases.has(unit.id):
			result.append(unit)
			continue
		var attributes: Dictionary = {}
		var original: Dictionary = bases[unit.id].attributes
		for key in unit.attributes:
			if (
				key in ["x_fp", "y_fp", "hp", "armor"]
				or not original.has(key)
				or unit.attributes[key] != original[key]
			):
				attributes[key] = unit.attributes[key]
		result.append({"id": unit.id, "owner": unit.owner, "attributes": attributes})
	return result


static func _units(entities) -> Array:
	var result: Array = []
	for entity in entities.snapshot().entities:
		if entity.kind == "marcher":
			result.append(entity)
	return result


static func _distance(a: Dictionary, b: Dictionary) -> int:
	var dx: int = int(a.x_fp) - int(b.x_fp)
	var dy: int = int(a.y_fp) - int(b.y_fp)
	return dx * dx + dy * dy


static func _busy(id: String, duels: Dictionary) -> bool:
	for duel in duels.values():
		if duel.units[0].id == id or duel.units[1].id == id:
			return true
	return false


static func _duel_alive(duel: Dictionary, entities) -> bool:
	for source in duel.units:
		var live: Dictionary = entities.get_entity(source.id)
		if (
			live.is_empty()
			or live.owner != source.owner
			or live.attributes.lane != source.attributes.lane
		):
			return false
	return (
		_distance(
			entities.get_entity(duel.units[0].id).attributes,
			entities.get_entity(duel.units[1].id).attributes
		)
		<= CONTACT_FP * CONTACT_FP
	)


static func _touches_enemy(unit: Dictionary, rows: Array) -> bool:
	for other in rows:
		if (
			other.owner != unit.owner
			and other.attributes.lane == unit.attributes.lane
			and _distance(unit.attributes, other.attributes) <= CONTACT_FP * CONTACT_FP
		):
			return true
	return false


static func _move(entities, duels: Dictionary, context: Dictionary, clock: int) -> void:
	var rows: Array = _units(entities)
	var accepted: Array = rows.duplicate(true)
	# Read targets from one tick snapshot; resolve personal-space conflicts in ID order.
	for unit in rows:
		var a: Dictionary = unit.attributes.duplicate(true)
		if _touches_enemy(unit, rows):
			if int(a.contact_tick) < 0:
				a.contact_tick = clock
			entities.update(unit.id, unit.owner, a)
			continue
		a.contact_tick = -1
		if a.waiting or a.movement_ready_round > context.round or _busy(unit.id, duels):
			entities.update(unit.id, unit.owner, a)
			continue
		var nearest: Dictionary = {}
		var best: int = 9223372036854775807
		for other in rows:
			if other.owner == unit.owner or other.attributes.lane != a.lane:
				continue
			var distance: int = _distance(a, other.attributes)
			if distance < best:
				nearest = other
				best = distance
		var dx: int = int(a.direction) * int(a.step_fp)
		var dy: int = 0
		if not nearest.is_empty():
			var vx: int = int(nearest.attributes.x_fp) - int(a.x_fp)
			var vy: int = int(nearest.attributes.y_fp) - int(a.y_fp)
			var distance: int = maxi(1, _ceil_sqrt(best))
			dx = _scaled(vx, int(a.step_fp), distance)
			dy = _scaled(vy, int(a.step_fp), distance)
			if dx == 0 and dy == 0 and a.step_fp > 0:
				if absi(vx) >= absi(vy):
					dx = 1 if vx > 0 else -1
				else:
					dy = 1 if vy > 0 else -1
		var proposed: Dictionary = a.duplicate(true)
		proposed.x_fp = clampi(int(a.x_fp) + dx, 0, LANE_FP)
		proposed.y_fp = clampi(int(a.y_fp) + dy, 0, WIDTH_FP)
		if not _space_free(unit, proposed, accepted):
			# A deterministic lateral detour avoids permanent single-file blockage.
			var side: int = (
				1 if (String(unit.id).unicode_at(String(unit.id).length() - 1) % 2) == 0 else -1
			)
			proposed = a.duplicate(true)
			proposed.y_fp = clampi(int(a.y_fp) + side * int(a.step_fp), 0, WIDTH_FP)
			if not _space_free(unit, proposed, accepted):
				proposed.y_fp = clampi(int(a.y_fp) - side * int(a.step_fp), 0, WIDTH_FP)
				if not _space_free(unit, proposed, accepted):
					proposed = a
		entities.update(unit.id, unit.owner, proposed)
		for changed in accepted:
			if changed.id == unit.id:
				changed.attributes = proposed
				break


static func _space_free(unit: Dictionary, proposed: Dictionary, accepted: Array) -> bool:
	for other in accepted:
		if (
			other.id == unit.id
			or other.owner != unit.owner
			or other.attributes.lane != unit.attributes.lane
		):
			continue
		var after: int = _distance(proposed, other.attributes)
		if (
			after < CENTER_GAP_FP * CENTER_GAP_FP
			and after < _distance(unit.attributes, other.attributes)
		):
			return false
	return true


static func _ceil_sqrt(value: int) -> int:
	var low: int = 0
	var high: int = LANE_FP + WIDTH_FP
	while low < high:
		var middle: int = (low + high) >> 1
		if middle * middle < value:
			low = middle + 1
		else:
			high = middle
	return low


static func _scaled(value: int, speed: int, distance: int) -> int:
	# Bounded integer inputs; nearest fixed-point step, with explicit rounding.
	var result: int = floori(float(absi(value) * speed + (distance >> 1)) / float(distance))
	return -result if value < 0 else result


static func _contact_pair(entities, lane: String, context: Dictionary, clock: int) -> Array:
	var rows: Array = _units(entities)
	var candidates: Array = []
	var earliest: int = 9223372036854775807
	for left in rows:
		if left.owner != 0 or left.attributes.lane != lane:
			continue
		for right in rows:
			if (
				right.owner != 1
				or right.attributes.lane != lane
				or _distance(left.attributes, right.attributes) > CONTACT_FP * CONTACT_FP
			):
				continue
			var arrived: int = maxi(
				clock if left.attributes.contact_tick < 0 else int(left.attributes.contact_tick),
				clock if right.attributes.contact_tick < 0 else int(right.attributes.contact_tick)
			)
			if arrived < 0:
				arrived = clock
			if arrived < earliest:
				earliest = arrived
				candidates = [[left, right]]
			elif arrived == earliest:
				candidates.append([left, right])
	if candidates.is_empty():
		return []
	var key: String = Data.instance_id("contact_queue", str(clock), lane)
	var roll: Dictionary = Rng.draw(context.seed, key, "CONTACT_TIE", 0, candidates.size())
	return candidates[int(roll.value)]


static func place_spawn(entities, entity_id: String, seed: String) -> Dictionary:
	var unit: Dictionary = entities.get_entity(entity_id)
	var best: Dictionary = unit.attributes.duplicate(true)
	var clearance: int = -1
	for attempt in range(64):
		var x: Dictionary = Rng.draw(seed, entity_id, "SPAWN_FORWARD", attempt, SPAWN_DEPTH_FP + 1)
		var y: Dictionary = Rng.draw(
			seed, entity_id, "SPAWN_LATERAL", attempt, WIDTH_FP - CONTACT_FP + 1
		)
		var candidate: Dictionary = unit.attributes.duplicate(true)
		candidate.x_fp = int(x.value) if unit.owner == 0 else LANE_FP - int(x.value)
		candidate.y_fp = (CONTACT_FP >> 1) + int(y.value)
		var nearest: int = 9223372036854775807
		for other in _units(entities):
			if (
				other.id != entity_id
				and other.owner == unit.owner
				and other.attributes.lane == candidate.lane
			):
				nearest = mini(nearest, _distance(candidate, other.attributes))
		if nearest > clearance:
			clearance = nearest
			best = candidate
		if nearest >= CENTER_GAP_FP * CENTER_GAP_FP:
			break
	var result: Dictionary = entities.update(entity_id, unit.owner, best)
	if result.action == "invalid":
		return result
	return {"action": "spawn_positioned", "entity": entities.get_entity(entity_id)}


static func _valid_duels(world: Dictionary) -> bool:
	var duels = world.data.get("marching_duels", {})
	if typeof(duels) != TYPE_DICTIONARY or not Data.is_data(duels):
		return false
	var used: Array = []
	for lane in duels:
		var duel = duels[lane]
		if lane not in LANES or typeof(duel) != TYPE_DICTIONARY:
			return false
		if (
			typeof(duel.get("id")) != TYPE_STRING
			or duel.id.is_empty()
			or typeof(duel.get("units")) != TYPE_ARRAY
			or duel.units.size() != 2
			or typeof(duel.get("exchanges")) != TYPE_ARRAY
			or duel.exchanges.is_empty()
			or duel.exchanges.size() >= 64
		):
			return false
		for key in ["round", "tick", "next_tick"]:
			if not Data.is_integer(duel.get(key)) or duel[key] < 0:
				return false
		if (
			duel.tick >= TICKS
			or (
				duel.next_tick
				!= int(duel.round) * TICKS + int(duel.tick) + duel.exchanges.size() * EXCHANGE_TICKS
			)
		):
			return false
		for index in range(2):
			var unit = duel.units[index]
			if (
				typeof(unit) != TYPE_DICTIONARY
				or unit.get("id", "") not in world.entities.used_ids
				or unit.get("owner") != index
				or unit.get("kind") != "marcher"
				or unit.id in used
				or typeof(unit.get("attributes")) != TYPE_DICTIONARY
				or unit.attributes.get("lane") != lane
			):
				return false
			if (
				typeof(unit.get("origin")) != TYPE_STRING
				or not Data.is_integer(unit.get("ordinal"))
			):
				return false
			if Ids.identity("marcher", unit.origin, int(unit.ordinal)) != unit.id:
				return false
			var single: Dictionary = {"entities": {"entities": [unit]}, "data": {}}
			if not valid(single):
				return false
			used.append(unit.id)
		if _distance(duel.units[0].attributes, duel.units[1].attributes) > CONTACT_FP * CONTACT_FP:
			return false
		var expected_id: String = Data.instance_id(
			"spatial_duel",
			str(int(duel.round) * TICKS + int(duel.tick)),
			JSON.stringify([duel.units[0].id, duel.units[1].id])
		)
		if duel.id != expected_id:
			return false
		for exchange in duel.exchanges:
			if typeof(exchange) != TYPE_DICTIONARY:
				return false
			for key in ["hp", "armor"]:
				if typeof(exchange.get(key)) != TYPE_ARRAY or exchange[key].size() != 2:
					return false
				for value in exchange[key]:
					if not Data.is_integer(value) or value < 0:
						return false
	return true


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
