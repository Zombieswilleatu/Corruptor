class_name U13SmokePlayback
extends RefCounted

# Presentation only. These frames never flow back into U13Match or its saves.
# Clashes/HP/Armor/deaths come from the resolved event tape. Movement between
# captured endpoints is visual interpolation, independent of frame rate.
const Feedback = preload("res://Prototype/U13/U13MarcherFeedback.gd")
const FLIGHT_SECONDS: float = 0.18
const BEAM_SECONDS: float = 0.22
const GROUND_BEAM_SECONDS: float = 0.10
const BEAM_BLAST_SECONDS: float = 0.30
const KOPITA_PULSE_SECONDS: float = 0.60
const MUNO_DASH_OUT: float = 0.16
const MUNO_STRIKE_HOLD: float = 0.06
const MUNO_DASH_BACK: float = 0.24
const MUNO_TRAIL_SECONDS: float = 0.16
var projectile_rows: Array = []
var feedback_rows: Array = []
var death_rows: Array = []
var _banished_ids: Dictionary = {}
var _monster_fields: Array = []
var _monster_attacks: Array = []
var _death_ids: Dictionary = {}
var _previous_units: Dictionary = {}
var _terminal: Dictionary = {}

const MOVE_SECONDS: float = 6.0
const EXCHANGE_SECONDS: float = 0.24
var duration: float = 0.0
var round_number: int = 0
var _frames: Array = []
var _spatial: bool = false
var _spatial_ticks: int = 200
var _spatial_lead: float = 0.0


