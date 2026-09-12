extends RefCounted

# Policy input is exclusively the public/own-hand projection. No match state,
# opponent hand, sealed orders, seed forecasts, or presentation nodes live here.
const Development = preload("res://Scripts/Sim/U13GameDevelopment.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
var view: Dictionary
var w: Dictionary
var pid: int
var rows: Dictionary = {}

func _init(source: Dictionary) -> void:
	view = source
	w = source.world
	pid = w.viewer_id
	for row in w.entities:
		rows[row.id] = row

func select(kind: String, owner_id: int, lane: String = "") -> Array:
	var result: Array = []
	for row in w.entities:
		if row.kind == kind and row.owner == owner_id and (lane.is_empty() or row.attributes.get("lane") == lane):
			result.append(row)
	result.sort_custom(func(a, b): return a.id < b.id)
	return result

func guards(owner_id: int, lane: String) -> Array:
	return select("card", owner_id, lane).filter(func(e): return e.attributes.get("role") == "guard")

func guard_value(owner_id: int, lane: String) -> int:
	var total: int = 0
	for row in guards(owner_id, lane):
		total += int(row.attributes.value)
	return total

func waiters(owner_id: int, lane: String, order: Dictionary = {}) -> int:
	var used: Array = []
	for spend in order.get("rites", {}).get("waiter_spends", []):
		used.append_array(spend.marcher_ids)
	return select("marcher", owner_id, lane).filter(func(e): return e.attributes.waiting and e.id not in used).size()

func castles(owner_id: int, active_only: bool = true) -> Array:
	var result: Array = select("castle", owner_id)
	return result.filter(func(e): return Structures.targetable(e)) if active_only else result

func printed(ids: Array) -> int:
	var total: int = 0
	for id in ids:
		total += int(rows[id].attributes.value)
	return total

func strength(ids: Array, exempt: String = "Butcher") -> int:
	var total: int = 0
	var suited: int = 0
	for id in ids:
		var a: Dictionary = rows[id].attributes
		total += int(a.value) if a.suit == exempt else maxi(1, int(a.value) - 1)
		suited += 1 if a.suit == exempt else 0
	return total + (1 if suited >= 2 else 0)

func card_score(id: String) -> float:
	var a: Dictionary = rows[id].attributes
	return float(a.value) + (0.4 if a.suit == "Butcher" else 0.0)

func available(powers: Array, order: Dictionary) -> Array:
	return Development.free_cards(view, powers, order)

# Finite meaningful payments, never the full Cartesian candidate vocabulary.
# At most 8 singles, 28 pairs, and 6 strong prefixes; works with oversized hands.
func payments(powers: Array, order: Dictionary, exempt: String = "Butcher") -> Array:
	var cards: Array = available(powers, order)
	cards.sort_custom(func(a, b):
		var av: int = strength([a], exempt)
		var bv: int = strength([b], exempt)
		return a < b if av == bv else av > bv)
	var sample: Array = cards.slice(0, 6)
	for id in cards.slice(maxi(0, cards.size() - 2)):
		if id not in sample:
			sample.append(id)
	var result: Array = [[]]
	for i in range(sample.size()):
		result.append([sample[i]])
		for j in range(i + 1, sample.size()):
			result.append([sample[i], sample[j]])
	for count in range(3, mini(6, cards.size()) + 1):
		result.append(cards.slice(0, count))
	return result

func tear_value(gain: int = 1) -> float:
	var ours: int = int(w.personal_tears[pid]) + gain
	if w.veil_total + gain >= 12 and ours >= 5 and ours > w.personal_tears[1 - pid]:
		return 150.0
	return 13.0 if w.personal_tears[pid] < 5 or w.personal_tears[pid] <= w.personal_tears[1 - pid] else 5.0

func screen(lane: String) -> int:
	var result: int = guard_value(1 - pid, lane)
	var sigil: String = w.sigils[1 - pid][lane]
	result += 2 if sigil == "fresh" else (1 if sigil == "flipped" else 0)
	return result

func castle_value(row: Dictionary) -> float:
	match row.attributes.castle_type:
		"Keep": return 9.0
		"Stockpile": return 8.0
		"SummoningCircle": return 8.0
		"SiegeEngine": return 7.0
	return 6.0
