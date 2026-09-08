class_name U13EntityIds
extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const VERSION: String = "U13_ENTITY_IDS_V1"
const KINDS: Array[String] = ["lord", "castle", "card", "marcher"]
var _entities: Dictionary = {}
var _used: Dictionary = {}


# Origin is immutable: setup slot/copy ordinal, or effect ID + spawn ordinal.
# Owner, location, current card role and lifetime state never enter the key.
static func identity(kind: String, origin: String, ordinal: int = 0) -> String:
	if kind not in KINDS or origin.is_empty() or ordinal < 0 or not Data.is_integer(ordinal):
		return ""
	return Data.instance_id("entity_" + kind, origin, str(ordinal))


func create(
	kind: String, origin: String, ordinal: int, owner: int, attributes: Dictionary = {}
) -> Dictionary:
	var entity_id: String = identity(kind, origin, ordinal)
	if entity_id.is_empty() or owner not in [-1, 0, 1] or not Data.is_data(attributes):
		return Data.invalid("entity_data_invalid")
	if _used.has(entity_id):
		return Data.invalid("entity_identity_already_used")
	var row: Dictionary = {
		"id": entity_id,
		"kind": kind,
		"origin": origin,
		"ordinal": ordinal,
		"owner": owner,
		"attributes": Data.copy_data(attributes)
	}
	_entities[entity_id] = row
	_used[entity_id] = true
	return {"action": "u13_entity_created", "entity": row.duplicate(true)}


func get_entity(entity_id: String) -> Dictionary:
	return _entities.get(entity_id, {}).duplicate(true)


func update(entity_id: String, owner: int, attributes: Dictionary) -> Dictionary:
	if not _entities.has(entity_id) or owner not in [-1, 0, 1] or not Data.is_data(attributes):
		return Data.invalid("entity_update_invalid")
	_entities[entity_id].owner = owner
	_entities[entity_id].attributes = Data.copy_data(attributes)
	return {"action": "u13_entity_updated"}


func retire(entity_id: String) -> Dictionary:
	if not _entities.has(entity_id):
		return Data.invalid("entity_missing")
	_entities.erase(entity_id)
	return {"action": "u13_entity_retired"}


func snapshot() -> Dictionary:
	var ids: Array = _entities.keys()
	ids.sort()
	var rows: Array = []
	for entity_id in ids:
		rows.append(_entities[entity_id].duplicate(true))
	var used: Array = _used.keys()
	used.sort()
	return {"schema_version": VERSION, "entities": rows, "used_ids": used}


func restore(raw: Dictionary) -> Dictionary:
	if not Data.is_data(raw) or raw.get("schema_version") != VERSION:
		return Data.invalid("entity_snapshot_invalid")
	if typeof(raw.get("entities")) != TYPE_ARRAY or typeof(raw.get("used_ids")) != TYPE_ARRAY:
		return Data.invalid("entity_snapshot_invalid")
	var decoded: Dictionary = Data.copy_data(raw)
	var candidate = get_script().new()
	for row in decoded.entities:
		if typeof(row) != TYPE_DICTIONARY:
			return Data.invalid("entity_snapshot_invalid")
		for key in ["id", "kind", "origin"]:
			if typeof(row.get(key)) != TYPE_STRING:
				return Data.invalid("entity_snapshot_invalid")
		if not Data.is_integer(row.get("ordinal")) or not Data.is_integer(row.get("owner")):
			return Data.invalid("entity_snapshot_invalid")
		if typeof(row.get("attributes")) != TYPE_DICTIONARY:
			return Data.invalid("entity_snapshot_invalid")
		var result: Dictionary = candidate.create(
			row.kind, row.origin, row.ordinal, row.owner, row.attributes
		)
		if result.action == "invalid" or result.entity.id != row.id:
			return Data.invalid("entity_snapshot_invalid")
	var used: Dictionary = {}
	for entity_id in decoded.used_ids:
		if typeof(entity_id) != TYPE_STRING or entity_id.is_empty() or used.has(entity_id):
			return Data.invalid("entity_snapshot_ids_invalid")
		used[entity_id] = true
	for entity_id in candidate._entities:
		if not used.has(entity_id):
			return Data.invalid("entity_snapshot_ids_invalid")
	_entities = candidate._entities
	_used = used
	return {"action": "u13_entities_restored"}


# Internal copy of already-owned state; external data must still use restore().
func _fork():
	var candidate = get_script().new()
	candidate._entities = _entities.duplicate(true)
	candidate._used = _used.duplicate(true)
	return candidate
