extends RefCounted
const Charge = preload("res://Scripts/Sim/U13TumlerCharge.gd")
# Frozen pre-optimization selectors for behavioral differential checks.
const Shroud = preload("res://Scripts/Sim/U13DotraShroud.gd")
const Fort = preload("res://Scripts/Sim/U13FieldFortifications.gd")
const Wish = preload("res://Scripts/Sim/U13Wishmaster.gd")
const Rules = preload("res://Scripts/Sim/U13MonsterRules.gd")

static func nearest(unit: Dictionary, targets: Array, radius: int = 4000, melee: bool = false) -> Dictionary:
	var best: Dictionary = {}
	var gap: int = radius * radius + 1
	for row in targets:
		if row.owner == unit.owner or row.attributes.lane != unit.attributes.lane or Shroud.active(row.attributes) or (row.kind == "marcher" and Wish.ignored(unit, row)): continue
		if unit.attributes.get("flying", false) and row.kind == "fortification" and row.attributes.structure == "Wall": continue
		if melee and not Fort.in_melee(unit, row): continue
		var d: int = Fort.gap(unit, row)
		if d <= radius * radius and (d < gap or (d == gap and (best.is_empty() or row.id < best.id))):
			best = row; gap = d
	return best

static func enemies(unit: Dictionary, rows: Array, radius: int = 4000) -> Array:
	return rows.filter(func(r): return r.owner != unit.owner and r.attributes.lane == unit.attributes.lane and Shroud.targetable(r.attributes) and Fort.gap(unit, r) <= radius * radius)

static func monster_nearest(unit: Dictionary, rows: Array, radius: int = 4000) -> Dictionary:
	var result: Dictionary = {}
	var best: int = radius * radius + 1
	for row in enemies(unit, rows, radius):
		var d: int = Fort.gap(unit, row)
		if d < best: result = row; best = d
	return result

# A local taunt does not let a distant Kurchin steal targets across the lane.

static func preferred(unit: Dictionary, rows: Array) -> Dictionary:
	if Charge.active(unit.attributes): return Charge.select_target(unit, rows, 0)
	var taunts: Array = enemies(unit, rows, Rules.TUNING.taunt_radius).filter(func(r): return r.attributes.get("monster_id") == "Kurchin")
	if not taunts.is_empty(): return monster_nearest(unit, taunts)
	var id: String = unit.attributes.get("hunt_target", "")
	if unit.attributes.get("monster_id") == "Tumler":
		for row in enemies(unit, rows):
			if row.id == id: return row
	return {}
