extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Space = preload("res://Scripts/Sim/U13SpatialSpace.gd")
const Events = preload("res://Scripts/Sim/U13ValakState.gd")
# Fixed-point tuning, independent of viewport pixels and render frame rate.
const ATTRACTION_FP: int = 248 # 330 reduced by 25%, rounded to fixed-point units.
const DESTRUCTION_FP: int = 65
const PULL_FP: int = 7


static func create(source: Dictionary, round_number: int) -> Dictionary:
	return {"id": Data.instance_id("persistent", source.declaration_id, "GravityOrb"), "owner": source.player_id, "target": source.target.duplicate(true), "round": round_number, "consumed": 0, "rewarded": false}


static func valid(rows) -> bool:
	if typeof(rows) != TYPE_ARRAY or rows.size() > 2:
		return false
	var owners: Array = []
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY or row.size() != 6 or typeof(row.get("id")) != TYPE_STRING or row.id.is_empty() or row.get("owner") not in [0, 1] or row.owner in owners:
			return false
		owners.append(row.owner)
		if typeof(row.get("target")) != TYPE_DICTIONARY or not preload("res://Scripts/Sim/U13SpatialFields.gd").target_valid(row.target):
			return false
		if not Data.is_integer(row.get("round")) or row.round < 1 or not Data.is_integer(row.get("consumed")) or row.consumed < 0 or typeof(row.get("rewarded")) != TYPE_BOOL or row.rewarded != (row.consumed >= 4):
			return false
	return true


static func _distance(a: Dictionary, point: Dictionary) -> int:
	return (int(a.x_fp) - int(point.x_fp)) ** 2 + (int(a.y_fp) - int(point.y_fp)) ** 2


static func _touches(a: Dictionary, b: Dictionary, point: Dictionary) -> bool:
	# Swept segment test avoids stepping through the destruction circle.
	var dx: int = int(b.x_fp) - int(a.x_fp)
	var dy: int = int(b.y_fp) - int(a.y_fp)
	var px: int = int(point.x_fp) - int(a.x_fp)
	var py: int = int(point.y_fp) - int(a.y_fp)
	var length_sq: int = dx * dx + dy * dy
	var dot: int = px * dx + py * dy
	if length_sq == 0 or dot <= 0:
		return _distance(a, point) <= DESTRUCTION_FP * DESTRUCTION_FP
	if dot >= length_sq:
		return _distance(b, point) <= DESTRUCTION_FP * DESTRUCTION_FP
	var cross: int = px * dy - py * dx
	return cross * cross <= DESTRUCTION_FP * DESTRUCTION_FP * length_sq


static func step(orbs: Array, entities, before: Array, round_number: int, tick: int, collapse: bool = false, pull_fp: int = PULL_FP, radius_fp: int = ATTRACTION_FP) -> Array:
	var events: Array = []
	for old in before:
		var unit: Dictionary = entities.get_entity(old.id)
		if unit.is_empty():
			continue
		var a: Dictionary = old.attributes
		var chosen: Dictionary = {}
		var best: int = 9223372036854775807
		for orb in orbs:
			if orb.target.lane != a.lane:
				continue
			var distance: int = _distance(a, orb.target.field_position)
			if distance <= radius_fp * radius_fp and (distance < best or (distance == best and (chosen.is_empty() or orb.id < chosen.id))):
				chosen = orb
				best = distance
		# Pull affects both sides, including waiters and engaged Marchers.
		# New commitments still wait until their normal movement-ready round.
		if pull_fp > 0 and not chosen.is_empty() and a.movement_ready_round <= round_number:
			var point: Dictionary = chosen.target.field_position
			var distance: int = maxi(1, ceili(sqrt(float(best))))
			var speed: int = ((pull_fp + tick % 2) >> 1) if collapse else pull_fp
			var next: Dictionary = unit.attributes.duplicate(true)
			next.x_fp = int(a.x_fp) + roundi(float(int(point.x_fp) - int(a.x_fp)) * speed / distance)
			next.y_fp = int(a.y_fp) + roundi(float(int(point.y_fp) - int(a.y_fp)) * speed / distance)
			next.waiting = false
			next.contact_tick = -1
			entities.update(unit.id, unit.owner, next)
			unit.attributes = next
		for orb in orbs:
			if orb.target.lane != a.lane or not _touches(a, unit.attributes, orb.target.field_position):
				continue
			entities.retire(unit.id)
			orb.consumed += 1
			var reward: bool = orb.consumed >= 4 and not orb.rewarded
			orb.rewarded = orb.consumed >= 4
			events.append(Events.event("GRAVITY_ORB_CONSUMED", {"effect_id": orb.id, "player_id": orb.owner, "unit": unit, "consumed": orb.consumed, "neutral_tears": 1 if reward else 0, "round": round_number, "tick": tick}))
			break
	return events