func build(events: Array) -> bool:
	_frames = []
	projectile_rows = []
	feedback_rows = []
	death_rows = []
	_banished_ids = {}
	_monster_fields = []
	_monster_attacks = []
	_death_ids = {}
	_previous_units = {}
	_terminal = {}
	_spatial = false
	_spatial_ticks = 200
	_spatial_lead = 0.0
	duration = 0.0
	round_number = 0
	var started: Dictionary = {}
	var finished: Dictionary = {}
	for event in events:
		if event.type == "MONSTER_BANISHED": _banished_ids[event.data.unit.id] = true
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
	_frames.back()["field_structures"] = finished.get("field_structures", []).duplicate(true)
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
	var status_clock: int = round_number * 200 + clampi(int(floor((at - _spatial_lead) * 200.0 / MOVE_SECONDS)) - 1, 0, 200)
	for unit in result:
		var ending: Dictionary = right_units.get(unit.id, unit)
		if unit.attributes.has("dotra_exposed_until_tick"):
			unit.attributes["visual_exposed"] = preload("res://Scripts/Sim/U13IncomingDamage.gd").active(unit.attributes, status_clock)
		if unit.attributes.has("dotra_shroud_until_tick"):
			unit.attributes["visual_shrouded"] = preload("res://Scripts/Sim/U13DotraShroud.gd").active(unit.attributes, status_clock)
			unit.attributes["visual_shroud_remaining"] = clampf(float(int(unit.attributes.dotra_shroud_until_tick) - status_clock) / float(maxi(1, int(unit.attributes.dotra_shroud_until_tick) - int(unit.attributes.get("dotra_shroud_from_tick", 0)))), 0.0, 1.0)
		# Keep fractional visual positions out of the simulation's *_fp fields.
		if _spatial:
			unit.attributes["visual_y"] = lerpf(
				float(unit.attributes.y_fp), float(ending.attributes.y_fp), weight
			)
		unit.attributes["visual_x"] = lerpf(
			float(unit.attributes.x_fp), float(ending.attributes.x_fp), weight
		)
	var projectiles: Array = []
	for shot in projectile_rows:
		if at >= shot.start and at < shot.end:
			var picture: Dictionary = shot.duplicate(true)
			picture["weight"] = (at - shot.start) / maxf(0.001, float(shot.end) - float(shot.start))
			projectiles.append(picture)
	var fields: Array = _monster_fields.filter(func(f): return at >= f.at).map(func(f): return f.field.duplicate(true))
	var attacks: Array = _monster_attacks.filter(func(a): return at >= a.start and at < a.end).map(func(a): return a.duplicate(true))
	for attack in attacks:
		attack["weight"] = clampf((at - float(attack.start)) / maxf(0.001, float(attack.end) - float(attack.start)), 0.0, 1.0)
		if attack.ability == "MunoDash":
			attack["elapsed"] = at
			for unit in result:
				if unit.id != attack.source_id: continue
				attack["ward_active"] = unit.attributes.get("muno_ward", true)
				var home := Vector2(float(unit.attributes.visual_x), float(unit.attributes.visual_y))
				attack["return_point"] = home
				var dash := muno_position(attack, at, home)
				unit.attributes["visual_x"] = dash.x
				unit.attributes["visual_y"] = dash.y
				if at < float(attack.return_at):
					unit.attributes["visual_muno_weight"] = (at - float(attack.start)) / (float(attack.return_at) - float(attack.start))
					unit.attributes["visual_muno_face_left"] = float(attack.target.y_fp) < float(attack.source.y_fp) if attack.target.y_fp != attack.source.y_fp else unit.owner == 1
				break
	# The returned echo is saved unit state, so it survives pauses, new rounds
	# and reloads, and disappears on the exact frame that spends the charge.
	for unit in result:
		if unit.attributes.get("muno_ward", false) and int(unit.attributes.hp) > 0 and not attacks.any(func(a): return a.ability == "MunoDash" and a.source_id == unit.id):
			attacks.append({"ability": "MunoAfterimage", "source": unit.attributes, "target": unit.attributes, "source_id": unit.id, "target_id": unit.id, "source_owner": unit.owner, "target_owner": unit.owner})
	# Charging is recorded unit state, so death, loss of targets, pause, and
	# cross-round continuation all follow the same authoritative timeline.
	if _spatial and at < duration:
		var clock: float = float(round_number * _spatial_ticks) + clampf((at - _spatial_lead) * float(_spatial_ticks) / MOVE_SECONDS - 1.0, 0.0, float(_spatial_ticks - 1))
		for unit in result:
			var a: Dictionary = unit.attributes
			var ready: int = int(a.get("beam_ready_tick", 0))
			var start: int = int(a.get("beam_charge_tick", 0))
			if ready <= start or int(a.hp) <= 0: continue
			attacks.append({"ability": "BeamCharge", "source": a, "target": a, "source_id": unit.id, "source_owner": unit.owner, "weight": clampf((clock - float(start)) / float(ready - start), 0.0, 1.0)})
	return {"units": result, "caption": left.caption, "clash": left.clash.duplicate(), "projectiles": projectiles, "monster_fields": fields, "monster_attacks": attacks, "banished_ids": _banished_ids.keys(), "field_structures": left.get("field_structures", []).duplicate(true)}


func tick_time(tick: int) -> float:
	return _spatial_lead + MOVE_SECONDS * float(tick + 1) / float(_spatial_ticks)


func final_units() -> Array:
	return [] if _frames.is_empty() else _frames.back().units.duplicate(true)


