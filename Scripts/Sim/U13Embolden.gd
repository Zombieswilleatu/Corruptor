extends RefCounted

# Shared with u13_pysim/embolden.py. Existing saves remain opt-in by profile.
const VERSION: String = "U13_DEFENSIVE_PRESSURE_V1"
const FIELDS: Array = ["hp", "max_hp", "attack", "armor", "max_armor", "regen", "tumler_charge_base_armor"]
const LANES: Array = ["Lord", "Castle"]

static func configure(world: Dictionary) -> void:
	world.data.merge({"defensive_pressure_profile": VERSION, "embolden_experiment": 10, "embolden_ramp_experiment": true, "ward_conversion_experiment": "regular"}, true)

static func enabled(world: Dictionary) -> bool:
	return world.get("data", {}).get("embolden_experiment", 0) > 0

static func numeric(value) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(value)

static func clean(value):
	var rounded: float = round(float(value) * 100000000.0) / 100000000.0
	return int(rounded) if rounded == floor(rounded) else rounded

static func apply(a: Dictionary, percent: int) -> void:
	var before: int = int(a.get("_embolden_percent", 0))
	if before != percent:
		var ratio: float = float(100 + percent) / float(100 + before)
		for field in FIELDS:
			if a.has(field): a[field] = clean(a[field] * ratio)
	# Even an unbuffed unit may receive fractional damage.
	a["_embolden_percent"] = percent

static func transform(a: Dictionary, fields: Array) -> void:
	var factor: float = float(100 + int(a.get("_embolden_percent", 0))) / 100.0
	if factor != 1.0:
		for field in fields: a[field] = clean(a[field] * factor)

static func observe(world: Dictionary, number: int, rows: Array = []) -> void:
	if not world.data.get("embolden_ramp_experiment", false): return
	if not world.data.has("embolden_guard_history"):
		var slots: Array = []
		for _pid in [0, 1]:
			var zones: Dictionary = {}
			for lane in LANES:
				zones[lane] = []
				for _slot in range(3): zones[lane].append({"age": 0, "occupied": false})
			slots.append(zones)
		world.data["embolden_guard_history"] = {"round": number, "slots": slots}
	var history: Dictionary = world.data.embolden_guard_history
	if number != history.round:
		assert(number == int(history.round) + 1, "Embolden round discontinuity")
		for zones in history.slots:
			for slots in zones.values():
				for slot in slots:
					slot.age = 0 if slot.occupied else mini(3, int(slot.age) + 1)
					slot.occupied = false
		history.round = number
	for row in (world.entities.entities if rows.is_empty() else rows):
		var a: Dictionary = row.attributes
		if row.kind == "card" and a.get("role") == "guard" and row.owner in [0, 1] and a.get("lane") in LANES and a.get("slot") in [0, 1, 2]:
			history.slots[row.owner][a.lane][a.slot].merge({"age": 0, "occupied": true}, true)

static func pressures(world: Dictionary, rows: Array = []) -> Array:
	var occupied: Array = [{"Lord": [], "Castle": []}, {"Lord": [], "Castle": []}]
	for row in (world.entities.entities if rows.is_empty() else rows):
		var a: Dictionary = row.attributes
		if row.kind == "card" and a.get("role") == "guard" and row.owner in [0, 1] and a.get("lane") in LANES and a.get("slot") in [0, 1, 2]:
			if a.slot not in occupied[row.owner][a.lane]: occupied[row.owner][a.lane].append(a.slot)
	var bonuses: Array = [{"Lord": 0, "Castle": 0}, {"Lord": 0, "Castle": 0}]
	var history: Array = world.data.get("embolden_guard_history", {}).get("slots", [])
	for pid in [0, 1]:
		for lane in LANES:
			for slot in range(3):
				if slot in occupied[1 - pid][lane]: continue
				if world.data.get("embolden_ramp_experiment", false):
					var age: int = 0 if history.is_empty() else int(history[1 - pid][lane][slot].age)
					bonuses[pid][lane] += mini(20, 5 + 5 * age) if age > 0 else 0
				else: bonuses[pid][lane] += int(world.data.get("embolden_experiment", 0))
	return bonuses

static func refresh(world: Dictionary) -> void:
	if not enabled(world): return
	var bonuses: Array = pressures(world)
	for row in world.entities.entities:
		if row.kind == "marcher": apply(row.attributes, bonuses[row.owner][row.attributes.lane])

static func refresh_phase(world: Dictionary, entities, number: int) -> void:
	if not enabled(world): return
	# Reactions may have changed Guards or unit ownership during the phase.
	var background: Array = world.entities.entities.filter(func(u): return u.kind != "marcher")
	observe(world, number, background)
	var bonuses: Array = pressures(world, background)
	for row in entities._read_marchers():
		var percent: int = bonuses[row.owner][row.attributes.lane]
		if row.attributes.get("_embolden_percent", -1) == percent: continue
		var a: Dictionary = row.attributes.duplicate(true)
		apply(a, percent)
		entities.update(row.id, row.owner, a)

static func valid(world: Dictionary) -> bool:
	if not world.data.has("defensive_pressure_profile"): return true
	if world.data.defensive_pressure_profile != VERSION or world.data.get("embolden_experiment") != 10 or world.data.get("embolden_ramp_experiment") != true or world.data.get("ward_conversion_experiment") != "regular": return false
	var history = world.data.get("embolden_guard_history", {})
	if typeof(history) != TYPE_DICTIONARY: return false
	if history.is_empty(): return true
	if not preload("res://Scripts/Sim/U13EffectData.gd").is_integer(history.get("round")) or history.round < 1 or typeof(history.get("slots")) != TYPE_ARRAY or history.slots.size() != 2: return false
	for zones in history.slots:
		if typeof(zones) != TYPE_DICTIONARY: return false
		for lane in LANES:
			if typeof(zones.get(lane)) != TYPE_ARRAY or zones[lane].size() != 3: return false
			for slot in zones[lane]:
				if typeof(slot) != TYPE_DICTIONARY or slot.get("age") not in [0, 1, 2, 3] or typeof(slot.get("occupied")) != TYPE_BOOL: return false
	return true
