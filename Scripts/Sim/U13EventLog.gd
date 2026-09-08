class_name U13EventLog
extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const VERSION: String = "U13_EVENT_LOG_V1"
var _rows: Array = []


# Explicit projections, never a blacklist over an authoritative payload.
# A hidden outcome can deliberately have the same minimal view for BOTH players.
func append(event: Dictionary, views: Array) -> Dictionary:
	if not _valid_event(event) or views.size() != 2:
		return Data.invalid("event_data_invalid")
	for view in views:
		if view != null and not _valid_event(view):
			return Data.invalid("event_view_invalid")
	_rows.append({"event": Data.copy_data(event), "views": Data.copy_data(views)})
	return {"action": "u13_event_recorded"}


func for_player(player_id: int) -> Array:
	var result: Array = []
	if player_id not in [0, 1]:
		return result
	for row in _rows:
		if row.views[player_id] != null:
			result.append(row.views[player_id].duplicate(true))
	return result


func snapshot() -> Dictionary:
	return {"schema_version": VERSION, "rows": _rows.duplicate(true)}


func restore(raw: Dictionary) -> Dictionary:
	if (
		not Data.is_data(raw)
		or raw.get("schema_version") != VERSION
		or typeof(raw.get("rows")) != TYPE_ARRAY
	):
		return Data.invalid("event_snapshot_invalid")
	var candidate = get_script().new()
	for row in raw.rows:
		if (
			typeof(row) != TYPE_DICTIONARY
			or typeof(row.get("event")) != TYPE_DICTIONARY
			or typeof(row.get("views")) != TYPE_ARRAY
		):
			return Data.invalid("event_snapshot_invalid")
		if candidate.append(row.event, row.views).action == "invalid":
			return Data.invalid("event_snapshot_invalid")
	_rows = candidate._rows
	return {"action": "u13_events_restored"}


static func _valid_event(event) -> bool:
	return (
		typeof(event) == TYPE_DICTIONARY
		and Data.is_data(event)
		and typeof(event.get("type")) == TYPE_STRING
		and not event.type.is_empty()
		and typeof(event.get("text")) == TYPE_STRING
		and typeof(event.get("data")) == TYPE_DICTIONARY
	)
