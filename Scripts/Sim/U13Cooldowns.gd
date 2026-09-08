class_name U13Cooldowns
extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const SCHEMA_VERSION: String = "U13_COOLDOWNS_V1"
const WAITING: String = "awaiting_expiration"
const COOLING: String = "cooling"

# One registry per U13 match. Step 2 order: advance persistent effects,
# deliver their expiration events here, then advance cooldowns, then submit.
# Eligibility is for the current advanced round only, never a speculative date.
var _round_number: int = 0
var _locks: Dictionary = {}
var _used_ids: Dictionary = {}


func is_ready(player_id: int, lord_id: String, power_id: String) -> bool:
	if _round_number < 1 or player_id not in [0, 1] or lord_id.is_empty() or power_id.is_empty():
		return false
	return not _locks.has(_slot(player_id, lord_id, power_id))


func start_on_activation(declaration: Dictionary, cooldown_rounds: int) -> Dictionary:
	# Activation R3 + one full blocked round R4 = ready at Step 2 of R5.
	# A zero-round cooldown still prevents another activation in the same round.
	return _register(declaration, cooldown_rounds, "")


func wait_for_expiration(
	declaration: Dictionary, cooldown_rounds: int, persistent_effect_id: String
) -> Dictionary:
	# Reserve at declaration/activation so a persistent power cannot be reused
	# while armed or active. Only the bound instance's expiration starts its clock.
	if persistent_effect_id.is_empty():
		return Data.invalid("cooldown_persistent_id_required")
	return _register(declaration, cooldown_rounds, persistent_effect_id)


func _register(declaration: Dictionary, duration: int, persistent_id: String) -> Dictionary:
	var record: Dictionary = Data.make_record("cooldown", declaration, "main", {}, {})
	if record.is_empty() or not Data.is_integer(duration) or duration < 0:
		return Data.invalid("cooldown_data_invalid")
	var source: Dictionary = record.declaration
	if _round_number < 1 or source.declared_round > _round_number:
		return Data.invalid("cooldown_round_invalid")
	if not Data.is_integer(_round_number + duration + 1):
		return Data.invalid("cooldown_duration_overflow")
	if _used_ids.has(record.effect_id):
		return Data.invalid("cooldown_declaration_already_used")
	var slot: String = _slot(source.player_id, source.lord_id, source.power_id)
	if _locks.has(slot):
		return Data.invalid("power_not_ready")
	record["registered_round"] = _round_number
	record["cooldown_rounds"] = duration
	record["persistent_effect_id"] = persistent_id
	record["phase"] = COOLING if persistent_id.is_empty() else WAITING
	record["first_blocked_round"] = _round_number + 1 if persistent_id.is_empty() else 0
	record["ready_round"] = _round_number + duration + 1 if persistent_id.is_empty() else 0
	_locks[slot] = record
	_used_ids[record.effect_id] = true
	var event_type: String = "COOLDOWN_STARTED" if persistent_id.is_empty() else "COOLDOWN_ARMED"
	return {
		"action": "u13_cooldown_registered",
		"cooldown": record.duplicate(true),
		"events": [Data.event(event_type, record, _timing(record))],
	}


func accept_expiration(event: Dictionary) -> Dictionary:
	if not Data.is_data(event) or event.get("type") != "PERSISTENT_EFFECT_EXPIRED":
		return Data.invalid("cooldown_expiration_event_invalid")
	var details = event.get("data")
	if typeof(details) != TYPE_DICTIONARY or typeof(details.get("effect_id")) != TYPE_STRING:
		return Data.invalid("cooldown_expiration_event_invalid")
	var matches: Array[String] = []
	for slot in _locks:
		if _locks[slot].persistent_effect_id == details.effect_id:
			matches.append(slot)
	if matches.is_empty():
		return {"action": "u13_cooldown_expiration_ignored", "events": []}
	if not Data.is_integer(details.get("round")) or int(details.round) != _round_number + 1:
		return Data.invalid("cooldown_expiration_must_precede_advancement")
	# Validate every matching lock before changing any of them.
	for slot: String in matches:
		var record: Dictionary = _locks[slot]
		if record.phase != WAITING:
			return Data.invalid("cooldown_expiration_already_applied")
		if details.get("player_id") != record.declaration.player_id:
			return Data.invalid("cooldown_expiration_owner_mismatch")
		if not Data.is_integer(int(details.round) + int(record.cooldown_rounds)):
			return Data.invalid("cooldown_duration_overflow")
	matches.sort()
	var events: Array[Dictionary] = []
	for slot: String in matches:
		var record: Dictionary = _locks[slot]
		record.phase = COOLING
		record.first_blocked_round = int(details.round)
		record.ready_round = int(details.round) + int(record.cooldown_rounds)
		events.append(Data.event("COOLDOWN_STARTED", record, _timing(record)))
	return {"action": "u13_cooldown_expiration_applied", "events": events}


func fizzle_waiting(declaration: Dictionary, firing_round: int) -> Dictionary:
	var source: Dictionary = Data.declaration_copy(declaration)
	if source.is_empty():
		return Data.invalid("cooldown_declaration_invalid")
	var slot: String = _slot(source.player_id, source.lord_id, source.power_id)
	if not _locks.has(slot) or _locks[slot].declaration.declaration_id != source.declaration_id:
		return Data.invalid("cooldown_lock_missing")
	var record: Dictionary = _locks[slot]
	if (
		record.phase != WAITING
		or firing_round not in [_round_number, _round_number + 1]
		or not Data.is_integer(firing_round + record.cooldown_rounds + 1)
	):
		return Data.invalid("cooldown_fizzle_invalid")
	# No persistent lifetime began. The failed activation still spends its clock.
	record.phase = COOLING
	record.first_blocked_round = firing_round + 1
	record.ready_round = firing_round + record.cooldown_rounds + 1
	return {
		"action": "u13_cooldown_fizzled",
		"events": [Data.event("COOLDOWN_STARTED", record, _timing(record))]
	}


