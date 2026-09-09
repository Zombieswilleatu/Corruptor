extends RefCounted

# Cosmetic rows only: no RNG, world writes, nodes or timers per hit.
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const TYPES: Array = [
	"MARCHER_DAMAGED", "MARCHER_DEFEATED", "MARCHER_REGENERATED", "HAZARD_HIT", "HAZARD_PULSED"
]
const LIFETIME: float = 1.1
const PULSE_GAP: float = 0.75
const MAX_VISIBLE: int = 96
var visible: Array = []


static func row(
	unit: Dictionary, hp: int, armor: int, at: float = 0.0, source: String = ""
) -> Dictionary:
	var a: Dictionary = unit.attributes
	return {
		"id": unit.id,
		"lane": a.lane,
		"x": float(a.get("visual_x", a.x_fp)),
		"y": float(a.get("visual_y", a.get("y_fp", 300))),
		"hp": hp,
		"armor": armor,
		"at": at,
		"source": source
	}


# Battle events include the actual clamped HP transition. Armor absorption is
# a separate hazard fact, combined with that hit rather than counted twice.
static func outside_marching(events: Array, units: Array) -> Array:
	var lookup: Dictionary = {}
	for unit in units:
		if unit.kind == "marcher":
			lookup[unit.id] = unit
	var result: Array = []
	var hits: Dictionary = {}
	var at: float = 0.0
	var hook: String = ""
	var group_start: int = 0
	for event in events:
		var d: Dictionary = event.data
		var next_hook: String = String(d.get("hook", ""))
		if next_hook != hook:
			if result.size() > group_start:
				at += PULSE_GAP
			hook = next_hook
			group_start = result.size()
			hits.clear()
		if event.type in ["MARCHER_DAMAGED", "MARCHER_DEFEATED"]:
			var victim: Dictionary = d.get("victim", {})
			if victim.get("kind", "") != "marcher" or not d.has("hp_after"):
				continue
			var hit: Dictionary = row(victim, int(d.hp_after) - int(d.hp_before), 0, at, "HIT")
			hits[victim.id] = hit
			result.append(hit)
		elif event.type == "HAZARD_HIT":
			if hits.has(d.entity_id):
				hits[d.entity_id].armor = -int(d.armor_absorbed)
				hits[d.entity_id].source = "SCORCH"
		elif event.type == "HAZARD_PULSED":
			if d.get("power_id", "") == "Inferno" and next_hook == Timeline.POST_RESOLUTION_DIRECT:
				# A presentation marker makes an empty-area Pyroclasm flash too.
				result.append({"id": "", "hp": 0, "armor": 0, "at": at, "pulse": d.effect_id})
			# Two pulses at one hook remain two visible impacts.
			if result.size() > group_start:
				at += PULSE_GAP
			group_start = result.size()
			hits.clear()
		elif event.type == "MARCHER_REGENERATED" and lookup.has(d.entity_id):
			result.append(row(lookup[d.entity_id], int(d.after) - int(d.before), 0, at, "REGEN"))
	var changed: Array = []
	for hit in result:
		if hit.hp != 0 or hit.armor != 0 or hit.has("pulse"):
			changed.append(hit)
	return changed


func show_rows(rows: Array) -> void:
	for hit in rows:
		if hit.hp == 0 and hit.armor == 0:
			continue
		# Repeated rapid exchanges on one chit accumulate in its still-visible
		# number. This preserves every amount without stacking unreadable labels.
		var merged: bool = false
		for existing in visible:
			if (
				existing.id == hit.id
				and existing.source == hit.source
				and signi(int(existing.hp)) == signi(int(hit.hp))
			):
				existing.hp += hit.hp
				existing.armor += hit.armor
				existing.age = 0.0
				existing.x = hit.x
				existing.y = hit.y
				existing.lane = hit.lane
				merged = true
				break
		if merged:
			continue
		var owned: Dictionary = hit.duplicate(true)
		owned["age"] = 0.0
		visible.append(owned)
		if visible.size() > MAX_VISIBLE:
			visible.pop_front()


func advance(delta: float) -> void:
	for index in range(visible.size() - 1, -1, -1):
		visible[index].age += maxf(0.0, delta)
		if visible[index].age >= LIFETIME:
			visible.remove_at(index)


func clear() -> void:
	visible.clear()
