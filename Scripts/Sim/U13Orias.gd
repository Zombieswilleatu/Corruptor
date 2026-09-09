extends RefCounted

const Guards = preload("res://Scripts/Sim/U13GuardDeployment.gd")
const Base = preload("res://Scripts/Sim/U13Kalligan.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Space = preload("res://Scripts/Sim/U13SpatialSpace.gd")
const Queries = preload("res://Scripts/Sim/U13SpatialQueries.gd")
const Fields = preload("res://Scripts/Sim/U13SpatialFields.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
const MatchOwner = preload("res://Scripts/Sim/U13Match.gd")
const Construction = preload("res://Scripts/Sim/U13Construction.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Stats = preload("res://Scripts/Sim/U13LordStats.gd")
const POLICY: String = Stats.ORIAS_WEB_PROFILE
const SNARE: String = "Snare"
const WEB: String = Fields.WEB
# User's initial tuning: diameter 540 covers 90% of the 600-unit lane width.
const WEB_RADIUS_FP: int = 270
var _base = Base.new()


func create_combat_match():
	var validators: Dictionary = {}
	var resolvers: Dictionary = {}
	for power in rules():
		validators[power] = Callable(self, "validate")
		resolvers[power] = Callable(self, "resolve")
	return MatchOwner.new(
		POLICY + ":" + Base.POLICY + ":" + Fields.VERSION,
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
	var result: Dictionary = Base.rules()
	result[WEB] = {
		"lord_id": "Orias",
		"fire_hook": Timeline.POST_RESOLUTION_HAZARDS,
		"cooldown_on": "expiration",
		"cooldown_rounds": 1,
		"delay_rounds": 0,
		"cost": {},
		"stages": [{"fresh": true}, {"fresh": false}],
		"target_kind": "",
		"target_relation": "any",
		"visibility": "public",
		"spatial_field": {"kind": "web", "radius_fp": WEB_RADIUS_FP}
	}
	result[SNARE] = {
		"lord_id": "Orias",
		"fire_hook": Timeline.ROUND_START_SCHEDULED,
		"cooldown_on": "activation",
		"cooldown_rounds": 0,
		"delay_rounds": 1,
		"cost": {},
		"stages": [],
		"target_kind": "",
		"target_relation": "any",
		"visibility": "public",
		"threat_gain": 1
	}
	return result


func valid_world(world: Dictionary) -> bool:
	if (
		world.data.get("orias_profile") != POLICY
		or world.data.get("spatial_field_profile") != Fields.VERSION
		or not _base.valid_world(world, true)
		or not Guards.valid(world)
	):
		return false
	if (
		typeof(world.data.get("snare_paid_rounds")) != TYPE_ARRAY
		or world.data.snare_paid_rounds.size() != 2
	):
		return false
	for paid_round in world.data.snare_paid_rounds:
		if not Data.is_integer(paid_round) or paid_round < 0:
			return false
	for entity in world.entities.entities:
		if entity.kind == "lord" and entity.attributes.get("lord_id") == "Orias":
			var threat = entity.attributes.get("threat")
			if not Data.is_integer(threat) or threat < 0 or threat > 1000000:
				return false
	return true


func validate(source: Dictionary, world: Dictionary, phase: String) -> Dictionary:
	if source.power_id == SNARE:
		var affordable: bool = true
		if phase == "declaration":
			var entities = Ids.new()
			entities.restore(world.entities)
			affordable = (
				int(
					(
						entities
						. get_entity(world.players[source.player_id].lord_entity_id)
						. attributes
						. threat
					)
				)
				< 1000000
			)
		return {
			"legal": _snare_target_valid(source) and source.parameters.is_empty() and affordable,
			"reason": "snare_terms_invalid"
		}
	if source.power_id != WEB:
		return _base.validate(source, world, phase)
	return {
		"legal": Fields.target_valid(source.target) and source.parameters.is_empty(),
		"reason": "web_position_invalid"
	}


# Single fresh pulse at Step 10E. Standard damage consumes Armor before HP.
# Actors entering later are slowed, but do not receive another damage pulse.
func resolve(record: Dictionary, context: Dictionary) -> Dictionary:
	if record.declaration.power_id == SNARE:
		return _resolve_snare(record, context)
	if record.declaration.power_id != WEB:
		return _base.resolve(record, context)
	var source: Dictionary = record.declaration
	# Match firing context omits hook; the validated pending record owns it.
	var hook: String = record.fire_hook
	if (
		(hook != Timeline.POST_RESOLUTION_HAZARDS or context.get("hook", hook) != hook)
		or not Fields.target_valid(source.target)
	):
		return Data.invalid("web_activation_invalid")
	var area: Dictionary = Space.circle_region(
		source.target.lane, source.target.field_position, WEB_RADIUS_FP
	)
	var query = Queries.new()
	if query.capture(context.world.entities).action == "invalid":
		return Data.invalid("web_query_invalid")
	var targets: Dictionary = query.members(area, 1 - int(source.player_id))
	if targets.action == "invalid":
		return targets
	var world: Dictionary = context.world.duplicate(true)
	var events: Array = []
	var effect_id: String = Data.instance_id("persistent", source.declaration_id, WEB)
	for entity_id in targets.ids:
		var entities = Ids.new()
		entities.restore(world.entities)
		var entity: Dictionary = entities.get_entity(entity_id)
		if entity.is_empty():
			continue
		var absorbed: int = mini(1, int(entity.attributes.armor))
		entity.attributes.armor -= absorbed
		entities.update(entity.id, entity.owner, entity.attributes)
		world.entities = entities.snapshot()
		var hit: Dictionary = Battle.apply(
			world,
			{
				"command_id": Data.instance_id("web_hit", effect_id, entity_id),
				"kind": "marcher_damage",
				"target_id": entity_id,
				"damage": 1 - absorbed,
				"cause": "hazard"
			},
			context.round,
			hook
		)
		if hit.action == "invalid":
			return hit
		var reacted: Dictionary = _base._humbaba.react(
			hit.world, hit.event, context.seed, context.player_order
		)
		if reacted.action == "invalid":
			return reacted
		world = reacted.world
		events.append({"event": hit.event, "views": [hit.event, hit.event]})
		events.append_array(reacted.events)
		events.append(
			_event(
				"WEB_HIT",
				{
					"effect_id": effect_id,
					"entity_id": entity_id,
					"armor_absorbed": absorbed,
					"intensity": 1,
					"round": context.round,
					"hook": hook
				}
			)
		)
	events.append(
		_event(
			"WEB_STARTED",
			{
				"effect_id": effect_id,
				"player_id": source.player_id,
				"target": source.target,
				"radius_fp": WEB_RADIUS_FP,
				"affected_ids": targets.ids,
				"round": context.round,
				"hook": hook
			}
		)
	)
	return {
		"action": "resolved",
		"world": world,
		"events": events,
		"persistent_payload": {"spatial_field": rules()[WEB].spatial_field}
	}


func on_hook(context: Dictionary) -> Dictionary:
	var ordinary: Dictionary = context.duplicate(true)
	ordinary.combat_orders = [
		Guards.strip_order(context.combat_orders[0]), Guards.strip_order(context.combat_orders[1])
	]
	var result: Dictionary = _base.on_hook(ordinary)
	if result.action == "invalid":
		return result
	if context.hook == Timeline.PRESENT_PUBLIC_STATE:
		Guards.capture_limits(result.world, context.round)
	elif context.hook == Timeline.DEVELOPMENT:
		var deployment_context: Dictionary = context.duplicate(true)
		deployment_context.world = result.world
		var deployed: Dictionary = Guards.resolve(deployment_context)
		if deployed.action == "invalid":
			return deployed
		result.world = deployed.world
		result.events.append_array(deployed.events)
	elif context.hook == Timeline.AFTERMATH:
		result.world.data.guard_orders = [null, null]
	return result


func project(world: Dictionary, player_id: int) -> Dictionary:
	var result: Dictionary = _base.project(world, player_id)
	result["orias_profile"] = POLICY
	result["web_radius_fp"] = WEB_RADIUS_FP
	result["guard_deployment_profile"] = Guards.VERSION
	result["orias_breach_name"] = Guards.BREACH_NAME
	result["guard_limit_round"] = world.data.guard_public_round
	result["guard_placement_limits"] = world.data.guard_public_limits.duplicate()
	result["snare_rounds"] = world.data.snare_rounds.duplicate()
	var record = world.data.guard_orders[player_id]
	result["guard_commitments"] = [] if record == null else record.moves.duplicate(true)
	return result


func accept_order(context: Dictionary) -> Dictionary:
	var trimmed: Dictionary = context.duplicate(true)
	trimmed.order = Guards.strip_order(context.order)
	var sealed_events: Array = []
	if context.phase == "snapshot":
		if not Guards.snapshot_valid(context) or not _snare_payments_valid(context):
			return Data.invalid("guard_or_snare_snapshot_invalid")
	else:
		var reserved: Dictionary = Guards.reserve(
			trimmed.world, context.player_id, context.order, context.round
		)
		if reserved.action == "invalid":
			return reserved
		trimmed.world = reserved.world
		sealed_events = reserved.events
		for source in context.declarations:
			if source.power_id == SNARE:
				var paid: Dictionary = _pay_snare(trimmed.world, source, context.round)
				if paid.action == "invalid":
					return paid
				trimmed.world = paid.world
				sealed_events.append_array(paid.events)
	var ordinary: Dictionary = _base.accept_order(trimmed)
	if ordinary.action != "invalid" and context.phase != "snapshot":
		ordinary.events = sealed_events + ordinary.events
	if ordinary.action == "invalid" or context.phase != "snapshot":
		return ordinary
	for pending in context.pending_effects:
		if pending.declaration.power_id == SNARE:
			if (
				pending.effect_key != "main"
				or not pending.payload.is_empty()
				or not _snare_target_valid(pending.declaration)
				or not pending.declaration.parameters.is_empty()
				or pending.fire_round != pending.declaration.declared_round + 1
				or pending.fire_hook != Timeline.ROUND_START_SCHEDULED
			):
				return Data.invalid("snare_pending_invalid")
		if pending.declaration.power_id != WEB:
			continue
		if (
			pending.effect_key != "main"
			or not pending.payload.is_empty()
			or not Fields.target_valid(pending.declaration.target)
			or not pending.declaration.parameters.is_empty()
		):
			return Data.invalid("web_pending_invalid")
	for active in context.persistent_effects:
		if active.declaration.power_id != WEB:
			if active.payload.has("spatial_field"):
				return Data.invalid("spatial_field_wrong_power")
			continue
		if not _valid_web(active, context):
			return Data.invalid("web_snapshot_invalid")
	return ordinary


static func _valid_web(active: Dictionary, context: Dictionary) -> bool:
	var source: Dictionary = active.declaration
	var rule: Dictionary = rules()[WEB]
	var fire_round: int = source.declared_round if source.fire_round == -1 else source.fire_round
	if (
		source.lord_id != "Orias"
		or active.effect_key != WEB
		or active.target != source.target
		or not Fields.target_valid(active.target)
		or not source.parameters.is_empty()
		or active.payload != {"spatial_field": rule.spatial_field}
		or active.stages != rule.stages
		or active.activated_round != fire_round
	):
		return false
	var bound: bool = false
	for clock in context.cooldown_locks:
		if clock.persistent_effect_id == active.effect_id:
			bound = (
				clock.phase == "awaiting_expiration"
				and clock.declaration == source
				and clock.cooldown_rounds == 1
			)
	if not bound:
		return false
	var age: int = int(context.round) - int(active.activated_round)
	if age < 0 or age > rule.stages.size():
		return false
	if age == 0 and context.next_hook_index <= Timeline.hook_rank(rule.fire_hook):
		return false
	return not (
		age == rule.stages.size()
		and context.next_hook_index > Timeline.hook_rank(Timeline.PERSISTENT_ADVANCEMENT)
	)


static func _event(kind: String, details: Dictionary) -> Dictionary:
	var event: Dictionary = {"type": kind, "text": "", "data": details}
	return {"event": event, "views": [event, event]}


static func _snare_target_valid(source: Dictionary) -> bool:
	return (
		source.target.size() == 1
		and Data.is_integer(source.target.get("player_id"))
		and source.target.player_id == 1 - int(source.player_id)
	)


static func _pay_snare(world: Dictionary, source: Dictionary, round_number: int) -> Dictionary:
	var pid: int = source.player_id
	if world.data.snare_paid_rounds[pid] >= round_number:
		return Data.invalid("snare_already_paid")
	var entities = Ids.new()
	entities.restore(world.entities)
	var lord: Dictionary = entities.get_entity(world.players[pid].lord_entity_id)
	var before: int = lord.attributes.threat
	if before >= 1000000:
		return Data.invalid("snare_threat_limit")
	lord.attributes.threat = before + 1
	entities.update(lord.id, pid, lord.attributes)
	world.entities = entities.snapshot()
	world.data.snare_paid_rounds[pid] = round_number
	return {
		"action": "resolved",
		"world": world,
		"events":
		[
			_event(
				"SNARE_ARMED",
				{
					"player_id": pid,
					"target_player_id": 1 - pid,
					"round": round_number,
					"hook": Timeline.SUBMISSION_LOCK,
					"declaration_id": source.declaration_id,
					"threat_before": before,
					"threat_after": before + 1
				}
			)
		]
	}


static func _resolve_snare(record: Dictionary, context: Dictionary) -> Dictionary:
	var source: Dictionary = record.declaration
	if (
		record.fire_hook != Timeline.ROUND_START_SCHEDULED
		or record.fire_round != context.round
		or context.get("hook", record.fire_hook) != record.fire_hook
		or not _snare_target_valid(source)
	):
		return Data.invalid("snare_firing_invalid")
	var world: Dictionary = context.world.duplicate(true)
	var pid: int = source.target.player_id
	world.data.snare_rounds[pid] = context.round
	return {
		"action": "resolved",
		"world": world,
		"events":
		[
			_event(
				"SNARE_ACTIVE",
				{
					"player_id": source.player_id,
					"target_player_id": pid,
					"round": context.round,
					"hook": record.fire_hook,
					"declaration_id": source.declaration_id,
					"guard_limit": 1
				}
			)
		]
	}


static func _snare_payments_valid(context: Dictionary) -> bool:
	for paid in context.world.data.snare_paid_rounds:
		if paid > context.round:
			return false
	if context.next_hook_index <= Timeline.hook_rank(Timeline.PRESENT_PUBLIC_STATE):
		return true
	var expected: int = context.presentation_world.data.snare_paid_rounds[context.player_id]
	for source in context.declarations:
		if (
			source.power_id == SNARE
			and context.next_hook_index > Timeline.hook_rank(Timeline.SUBMISSION_LOCK)
		):
			expected = context.round
	if context.world.data.snare_paid_rounds[context.player_id] != expected:
		return false
	# Immediately after lock, no combat has changed Threat yet: verify the cost.
	if (
		expected == context.round
		and context.next_hook_index == Timeline.hook_rank(Timeline.SUBMISSION_LOCK) + 1
	):
		var current_ids = Ids.new()
		var prior_ids = Ids.new()
		current_ids.restore(context.world.entities)
		prior_ids.restore(context.presentation_world.entities)
		var id: String = context.world.players[context.player_id].lord_entity_id
		if (
			current_ids.get_entity(id).attributes.threat
			!= prior_ids.get_entity(id).attributes.threat + 1
		):
			return false
	return true
