extends "res://Scripts/Sim/U13Orias.gd"

const ODRADEK_POLICY: String = Stats.ODRADEK_PROFILE
const REDIRECT: String = "Redirect"
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
	return result


func valid_world(world: Dictionary) -> bool:
	if not super.valid_world(world) or world.data.get("odradek_profile") != ODRADEK_POLICY:
		return false
	if (
		not Data.is_integer(world.data.get("reconfiguration_round"))
		or world.data.reconfiguration_round < 0
	):
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


func validate(source: Dictionary, world: Dictionary, phase: String) -> Dictionary:
	if source.power_id != REDIRECT:
		return super.validate(source, world, phase)
	return {
		"legal": Fields.target_valid(source.target) and source.parameters.is_empty(),
		"reason": "redirect_area_invalid"
	}


func resolve(record: Dictionary, context: Dictionary) -> Dictionary:
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
			_event(
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
	if result.action == "invalid" or context.hook != Timeline.ROUND_START_AUTOMATIC:
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
				_event(
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
			_event(
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
			pending.declaration.power_id == REDIRECT
			and (
				pending.effect_key != "main"
				or not pending.payload.is_empty()
				or not Fields.target_valid(pending.declaration.target)
				or not pending.declaration.parameters.is_empty()
			)
		):
			return Data.invalid("redirect_pending_invalid")
	# Resource payment must survive save/load exactly at the lock boundary.
	if context.next_hook_index == Timeline.hook_rank(Timeline.SUBMISSION_LOCK) + 1:
		var budget: int = context.presentation_world.players[context.player_id].resources[RESOURCE]
		for source in context.declarations:
			budget -= int(source.cost.get(RESOURCE, 0))
		if budget < 0 or context.world.players[context.player_id].resources[RESOURCE] != budget:
			return Data.invalid("reconfiguration_payment_invalid")
	return result
