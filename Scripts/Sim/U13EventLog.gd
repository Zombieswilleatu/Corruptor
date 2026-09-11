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
	var owned: Dictionary = Data.copy_data(event)
	var copied_views: Array = []
	for index in range(views.size()):
		var view = views[index]
		if view == null:
			copied_views.append(null)
		elif is_same(view, event):
			# Exact same input object: already validated and normalized above.
			copied_views.append(owned)
		elif index == 1 and is_same(view, views[0]):
			copied_views.append(copied_views[0])
		else:
			if not _valid_event(view):
				return Data.invalid("event_view_invalid")
			copied_views.append(Data.copy_data(view))
	_rows.append({"event": owned, "views": copied_views})
	return {"action": "u13_event_recorded"}


func for_player(player_id: int, from_row: int = 0, max_events: int = -1) -> Array:
	var result: Array = []
	if player_id not in [0, 1]:
		return result
	var first: int = clampi(from_row, 0, _rows.size())
	# Tail limits count visible events, not authoritative rows: hidden entries
	# cannot displace a visible event from a player's history summary.
	if max_events >= 0:
		if max_events == 0:
			return result
		var remaining: int = max_events
		for index in range(_rows.size() - 1, first - 1, -1):
			if _rows[index].views[player_id] != null:
				remaining -= 1
				if remaining == 0:
					first = index
					break
	for index in range(first, _rows.size()):
		var row: Dictionary = _rows[index]
		if row.views[player_id] != null:
			result.append(row.views[player_id].duplicate(true))
	return result


func snapshot() -> Dictionary:
	return {"schema_version": VERSION, "rows": _rows.duplicate(true)}


func restore(raw: Dictionary) -> Dictionary:
	if not Data.is_data(raw):
		return Data.invalid("event_snapshot_invalid")
	return _restore_owned(Data.copy_data(raw))


# Internal ownership transfer only: caller has validated the ENTIRE envelope
# with is_data and normalized/deep-copied it with copy_data. Match.restore
# already performs these steps, including history, before reaching this method.
# Keep structural checks and atomic installation; never expose owned rows.
func _restore_owned(raw: Dictionary) -> Dictionary:
	if raw.get("schema_version") != VERSION or typeof(raw.get("rows")) != TYPE_ARRAY:
		return Data.invalid("event_snapshot_invalid")
	var rows: Array = []
	for row in raw.rows:
		if typeof(row) != TYPE_DICTIONARY or not _valid_event_shape(row.get("event")) or typeof(row.get("views")) != TYPE_ARRAY or row.views.size() != 2:
			return Data.invalid("event_snapshot_invalid")
		for view in row.views:
			if view != null and not _valid_event_shape(view):
				return Data.invalid("event_snapshot_invalid")
		rows.append({"event": row.event, "views": row.views})
	_rows = rows
	return {"action": "u13_events_restored"}


static func _valid_event(event) -> bool:
	return _valid_event_shape(event) and Data.is_data(event)


static func _valid_event_shape(event) -> bool:
	return (
		typeof(event) == TYPE_DICTIONARY
		and typeof(event.get("type")) == TYPE_STRING
		and not event.type.is_empty()
		and typeof(event.get("text")) == TYPE_STRING
		and typeof(event.get("data")) == TYPE_DICTIONARY
	)


# Stored rows are immutable: append() owns its data; every public read returns
# deep copies; restore() replaces the list. Fork only the private outer array.
# Sharing immutable past rows avoids recopying every tick payload per hook.
func _fork():
	var candidate = get_script().new()
	candidate._rows = _rows.duplicate()
	return candidate


# Internal owner cursor; never a player-visible count of hidden events.
func _cursor() -> int:
	return _rows.size()


# Filter the player's projection BEFORE copying. Board feedback must not copy
# the dense Marching tape or inspect authoritative/hidden event payloads.
func selected_for_player(
	player_id: int, from_row: int, types: Array, excluded_hook: String = ""
) -> Array:
	var result: Array = []
	if player_id not in [0, 1]:
		return result
	for index in range(clampi(from_row, 0, _rows.size()), _rows.size()):
		var view = _rows[index].views[player_id]
		if view == null or view.type not in types:
			continue
		if not excluded_hook.is_empty() and view.data.get("hook", "") == excluded_hook:
			continue
		result.append(view.duplicate(true))
	return result
