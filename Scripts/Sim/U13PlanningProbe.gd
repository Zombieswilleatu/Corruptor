# Profiling/reference adapter only. Never configured by a playable match.
extends "res://Scripts/Sim/U13Match.gd"

var reference_mode: bool = false
var samples: Array = []
var domains: Array = []


func legal_power_candidates(player_id: int, sources: Array) -> Array:
	var started: int = Time.get_ticks_usec()
	var result: Array = []
	if reference_mode:
		for source in sources:
			if (
				typeof(source) == TYPE_DICTIONARY
				and preview_submission(player_id, [source], {}).action != "invalid"
			):
				result.append(source)
	else:
		result = super.legal_power_candidates(player_id, sources)
	_capture("powers", started, sources.size(), result)
	return result


func legal_order_candidates(player_id: int, declarations: Array, orders: Array) -> Array:
	var started: int = Time.get_ticks_usec()
	var result: Array = (
		_reference_orders(player_id, declarations, orders)
		if reference_mode
		else super.legal_order_candidates(player_id, declarations, orders)
	)
	_capture(
		(
			"castle"
			if (
				not orders.is_empty()
				and orders[0].has("castle_action")
				and not orders[0].has("action")
			)
			else "combat"
		),
		started,
		orders.size(),
		result
	)
	return result


func _capture(stage: String, started: int, count: int, result: Array) -> void:
	samples.append(
		{
			"stage": stage,
			"input": count,
			"legal": result.size(),
			"ms": (Time.get_ticks_usec() - started) / 1000.0
		}
	)
	domains.append(result.duplicate(true))


func _reference_orders(player_id: int, declarations: Array, orders: Array) -> Array:
	if (
		_seed.is_empty()
		or player_id not in [0, 1]
		or next_hook() != Timeline.SUBMISSION_LOCK
		or _submissions[player_id] != null
	):
		return []
	if not _order_screen.is_valid():
		var legacy: Array = []
		for order in orders:
			if (
				typeof(order) == TYPE_DICTIONARY
				and preview_submission(player_id, declarations, order).action != "invalid"
			):
				legacy.append(order)
		return legacy
	var screened: Array = screen_order_candidates(player_id, declarations, orders)
	if screened.is_empty():
		return []
	var baseline = _clone()
	if baseline == null:
		return []
	var result: Array = []
	for order in screened:
		if typeof(order) != TYPE_DICTIONARY:
			continue
		var candidate = baseline._fork_validated()
		if candidate._accept(player_id, declarations, order).action != "invalid":
			result.append(order)
	return result
