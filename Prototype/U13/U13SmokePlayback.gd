class_name U13SmokePlayback
extends RefCounted

# Presentation only. These frames never flow back into U13Match or its saves.
# Clashes/HP/Armor/deaths come from the resolved event tape. Movement between
# captured endpoints is visual interpolation, independent of frame rate.
const MOVE_SECONDS: float = 6.0
const EXCHANGE_SECONDS: float = 0.24
var duration: float = 0.0
var round_number: int = 0
var _frames: Array = []
var _spatial: bool = false


func build(events: Array) -> bool:
	_frames = []
	_spatial = false
	duration = 0.0
	round_number = 0
	var started: Dictionary = {}
	var finished: Dictionary = {}
	for event in events:
		if event.type == "MARCHING_STARTED":
			started = event.data
		elif event.type == "MARCHING_FINISHED":
			finished = event.data
	if started.is_empty() or finished.is_empty():
		return false
	if started.get("model", "") == "U13_MARCHING_SPATIAL_V2":
		return _build_spatial(events, started, finished)
	round_number = int(started.round)
	var units: Dictionary = {}
	for unit in started.units:
		units[unit.id] = unit.duplicate(true)
	_append(units, "Marching begins", [])
	var previous_tick: int = 0
	for event in events:
		if event.type not in ["MARCHER_CLASH", "MARCHER_WAITING"]:
			continue
		var details: Dictionary = event.data
		var tick: int = int(details.tick) + 1
		var delta_ticks: int = maxi(0, tick - previous_tick)
		_advance_picture(units, delta_ticks, int(started.round))
		duration += MOVE_SECONDS * float(delta_ticks) / float(started.ticks)
		previous_tick = tick
		if event.type == "MARCHER_WAITING":
			if units.has(details.entity_id):
				units[details.entity_id].attributes.x_fp = details.x_fp
				units[details.entity_id].attributes.waiting = true
			_append(units, "A Marcher reaches the gate and waits", [])
			continue
		var fighters: Array = []
		for source in details.units:
			fighters.append(source.id)
			units[source.id] = source.duplicate(true)
			units[source.id].attributes.x_fp = details.x_fp
		_append(units, "Contact in the " + String(details.lane) + " lane", fighters)
		var exchange_index: int = 0
		for exchange in details.exchanges:
			duration += EXCHANGE_SECONDS
			for index in range(fighters.size()):
				units[fighters[index]].attributes.hp = exchange.hp[index]
				units[fighters[index]].attributes.armor = exchange.armor[index]
			exchange_index += 1
			_append(units, "Exchange %d: both attacks land" % exchange_index, fighters)
		duration += 0.3
		for entity_id in fighters:
			if units[entity_id].attributes.hp == 0:
				units.erase(entity_id)
		_append(units, "Clash resolved", [])
	var remaining: int = maxi(0, int(started.ticks) - previous_tick)
	duration += MOVE_SECONDS * float(remaining) / float(started.ticks)
	# Finish at the exact recorded state, never a reconstructed simulation result.
	units = {}
	for unit in finished.units:
		units[unit.id] = unit.duplicate(true)
	_append(units, "Marching complete", [])
	return true


func sample(seconds: float) -> Dictionary:
	if _frames.is_empty():
		return {"units": [], "caption": "", "clash": []}
	var at: float = clampf(seconds, 0.0, duration)
	var index: int = 0
	while index + 1 < _frames.size() and float(_frames[index + 1].at) <= at:
		index += 1
	var left: Dictionary = _frames[index]
	var right: Dictionary = _frames[mini(index + 1, _frames.size() - 1)]
	var span: float = float(right.at) - float(left.at)
	var weight: float = clampf((at - float(left.at)) / span, 0.0, 1.0) if span > 0 else 0.0
	var right_units: Dictionary = {}
	for unit in right.units:
		right_units[unit.id] = unit
	var result: Array = left.units.duplicate(true)
	for unit in result:
		var ending: Dictionary = right_units.get(unit.id, unit)
		# Keep fractional visual positions out of the simulation's *_fp fields.
		if _spatial:
			unit.attributes["visual_y"] = lerpf(
				float(unit.attributes.y_fp), float(ending.attributes.y_fp), weight
			)
		unit.attributes["visual_x"] = lerpf(
			float(unit.attributes.x_fp), float(ending.attributes.x_fp), weight
		)
	return {"units": result, "caption": left.caption, "clash": left.clash.duplicate()}


func final_units() -> Array:
	return [] if _frames.is_empty() else _frames.back().units.duplicate(true)


func _append(units: Dictionary, caption: String, clash: Array) -> void:
	var ids: Array = units.keys()
	ids.sort()
	var rows: Array = []
	for entity_id in ids:
		rows.append(units[entity_id].duplicate(true))
	_frames.append({"at": duration, "units": rows, "caption": caption, "clash": clash.duplicate()})


static func _advance_picture(units: Dictionary, ticks: int, round_number: int) -> void:
	for unit in units.values():
		var a: Dictionary = unit.attributes
		if a.waiting or a.movement_ready_round > round_number:
			continue
		a.x_fp = clampi(int(a.x_fp) + int(a.direction) * int(a.step_fp) * ticks, 0, 2400)


func _build_spatial(events: Array, started: Dictionary, finished: Dictionary) -> bool:
	_spatial = true
	round_number = int(started.round)
	var units: Dictionary = {}
	for unit in started.units:
		units[unit.id] = unit.duplicate(true)
	_append(units, "Marching begins", [])
	var expected_tick: int = 0
	for event in events:
		if event.type != "MARCHING_TICK":
			continue
		var details: Dictionary = event.data
		if int(details.tick) != expected_tick:
			_frames = []
			return false
		expected_tick += 1
		duration = MOVE_SECONDS * float(expected_tick) / float(started.ticks)
		units = {}
		for unit in details.units:
			units[unit.id] = unit.duplicate(true)
		_append(
			units,
			"Contact queue — duel in progress" if not details.clash.is_empty() else "Marching",
			details.clash
		)
	if expected_tick != int(started.ticks):
		_frames = []
		return false
	units = {}
	for unit in finished.units:
		units[unit.id] = unit.duplicate(true)
	_append(units, "Marching complete", [])
	return true
