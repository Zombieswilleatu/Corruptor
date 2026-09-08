class_name U13Match
extends RefCounted

const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Runtime = preload("res://Scripts/Sim/U13RoundRuntime.gd")
const Pending = preload("res://Scripts/Sim/U13PendingEffects.gd")
const Persistent = preload("res://Scripts/Sim/U13PersistentEffects.gd")
const Cooldowns = preload("res://Scripts/Sim/U13Cooldowns.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const Entities = preload("res://Scripts/Sim/U13EntityIds.gd")
const Legality = preload("res://Scripts/Sim/U13Legality.gd")
const EventLog = preload("res://Scripts/Sim/U13EventLog.gd")
const VERSION: String = "U13_MATCH_V1"
const ENGINE_VERSION: String = "4.7.2"

# Authoritative simulation owner; this is not a replacement U12 scene/controller.
# Content callbacks are pure data transforms. They never receive this owner.
# policy_id versions callback implementation; rules themselves are also hashed.
var _policy_id: String
var _rules: Dictionary
var _validators: Dictionary
var _resolvers: Dictionary
var _projector: Callable
var _hook_handler: Callable
var _context_hook: Callable
# Retain RefCounted content that owns configured Callables, without serializing it.
var _content_owner: RefCounted
var _world_validator: Callable
var _seed: String = ""
var _world: Dictionary = {}
var _presentation_world: Dictionary = {}
var _submissions: Array = [null, null]
var _order: Array = [0, 1]
var _runtime = Runtime.new()
var _pending = Pending.new()
var _persistent = Persistent.new()
var _cooldowns = Cooldowns.new()
var _entities = Entities.new()
var _events = EventLog.new()


func _init(
	policy_id: String = "",
	rules: Dictionary = {},
	validators: Dictionary = {},
	resolvers: Dictionary = {},
	projector: Callable = Callable(),
	hook_handler: Callable = Callable(),
	context_hook: Callable = Callable(),
	content_owner: RefCounted = null,
	world_validator: Callable = Callable()
) -> void:
	_policy_id = policy_id
	_rules = rules.duplicate(true)
	_validators = validators.duplicate()
	_resolvers = resolvers.duplicate()
	_projector = projector
	_hook_handler = hook_handler
	_context_hook = context_hook
	_content_owner = content_owner
	_world_validator = world_validator


static func declaration_id(player_id: int, round_number: int, queue_index: int) -> String:
	return Data.instance_id("declaration", "%d:%d" % [player_id, round_number], str(queue_index))


func start(seed_value: String, world: Dictionary, player_order: Array) -> Dictionary:
	if not _seed.is_empty():
		return Data.invalid("match_already_started")
	if seed_value.is_empty():
		return Data.invalid("match_seed_required")
	if not Data.valid_player_order(player_order):
		return Data.invalid("match_player_order_invalid")
	# Preserve the strict data contract and report the failed startup boundary.
	if not Data.is_data(_rules):
		return Data.invalid("match_rules_data_invalid")
	if not _configuration_valid():
		return Data.invalid("match_configuration_invalid")
	var candidate = _new_owner()
	var installed: Dictionary = candidate._install_world(world)
	if installed.action == "invalid":
		return installed
	candidate._seed = seed_value
	candidate._order = player_order.duplicate()
	candidate._runtime.begin_round(1)
	candidate._presentation_world = candidate._world.duplicate(true)
	_adopt(candidate)
	return {"action": "u13_match_started"}


func begin_next_round(player_order: Array) -> Dictionary:
	if not _runtime.completed or not Data.valid_player_order(player_order):
		return Data.invalid("match_round_not_complete")
	if not Data.is_integer(_runtime.round_number + 1):
		return Data.invalid("match_round_overflow")
	_order = player_order.duplicate()
	_submissions = [null, null]
	return _runtime.begin_round(_runtime.round_number + 1)


func next_hook() -> String:
	return _runtime.next_hook()


# Same entry point for UI, bot and submit. A complete queue is evaluated together
# so two powers cannot spend the same resources or reserve the same cooldown.
func preview_submission(player_id: int, declarations: Array) -> Dictionary:
	if _seed.is_empty() or player_id not in [0, 1] or next_hook() != Timeline.SUBMISSION_LOCK:
		return Data.invalid("submission_window_closed")
	if _submissions[player_id] != null:
		return Data.invalid("submission_already_locked")
	var candidate = _clone()
	if candidate == null:
		return Data.invalid("match_clone_failed")
	return candidate._accept(player_id, declarations)


func submit(player_id: int, declarations: Array) -> Dictionary:
	var result: Dictionary = preview_submission(player_id, declarations)
	if result.action == "invalid":
		return result
	_submissions[player_id] = Data.copy_data(declarations)
	return {"action": "u13_submission_accepted"}


# The whole hook (world, queues, clocks, events and cursor) commits together.
func run_next_hook() -> Dictionary:
	if _seed.is_empty() or _runtime.completed:
		return Data.invalid("match_hook_unavailable")
	var candidate = _clone()
	if candidate == null:
		return Data.invalid("match_clone_failed")
	var result: Dictionary = candidate._runtime.run_hook(
		candidate.next_hook(), Callable(candidate, "_dispatch")
	)
	if result.action == "invalid":
		return result
	_adopt(candidate)
	# Return an acknowledgement, not the authoritative execution payload.
	return {"action": "u13_match_hook", "next_hook": next_hook(), "round": _runtime.round_number}


func player_view(player_id: int) -> Dictionary:
	if player_id not in [0, 1] or _seed.is_empty():
		return Data.invalid("viewer_invalid")
	# While choosing, both players see the same pre-submission world.
	var choosing: bool = next_hook() == Timeline.SUBMISSION_LOCK
	var visible_world: Dictionary = _presentation_world if choosing else _world
	var projection = _projector.call(visible_world.duplicate(true), player_id)
	if typeof(projection) != TYPE_DICTIONARY or not Data.is_data(projection):
		return Data.invalid("world_projection_invalid")
	return {
		"action": "u13_player_view",
		"round": _runtime.round_number,
		"next_hook": next_hook(),
		"submitted": _submissions[player_id] != null,
		"world": Data.copy_data(projection),
		"events": _events.for_player(player_id),
		"pending": _pending.public_state(),
		"persistent": _persistent.public_state(),
		"cooldowns": _cooldowns.public_state()
	}


# Server/save/replay only. Never expose this envelope as a player view.
func snapshot() -> Dictionary:
	return {
		"schema_version": VERSION,
		"engine_version": ENGINE_VERSION,
		"policy_id": _policy_id,
		"rules_hash": JSON.stringify(_rules, "", true).sha256_text(),
		"rng_version": Rng.VERSION,
		"seed": _seed,
		"world": _world.duplicate(true),
		"presentation_world": _presentation_world.duplicate(true),
		"submissions": _submissions.duplicate(true),
		"player_order": _order.duplicate(),
		"runtime": _runtime.snapshot(),
		"pending": _pending.snapshot(),
		"persistent": _persistent.snapshot(),
		"cooldowns": _cooldowns.snapshot(),
		"events": _events.snapshot()
	}


func restore(raw: Dictionary) -> Dictionary:
	if not _configuration_valid() or not Data.is_data(raw):
		return Data.invalid("match_snapshot_invalid")
	if (
		raw.get("schema_version") != VERSION
		or raw.get("engine_version") != ENGINE_VERSION
		or raw.get("rng_version") != Rng.VERSION
	):
		return Data.invalid("match_version_mismatch")
	if (
		raw.get("policy_id") != _policy_id
		or raw.get("rules_hash") != JSON.stringify(_rules, "", true).sha256_text()
	):
		return Data.invalid("match_policy_mismatch")
	if typeof(raw.get("seed")) != TYPE_STRING or raw.seed.is_empty():
		return Data.invalid("match_seed_invalid")
	var decoded: Dictionary = Data.copy_data(raw)
	for key in [
		"world", "presentation_world", "runtime", "pending", "persistent", "cooldowns", "events"
	]:
		if typeof(decoded.get(key)) != TYPE_DICTIONARY:
			return Data.invalid("match_snapshot_invalid")
	if (
		typeof(decoded.get("player_order")) != TYPE_ARRAY
		or not Data.valid_player_order(decoded.player_order)
		or typeof(decoded.get("submissions")) != TYPE_ARRAY
		or decoded.submissions.size() != 2
	):
		return Data.invalid("match_snapshot_invalid")
	for key in ["round", "next_hook_index"]:
		if not Data.is_integer(decoded.runtime.get(key)):
			return Data.invalid("match_runtime_invalid")
	if typeof(decoded.runtime.get("completed")) != TYPE_BOOL:
		return Data.invalid("match_runtime_invalid")
	var candidate = _new_owner()
	if (
		candidate._install_world(decoded.presentation_world).action == "invalid"
		or candidate._install_world(decoded.world).action == "invalid"
	):
		return Data.invalid("match_world_invalid")
	for pair in [
		[candidate._runtime, "runtime"],
		[candidate._pending, "pending"],
		[candidate._persistent, "persistent"],
		[candidate._cooldowns, "cooldowns"],
		[candidate._events, "events"]
	]:
		if pair[0].restore(decoded[pair[1]]).action == "invalid":
			return Data.invalid("match_component_invalid_" + pair[1])
	candidate._seed = decoded.seed
	candidate._order = decoded.player_order
	candidate._presentation_world = decoded.presentation_world
	candidate._submissions = decoded.submissions
	if not candidate._consistent():
		return Data.invalid("match_snapshot_inconsistent")
	_adopt(candidate)
	return {"action": "u13_match_restored"}


func _accept(player_id: int, declarations: Array) -> Dictionary:
	if not Data.is_data(declarations):
		return Data.invalid("submission_data_invalid")
	for index in range(declarations.size()):
		var source: Dictionary = Data.declaration_copy(declarations[index])
		if (
			source.is_empty()
			or source.player_id != player_id
			or source.queue_index != index
			or source.declaration_id != declaration_id(player_id, _runtime.round_number, index)
		):
			return Data.invalid("submission_identity_invalid")
		if not _rules.has(source.power_id):
			return Data.invalid("unknown_power")
		var rule: Dictionary = _rules[source.power_id]
		for active in _persistent.snapshot().active:
			if active.declaration.player_id == player_id and active.effect_key == source.power_id:
				return Data.invalid("persistent_power_already_active")
		# Both players choose against the presented round state. Only this
		# player's staged resource budget changes across its own queue.
		var legality_world: Dictionary = _presentation_world.duplicate(true)
		legality_world.players[player_id].resources = _world.players[player_id].resources.duplicate(
			true
		)
		var checked: Dictionary = Legality.declaration(
			source,
			rule,
			legality_world,
			_runtime.round_number,
			_cooldowns,
			_entities,
			_validators[source.power_id]
		)
		if checked.action == "invalid":
			return checked
		var discard_count: int = int(rule.get("discard_count", 0))
		if discard_count > 0:
			var selected = source.cost.get("discard_ids")
			if not Cards.can_discard(_world, player_id, selected, discard_count):
				return Data.invalid("discard_payment_invalid")
			Cards.discard(_world, player_id, selected)
			_entities.restore(_world.entities)
			_record(
				{
					"type": "CARDS_DISCARDED",
					"text": "",
					"data":
					{
						"player_id": player_id,
						"card_ids": selected.duplicate(),
						"declaration_id": source.declaration_id
					}
				},
				source
			)
		var registered: Dictionary
		if rule.cooldown_on == "expiration":
			registered = _cooldowns.wait_for_expiration(
				source,
				rule.cooldown_rounds,
				Data.instance_id("persistent", source.declaration_id, source.power_id)
			)
		else:
			registered = _cooldowns.start_on_activation(source, rule.cooldown_rounds)
		if registered.action == "invalid":
			return registered
		for resource in rule.cost:
			_world.players[player_id].resources[resource] = (
				_world.players[player_id].resources.get(resource, 0) - rule.cost[resource]
			)
		var scheduled: Dictionary = _pending.schedule(source)
		if scheduled.action == "invalid":
			return scheduled
		var record: Dictionary = Data.make_record("pending", source, "main", {}, {})
		_record(Data.event("POWER_DECLARED", record), source)
		for event in registered.events:
			_record(event, source)
	return {"action": "legal"}


func _dispatch(_context: Dictionary) -> Dictionary:
	var hook: String = next_hook()
	var round_number: int = _runtime.round_number
	if hook == Timeline.SUBMISSION_LOCK:
		if _submissions[0] == null or _submissions[1] == null:
			return Data.invalid("both_submissions_required")
		for player_id in _order:
			var accepted: Dictionary = _accept(player_id, _submissions[player_id])
			if accepted.action == "invalid":
				return accepted
	if hook == Timeline.PERSISTENT_ADVANCEMENT:
		var before: Array = _persistent.snapshot().active
		var advanced: Dictionary = _persistent.advance(round_number, hook)
		if advanced.action == "invalid":
			return advanced
		for event in advanced.events:
			var source: Dictionary = _source_for(event.data.effect_id, before)
			_record(event, source)
			if event.type == "PERSISTENT_EFFECT_EXPIRED":
				var delivered: Dictionary = _cooldowns.accept_expiration(event)
				if delivered.action == "invalid":
					return delivered
				for clock_event in delivered.events:
					_record(clock_event, source)
		var clock_before: Array = _cooldowns.snapshot().locks
		var clock: Dictionary = _cooldowns.advance(round_number, hook)
		if clock.action == "invalid":
			return clock
		for event in clock.events:
			_record(event, _source_for(event.data.effect_id, clock_before))
	var due: Dictionary = _pending.due_effects(round_number, hook, _order)
	if due.action == "invalid":
		return due
	var resolved: Dictionary = _pending.resolve_hook(
		round_number, hook, _order, Callable(self, "_resolve")
	)
	if resolved.action == "invalid":
		return resolved
	for event in resolved.events:
		_record(event, _source_for(event.data.effect_id, due.effects))
	# Ordinary rules (combat, Banishment, etc.) enter as a versioned pure transform.
	var transformed
	if _context_hook.is_valid():
		transformed = _context_hook.call(
			{
				"hook": hook,
				"round": round_number,
				"seed": _seed,
				"player_order": _order.duplicate(),
				"world": _world.duplicate(true)
			}
		)
	else:
		transformed = _hook_handler.call(hook, round_number, _world.duplicate(true))
	var applied: Dictionary = _apply_transform(transformed)
	if applied.action == "invalid":
		return applied
	if hook == Timeline.PRESENT_PUBLIC_STATE:
		_presentation_world = _world.duplicate(true)
	return {"action": "u13_dispatched"}


func _resolve(record: Dictionary) -> Dictionary:
	var source: Dictionary = record.declaration
	if not _rules.has(source.power_id):
		return Data.invalid("resolver_power_missing")
	var rule: Dictionary = _rules[source.power_id]
	var checked: Dictionary = Legality.firing(
		source, rule, _world, _entities, _validators[source.power_id]
	)
	if checked.action == "fizzle":
		if record.effect_key == "main" and rule.cooldown_on == "expiration":
			var clock: Dictionary = _cooldowns.fizzle_waiting(source, _runtime.round_number)
			if clock.action == "invalid":
				return clock
			for event in clock.events:
				_record(event, source)
		return checked
	if checked.action == "invalid":
		return checked
	var context: Dictionary = {
		"world": _world.duplicate(true),
		"seed": _seed,
		"round": _runtime.round_number,
		"rng_version": Rng.VERSION
	}
	var transformed = _resolvers[source.power_id].call(record.duplicate(true), context)
	var applied: Dictionary = _apply_transform(transformed, source)
	if applied.action == "invalid":
		return applied
	if record.effect_key == "main" and not rule.stages.is_empty():
		var started: Dictionary = _persistent.activate(
			source, source.power_id, rule.stages, {}, {}, _runtime.round_number
		)
		if started.action == "invalid":
			return started
		for event in started.events:
			_record(event, source)
	return {"action": "resolved"}


func _apply_transform(result, source: Dictionary = {}) -> Dictionary:
	if (
		typeof(result) != TYPE_DICTIONARY
		or not Data.is_data(result)
		or result.get("action") != "resolved"
	):
		return Data.invalid("transform_contract_error")
	if typeof(result.get("world")) != TYPE_DICTIONARY or typeof(result.get("events")) != TYPE_ARRAY:
		return Data.invalid("transform_contract_error")
	var previous_used: Array = _entities.snapshot().used_ids
	var previous_active: Dictionary = {}
	for row in _entities.snapshot().entities:
		previous_active[row.id] = true
	var installed: Dictionary = _install_world(result.world)
	if installed.action == "invalid":
		return installed
	var installed_ids: Dictionary = _entities.snapshot()
	for row in installed_ids.entities:
		if row.id in previous_used and not previous_active.has(row.id):
			return Data.invalid("retired_entity_resurrected")
	for entity_id in previous_used:
		if entity_id not in installed_ids.used_ids:
			return Data.invalid("entity_history_rewritten")
	for event in result.events:
		if source.is_empty():
			# Ordinary-hook events must supply explicit views; no default leak.
			if (
				typeof(event) != TYPE_DICTIONARY
				or typeof(event.get("event")) != TYPE_DICTIONARY
				or typeof(event.get("views")) != TYPE_ARRAY
			):
				return Data.invalid("transform_event_views_required")
			if _events.append(event.event, event.views).action == "invalid":
				return Data.invalid("transform_event_invalid")
		else:
			if not EventLog._valid_event(event):
				return Data.invalid("transform_event_invalid")
			_record(event, source)
	return {"action": "resolved"}


func _record(event: Dictionary, source: Dictionary = {}) -> void:
	# Hidden events are omitted entirely; the pending view separately reveals due
	# round/hook. Revealing a completed Price later requires an explicit policy.
	var hidden: bool = source.is_empty() or source.get("visibility") != "public"
	_events.append(event, [null, null] if hidden else [event, event])


func _install_world(raw: Dictionary) -> Dictionary:
	if (
		not Data.is_data(raw)
		or typeof(raw.get("players")) != TYPE_ARRAY
		or raw.players.size() != 2
		or typeof(raw.get("entities")) != TYPE_DICTIONARY
		or typeof(raw.get("data")) != TYPE_DICTIONARY
	):
		return Data.invalid("world_data_invalid")
	var candidate = Entities.new()
	if candidate.restore(raw.entities).action == "invalid":
		return Data.invalid("world_entities_invalid")
	for player_id in [0, 1]:
		var player = raw.players[player_id]
		if (
			typeof(player) != TYPE_DICTIONARY
			or typeof(player.get("lord_id")) != TYPE_STRING
			or typeof(player.get("lord_entity_id")) != TYPE_STRING
			or typeof(player.get("resources")) != TYPE_DICTIONARY
		):
			return Data.invalid("world_player_invalid")
		var lord: Dictionary = candidate.get_entity(player.lord_entity_id)
		if (
			lord.is_empty()
			or lord.kind != "lord"
			or lord.owner != player_id
			or lord.attributes.get("lord_id") != player.lord_id
			or typeof(lord.attributes.get("alive")) != TYPE_BOOL
		):
			return Data.invalid("world_lord_invalid")
		for amount in player.resources.values():
			if not Data.is_integer(amount) or amount < 0:
				return Data.invalid("world_resources_invalid")
	if raw.data.has("card_zones") and not Cards.valid(raw):
		return Data.invalid("world_card_zones_invalid")
	if _world_validator.is_valid():
		var accepted = _world_validator.call(Data.copy_data(raw))
		if typeof(accepted) != TYPE_BOOL or not accepted:
			return Data.invalid("content_world_invalid")
	_world = Data.copy_data(raw)
	_entities = candidate
	return {"action": "u13_world_installed"}


func _consistent() -> bool:
	var current: int = _runtime.round_number
	var expected: int = (
		current
		if _runtime.next_hook_index > Timeline.hook_rank(Timeline.PERSISTENT_ADVANCEMENT)
		else current - 1
	)
	if _cooldowns.snapshot().round != expected or _persistent.snapshot().advanced_round != expected:
		return false
	for player_id in [0, 1]:
		var submission = _submissions[player_id]
		if submission == null:
			if _runtime.next_hook_index > Timeline.hook_rank(Timeline.SUBMISSION_LOCK):
				return false
			continue
		if (
			typeof(submission) != TYPE_ARRAY
			or _runtime.next_hook_index < Timeline.hook_rank(Timeline.SUBMISSION_LOCK)
		):
			return false
		for index in range(submission.size()):
			var source: Dictionary = Data.declaration_copy(submission[index])
			if (
				source.is_empty()
				or source.player_id != player_id
				or source.queue_index != index
				or source.declared_round != current
				or source.declaration_id != declaration_id(player_id, current, index)
				or not _source_matches_rule(source)
			):
				return false
	var pending_rows: Array = _pending.snapshot().pending
	var persistent_rows: Array = _persistent.snapshot().active
	for row in pending_rows + persistent_rows + _cooldowns.snapshot().locks:
		if not _source_matches_rule(row.declaration) or row.declaration.declared_round > current:
			return false
	for clock in _cooldowns.snapshot().locks:
		if clock.phase == Cooldowns.WAITING:
			var bound: bool = false
			for row in persistent_rows:
				bound = bound or row.effect_id == clock.persistent_effect_id
			for row in pending_rows:
				bound = (
					bound
					or (
						row.effect_key == "main"
						and row.declaration.declaration_id == clock.declaration.declaration_id
					)
				)
			if not bound:
				return false
	return true


func _source_matches_rule(source: Dictionary) -> bool:
	if not _rules.has(source.power_id):
		return false
	var rule: Dictionary = _rules[source.power_id]
	var fire_round: int = source.declared_round if source.fire_round == -1 else source.fire_round
	return (
		source.lord_id == rule.lord_id
		and source.visibility == rule.visibility
		and Legality.cost_matches(source, rule)
		and source.fire_hook == rule.fire_hook
		and fire_round == source.declared_round + int(rule.delay_rounds)
	)


func _configuration_valid() -> bool:
	if (
		_policy_id.is_empty()
		or not _projector.is_valid()
		or (not _hook_handler.is_valid() and not _context_hook.is_valid())
		or not Data.is_data(_rules)
	):
		return false
	for power_id in _rules:
		if (
			typeof(_rules[power_id]) != TYPE_DICTIONARY
			or not Legality.validate_rule(_rules[power_id])
		):
			return false
		if (
			typeof(_validators.get(power_id)) != TYPE_CALLABLE
			or not _validators[power_id].is_valid()
			or typeof(_resolvers.get(power_id)) != TYPE_CALLABLE
			or not _resolvers[power_id].is_valid()
		):
			return false
	return true


func _new_owner():
	return get_script().new(
		_policy_id,
		_rules,
		_validators,
		_resolvers,
		_projector,
		_hook_handler,
		_context_hook,
		_content_owner,
		_world_validator
	)


func _clone():
	var candidate = _new_owner()
	if candidate.restore(snapshot()).action == "invalid":
		return null
	return candidate


func _adopt(candidate) -> void:
	_seed = candidate._seed
	_world = candidate._world
	_presentation_world = candidate._presentation_world
	_submissions = candidate._submissions
	_order = candidate._order
	_runtime = candidate._runtime
	_pending = candidate._pending
	_persistent = candidate._persistent
	_cooldowns = candidate._cooldowns
	_entities = candidate._entities
	_events = candidate._events


static func _source_for(effect_id: String, records: Array) -> Dictionary:
	for record in records:
		if record.effect_id == effect_id:
			return record.declaration
	return {}