func _append(units: Dictionary, caption: String, clash: Array, expired_armor: Dictionary = {}) -> void:
	for entity_id in _previous_units:
		var before: Dictionary = _previous_units[entity_id]
		var after: Dictionary = units.get(entity_id, {})
		if _banished_ids.has(entity_id) and after.is_empty(): continue
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
		# Expiring temporary Armor is not a hit. Preserve genuine damage in
		# the same tick, including packets that consumed some of that Armor.
		var armor_delta: int = armor - int(before.attributes.armor) + int(expired_armor.get(entity_id, 0))
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
	_frames.back()["field_structures"] = started.get("field_structures", []).duplicate(true)
	var lead: float = FLIGHT_SECONDS if started.has("ranged_profile") else 0.0
	_spatial_ticks = int(started.ticks)
	_spatial_lead = lead
	for event in events:
		if event.type == "MARCHER_RANGED_ATTACK":
			var impact: float = lead + MOVE_SECONDS * float(int(event.data.tick) + 1) / float(started.ticks)
			projectile_rows.append({"start": impact - FLIGHT_SECONDS, "end": impact, "lane": event.data.lane, "source_id": event.data.attacker.id, "target_id": event.data.target.id, "source": event.data.attacker.attributes.duplicate(true), "target": event.data.target.attributes.duplicate(true)})
	for field in started.get("monster_fields", []): _monster_fields.append({"at": 0.0, "field": field})
	var death_ticks: Dictionary = {}
	var beams: Dictionary = {}
	var pulses: Dictionary = {}
	for pending in started.get("monster_beams", []):
		var until: float = lead + MOVE_SECONDS * float(int(pending.detonate_tick) - round_number * _spatial_ticks + 1) / float(_spatial_ticks)
		_monster_attacks.append(_beam_picture(pending, 0.0, minf(lead + MOVE_SECONDS, until), "BeamTrail"))
	for event in events:
		var d: Dictionary = event.data
		if event.type == "MARCHER_DEFEATED": death_ticks[d.victim.id + ":pool"] = int(d.get("tick", 0))
		if event.type == "MONSTER_EXPOSURE_PULSE":
			var at: float = lead + MOVE_SECONDS * float(int(d.tick) + 1) / float(started.ticks)
			_monster_attacks.append({"start": at, "end": at + 0.32, "source": d.source.attributes, "source_id": d.source.id, "source_owner": d.source.owner, "range_fp": d.radius_fp, "ability": "DotraExpose"})
		if event.type == "MONSTER_PULSE":
			# Old tapes retain the caster ID, but do not identify healed bodies.
			# Show the cast without inventing successful heals in those replays.
			var source: Dictionary = d.get("source", bases.get(d.unit_id, {}))
			if not source.is_empty():
				var at: float = lead + MOVE_SECONDS * float(int(d.tick) + 1) / float(started.ticks)
				var pulse: Dictionary = _kopita_picture(d, source, at)
				pulses["%s:%d" % [d.unit_id, d.tick]] = pulse
				_monster_attacks.append(pulse)
		if event.type in ["MONSTER_BEAM_FIRED", "MONSTER_BEAM_DETONATED"]:
			var at: float = lead + MOVE_SECONDS * float(int(d.tick) + 1) / float(started.ticks)
			var key: String = "%s:%d" % [d.attacker.id, d.tick]
			var blast: bool = event.type == "MONSTER_BEAM_DETONATED"
			var span: float = BEAM_BLAST_SECONDS if blast else (GROUND_BEAM_SECONDS if d.has("detonate_tick") else BEAM_SECONDS)
			var beam: Dictionary = _beam_picture(d, at, at + span, "BeamBlast" if blast else "Beam")
			beams[key] = beam
			_monster_attacks.append(beam)
			if not blast and d.has("detonate_tick"):
				var until: float = lead + MOVE_SECONDS * float(int(d.detonate_tick) - round_number * _spatial_ticks + 1) / float(_spatial_ticks)
				_monster_attacks.append(_beam_picture(d, at + span, minf(lead + MOVE_SECONDS, until), "BeamTrail"))
	for event in events:
		var d: Dictionary = event.data
		if d.get("evaded", false) and event.type in ["MARCHER_MELEE_ATTACK", "MARCHER_RANGED_ATTACK", "MONSTER_ATTACK"]:
			var at: float = lead + MOVE_SECONDS * float(int(d.tick) + 1) / float(started.ticks)
			_monster_attacks.append({"start": at, "end": at + 0.20, "source": d.attacker.attributes, "target": d.target.attributes, "source_id": d.attacker.id, "target_id": d.target.id, "source_owner": d.attacker.owner, "target_owner": d.target.owner, "ability": "ArmorDeflect" if d.target.attributes.get("monster_id") == "Kurchin" else "HuntDodge"})
		if d.get("blocked", false) and event.type in ["MARCHER_MELEE_ATTACK", "MARCHER_RANGED_ATTACK", "MONSTER_ATTACK"]:
			var at: float = lead + MOVE_SECONDS * float(int(d.tick) + 1) / float(started.ticks)
			_monster_attacks.append({"start": at, "end": at + 0.20, "source": d.attacker.attributes, "target": d.target.attributes, "source_id": d.attacker.id, "target_id": d.target.id, "source_owner": d.attacker.owner, "target_owner": d.target.owner, "ability": "RangedBlock"})
		if event.type == "MONSTER_FIELD_CREATED" and not _monster_fields.any(func(f): return f.field.id == d.field.id):
			var tick: int = int(d.get("tick", death_ticks.get(d.field.id, 0)))
			_monster_fields.append({"at": lead + MOVE_SECONDS * float(tick + 1) / float(started.ticks), "field": d.field})
		elif event.type == "MONSTER_ATTACK":
			var at: float = lead + MOVE_SECONDS * float(int(d.tick) + 1) / float(started.ticks)
			var key: String = "%s:%d" % [d.attacker.id, d.tick]
			if d.ability == "Beam" and beams.has(key):
				# Collateral lights up the struck bodies; it never redirects the beam.
				if not d.get("evaded", false): beams[key].impacts.append({"attributes": d.target.attributes, "id": d.target.id, "owner": d.target.owner, "blocked": d.get("blocked", false)})
			elif d.ability == "Kopita":
				if not pulses.has(key):
					pulses[key] = _kopita_picture({"healing": false}, d.attacker, at)
					_monster_attacks.append(pulses[key])
				# Armor absorbs this damage normally; it still receives a hit flash.
				if not d.get("evaded", false): pulses[key].impacts.append({"attributes": d.target.attributes, "id": d.target.id, "owner": d.target.owner})
			elif d.ability == "Muno":
				# Arrive when the recorded hit lands, then retreat. Simulation
				# coordinates remain untouched by this short cosmetic excursion.
				_monster_attacks.append({"start": maxf(0.0, at - MUNO_DASH_OUT), "impact_at": at, "return_at": at + MUNO_STRIKE_HOLD + MUNO_DASH_BACK, "end": at + MUNO_STRIKE_HOLD + MUNO_DASH_BACK + MUNO_TRAIL_SECONDS, "source": d.attacker.attributes, "target": d.target.attributes, "source_id": d.attacker.id, "target_id": d.target.id, "source_owner": d.attacker.owner, "target_owner": d.target.owner, "ability": "MunoDash"})
			else:
				# Older tapes contain hit records only and can still show their shots.
				_monster_attacks.append({"start": at, "end": at + (BEAM_SECONDS if d.ability == "Beam" else 0.14), "source": d.attacker.attributes, "target": d.target.attributes, "source_id": d.attacker.id, "target_id": d.target.id, "source_owner": d.attacker.owner, "target_owner": d.target.owner, "ability": d.ability})
	var charge_expiry: Dictionary = {}
	for event in events:
		if event.type == "MONSTER_CHARGE_ENDED":
			var tick_key: int = int(event.data.tick)
			if not charge_expiry.has(tick_key): charge_expiry[tick_key] = {}
			charge_expiry[tick_key][event.data.unit_id] = int(event.data.armor_removed)
	var expected_tick: int = 0
	for event in events:
		if event.type != "MARCHING_TICK":
			continue
		var details: Dictionary = event.data
		if int(details.tick) != expected_tick:
			_frames = []
			return false
		expected_tick += 1
		duration = lead + MOVE_SECONDS * float(expected_tick) / float(started.ticks)
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
			"Melee in progress" if not details.clash.is_empty() else "Marching",
			details.clash,
			charge_expiry.get(int(details.tick), {})
		)
		_frames.back()["field_structures"] = details.get("field_structures", []).duplicate(true)
	if expected_tick != int(started.ticks):
		_frames = []
		return false
	units = {}
	for unit in finished.units:
		units[unit.id] = unit.duplicate(true)
	_align_attack_reveals(events)
	# Let the last recorded pulse finish instead of sticking on the final frame.
	for attack in _monster_attacks:
		duration = maxf(duration, float(attack.end))
	for shot in projectile_rows:
		duration = maxf(duration, float(shot.end))
	_append(units, "Marching complete", [])
	_frames.back()["field_structures"] = finished.get("field_structures", []).duplicate(true)
	return true


