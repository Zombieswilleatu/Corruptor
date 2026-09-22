extends SceneTree
const Melee = preload("res://Scripts/Sim/U13FieldMelee.gd")
const Effects = preload("res://Scripts/Sim/U13MonsterEffects.gd")
const Reference = preload("res://Scripts/Sim/U13TargetingReference.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)

func row(id: String, owner: int, x: int, y: int, name: String = "") -> Dictionary:
	return {"id": id, "kind": "marcher", "owner": owner, "attributes": {"lane": "Lord", "x_fp": x, "y_fp": y, "monster_id": name, "hp": 10, "suit": "Monster" if not name.is_empty() else "Butcher"}}

func compare(unit: Dictionary, targets: Array) -> void:
	var before: PackedByteArray = var_to_bytes([unit, targets])
	for radius in [0, 42, 90, 360, 4000, -90]:
		for melee in [false, true]:
			check(var_to_bytes(Melee.nearest(unit, targets, radius, melee)) == var_to_bytes(Reference.nearest(unit, targets, radius, melee)), "nearest radius=%d melee=%s" % [radius, melee])
	check(var_to_bytes(Effects.preferred(unit, targets)) == var_to_bytes(Reference.preferred(unit, targets)), "preferred target")
	check(var_to_bytes([unit, targets]) == before, "selectors preserve inputs")

func _initialize() -> void:
	var unit: Dictionary = row("source", 0, 1200, 300, "Tumler")
	var a: Dictionary = row("a", 1, 1290, 300, "Kurchin")
	var b: Dictionary = row("b", 1, 1110, 300, "Kurchin")
	check(Melee.nearest(unit, [b, a]).id == "a", "melee tie uses identity")
	check(Effects.preferred(unit, [b, a]).id == "b", "taunt tie uses input order")
	for dx in [0, 89, 90, 91, 359, 360, 361, 4000, 4001]:
		for dy in [0, 41, 42, 43, 150, 151]:
			a.attributes.x_fp = 1200 + dx
			a.attributes.y_fp = 300 + dy
			unit.attributes.hunt_target = "a"
			compare(unit, [a, b])
			var wall: Dictionary = a.duplicate(true)
			wall.kind = "fortification"
			wall.attributes.structure = "Wall"
			for flying in [false, true]:
				unit.attributes.flying = flying
				compare(unit, [wall, b])
	# Active charges retain their locked target before considering taunts.
	for phase in ["windup", "charge"]:
		unit.attributes.tumler_charge_phase = phase
		unit.attributes.tumler_charge_target = "b"
		compare(unit, [a, b])
		check(Effects.preferred(unit, [a, b]).id == "b", "V21 charge keeps locked target")
		b.attributes.hidden = true
		compare(unit, [a, b])
		check(Effects.preferred(unit, [a, b]).is_empty(), "V21 charge does not retarget from hidden prey")
		b.attributes.hidden = false
	var rng = RandomNumberGenerator.new()
	rng.seed = 462109
	for case in range(1000):
		unit = row("source", case % 2, rng.randi_range(0, 2400), rng.randi_range(0, 600), "Tumler" if case % 3 == 0 else "Butcher")
		unit.attributes.flying = case % 7 == 0
		unit.attributes.hidden = case % 11 == 0
		unit.attributes.hunt_target = "target-2"
		unit.attributes.ghost_bypassed = ["target-3"] if case % 5 == 0 else []
		var targets: Array = []
		for index in range(12):
			var target: Dictionary = row("target-%d" % index, rng.randi_range(0, 1), rng.randi_range(0, 2400), rng.randi_range(0, 600), ["Kurchin", "Dotra", "Tumler", "Butcher"][rng.randi_range(0, 3)])
			target.attributes.lane = "Castle" if rng.randi_range(0, 5) == 0 else "Lord"
			target.attributes.hidden = rng.randi_range(0, 8) == 0
			target.attributes.dotra_shroud_until_tick = 100 if rng.randi_range(0, 3) == 0 else 0
			target.attributes.ghost_bypassed = ["source"] if rng.randi_range(0, 9) == 0 else []
			if index % 5 == 0:
				target.kind = "fortification"
				target.attributes.structure = "Wall" if index == 0 else "Tower"
			targets.append(target)
		compare(unit, targets)
	print("TARGETING CHECKS ", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
