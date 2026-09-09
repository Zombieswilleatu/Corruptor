class_name U13SpatialQueries
extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Space = preload("res://Scripts/Sim/U13SpatialSpace.gd")
var _rows: Array = []
var _captured: bool = false


# Ephemeral read model. Capture once at the authoritative hook/tick that needs
# queries; recapture after movement, spawn, death or allegiance mutation.
# Never persist this alongside the registry or use it as a second authority.
func capture(registry_snapshot: Dictionary) -> Dictionary:
	var registry = Ids.new()
	if registry.restore(registry_snapshot).action == "invalid":
		return Data.invalid("spatial_registry_invalid")
	var next_rows: Array = []
	for row in registry.snapshot().entities:
		if row.kind != "marcher":
			continue
		var attributes: Dictionary = row.attributes
		var point: Dictionary = Space.position(
			{"x_fp": attributes.get("x_fp"), "y_fp": attributes.get("y_fp")}
		)
		if point.is_empty() or Space.lane_region(attributes.get("lane")).is_empty():
			return Data.invalid("spatial_marcher_position_invalid")
		if not Data.is_integer(attributes.get("hp")) or attributes.hp < 1:
			return Data.invalid("spatial_marcher_life_invalid")
		next_rows.append(
			{"id": row.id, "owner": row.owner, "lane": attributes.lane, "field_position": point}
		)
	# Registry snapshot is already sorted by stable ID, irrespective of insertion.
	_rows = next_rows
	_captured = true
	return {"action": "u13_spatial_captured", "count": _rows.size()}


# owner_filter -2 = any, -1 = neutral, 0/1 = current allegiance.
# All membership queries return IDs in stable ID order, including edge contact.
func members(raw_region, owner_filter: Variant = -2, padding_fp: Variant = 0) -> Dictionary:
	var area: Dictionary = Space.region(raw_region)
	if (
		not _captured
		or area.is_empty()
		or not _valid_owner(owner_filter)
		or not Space.valid_radius(padding_fp)
	):
		return Data.invalid("spatial_query_invalid")
	var ids: Array = []
	for row in _rows:
		if row.lane != area.lane or (owner_filter != -2 and row.owner != owner_filter):
			continue
		if Space._contains(area, row.field_position, int(padding_fp)):
			ids.append(row.id)
	return {"action": "u13_spatial_members", "ids": ids}


# Explicit distance ordering for mechanics that require it. Ties use ID.
# A valid empty query has id="" and distance_squared_fp=-1.
func nearest(raw_region, raw_origin, owner_filter: Variant = -2) -> Dictionary:
	var area: Dictionary = Space.region(raw_region)
	var origin: Dictionary = Space.position(raw_origin)
	if not _captured or area.is_empty() or origin.is_empty() or not _valid_owner(owner_filter):
		return Data.invalid("spatial_query_invalid")
	var best_id: String = ""
	var best_distance: int = -1
	for row in _rows:
		if row.lane != area.lane or (owner_filter != -2 and row.owner != owner_filter):
			continue
		if not Space._contains(area, row.field_position):
			continue
		var distance: int = Space._distance_squared(origin, row.field_position)
		if best_distance < 0 or distance < best_distance:
			best_distance = distance
			best_id = row.id
	return {"action": "u13_spatial_nearest", "id": best_id, "distance_squared_fp": best_distance}


static func _valid_owner(raw) -> bool:
	return Data.is_integer(raw) and raw in [-2, -1, 0, 1]
