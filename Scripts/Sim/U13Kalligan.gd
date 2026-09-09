extends RefCounted

const Humbaba = preload("res://Scripts/Sim/U13Humbaba.gd")
const Hazards = preload("res://Scripts/Sim/U13Hazards.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const MatchOwner = preload("res://Scripts/Sim/U13Match.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Construction = preload("res://Scripts/Sim/U13Construction.gd")
const Legality = preload("res://Scripts/Sim/U13Legality.gd")
const Stats = preload("res://Scripts/Sim/U13LordStats.gd")
const POLICY: String = Stats.KALLIGAN_PROFILE
const INFERNO: String = "Inferno"
const PYROCLASM: String = "Pyroclasm"
var _humbaba = Humbaba.new()


func create_combat_match():
	var validators: Dictionary = {}
	var resolvers: Dictionary = {}
	for power in rules():
		validators[power] = Callable(self, "validate")
		resolvers[power] = Callable(self, "resolve")
	return MatchOwner.new(
		POLICY + ":" + Humbaba.POLICY + ":" + Hazards.VERSION,
		rules(),
		validators,
		resolvers,
		Callable(self, "project"),
		Callable(),
		Callable(self, "on_hook"),
		self,
		Callable(self, "valid_world"),
		Callable(self, "accept_order"),
		Callable(Construction, "screen_orders"),
		Callable(Construction, "legal_orders")
	)


static func rules() -> Dictionary:
	var result: Dictionary = Humbaba.rules()
	result[INFERNO] = {
		"lord_id": "Kalligan",
		"fire_hook": Timeline.PERSISTENT_ADVANCEMENT,
		"delay_rounds": 1,
		"cooldown_on": "expiration",
		"cooldown_rounds": 1,
		"cost": {},
		"stages": [{"intensity": 1}, {"intensity": 2}, {"intensity": 1}],
		"target_kind": "",
		"target_relation": "any",
		"visibility": "public",
		"persistent_relocatable": true,
		"persistent_context": true
	}
	result[PYROCLASM] = {
		"lord_id": "Kalligan",
		"fire_hook": Timeline.POST_RESOLUTION_DIRECT,
		"delay_rounds": 0,
		"cooldown_on": "activation",
		"cooldown_rounds": 0,
		"cost": {},
		"stages": [],
		"target_kind": "",
		"target_relation": "any",
		"visibility": "public",
		"persistent_context": true
	}
	return result


func valid_world(world: Dictionary, allow_orias: bool = false) -> bool:
	if world.data.has("orias_profile") and not allow_orias:
		return false
	if (
		world.data.get("kalligan_profile") != POLICY
		or world.data.get("hazard_profile") != Hazards.VERSION
		or not _humbaba.valid_world(world, true)
	):
		return false
	for name in ["kalligan_upkeep_round", "scorch_guard_round", "scorch_lane_round"]:
		if not Data.is_integer(world.data.get(name)) or world.data[name] < 0:
			return false
	var used = world.data.get("rekindle_rounds")
	var eligible = world.data.get("rekindle_defunct_ids")
	if typeof(used) != TYPE_ARRAY or used.size() != 2 or typeof(eligible) != TYPE_ARRAY:
		return false
	for number in used:
		if not Data.is_integer(number) or number < 0:
			return false
	var ids = Ids.new()
	ids.restore(world.entities)
	var seen: Dictionary = {}
	for entity_id in eligible:
		if typeof(entity_id) != TYPE_STRING or seen.has(entity_id):
			return false
		seen[entity_id] = true
		var castle: Dictionary = ids.get_entity(entity_id)
		if (
			castle.is_empty()
			or castle.kind != "castle"
			or world.players[castle.owner].lord_id != "Kalligan"
		):
			return false
	for player in world.players:
		if player.lord_id == "Kalligan":
			var lord: Dictionary = ids.get_entity(player.lord_entity_id)
			if (
				not Data.is_integer(lord.attributes.get("threat"))
				or lord.attributes.threat < 0
				or lord.attributes.threat > 1000000
			):
				return false
	return true


func validate(source: Dictionary, world: Dictionary, phase: String) -> Dictionary:
	if source.power_id not in [INFERNO, PYROCLASM]:
		return _humbaba.validate(source, world, phase)
	if not source.parameters.is_empty():
		return {"legal": false, "reason": "kalligan_parameters_invalid"}
	if source.power_id == INFERNO:
		return {
			"legal": Hazards.target_valid(source.target, source.player_id),
			"reason": "scorch_target_invalid"
		}
	var scorch: Dictionary = _scorch(source.player_id, world.get("persistent_effects", []))
	return {
		"legal": source.target.is_empty() and not scorch.is_empty(),
		"reason": "pyroclasm_requires_active_scorch"
	}


static func _scorch(player_id: int, effects: Array) -> Dictionary:
	return Legality.active_for({"player_id": player_id, "power_id": INFERNO}, effects)


func resolve(record: Dictionary, context: Dictionary) -> Dictionary:
	var source: Dictionary = record.declaration
	if source.power_id not in [INFERNO, PYROCLASM]:
		return _humbaba.resolve(record, context)
	if source.power_id == INFERNO:
		return {
			"action": "resolved",
			"world": context.world,
			"events": [],
			"persistent_payload": {"hazard": "scorch"}
		}
	var pulse_context: Dictionary = context.duplicate(true)
	pulse_context["hook"] = Timeline.POST_RESOLUTION_DIRECT
	var result: Dictionary = Hazards.pulse(
		pulse_context,
		_scorch(source.player_id, context.persistent_effects),
		record.effect_id,
		Callable(_humbaba, "react")
	)
	return result


func on_hook(context: Dictionary, reaction: Callable = Callable()) -> Dictionary:
	var handler: Callable = reaction if reaction.is_valid() else Callable(_humbaba, "react")
	var result: Dictionary = _humbaba.on_hook(context, handler)
	if result.action == "invalid":
		return result
	if context.hook == Timeline.ROUND_START_AUTOMATIC:
		result = _upkeep(context, result)
	if context.hook in [Timeline.PERSISTENT_ADVANCEMENT, Timeline.MARCHING_START]:
		var field: String = (
			"scorch_guard_round"
			if context.hook == Timeline.PERSISTENT_ADVANCEMENT
			else "scorch_lane_round"
		)
		if result.world.data[field] >= context.round:
			return Data.invalid("scorch_pulse_already_applied")
		var effects: Array = context.get("persistent_effects", []).duplicate(true)
		effects.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				var ai: int = context.player_order.find(a.declaration.player_id)
				var bi: int = context.player_order.find(b.declaration.player_id)
				return ai < bi if ai != bi else a.effect_id < b.effect_id
		)
		for active in effects:
			if (
				active.effect_key != INFERNO
				or (
					active.target.kind
					!= ("guard" if context.hook == Timeline.PERSISTENT_ADVANCEMENT else "lane")
				)
			):
				continue
			var pulse_context: Dictionary = context.duplicate(true)
			pulse_context.world = result.world
			var pulse: Dictionary = Hazards.pulse(
				pulse_context,
				active,
				Data.instance_id(
					"normal_pulse", active.effect_id, str(context.round) + context.hook
				),
				handler
			)
			if pulse.action == "invalid":
				return pulse
			result.world = pulse.world
			result.events.append_array(pulse.events)
		result.world.data[field] = context.round
	return _rekindle(context, result)


