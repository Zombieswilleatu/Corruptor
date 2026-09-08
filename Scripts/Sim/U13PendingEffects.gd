class_name U13PendingEffects
extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const SCHEMA_VERSION: String = "U13_PENDING_EFFECTS_V1"

# One authoritative collection per U13 match. The U13 conductor owns hook
# progression; Lords do not poll this queue. Costs are paid by declaration
# validation, never here. Banishment does not implicitly cancel an armed effect.
var _pending: Dictionary = {}
var _used_ids: Dictionary = {}
var _resolving: bool = false
var _resolving_round: int = 0
var _resolving_hook: String = ""


func schedule(
	declaration: Dictionary,
	effect_key: String = "main",
	payload: Dictionary = {},
	public_data: Dictionary = {},
	fire_round: int = -1,
	fire_hook: String = ""
) -> Dictionary:
	var record: Dictionary = Data.make_record(
		"pending", declaration, effect_key, payload, public_data
	)
	if record.is_empty():
		return Data.invalid("effect_data_invalid")
	var source: Dictionary = record.declaration
	var due_round: int = fire_round
	if due_round == -1:
		due_round = source.fire_round if source.fire_round != -1 else source.declared_round
	var due_hook: String = source.fire_hook if fire_hook.is_empty() else fire_hook
	if (
		not Data.is_integer(due_round)
		or due_round < source.declared_round
		or not Timeline.is_valid_hook(due_hook)
	):
		return Data.invalid("effect_schedule_invalid")
	if _used_ids.has(record.effect_id):
		return Data.invalid("effect_id_already_used")
	# Snapshot the hook's due batch. Resolver-created effects must fire later;
	# no insertion into the batch currently being resolved.
	if (
		_resolving
		and (
			due_round < _resolving_round
			or (
				due_round == _resolving_round
				and Timeline.hook_rank(due_hook) <= Timeline.hook_rank(_resolving_hook)
			)
		)
	):
		return Data.invalid("schedule_during_current_or_past_hook")
	record["fire_round"] = due_round
	record["fire_hook"] = due_hook
	_pending[record.effect_id] = record
	_used_ids[record.effect_id] = true
	return {"action": "u13_effect_scheduled", "effect": record.duplicate(true)}


func due_effects(round_number: int, hook: String, player_order: Array) -> Dictionary:
	if round_number < 1 or not Timeline.is_valid_hook(hook):
		return Data.invalid("effect_hook_invalid")
	if not Data.valid_player_order(player_order):
		return Data.invalid("player_order_invalid")
	var due: Array[Dictionary] = []
	for record in _pending.values():
		if (
			record.fire_round < round_number
			or (
				record.fire_round == round_number
				and Timeline.hook_rank(record.fire_hook) < Timeline.hook_rank(hook)
			)
		):
			return Data.invalid("overdue_pending_effect")
		if record.fire_round == round_number and record.fire_hook == hook:
			due.append(record.duplicate(true))
	# Effect class was selected by hook first. Caller supplies authoritative
	# Reflex order, not the old U12 reflex_winner (which now means Momentum).
	# For one player's effects from different submissions: oldest submission
	# first, then its chosen queue order; stable effect ID is the final tie-break.
	due.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var left: Dictionary = a.declaration
			var right: Dictionary = b.declaration
			if left.player_id != right.player_id:
				return player_order.find(left.player_id) < player_order.find(right.player_id)
			if left.declared_round != right.declared_round:
				return left.declared_round < right.declared_round
			if left.queue_index != right.queue_index:
				return left.queue_index < right.queue_index
			return a.effect_id < b.effect_id
	)
	return {"action": "u13_effects_due", "effects": due}


