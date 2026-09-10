extends "res://Scripts/Sim/U13Orias.gd"

const ODRADEK_POLICY: String = Stats.ODRADEK_PROFILE
const REDIRECT: String = "Redirect"
const Transfers = preload("res://Scripts/Sim/U13GuardTransfers.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const FALSE_ORDERS: String = "FalseOrders"
const SHIFT: String = "AllegianceShift"
const INVERSION: String = "Inversion"
const POWERS: Array = [REDIRECT, FALSE_ORDERS, SHIFT, INVERSION]
# Smaller than Redirect; shared initial tuning for Paradox's small circle.
const SHIFT_RADIUS_FP: int = 180
const RESOURCE: String = "reconfiguration"
# Initial exercise tuning: one lane-width diameter. Not shipping balance.
const REDIRECT_RADIUS_FP: int = 300


func create_combat_match():
	var validators: Dictionary = {}
	var resolvers: Dictionary = {}
	for power in rules():
		validators[power] = Callable(self, "validate")
		resolvers[power] = Callable(self, "resolve")
	return MatchOwner.new(
		ODRADEK_POLICY + ":" + POLICY,
		rules(),
		validators,
		resolvers,
		Callable(self, "project"),
		Callable(),
		Callable(self, "on_hook"),
		self,
		Callable(self, "valid_world"),
		Callable(self, "accept_order"),
		Callable(),
		Callable(Guards, "legal_orders")
	)


static func rules() -> Dictionary:
	var result: Dictionary = preload("res://Scripts/Sim/U13Orias.gd").rules()
	result[REDIRECT] = {
		"lord_id": "Odradek",
		"fire_hook": Timeline.POST_RESOLUTION_POSITION,
		"cooldown_on": "activation",
		"cooldown_rounds": 0,
		"delay_rounds": 0,
		"cost": {RESOURCE: 1},
		"stages": [],
		"target_kind": "",
		"target_relation": "any",
		"visibility": "public",
		"repeatable": true
	}
	for power in [FALSE_ORDERS, SHIFT, INVERSION]:
		var rule: Dictionary = result[REDIRECT].duplicate(true)
		rule.cost = {RESOURCE: POWERS.find(power) + 1}
		rule.fire_hook = (
			Timeline.POST_RESOLUTION_ALLEGIANCE
			if power == SHIFT
			else Timeline.ROUND_START_SCHEDULED
		)
		rule.delay_rounds = 0 if power == SHIFT else 1
		result[power] = rule
	return result


func valid_world(world: Dictionary) -> bool:
	if not super.valid_world(world) or world.data.get("odradek_profile") != ODRADEK_POLICY:
		return false
	if (
		not Data.is_integer(world.data.get("reconfiguration_round"))
		or world.data.reconfiguration_round < 0
	):
		return false
	if not Data.is_integer(world.data.get("paradox_round")) or world.data.paradox_round < 0:
		return false
	if (
		typeof(world.data.get("interlock_rounds")) != TYPE_ARRAY
		or world.data.interlock_rounds.size() != 2
	):
		return false
	for used_round in world.data.interlock_rounds:
		if not Data.is_integer(used_round) or used_round < 0:
			return false
	for player in world.players:
		var amount = player.resources.get(RESOURCE)
		if not Data.is_integer(amount) or amount < 0 or amount > 4:
			return false
		if player.lord_id != "Odradek" and amount != 0:
			return false
	for lord in world.entities.entities:
		if lord.kind == "lord" and lord.attributes.lord_id == "Odradek":
			if (
				not Data.is_integer(lord.attributes.get("threat"))
				or lord.attributes.threat < 0
				or lord.attributes.threat > 1000000
			):
				return false
			if not lord.attributes.alive and world.players[lord.owner].resources[RESOURCE] != 0:
				return false
	return true


static func target_shape(power: String, target: Dictionary, pid: int) -> bool:
	if power in [REDIRECT, SHIFT]:
		return Fields.target_valid(target)
	if power == FALSE_ORDERS:
		return (
			target.size() == 3
			and typeof(target.get("entity_id")) == TYPE_STRING
			and not target.entity_id.is_empty()
			and Data.is_integer(target.get("owner_id"))
			and target.owner_id in [0, 1]
			and target.get("lane") in Guards.LANES
		)
	if power == INVERSION:
		return (
			target.size() == 2
			and Data.is_integer(target.get("owner_id"))
			and target.owner_id == 1 - pid
			and target.get("lane") in Guards.LANES
		)
	return false


func validate(source: Dictionary, world: Dictionary, phase: String) -> Dictionary:
	if source.power_id not in POWERS:
		return super.validate(source, world, phase)
	var legal: bool = (
		source.parameters.is_empty()
		and target_shape(source.power_id, source.target, source.player_id)
	)
	if legal and source.power_id == FALSE_ORDERS:
		legal = (
			(
				Transfers
				. move(
					world,
					source.target.entity_id,
					source.target.owner_id,
					source.target.owner_id,
					source.target.lane
				)
				. action
			)
			== "resolved"
		)
	elif legal and source.power_id == INVERSION:
		legal = not (
			Transfers
			. eligible(world, source.target.owner_id, source.target.lane, source.player_id)
			. is_empty()
		)
	return {"legal": legal, "reason": "reconfiguration_target_unavailable"}


func resolve(record: Dictionary, context: Dictionary) -> Dictionary:
	if record.declaration.power_id in [FALSE_ORDERS, SHIFT, INVERSION]:
		return _resolve_reconfiguration(record, context)
	if record.declaration.power_id != REDIRECT:
		return super.resolve(record, context)
	if (
		record.fire_hook != Timeline.POST_RESOLUTION_POSITION
		or context.get("hook", record.fire_hook) != record.fire_hook
	):
		return Data.invalid("redirect_hook_invalid")
	var source: Dictionary = record.declaration
	var area: Dictionary = Space.circle_region(
		source.target.lane, source.target.field_position, REDIRECT_RADIUS_FP
	)
	var query = Queries.new()
	if query.capture(context.world.entities).action == "invalid":
		return Data.invalid("redirect_query_invalid")
	# One snapshot for each effect, both owners; the next queued effect recaptures.
	var members: Dictionary = query.members(area)
	if members.action == "invalid":
		return members
	var world: Dictionary = Data.copy_data(context.world)
	var entities = Ids.new()
	entities.restore(world.entities)
	var prior: Dictionary = {}
	for id in members.ids:
		prior[id] = entities.get_entity(id).duplicate(true)
	var changes: Array = []
	var duels: Dictionary = world.data.get("marching_duels", {})
	for lane in duels.keys():
		var interrupted: bool = false
		for participant in duels[lane].units:
			interrupted = interrupted or participant.id in members.ids
		if interrupted:
			for participant in duels[lane].units:
				var unit: Dictionary = entities.get_entity(participant.id)
				if not unit.is_empty():
					unit.attributes.contact_tick = -1
					entities.update(unit.id, unit.owner, unit.attributes)
			duels.erase(lane)
	if world.data.has("marching_duels"):
		world.data.marching_duels = duels
	for id in members.ids:
		var unit: Dictionary = entities.get_entity(id)
		var before: Dictionary = prior[id]
		unit.attributes.lane = "Castle" if unit.attributes.lane == "Lord" else "Lord"
		entities.update(id, unit.owner, unit.attributes)
		changes.append({"before": before, "after": entities.get_entity(id)})
	world.entities = entities.snapshot()
	return {
		"action": "resolved",
		"world": world,
		"events":
		[
			_odradek_event(
				"REDIRECT_RESOLVED",
				{
					"declaration_id": source.declaration_id,
					"player_id": source.player_id,
					"round": context.round,
					"hook": record.fire_hook,
					"target": source.target,
					"radius_fp": REDIRECT_RADIUS_FP,
					"changes": changes
				}
			)
		]
	}


func on_hook(context: Dictionary) -> Dictionary:
	var result: Dictionary = super.on_hook(context)
	if result.action == "invalid":
		return result
	if context.hook == Timeline.POST_RESOLUTION_ALLEGIANCE:
		return _paradox(context, result)
	if context.hook != Timeline.ROUND_START_AUTOMATIC:
		return result
	if result.world.data.reconfiguration_round >= context.round:
		return Data.invalid("reconfiguration_already_advanced")
	var entities = Ids.new()
	entities.restore(result.world.entities)
	for pid in [0, 1]:
		var player: Dictionary = result.world.players[pid]
		var lord: Dictionary = entities.get_entity(player.lord_entity_id)
		if player.lord_id == "Odradek" and lord.attributes.alive:
			var before: int = player.resources[RESOURCE]
			player.resources[RESOURCE] = mini(4, before + 1)
			result.events.append(
				_odradek_event(
					"RECONFIGURATION_GAINED",
					{
						"player_id": pid,
						"before": before,
						"after": player.resources[RESOURCE],
						"round": context.round
					}
				)
			)
	result.world.data.reconfiguration_round = context.round
	return result


func react(
	raw: Dictionary, fact: Dictionary, seed_value: String, player_order: Array
) -> Dictionary:
	var result: Dictionary = super.react(raw, fact, seed_value, player_order)
	if result.action != "invalid" and fact.type == "MARCHER_DEFEATED":
		return _interlock(result, fact, seed_value, player_order)
	if result.action == "invalid" or fact.type != "LORD_BANISHED":
		return result
	var entities = Ids.new()
	entities.restore(result.world.entities)
	var lord: Dictionary = entities.get_entity(fact.data.lord_id)
	if not lord.is_empty() and lord.attributes.lord_id == "Odradek":
		var pid: int = lord.owner
		var before: int = result.world.players[pid].resources[RESOURCE]
		result.world.players[pid].resources[RESOURCE] = 0
		result.events.append(
			_odradek_event(
				"RECONFIGURATION_RESET",
				{"player_id": pid, "before": before, "after": 0, "event_id": fact.data.event_id}
			)
		)
	return result


func project(world: Dictionary, player_id: int) -> Dictionary:
	var result: Dictionary = super.project(world, player_id)
	result["odradek_profile"] = ODRADEK_POLICY
	result["reconfiguration"] = [
		world.players[0].resources[RESOURCE], world.players[1].resources[RESOURCE]
	]
	result["redirect_radius_fp"] = REDIRECT_RADIUS_FP
	result["shift_radius_fp"] = SHIFT_RADIUS_FP
	result["interlock_rounds"] = world.data.interlock_rounds.duplicate()
	return result


func accept_order(context: Dictionary) -> Dictionary:
	var result: Dictionary = super.accept_order(context)
	if result.action == "invalid" or context.phase != "snapshot":
		return result
	var expected_round: int = (
		context.round
		if context.next_hook_index > Timeline.hook_rank(Timeline.ROUND_START_AUTOMATIC)
		else context.round - 1
	)
	if context.world.data.reconfiguration_round != expected_round:
		return Data.invalid("reconfiguration_clock_invalid")
	for pending in context.pending_effects:
		if (
			pending.declaration.power_id in POWERS
			and (
				pending.effect_key != "main"
				or not pending.payload.is_empty()
				or not target_shape(
					pending.declaration.power_id,
					pending.declaration.target,
					pending.declaration.player_id
				)
				or not pending.declaration.parameters.is_empty()
			)
		):
			return Data.invalid("redirect_pending_invalid")
	var paradox_round: int = (
		context.round
		if context.next_hook_index > Timeline.hook_rank(Timeline.POST_RESOLUTION_ALLEGIANCE)
		else context.round - 1
	)
	if context.world.data.paradox_round != paradox_round:
		return Data.invalid("paradox_clock_invalid")
	for used_round in context.world.data.interlock_rounds:
		if (
			used_round > context.round
			or (
				used_round == context.round
				and context.next_hook_index <= Timeline.hook_rank(Timeline.MARCHING)
			)
		):
			return Data.invalid("interlock_clock_invalid")
	# Resource payment must survive save/load exactly at the lock boundary.
	if context.next_hook_index == Timeline.hook_rank(Timeline.SUBMISSION_LOCK) + 1:
		var budget: int = context.presentation_world.players[context.player_id].resources[RESOURCE]
		for source in context.declarations:
			budget -= int(source.cost.get(RESOURCE, 0))
		if budget < 0 or context.world.players[context.player_id].resources[RESOURCE] != budget:
			return Data.invalid("reconfiguration_payment_invalid")
	return result


func _resolve_reconfiguration(record: Dictionary, context: Dictionary) -> Dictionary:
	var source: Dictionary = record.declaration
	var rule: Dictionary = rules()[source.power_id]
	if (
		record.fire_hook != rule.fire_hook
		or context.get("hook", record.fire_hook) != record.fire_hook
	):
		return Data.invalid("reconfiguration_hook_invalid")
	if not target_shape(source.power_id, source.target, source.player_id):
		return Data.invalid("reconfiguration_target_invalid")
	var result: Dictionary = {
		"action": "resolved", "world": Data.copy_data(context.world), "events": []
	}
	if source.power_id == SHIFT:
		return _shift(result, source.target, source.player_id, context.round, source.declaration_id)
	var targets: Array = (
		[source.target.entity_id]
		if source.power_id == FALSE_ORDERS
		else Transfers.eligible(
			result.world, source.target.owner_id, source.target.lane, source.player_id
		)
	)
	var changed: int = 0
	for id in targets:
		var moved: Dictionary = Transfers.move(
			result.world,
			id,
			source.target.owner_id,
			source.target.owner_id if source.power_id == FALSE_ORDERS else source.player_id,
			source.target.lane
		)
		if moved.action == "invalid":
			return moved
		if moved.action != "resolved":
			continue
		result.world = moved.world
		changed += 1
		result.events.append(
			_odradek_event(
				"GUARD_RECONFIGURED",
				{
					"before": moved.before,
					"after": moved.after,
					"power": source.power_id,
					"declaration_id": source.declaration_id,
					"round": context.round,
					"hook": record.fire_hook
				}
			)
		)
	var tear: int = 1 if source.power_id == INVERSION and changed > 0 else 0
	if tear > 0:
		result.world.data.neutral_tears += tear
		result.events.append(
			_odradek_event(
				"NEUTRAL_TEAR_CREATED",
				{
					"amount": tear,
					"source": INVERSION,
					"player_id": source.player_id,
					"round": context.round,
					"hook": record.fire_hook
				}
			)
		)
	result.events.append(
		_odradek_event(
			"RECONFIGURATION_RESOLVED",
			{
				"power": source.power_id,
				"player_id": source.player_id,
				"declaration_id": source.declaration_id,
				"round": context.round,
				"hook": record.fire_hook,
				"moved": changed,
				"neutral_tears": tear
			}
		)
	)
	return result


func _shift(
	result: Dictionary, target: Dictionary, new_owner: int, round_number: int, identity: String
) -> Dictionary:
	var query = Queries.new()
	if query.capture(result.world.entities).action == "invalid":
		return Data.invalid("shift_query_invalid")
	var area: Dictionary = Space.circle_region(target.lane, target.field_position, SHIFT_RADIUS_FP)
	# Paradox uses -1 to flip both owners; capture membership before the first flip.
	var members: Dictionary = query.members(area, 1 - new_owner if new_owner in [0, 1] else -2)
	if members.action == "invalid":
		return members
	for id in members.ids:
		var entities = Ids.new()
		entities.restore(result.world.entities)
		var unit: Dictionary = entities.get_entity(id)
		var moved: Dictionary = Battle.apply(
			result.world,
			{
				"command_id": Data.instance_id("allegiance", identity, id),
				"kind": "change_marcher_allegiance",
				"target_id": id,
				"new_owner": new_owner if new_owner in [0, 1] else 1 - int(unit.owner)
			},
			round_number,
			Timeline.POST_RESOLUTION_ALLEGIANCE
		)
		if moved.action == "invalid":
			return moved
		result.world = moved.world
		result.events.append({"event": moved.event, "views": [moved.event, moved.event]})
	result.events.append(
		_odradek_event(
			"ALLEGIANCE_SHIFT_RESOLVED",
			{
				"declaration_id": identity,
				"player_id": new_owner,
				"target": target,
				"radius_fp": SHIFT_RADIUS_FP,
				"affected_ids": members.ids,
				"round": round_number,
				"hook": Timeline.POST_RESOLUTION_ALLEGIANCE
			}
		)
	)
	return result


func _interlock(
	result: Dictionary, fact: Dictionary, seed_value: String, player_order: Array
) -> Dictionary:
	var d: Dictionary = fact.data
	if (
		d.get("cause") != "combat"
		or d.get("hook") != Timeline.MARCHING
		or typeof(d.get("victim")) != TYPE_DICTIONARY
		or typeof(d.get("attacker")) != TYPE_DICTIONARY
	):
		return result
	var victim: Dictionary = d.victim
	var attacker: Dictionary = d.attacker
	if (
		victim.get("kind") != "marcher"
		or attacker.get("kind") != "marcher"
		or victim.owner not in [0, 1]
		or attacker.owner != 1 - int(victim.owner)
	):
		return result
	var pid: int = victim.owner
	var player: Dictionary = result.world.players[pid]
	var entities = Ids.new()
	entities.restore(result.world.entities)
	var lord: Dictionary = entities.get_entity(player.lord_entity_id)
	if (
		player.lord_id != "Odradek"
		or not lord.attributes.alive
		or result.world.data.interlock_rounds[pid] >= d.round
	):
		return result
	if not Data.is_integer(d.get("damage_dealt")) or d.damage_dealt < 1:
		return Data.invalid("interlock_killing_damage_missing")
	result.world.data.interlock_rounds[pid] = d.round
	var target: Dictionary = entities.get_entity(attacker.id)
	result.events.append(
		_odradek_event(
			"PSYCHIC_INTERLOCK",
			{
				"player_id": pid,
				"round": d.round,
				"hook": d.hook,
				"trigger_id": d.event_id,
				"target_id": attacker.id,
				"damage": d.damage_dealt,
				"target_alive": not target.is_empty()
			}
		)
	)
	# Simultaneous mutual kills still consume the first-kill trigger; never revive
	# the attacker to apply reflection. Hazard attribution prevents recursion.
	if target.is_empty():
		return result
	var absorbed: int = mini(int(target.attributes.armor), int(d.damage_dealt))
	target.attributes.armor -= absorbed
	entities.update(target.id, target.owner, target.attributes)
	result.world.entities = entities.snapshot()
	var hit: Dictionary = Battle.apply(
		result.world,
		{
			"command_id": Data.instance_id("interlock", d.event_id, str(pid)),
			"kind": "marcher_damage",
			"target_id": target.id,
			"damage": int(d.damage_dealt) - absorbed,
			"cause": "hazard"
		},
		d.round,
		Timeline.MARCHING
	)
	if hit.action == "invalid":
		return hit
	var reactions: Dictionary = super.react(hit.world, hit.event, seed_value, player_order)
	if reactions.action == "invalid":
		return reactions
	result.world = reactions.world
	result.events.append({"event": hit.event, "views": [hit.event, hit.event]})
	result.events.append_array(reactions.events)
	return result


func _paradox(context: Dictionary, result: Dictionary) -> Dictionary:
	if result.world.data.paradox_round >= context.round:
		return Data.invalid("paradox_already_resolved")
	result.world.data.paradox_round = context.round
	if result.world.data.breach_lord != "Odradek":
		return result
	var pools: Dictionary = {}
	for lane in Guards.LANES:
		var candidates: Array = []
		for pid in [0, 1]:
			candidates.append_array(Transfers.eligible(result.world, pid, lane, 1 - pid))
		candidates.sort()
		if not candidates.is_empty():
			pools[lane] = candidates
	var bodies: Array = []
	for row in result.world.entities.entities:
		if row.kind == "marcher":
			bodies.append(row.id)
	bodies.sort()
	if not bodies.is_empty():
		pools["Marcher"] = bodies
	var types: Array = pools.keys()
	types.sort()
	var identity: String = Data.instance_id("paradox", str(context.round), "breach")
	if types.is_empty():
		result.events.append(
			_odradek_event(
				"PARADOX_GEOMETRY",
				{
					"event_id": identity,
					"round": context.round,
					"kind": "none",
					"reason": "no_valid_targets"
				}
			)
		)
		return result
	var kind: String = types[int(
		Rng.draw(context.seed, identity, "PARADOX_KIND", 0, types.size()).value
	)]
	var id: String = pools[kind][int(
		Rng.draw(context.seed, identity, "PARADOX_TARGET", 0, pools[kind].size()).value
	)]
	result.events.append(
		_odradek_event(
			"PARADOX_GEOMETRY",
			{
				"event_id": identity,
				"round": context.round,
				"hook": context.hook,
				"kind": kind,
				"target_id": id
			}
		)
	)
	if kind == "Marcher":
		var entities = Ids.new()
		entities.restore(result.world.entities)
		var a: Dictionary = entities.get_entity(id).attributes
		return _shift(
			result,
			{"lane": a.lane, "field_position": {"x_fp": a.x_fp, "y_fp": a.y_fp}},
			-1,
			context.round,
			identity
		)
	var guard: Dictionary = Transfers.guard(result.world, id)
	var moved: Dictionary = Transfers.move(
		result.world, id, guard.owner, 1 - int(guard.owner), kind
	)
	if moved.action != "resolved":
		return Data.invalid("paradox_selected_transfer_failed")
	result.world = moved.world
	result.events.append(
		_odradek_event(
			"GUARD_RECONFIGURED",
			{
				"before": moved.before,
				"after": moved.after,
				"power": "ParadoxGeometry",
				"event_id": identity,
				"round": context.round,
				"hook": context.hook
			}
		)
	)
	return result


static func _odradek_event(kind: String, details: Dictionary) -> Dictionary:
	var message: String = ""
	match kind:
		"GUARD_RECONFIGURED":
			message = (
				"%s: %s %d moves to player %d's %s Guards."
				% [
					details.power,
					details.after.attributes.suit,
					details.after.attributes.value,
					int(details.after.owner) + 1,
					details.after.attributes.lane
				]
			)
		"RECONFIGURATION_RESOLVED":
			message = "%s: %d Guard(s) moved." % [details.power, details.moved]
		"NEUTRAL_TEAR_CREATED":
			message = "Inversion: +1 Neutral Tear."
		"ALLEGIANCE_SHIFT_RESOLVED":
			message = (
				"%s: %d Marcher(s) changed allegiance."
				% [
					"Paradox Geometry" if details.player_id == -1 else "Allegiance Shift",
					details.affected_ids.size()
				]
			)
		"PSYCHIC_INTERLOCK":
			message = (
				"Psychic Interlock: %d damage reflected%s."
				% [details.damage, "" if details.target_alive else " (attacker already defeated)"]
			)
		"PARADOX_GEOMETRY":
			message = (
				"Paradox Geometry: %s."
				% [
					(
						"no valid targets"
						if details.kind == "none"
						else details.kind + " allegiance event"
					)
				]
			)
	var event: Dictionary = {"type": kind, "text": message, "data": details}
	return {"event": event, "views": [event, event]}