func _align_attack_reveals(events: Array) -> void:
	var concealed: Dictionary = {}
	var reveals: Dictionary = {}
	var targetable_at: Dictionary = {}
	for frame in _frames:
		for unit in frame.units:
			var deadline: int = int(unit.attributes.get("dotra_shroud_until_tick", 0))
			if deadline > 0:
				var tick: int = deadline - round_number * 200
				if not targetable_at.has(unit.id): targetable_at[unit.id] = []
				var expires_at: float = _spatial_lead + MOVE_SECONDS * float(tick + 1) / float(_spatial_ticks)
				if expires_at not in targetable_at[unit.id]: targetable_at[unit.id].append(expires_at)
			var hidden: bool = unit.attributes.get("hidden", false)
			if concealed.get(unit.id, false) and not hidden:
				if not reveals.has(unit.id): reveals[unit.id] = []
				reveals[unit.id].append(float(frame.at))
			concealed[unit.id] = hidden
	for event in events:
		if event.type == "MONSTER_ATTACK" and event.data.ability == "Ambush":
			# A lethal counterattack can remove Dotra before the next unit frame.
			# Its recorded ambush still establishes the exact reveal instant.
			var identity: String = event.data.attacker.id
			if not reveals.has(identity): reveals[identity] = []
			reveals[identity].append(_spatial_lead + MOVE_SECONDS * float(int(event.data.tick) + 1) / float(_spatial_ticks))
	for shot in projectile_rows:
		var visible_at: float = _latest_reveal(reveals, shot.source_id, shot.target_id, shot.end)
		visible_at = maxf(visible_at, _latest_reveal(targetable_at, "", shot.target_id, shot.end))
		shot.start = maxf(float(shot.start), visible_at)
		if float(shot.end) - float(shot.start) < 0.001:
			# The simulation hit is instantaneous on the reveal tick. Show its
			# impact there, without inventing a flight aimed at an invisible unit.
			shot["impact_only"] = true
			shot.end = float(shot.start) + 0.08
	for attack in _monster_attacks:
		if attack.ability == "MunoDash":
			attack.start = maxf(float(attack.start), _latest_reveal(reveals, attack.source_id, attack.target_id, attack.impact_at))
			attack.start = maxf(float(attack.start), _latest_reveal(targetable_at, "", attack.target_id, attack.impact_at))


