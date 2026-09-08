class_name U13PersistentEffects
extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const SCHEMA_VERSION: String = "U13_PERSISTENT_EFFECTS_V1"

# Stages describe each active round, e.g. Scorch [{intensity:1},
# {intensity:2}, {intensity:1}]. Gameplay pulses/damage belong to their own
# timeline hooks. This registry only owns lifecycle and mutable effect state.
# A persistent effect created in Step 1/2 keeps stage zero for that round.
var _active: Dictionary = {}
var _used_ids: Dictionary = {}
var _advanced_round: int = 0


func activate(
	declaration: Dictionary,
	effect_key: String,
	stages: Array,
	payload: Dictionary = {},
	public_data: Dictionary = {},
	activation_round: int = -1
) -> Dictionary:
	var record: Dictionary = Data.make_record(
		"persistent", declaration, effect_key, payload, public_data
	)
	if record.is_empty() or not _valid_stages(stages):
		return Data.invalid("persistent_effect_data_invalid")
	var source: Dictionary = record.declaration
	var active_round: int = activation_round
	if active_round == -1:
		active_round = source.fire_round if source.fire_round != -1 else source.declared_round
	if not Data.is_integer(active_round) or active_round < source.declared_round:
		return Data.invalid("persistent_activation_round_invalid")
	# Allow creation before this round's Step 2 as well as after it. The
	# conductor owns the actual firing hook; future powers stay pending.
	if _advanced_round > 0 and active_round not in [_advanced_round, _advanced_round + 1]:
		return Data.invalid("persistent_activation_round_invalid")
	if _used_ids.has(record.effect_id):
		return Data.invalid("effect_id_already_used")
	for active in _active.values():
		if active.declaration.player_id == source.player_id and active.effect_key == effect_key:
			return Data.invalid("persistent_slot_occupied")
	record["activated_round"] = active_round
	record["stage_index"] = 0
	record["stages"] = Data.copy_data(stages)
	record["target"] = source.target.duplicate(true)
	_active[record.effect_id] = record
	_used_ids[record.effect_id] = true
	return {
		"action": "u13_persistent_activated",
		"effect": record.duplicate(true),
		"events": [Data.event("PERSISTENT_EFFECT_STARTED", record, {"round": active_round})],
	}


func advance(round_number: int, hook: String) -> Dictionary:
	if (
		hook != Timeline.PERSISTENT_ADVANCEMENT
		or not Data.is_integer(round_number)
		or round_number < 1
	):
		return Data.invalid("persistent_advancement_hook_invalid")
	if _advanced_round > 0 and round_number != _advanced_round + 1:
		return Data.invalid("persistent_advancement_round_out_of_order")
	for record in _active.values():
		# A new registry may be attached at its activation round or the next
		# round's Step 2; it may not silently skip multiple lifecycle stages.
		var age: int = round_number - int(record.activated_round)
		if age < 0 or age > int(record.stage_index) + 1:
			return Data.invalid("persistent_lifecycle_gap")
	var events: Array[Dictionary] = []
	for record: Dictionary in _sorted_records():
		var age: int = round_number - int(record.activated_round)
		if age >= record.stages.size():
			_active.erase(record.effect_id)
			events.append(Data.event("PERSISTENT_EFFECT_EXPIRED", record, {"round": round_number}))
		elif age != record.stage_index:
			_active[record.effect_id]["stage_index"] = age
			var event_details: Dictionary = {"round": round_number, "stage_index": age}
			events.append(Data.event("PERSISTENT_EFFECT_ADVANCED", record, event_details))
	_advanced_round = round_number
	return {"action": "u13_persistent_advanced", "events": events}


func get_effect(effect_id: String) -> Dictionary:
	return _active[effect_id].duplicate(true) if _active.has(effect_id) else {}


func current_stage(effect_id: String) -> Dictionary:
	if not _active.has(effect_id):
		return {}
	var record: Dictionary = _active[effect_id]
	return record.stages[record.stage_index].duplicate(true)


