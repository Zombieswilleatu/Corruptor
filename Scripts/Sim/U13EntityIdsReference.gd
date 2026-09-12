# Test/profile reference for registry restore before redundant copies were removed.
extends "res://Scripts/Sim/U13EntityIds.gd"

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