static func _latest_reveal(reveals: Dictionary, source: String, target: String, at: float) -> float:
	var latest: float = 0.0
	for identity in [source, target]:
		for revealed_at in reveals.get(identity, []):
			if float(revealed_at) <= at + 0.000001: latest = maxf(latest, float(revealed_at))
	return latest


static func _beam_picture(d: Dictionary, at: float, until: float, ability: String) -> Dictionary:
	return {"start": at, "end": until, "source": d.attacker.attributes, "target": d.target.attributes, "source_id": d.attacker.id, "target_id": d.target.id, "source_owner": d.attacker.owner, "target_owner": d.target.owner, "range_fp": d.range_fp, "ground": d.has("detonate_tick"), "ability": ability, "impacts": []}


static func _kopita_picture(d: Dictionary, source: Dictionary, at: float) -> Dictionary:
	return {"start": at, "end": at + KOPITA_PULSE_SECONDS, "source": source.attributes, "source_id": source.id, "source_owner": source.owner, "range_fp": d.get("radius_fp", 360), "ability": "KopitaPulse", "healing": d.healing, "impacts": d.get("healed", []).duplicate(true)}


static func muno_position(attack: Dictionary, at: float, home: Vector2) -> Vector2:
	var origin := Vector2(attack.source.x_fp, attack.source.y_fp)
	var target := Vector2(attack.target.x_fp, attack.target.y_fp)
	var delta := target - origin
	# Stop inside the melee footprint instead of overlapping the victim.
	var reach: float = (delta / Vector2(90.0, 42.0)).length()
	var strike: Vector2 = origin + delta * maxf(0.0, 1.0 - 0.75 / maxf(0.001, reach))
	if at < float(attack.impact_at):
		return origin.lerp(strike, smoothstep(float(attack.start), float(attack.impact_at), at))
	if at < float(attack.impact_at) + MUNO_STRIKE_HOLD: return strike
	return strike.lerp(home, smoothstep(float(attack.impact_at) + MUNO_STRIKE_HOLD, float(attack.return_at), at))


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