func _upkeep(context: Dictionary, result: Dictionary) -> Dictionary:
	var world: Dictionary = result.world
	if world.data.kalligan_upkeep_round >= context.round:
		return Data.invalid("kalligan_upkeep_already_applied")
	var ids = Ids.new()
	ids.restore(world.entities)
	var breach: bool = world.data.breach_lord == "Kalligan"
	for castle in world.entities.entities:
		if (
			not Structures.targetable(castle)
			or castle.attributes.integrity >= castle.attributes.max_integrity
		):
			continue
		var player: Dictionary = world.players[castle.owner]
		var lord: Dictionary = ids.get_entity(player.lord_entity_id)
		if not breach and (player.lord_id != "Kalligan" or not lord.attributes.alive):
			continue
		var before: int = castle.attributes.integrity
		castle.attributes.integrity = mini(int(castle.attributes.max_integrity), before + 2)
		castle.attributes.status = "standing"
		ids.update(castle.id, castle.owner, castle.attributes)
		result.events.append(
			Structures.public_event(
				"RAPID_CONSTRUCTION" if breach else "FORGE_REPAIR",
				{
					"player_id": castle.owner,
					"castle_id": castle.id,
					"before": before,
					"after": castle.attributes.integrity,
					"round": context.round
				}
			)
		)
	world.entities = ids.snapshot()
	world.data.kalligan_upkeep_round = context.round
	return result


func _rekindle(context: Dictionary, result: Dictionary) -> Dictionary:
	if result.action == "invalid":
		return result
	var world: Dictionary = result.world
	var eligible: Array = world.data.rekindle_defunct_ids
	# Observe actual exposed Defunct episodes before upkeep/development can
	# repair them. Initial protected construction is never a revival reward.
	for castle in context.world.entities.entities:
		if (
			Structures.targetable(castle)
			and castle.attributes.status == "defunct"
			and world.players[castle.owner].lord_id == "Kalligan"
			and castle.id not in eligible
		):
			eligible.append(castle.id)
	var ids = Ids.new()
	ids.restore(world.entities)
	eligible.sort()
	for entity_id in eligible.duplicate():
		var castle: Dictionary = ids.get_entity(entity_id)
		if not Structures.targetable(castle):
			eligible.erase(entity_id)
			continue
		if not Structures.operational(castle):
			continue
		eligible.erase(entity_id)
		var player_id: int = castle.owner
		var lord: Dictionary = ids.get_entity(world.players[player_id].lord_entity_id)
		if lord.attributes.alive and world.data.rekindle_rounds[player_id] < context.round:
			world.data.rekindle_rounds[player_id] = context.round
			world.data.neutral_tears += 1
			result.events.append(
				Structures.public_event(
					"NEUTRAL_TEAR_CREATED",
					{
						"source": "Rekindle",
						"amount": 1,
						"player_id": player_id,
						"castle_id": castle.id,
						"round": context.round
					}
				)
			)
	world.data.rekindle_defunct_ids = eligible
	return result


