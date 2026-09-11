class_name U13SmokePlayback
extends RefCounted

# Presentation only. These frames never flow back into U13Match or its saves.
# Clashes/HP/Armor/deaths come from the resolved event tape. Movement between
# captured endpoints is visual interpolation, independent of frame rate.
const Feedback = preload("res://Prototype/U13/U13MarcherFeedback.gd")
var feedback_rows: Array = []
var death_rows: Array = []
var _death_ids: Dictionary = {}
var _previous_units: Dictionary = {}
var _terminal: Dictionary = {}

const MOVE_SECONDS: float = 6.0
const EXCHANGE_SECONDS: float = 0.24
var duration: float = 0.0
var round_number: int = 0
var _frames: Array = []
var _spatial: bool = false


func build(events: Array) -> bool:
	_frames = []
	feedback_rows = []
	death_rows = []
	_death_ids = {}
	_previous_units = {}
	_terminal = {}
	_spatial = false
	duration = 0.0
	round_number = 0
	var started: Dictionary = {}
	var finished: Dictionary = {}
	for event in events:
		if event.type == "MARCHER_DEFEATED" and event.data.has("hp_after"):
			_terminal[event.data.victim.id] = int(event.data.victim.attributes.armor)
		if event.type == "MARCHER_CLASH" and not event.data.exchanges.is_empty():
			var ending: Dictionary = event.data.exchanges.back()
			for fighter in range(event.data.units.size()):
				if int(ending.hp[fighter]) == 0:
					_terminal[event.data.units[fighter].id] = int(ending.armor[fighter])
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
	for entity_id in _previous_units:
		var before: Dictionary = _previous_units[entity_id]
		var after: Dictionary = units.get(entity_id, {})
		if (after.is_empty() or int(after.attributes.hp) <= 0) and not _death_ids.has(entity_id):
			_death_ids[entity_id] = true
			death_rows.append({"at": duration, "unit": (before if after.is_empty() else after).duplicate(true)})
		var hp: int = int(before.attributes.hp)
		var armor: int = int(before.attributes.armor)
		if not after.is_empty():
			hp = int(after.attributes.hp)
			armor = int(after.attributes.armor)
		elif _terminal.has(entity_id):
			hp = 0
			armor = int(_terminal[entity_id])
		var hp_delta: int = hp - int(before.attributes.hp)
		var armor_delta: int = armor - int(before.attributes.armor)
		if hp_delta != 0 or armor_delta != 0:
			feedback_rows.append(
				Feedback.row(
					after if not after.is_empty() else before, hp_delta, armor_delta, duration
				)
			)
	_previous_units = {}
	var ids: Array = units.keys()
	ids.sort()
	var rows: Array = []
	for entity_id in ids:
		var owned: Dictionary = units[entity_id].duplicate(true)
		rows.append(owned)
		_previous_units[entity_id] = owned
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
	var bases: Dictionary = units.duplicate(true)
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
			if details.get("unit_format", "") == "attribute_delta_v1" and bases.has(unit.id):
				var restored: Dictionary = bases[unit.id].duplicate(true)
				restored.owner = unit.owner
				restored.attributes.merge(unit.attributes, true)
				units[unit.id] = restored
			else:
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


func feedback_through(seconds: float, cursor: int) -> Dictionary:
	var rows: Array = []
	var next: int = clampi(cursor, 0, feedback_rows.size())
	while next < feedback_rows.size() and float(feedback_rows[next].at) <= seconds:
		rows.append(feedback_rows[next].duplicate(true))
		next += 1
	return {"rows": rows, "cursor": next}


# Drain every recorded casualty even when a slow display skips sampled ticks.
func deaths_through(seconds: float, cursor: int) -> Dictionary:
	var rows: Array = []
	var next: int = clampi(cursor, 0, death_rows.size())
	while next < death_rows.size() and float(death_rows[next].at) <= seconds:
		rows.append(death_rows[next])
		next += 1
	return {"rows": rows, "cursor": next}
