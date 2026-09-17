extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const VERSION: String = "U13_PERMANENT_BREACHES_V1"
const LORDS: Array = ["Gremory", "Deimos", "Humbaba", "Kalligan", "Orias", "Odradek", "Kroni", "Valak", "Kanifous"]
const THRESHOLDS: Array = [5, 9, 13, 17]
const BENEFICIAL: Array = ["Gremory", "Kalligan", "Kanifous"]

static func configure(world: Dictionary) -> void:
	world.data["veil_breaches"] = {"version": VERSION, "arrivals": [], "checked_round": 0, "veil_21_round": 0, "cascade_round": 0, "round_history": []}

static func enabled(world: Dictionary) -> bool:
	return world.data.has("veil_breaches")

static func total(world: Dictionary) -> int:
	return world.data.neutral_tears + world.players[0].resources.personal_tears + world.players[1].resources.personal_tears

static func arrival(world: Dictionary, lord: String) -> Dictionary:
	for row in world.data.get("veil_breaches", {}).get("arrivals", []):
		if row.lord_id == lord:
			return row
	return {}

static func active(world: Dictionary, lord: String) -> bool:
	return world.data.get("breach_lord", "") == lord or not arrival(world, lord).is_empty()

static func protected_player(world: Dictionary, lord: String, pid: int) -> bool:
	var row: Dictionary = arrival(world, lord)
	return not row.is_empty() and row.protection > 0 and world.players[pid].resources.personal_tears >= row.protection

# Beneficial intruders are denied by the recipient's opponent's protection.
# Ordinary participating-Lord Breaches never inherit permanent-arrival stamps.
static func affects(world: Dictionary, lord: String, pid: int) -> bool:
	if world.data.get("breach_lord", "") == lord:
		return true
	return not arrival(world, lord).is_empty() and not protected_player(world, lord, 1 - pid if lord in BENEFICIAL else pid)

static func affected_players(world: Dictionary, lord: String) -> Array:
	return [affects(world, lord, 0), affects(world, lord, 1)]

static func applies_to(effect, pid: int) -> bool:
	return effect[pid] if typeof(effect) == TYPE_ARRAY else effect

static func source_valid(world: Dictionary, source_id: String) -> bool:
	return source_id == "veil:Humbaba" and not arrival(world, "Humbaba").is_empty()

static func observe(world: Dictionary, round_number: int) -> void:
	if enabled(world) and total(world) >= 21 and world.data.veil_breaches.veil_21_round == 0:
		world.data.veil_breaches.veil_21_round = round_number

# Sample only on arrival: neither saves nor observations hold a future sequence.
static func begin(world: Dictionary, round_number: int, seed_value: String) -> Array:
	if not enabled(world) or world.data.get("victory", {}).get("winner", -1) != -1:
		return []
	var state: Dictionary = world.data.veil_breaches
	if state.checked_round >= round_number:
		return []
	state.checked_round = round_number
	observe(world, round_number)
	var available: Array = LORDS.filter(func(lord): return lord != world.players[0].lord_id and lord != world.players[1].lord_id and arrival(world, lord).is_empty())
	var admitted: Array = []
	while not available.is_empty():
		var index: int = state.arrivals.size()
		var cascade: bool = index >= THRESHOLDS.size()
		if (cascade and (total(world) < 21 or round_number < 21)) or (not cascade and total(world) < THRESHOLDS[index]):
			break
		var pick: int = int(Rng.draw(seed_value, VERSION, "arrival", index, available.size()).value)
		var row: Dictionary = {"lord_id": available.pop_at(pick), "threshold": 21 if cascade else THRESHOLDS[index], "protection": 0 if cascade else index + 1, "round": round_number, "veil": total(world)}
		state.arrivals.append(row)
		admitted.append(row.duplicate(true))
		if cascade:
			state.cascade_round = round_number
	return admitted

static func finish(world: Dictionary, round_number: int) -> void:
	if not enabled(world):
		return
	observe(world, round_number)
	world.data.veil_breaches.round_history.append({"round": round_number, "veil": total(world), "kanifous_active": active(world, "Kanifous"), "arrivals": world.data.veil_breaches.arrivals.size(), "winner": world.data.victory.winner})

static func valid(world: Dictionary) -> bool:
	var state = world.data.get("veil_breaches")
	if typeof(state) != TYPE_DICTIONARY or state.size() != 6 or state.get("version") != VERSION:
		return false
	for key in ["checked_round", "veil_21_round", "cascade_round"]:
		if not Data.is_integer(state.get(key)) or state[key] < 0:
			return false
	if typeof(state.get("arrivals")) != TYPE_ARRAY or typeof(state.get("round_history")) != TYPE_ARRAY:
		return false
	var seen: Array = []
	var last_round: int = 0
	for row in state.arrivals:
		var i: int = seen.size()
		if typeof(row) != TYPE_DICTIONARY or row.size() != 5 or row.get("lord_id") not in LORDS or row.lord_id in seen or row.lord_id in [world.players[0].lord_id, world.players[1].lord_id]:
			return false
		for key in ["threshold", "protection", "round", "veil"]:
			if not Data.is_integer(row.get(key)):
				return false
		if row.threshold != (21 if i >= 4 else THRESHOLDS[i]) or row.protection != (0 if i >= 4 else i + 1) or row.veil < row.threshold or row.round < maxi(1, last_round) or row.round > state.checked_round or (i >= 4 and (row.round < 21 or row.round != state.cascade_round)):
			return false
		last_round = row.round
		seen.append(row.lord_id)
	if (state.cascade_round > 0) != (seen.size() > 4) or (seen.size() > 4 and seen.size() != LORDS.size() - (1 if world.players[0].lord_id == world.players[1].lord_id else 2)):
		return false
	for i in range(state.round_history.size()):
		var row = state.round_history[i]
		if typeof(row) != TYPE_DICTIONARY or row.size() != 5 or row.get("round") != i + 1 or not Data.is_integer(row.get("veil")) or row.veil < 0 or typeof(row.get("kanifous_active")) != TYPE_BOOL or not Data.is_integer(row.get("arrivals")) or row.arrivals < 0 or row.arrivals > seen.size() or row.get("winner") not in [-1, 0, 1]:
			return false
	return true