func accept_order(context: Dictionary) -> Dictionary:
	var ordinary: Dictionary = _humbaba.accept_order(context)
	if ordinary.action == "invalid" or context.phase != "snapshot":
		return ordinary
	for entry in [
		["kalligan_upkeep_round", Timeline.ROUND_START_AUTOMATIC],
		["scorch_guard_round", Timeline.PERSISTENT_ADVANCEMENT],
		["scorch_lane_round", Timeline.MARCHING_START]
	]:
		var expected: int = (
			context.round
			if context.next_hook_index > Timeline.hook_rank(entry[1])
			else context.round - 1
		)
		if context.world.data[entry[0]] != expected:
			return Data.invalid("kalligan_phase_ledger_invalid")
	for used in context.world.data.rekindle_rounds:
		if used > context.round:
			return Data.invalid("rekindle_ledger_ahead")
	var entities = Ids.new()
	entities.restore(context.world.entities)
	for entity_id in context.world.data.rekindle_defunct_ids:
		var castle: Dictionary = entities.get_entity(entity_id)
		if not Structures.targetable(castle) or Structures.operational(castle):
			return Data.invalid("rekindle_episode_inconsistent")
	for pending in context.get("pending_effects", []):
		var source: Dictionary = pending.declaration
		if source.power_id not in [INFERNO, PYROCLASM]:
			continue
		if (
			pending.effect_key != "main"
			or (
				pending.fire_round
				!= (source.declared_round if source.fire_round == -1 else source.fire_round)
			)
			or pending.fire_hook != source.fire_hook
			or not source.parameters.is_empty()
		):
			return Data.invalid("kalligan_pending_terms_invalid")
		if source.power_id == PYROCLASM:
			if not pending.payload.is_empty() or not source.target.is_empty():
				return Data.invalid("pyroclasm_pending_invalid")
		elif (
			not Hazards.target_valid(source.target, source.player_id)
			or (not pending.payload.is_empty() and not pending.payload.has("relocate_effect_id"))
		):
			return Data.invalid("inferno_pending_invalid")
	for active in context.persistent_effects:
		if active.effect_key != INFERNO and active.declaration.power_id != INFERNO:
			if active.payload.has("hazard"):
				return Data.invalid("hazard_payload_wrong_power")
			continue
		if not _valid_scorch(active, context):
			return Data.invalid("scorch_snapshot_invalid")
	return ordinary


static func _valid_scorch(active: Dictionary, context: Dictionary) -> bool:
	var original: Dictionary = active.declaration
	if (
		active.effect_key != INFERNO
		or original.power_id != INFERNO
		or original.lord_id != "Kalligan"
		or active.stages != rules()[INFERNO].stages
		or active.payload.get("hazard") != "scorch"
		or not Hazards.target_valid(active.target, original.player_id)
		or not Hazards.target_valid(original.target, original.player_id)
		or not original.parameters.is_empty()
		or active.activated_round != original.fire_round
	):
		return false
	var bound: bool = false
	for clock in context.cooldown_locks:
		if clock.persistent_effect_id == active.effect_id:
			bound = (
				clock.phase == "awaiting_expiration"
				and clock.declaration == original
				and clock.cooldown_rounds == 1
			)
	if not bound:
		return false
	if active.payload.has("last_relocation"):
		var moved: Dictionary = Data.declaration_copy(active.payload.last_relocation)
		if (
			moved.is_empty()
			or active.payload.size() != 2
			or moved.player_id != original.player_id
			or moved.power_id != INFERNO
			or moved.lord_id != "Kalligan"
			or moved.fire_hook != Timeline.PERSISTENT_ADVANCEMENT
			or moved.fire_round != moved.declared_round + 1
			or moved.fire_round > context.round
			or moved.fire_round >= active.activated_round + active.stages.size()
			or moved.fire_round <= active.activated_round
			or moved.target != active.target
			or not moved.parameters.is_empty()
			or not moved.cost.is_empty()
			or moved.visibility != "public"
			or (
				moved.declaration_id
				!= MatchOwner.declaration_id(
					moved.player_id, moved.declared_round, moved.queue_index
				)
			)
		):
			return false
		if (
			moved.fire_round == context.round
			and context.next_hook_index <= Timeline.hook_rank(Timeline.PERSISTENT_ADVANCEMENT)
		):
			return false
	elif active.payload.size() != 1 or active.target != original.target:
		return false
	return not (
		active.activated_round == context.round
		and context.next_hook_index <= Timeline.hook_rank(Timeline.PERSISTENT_ADVANCEMENT)
	)


func project(world: Dictionary, player_id: int) -> Dictionary:
	var view: Dictionary = _humbaba.project(world, player_id)
	view["kalligan_profile"] = POLICY
	return view
