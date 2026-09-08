extends RefCounted

# Private phase working state. External/reaction snapshots enter through Ids'
# validator. Only the bounded integer Marching loop calls update(); publishing
# still passes the match world's validator. No world or public tape aliases it.
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
var _by_id: Dictionary = {}
var _ids: Array = []
var _marcher_ids: Array = []
var _used_ids: Array = []


func restore(raw: Dictionary) -> Dictionary:
	var checked = Ids.new()
	var result: Dictionary = checked.restore(raw)
	if result.action == "invalid":
		return result
	var state: Dictionary = checked.snapshot()
	_by_id = {}
	_ids = []
	_marcher_ids = []
	_used_ids = state.used_ids
	for unit in state.entities:
		_by_id[unit.id] = unit
		_ids.append(unit.id)
		if unit.kind == "marcher":
			_marcher_ids.append(unit.id)
	return result


func get_entity(entity_id: String) -> Dictionary:
	return _by_id.get(entity_id, {}).duplicate(true)


func update(entity_id: String, owner: int, attributes: Dictionary) -> Dictionary:
	if not _by_id.has(entity_id) or _by_id[entity_id].kind != "marcher" or owner not in [0, 1]:
		return Data.invalid("marching_buffer_update_invalid")
	_by_id[entity_id].owner = owner
	_by_id[entity_id].attributes = attributes.duplicate(true)
	return {"action": "u13_entity_updated"}


func retire(entity_id: String) -> Dictionary:
	if not _by_id.has(entity_id):
		return Data.invalid("entity_missing")
	_by_id.erase(entity_id)
	return {"action": "u13_entity_retired"}


func marchers() -> Array:
	var rows: Array = []
	for entity_id in _marcher_ids:
		if _by_id.has(entity_id):
			rows.append(_by_id[entity_id].duplicate(true))
	return rows


func snapshot() -> Dictionary:
	var rows: Array = []
	for entity_id in _ids:
		if _by_id.has(entity_id):
			rows.append(_by_id[entity_id].duplicate(true))
	return {"schema_version": Ids.VERSION, "entities": rows, "used_ids": _used_ids.duplicate()}