func resolve_hook(
	round_number: int, hook: String, player_order: Array, resolver: Callable
) -> Dictionary:
	if _resolving:
		return Data.invalid("effect_resolution_reentrant")
	var selected: Dictionary = due_effects(round_number, hook, player_order)
	if selected.action == "invalid":
		return selected
	if not selected.effects.is_empty() and not resolver.is_valid():
		return Data.invalid("effect_resolver_required")
	var events: Array[Dictionary] = []
	_resolving = true
	_resolving_round = round_number
	_resolving_hook = hook
	for record: Dictionary in selected.effects:
		# The resolver owns firing legality and game mutations. It must return
		# resolved or fizzle, with no new player choice. An invalid engine result
		# must not have mutated game state; it is NOT a gameplay fizzle.
		var result = resolver.call(record.duplicate(true))
		if not _valid_result(result):
			_resolving = false
			return {
				"action": "invalid",
				"reason": "effect_result_invalid",
				"effect_id": record.effect_id,
				"events": events,
			}
		_pending.erase(record.effect_id)
		var event_type: String = (
			"POWER_RESOLVED" if result.action == "resolved" else "FIZZLE_INVALID_TARGET"
		)
		var event_details: Dictionary = {
			"round": round_number, "hook": hook, "result": Data.copy_data(result),
		}
		events.append(Data.event(event_type, record, event_details))
	_resolving = false
	return {"action": "u13_effects_resolved", "events": events}


func public_state() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for record: Dictionary in _sorted_records():
		var row: Dictionary = Data.public_record(record)
		row["fire_round"] = record.fire_round
		row["fire_hook"] = record.fire_hook
		rows.append(row)
	return rows


func snapshot() -> Dictionary:
	var used: Array = _used_ids.keys()
	used.sort()
	return {"schema_version": SCHEMA_VERSION, "pending": _sorted_records(), "used_ids": used}


func restore(raw: Dictionary) -> Dictionary:
	if _resolving:
		return Data.invalid("restore_during_resolution")
	if not Data.is_data(raw) or raw.get("schema_version") != SCHEMA_VERSION:
		return Data.invalid("pending_snapshot_invalid")
	if typeof(raw.get("pending")) != TYPE_ARRAY or typeof(raw.get("used_ids")) != TYPE_ARRAY:
		return Data.invalid("pending_snapshot_invalid")
	var used: Dictionary = {}
	for effect_id in raw.used_ids:
		if typeof(effect_id) != TYPE_STRING or effect_id.is_empty() or used.has(effect_id):
			return Data.invalid("pending_snapshot_ids_invalid")
		used[effect_id] = true
	var restored: Dictionary = {}
	for row in raw.pending:
		var record: Dictionary = Data.record_copy(row, "pending")
		if record.is_empty():
			return Data.invalid("pending_snapshot_record_invalid")
		if (
			not Data.is_integer(row.get("fire_round"))
			or typeof(row.get("fire_hook")) != TYPE_STRING
		):
			return Data.invalid("pending_snapshot_schedule_invalid")
		if (
			int(row.fire_round) < record.declaration.declared_round
			or not Timeline.is_valid_hook(row.fire_hook)
		):
			return Data.invalid("pending_snapshot_schedule_invalid")
		if restored.has(record.effect_id) or not used.has(record.effect_id):
			return Data.invalid("pending_snapshot_ids_invalid")
		record["fire_round"] = int(row.fire_round)
		record["fire_hook"] = row.fire_hook
		restored[record.effect_id] = record
	# Validate the entire snapshot before replacing live state.
	_pending = restored
	_used_ids = used
	return {"action": "u13_pending_restored"}


func _sorted_records() -> Array[Dictionary]:
	var ids: Array = _pending.keys()
	ids.sort()
	var rows: Array[Dictionary] = []
	for effect_id in ids:
		rows.append(_pending[effect_id].duplicate(true))
	return rows


static func _valid_result(result) -> bool:
	if typeof(result) != TYPE_DICTIONARY or not Data.is_data(result):
		return false
	if result.get("action") == "resolved":
		return true
	return (
		result.get("action") == "fizzle"
		and typeof(result.get("reason")) == TYPE_STRING
		and not result.reason.is_empty()
	)
