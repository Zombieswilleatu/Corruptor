extends RefCounted

# Private phase working state. External/reaction snapshots enter through Ids'
# validator. Only the bounded integer Marching loop calls update(); publishing
# still passes the match world's validator. No world or public tape aliases it.
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
var _by_id: Dictionary = {}
var _ids: Array = []
var _marcher_rows: Array = []
var _marcher_index: Dictionary = {}
var _used_ids: Array = []


func restore(raw: Dictionary) -> Dictionary:
	var checked = Ids.new()
	var result: Dictionary = checked.restore(raw)
	if result.action == "invalid":
		return result
	var state: Dictionary = checked.snapshot()
	_by_id = {}
	_ids = []
	_marcher_rows = []
	_marcher_index = {}
	_used_ids = state.used_ids
	for unit in state.entities:
		_by_id[unit.id] = unit
		_ids.append(unit.id)
		if unit.kind == "marcher":
			_marcher_index[unit.id] = _marcher_rows.size()
			_marcher_rows.append(unit)
	return result


func get_entity(entity_id: String) -> Dictionary:
	return _by_id.get(entity_id, {}).duplicate(true)


func update(entity_id: String, owner: int, attributes: Dictionary) -> Dictionary:
	if not _by_id.has(entity_id) or _by_id[entity_id].kind != "marcher" or owner not in [0, 1]:
		return Data.invalid("marching_buffer_update_invalid")
	# Replace rows: internal readers may retain the previous tick's version.
	var row: Dictionary = _by_id[entity_id].duplicate()
	row.owner = owner
	row.attributes = attributes.duplicate(true)
	if row.attributes.has("_embolden_percent"):
		for field in preload("res://Scripts/Sim/U13Embolden.gd").FIELDS:
			if row.attributes.has(field): row.attributes[field] = preload("res://Scripts/Sim/U13Embolden.gd").clean(row.attributes[field])
	_by_id[entity_id] = row
	_marcher_rows[_marcher_index[entity_id]] = row
	return {"action": "u13_entity_updated"}


func retire(entity_id: String) -> Dictionary:
	if not _by_id.has(entity_id):
		return Data.invalid("entity_missing")
	_by_id.erase(entity_id)
	if _marcher_index.has(entity_id):
		var index: int = _marcher_index[entity_id]
		_marcher_rows.remove_at(index)
		_marcher_index.erase(entity_id)
		for next in range(index, _marcher_rows.size()):
			_marcher_index[_marcher_rows[next].id] = next
	return {"action": "u13_entity_retired"}


func marchers() -> Array:
	return _marcher_rows.duplicate(true)


# Internal read-only versions. Do not edit a returned row or nested payload;
# use get_entity()/duplicate(true) before editing, and update() to publish.
# Public snapshot/marchers/get_entity continue to return detached deep copies.
func _read_marchers() -> Array:
	# Copy only the collection; update replaces rows so prior reads retain
	# their observed versions. Retirement preserves the remaining ID order.
	return _marcher_rows.duplicate()


func _read_entity(entity_id: String) -> Dictionary:
	return _by_id.get(entity_id, {})


func snapshot() -> Dictionary:
	var rows: Array = []
	for entity_id in _ids:
		if _by_id.has(entity_id):
			rows.append(_by_id[entity_id].duplicate(true))
	return {"schema_version": Ids.VERSION, "entities": rows, "used_ids": _used_ids.duplicate()}