func advance(round_number: int, hook: String) -> Dictionary:
	if (
		hook != Timeline.PERSISTENT_ADVANCEMENT
		or not Data.is_integer(round_number)
		or round_number < 1
	):
		return Data.invalid("cooldown_advancement_invalid")
	if _round_number > 0 and round_number != _round_number + 1:
		return Data.invalid("cooldown_advancement_round_out_of_order")
	var slots: Array = _locks.keys()
	slots.sort()
	var events: Array[Dictionary] = []
	for slot in slots:
		var record: Dictionary = _locks[slot]
		if record.phase == COOLING and record.ready_round <= round_number:
			events.append(Data.event("COOLDOWN_READY", record, {"round": round_number}))
			_locks.erase(slot)
	_round_number = round_number
	return {"action": "u13_cooldowns_advanced", "events": events}


func get_state(player_id: int, lord_id: String, power_id: String) -> Dictionary:
	var slot: String = _slot(player_id, lord_id, power_id)
	return _locks[slot].duplicate(true) if _locks.has(slot) else {}


func public_state() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for record: Dictionary in _records():
		var row: Dictionary = Data.public_record(record)
		# Do not expose the underlying instance/clock for a hidden declaration.
		if record.declaration.visibility == "public":
			row.merge(_timing(record), true)
		rows.append(row)
	return rows


func snapshot() -> Dictionary:
	var used: Array = _used_ids.keys()
	used.sort()
	return {
		"schema_version": SCHEMA_VERSION,
		"round": _round_number,
		"locks": _records(),
		"used_ids": used,
	}


func restore(raw: Dictionary) -> Dictionary:
	if not Data.is_data(raw) or raw.get("schema_version") != SCHEMA_VERSION:
		return Data.invalid("cooldown_snapshot_invalid")
	if not Data.is_integer(raw.get("round")) or int(raw.round) < 0:
		return Data.invalid("cooldown_snapshot_round_invalid")
	if typeof(raw.get("locks")) != TYPE_ARRAY or typeof(raw.get("used_ids")) != TYPE_ARRAY:
		return Data.invalid("cooldown_snapshot_invalid")
	var decoded: Dictionary = Data.copy_data(raw)
	var used: Dictionary = {}
	for effect_id in decoded.used_ids:
		if typeof(effect_id) != TYPE_STRING or effect_id.is_empty() or used.has(effect_id):
			return Data.invalid("cooldown_snapshot_ids_invalid")
		used[effect_id] = true
	var locks: Dictionary = {}
	for row in decoded.locks:
		var record: Dictionary = Data.record_copy(row, "cooldown")
		if (
			record.is_empty()
			or not _valid_clock(row, decoded.round, record.declaration.declared_round)
		):
			return Data.invalid("cooldown_snapshot_clock_invalid")
		for key: String in [
			"registered_round",
			"cooldown_rounds",
			"persistent_effect_id",
			"phase",
			"first_blocked_round",
			"ready_round",
		]:
			record[key] = row[key]
		var source: Dictionary = record.declaration
		var slot: String = _slot(source.player_id, source.lord_id, source.power_id)
		if locks.has(slot) or not used.has(record.effect_id):
			return Data.invalid("cooldown_snapshot_ids_invalid")
		locks[slot] = record
	_locks = locks
	_used_ids = used
	_round_number = decoded.round
	return {"action": "u13_cooldowns_restored"}


static func _valid_clock(row: Dictionary, current_round: int, declared_round: int) -> bool:
	for key: String in [
		"registered_round", "cooldown_rounds", "first_blocked_round", "ready_round"
	]:
		if not Data.is_integer(row.get(key)):
			return false
	if (
		typeof(row.get("persistent_effect_id")) != TYPE_STRING
		or typeof(row.get("phase")) != TYPE_STRING
	):
		return false
	if (
		row.registered_round < declared_round
		or row.registered_round > current_round
		or row.cooldown_rounds < 0
	):
		return false
	if row.phase == WAITING:
		return (
			not row.persistent_effect_id.is_empty()
			and row.first_blocked_round == 0
			and row.ready_round == 0
		)
	if row.phase != COOLING:
		return false
	if (
		row.first_blocked_round <= row.registered_round
		or row.first_blocked_round > current_round + 2
	):
		return false
	if row.persistent_effect_id.is_empty() and row.first_blocked_round != row.registered_round + 1:
		return false
	return (
		row.ready_round == row.first_blocked_round + row.cooldown_rounds
		and row.ready_round > current_round
	)


func _records() -> Array[Dictionary]:
	var slots: Array = _locks.keys()
	slots.sort()
	var rows: Array[Dictionary] = []
	for slot in slots:
		rows.append(_locks[slot].duplicate(true))
	return rows


static func _slot(player_id: int, lord_id: String, power_id: String) -> String:
	return JSON.stringify([player_id, lord_id, power_id])


static func _timing(record: Dictionary) -> Dictionary:
	return {
		"phase": record.phase,
		"first_blocked_round": record.first_blocked_round,
		"ready_round": record.ready_round,
		"cooldown_rounds": record.cooldown_rounds,
	}