func relocate(effect_id: String, target: Dictionary) -> Dictionary:
	if not _active.has(effect_id) or not Data.is_data(target):
		return Data.invalid("persistent_target_invalid")
	# Original declaration is historical evidence; only the live target moves.
	# Identity, activation round, stages and age remain unchanged.
	_active[effect_id]["target"] = Data.copy_data(target)
	return {"action": "u13_persistent_relocated", "effect": get_effect(effect_id)}


func set_payload(effect_id: String, payload: Dictionary) -> Dictionary:
	if not _active.has(effect_id) or not Data.is_data(payload):
		return Data.invalid("persistent_payload_invalid")
	_active[effect_id]["payload"] = Data.copy_data(payload)
	return {"action": "u13_persistent_updated", "effect": get_effect(effect_id)}


func public_state() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for record: Dictionary in _sorted_records():
		rows.append(Data.public_record(record))
	return rows


func snapshot() -> Dictionary:
	var used: Array = _used_ids.keys()
	used.sort()
	return {
		"schema_version": SCHEMA_VERSION,
		"advanced_round": _advanced_round,
		"active": _sorted_records(),
		"used_ids": used,
	}


func restore(raw: Dictionary) -> Dictionary:
	if not Data.is_data(raw) or raw.get("schema_version") != SCHEMA_VERSION:
		return Data.invalid("persistent_snapshot_invalid")
	if not Data.is_integer(raw.get("advanced_round")) or int(raw.advanced_round) < 0:
		return Data.invalid("persistent_snapshot_round_invalid")
	if typeof(raw.get("active")) != TYPE_ARRAY or typeof(raw.get("used_ids")) != TYPE_ARRAY:
		return Data.invalid("persistent_snapshot_invalid")
	var used: Dictionary = {}
	for effect_id in raw.used_ids:
		if typeof(effect_id) != TYPE_STRING or effect_id.is_empty() or used.has(effect_id):
			return Data.invalid("persistent_snapshot_ids_invalid")
		used[effect_id] = true
	var restored: Dictionary = {}
	var slots: Dictionary = {}
	var restored_round: int = int(raw.advanced_round)
	for row in raw.active:
		var record: Dictionary = Data.record_copy(row, "persistent")
		if record.is_empty():
			return Data.invalid("persistent_snapshot_record_invalid")
		if (
			not Data.is_integer(row.get("activated_round"))
			or not Data.is_integer(row.get("stage_index"))
		):
			return Data.invalid("persistent_snapshot_lifecycle_invalid")
		if not _valid_stages(row.get("stages")) or typeof(row.get("target")) != TYPE_DICTIONARY:
			return Data.invalid("persistent_snapshot_lifecycle_invalid")
		var activation: int = int(row.activated_round)
		var age: int = int(row.stage_index)
		var source: Dictionary = record.declaration
		if activation < source.declared_round or age < 0 or age >= row.stages.size():
			return Data.invalid("persistent_snapshot_lifecycle_invalid")
		if restored_round == 0:
			if age != 0:
				return Data.invalid("persistent_snapshot_lifecycle_invalid")
		elif activation > restored_round + 1 or age != maxi(0, restored_round - activation):
			return Data.invalid("persistent_snapshot_lifecycle_invalid")
		var slot: String = JSON.stringify([source.player_id, record.effect_key])
		if slots.has(slot) or restored.has(record.effect_id) or not used.has(record.effect_id):
			return Data.invalid("persistent_snapshot_ids_invalid")
		slots[slot] = true
		record["activated_round"] = activation
		record["stage_index"] = age
		record["stages"] = Data.copy_data(row.stages)
		record["target"] = Data.copy_data(row.target)
		restored[record.effect_id] = record
	_active = restored
	_used_ids = used
	_advanced_round = restored_round
	return {"action": "u13_persistent_restored"}


func _sorted_records() -> Array[Dictionary]:
	var ids: Array = _active.keys()
	ids.sort()
	var rows: Array[Dictionary] = []
	for effect_id in ids:
		rows.append(_active[effect_id].duplicate(true))
	return rows


static func _valid_stages(stages) -> bool:
	if typeof(stages) != TYPE_ARRAY or stages.is_empty() or not Data.is_data(stages):
		return false
	for stage in stages:
		if typeof(stage) != TYPE_DICTIONARY:
			return false
	return true
