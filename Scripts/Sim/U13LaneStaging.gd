extends RefCounted

# Protected reserves for the lane experiment. Rows keep their immutable IDs,
# but are absent from the battlefield registry until a round-boundary release.
const VERSION: String = "U13_LANE_STAGING_V1"
const DEFAULT_CAPACITY: int = 15

static func configure(world: Dictionary, capacity: int) -> void:
	world.data["marcher_staging"] = {"version": VERSION, "capacity": clampi(capacity, 12, 15), "units": [], "decisions": [], "prepared_round": 0}

static func enabled(world: Dictionary) -> bool:
	return world.data.get("marcher_staging", {}).get("version") == VERSION

static func rows(world: Dictionary, owner: int = -1) -> Array:
	var reserves: Array = world.data.get("marcher_staging", {}).get("units", [])
	return reserves.filter(func(u): return owner < 0 or u.owner == owner)

static func eligible(world: Dictionary, owner: int, number: int) -> Array:
	return rows(world, owner).filter(func(u): return int(u.attributes.staged_round) < number)

static func store_units(world: Dictionary, identities: Array, number: int) -> void:
	if not enabled(world): return
	var field: Array = []
	for unit in world.entities.entities:
		if unit.id not in identities:
			field.append(unit)
			continue
		unit.attributes["staged_round"] = number
		unit.attributes.birth_round = number
		unit.attributes.movement_ready_round = number + 1
		world.data.marcher_staging.units.append(unit)
	world.entities.entities = field

static func strength(units: Array, opponents: Array = []) -> int:
	var power: int = 0
	var butchers: int = opponents.filter(func(u): return u.attributes.suit == "Butcher").size()
	for unit in units:
		var a: Dictionary = unit.attributes
		var attack: int = int(a.attack)
		if a.suit == "Vulture" and butchers * 2 >= maxi(1, opponents.size()): attack += 1
		power += (int(a.hp) + int(a.armor)) * (attack + 1)
	return power

static func decision(world: Dictionary, owner: int, number: int, mode: String) -> Dictionary:
	var ready: Array = eligible(world, owner, number)
	var field: Array = world.entities.entities.filter(func(u): return u.kind == "marcher")
	# Look beyond midfield: approaching armies can meet the released group
	# this interval. Do not inspect the opponent's protected reserve.
	var local: Array = field.filter(func(u): return (int(u.attributes.x_fp) if owner == 0 else 2400 - int(u.attributes.x_fp)) <= 1800 and not u.attributes.waiting and not u.attributes.get("hidden", false))
	var enemies: Array = local.filter(func(u): return u.owner != owner)
	var allies: Array = local.filter(func(u): return u.owner == owner)
	var available: int = strength(ready + allies, enemies)
	var pressure: int = strength(enemies, ready + allies)
	var release: bool = not ready.is_empty() and (mode == "March" or (mode == "Auto" and (available * 5 >= pressure * 4 or ready.size() >= int(world.data.marcher_staging.capacity))))
	var reason: String = "New units wait one full round." if ready.is_empty() else "Holding by choice."
	if release: reason = "March: reserves full." if mode == "Auto" and ready.size() >= int(world.data.marcher_staging.capacity) else "March: force ready."
	elif mode == "Auto" and not ready.is_empty(): reason = "Holding for reinforcements: pressure %d / force %d." % [pressure, available]
	return {"owner": owner, "release": release, "reason": reason, "force": available, "pressure": pressure, "released": 0, "overflow": 0}

static func prepare(world: Dictionary, number: int, modes: Array, limit: int = 64) -> Array:
	if not enabled(world) or world.data.marcher_staging.prepared_round >= number: return []
	var staging: Dictionary = world.data.marcher_staging
	# Seal both choices from the same pre-release field. No first-player peek.
	var decisions: Array = [decision(world, 0, number, modes[0]), decision(world, 1, number, modes[1])]
	for owner in [number % 2, 1 - number % 2]:
		var ready: Array = eligible(world, owner, number)
		ready.sort_custom(func(a, b): return a.attributes.staged_round < b.attributes.staged_round if a.attributes.staged_round != b.attributes.staged_round else a.id < b.id)
		var chosen: Array = ready.duplicate() if decisions[owner].release else []
		var excess: int = rows(world, owner).size() - int(staging.capacity)
		if chosen.is_empty() and excess > 0:
			# Overflow releases complete oldest birth-round groups. Newborns can
			# temporarily exceed capacity, but never bypass their protected wait.
			for unit in ready:
				if chosen.size() >= excess and unit.attributes.staged_round != chosen.back().attributes.staged_round: break
				chosen.append(unit)
			decisions[owner].overflow = chosen.size()
			if not chosen.is_empty(): decisions[owner].reason = "Overflow: oldest ready group marches."
		var space: int = limit - world.entities.entities.filter(func(u): return u.kind == "marcher").size()
		if chosen.size() > space:
			decisions[owner].reason = "Holding: field capacity; group stays protected."
			chosen.clear()
			decisions[owner].overflow = 0
		deploy(world, chosen, number)
		decisions[owner].released = chosen.size()
	staging.decisions = decisions
	staging.prepared_round = number
	return decisions

static func deploy(world: Dictionary, units: Array, number: int) -> void:
	# Screen in front, support behind, each rank spread across the gate.
	units.sort_custom(func(a, b):
		var ar: int = rank(a); var br: int = rank(b)
		return ar < br if ar != br else a.id < b.id)
	for i in range(units.size()):
		var unit: Dictionary = units[i]
		var a: Dictionary = unit.attributes
		var column: int = i % 10
		var row: int = floori(float(i) / 10.0)
		var columns: int = mini(10, units.size() - row * 10)
		a.x_fp = maxi(0, 100 - row * 60) if unit.owner == 0 else mini(2400, 2300 + row * 60)
		a.y_fp = floori(float((column + 1) * 600) / float(columns + 1))
		a.movement_ready_round = number
		a["deployed_round"] = number
		world.data.marcher_staging.units.erase(unit)
		world.entities.entities.append(unit)
	world.entities.entities.sort_custom(func(a, b): return a.id < b.id)

static func rank(unit: Dictionary) -> int:
	var a: Dictionary = unit.attributes
	if a.suit == "Penitent" or a.get("monster_id") in ["Lemek", "Kurchin"]: return 0
	if a.suit == "Vulture" or a.get("monster_id") in ["Kopita", "Sooge", "Sinodek"]: return 2
	return 1
