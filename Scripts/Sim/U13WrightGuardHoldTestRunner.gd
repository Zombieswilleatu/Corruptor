extends "res://Scripts/Sim/U13WrightRepairTestRunner.gd"

const Arena = preload("res://Scripts/Sim/U13LaneSandbox.gd")
var replay_output

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0: phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	if args.size() > 1: replay_output = FileAccess.open(args[1], FileAccess.WRITE)
	for pid in [0, 1]:
		var home: Dictionary = Fort.anchor(pid, 0)
		var f: Dictionary = guarded(pid, 0, 6, 400)
		put(f.world, "Butcher", 1-pid, 1320 if pid == 0 else 1080, {"y_fp": 450, "step_fp": 0})
		var r: Dictionary = phase("guard_incoming_wave_%d" % pid, f.world)
		var guard: Dictionary = Kanifous._entity(r.world, f.builder.id)
		check(not guard.attributes.wright_released and Fort.distance(guard.attributes, home) == 0, "distant field enemy keeps expired full-health post guarded")
		check(Fort.goal(guard, Fort.rows(r.world), 9999, {}) == home, "movement honors unreleased guard even without a nearest target")
		for state in [{"hidden": true}, {"waiting": true}, {"lane": "Castle"}]:
			f = guarded(pid, 0, 6, 400)
			put(f.world, "Butcher", 1-pid, 1320 if pid == 0 else 1080, state)
			raw_step(f.world, 2)
			check(Kanifous._entity(f.world, f.builder.id).attributes.wright_released, "hidden, waiting, or other-lane unit does not hold guard duty")
		# A distant fortified opponent must not keep both armies at home.
		f = guarded(pid, 0, 6, 400)
		var opposing: Dictionary = guarded(1-pid, 0, 6, 9999)
		var other: Dictionary = put(f.world, "Wright", 1-pid, opposing.builder.attributes.x_fp, opposing.builder.attributes)
		var fortification: Dictionary = Fort.rows(opposing.world)[0].duplicate(true)
		fortification.attributes.builder_id = other.id
		Fort.rows(f.world).append(fortification)
		raw_step(f.world, 2)
		check(Kanifous._entity(f.world, f.builder.id).attributes.wright_released, "distant enemy fort guard allows eventual departure")
		for reach in [500, 800]:
			f = guarded(pid, 0, 6, 400)
			put(f.world, "Sooge", 1-pid, home.x_fp + reach*(1 if pid == 0 else -1), {"y_fp": home.y_fp, "sprite_form": "turret"})
			raw_step(f.world, 2)
			check(Kanifous._entity(f.world, f.builder.id).attributes.wright_released == (reach == 800), "stationary turret holds local defense only")
	for index in range(2):
		for order in [["Penitent", "Penitent", "Butcher", "Butcher"], ["Butcher", "Butcher", "Penitent", "Penitent"]]:
			for reflected in [false, true]:
				formation(index, order, reflected)
	if phase_output != null: phase_output.close()
	if replay_output != null: replay_output.close()
	print("U13 Wright guard hold failures: ", failures)
	quit(1 if failures else 0)

func formation(index: int, opponents: Array, reflected: bool) -> void:
	var seed_value: String = "monster-audit:%d" % index
	var sim = Arena.new(seed_value, true, true, false, 15)
	for i in range(4): sim.spawn("Wright", 0)
	for name in opponents: sim.spawn(name, 1)
	sim.round_number = 2
	sim.prepare_releases(["March", "March"])
	if reflected: sim.world = Arena.mirror(sim.world)
	var builders: Dictionary = {}
	var guard_shots: int = 0
	var early_releases: int = 0
	var exposed_guards: int = 0
	var guard_melee: int = 0
	var free_melee: int = 0
	for number in range(2, 11):
		var bases: Dictionary = {}
		for u in sim.units(): bases[u.id] = u
		var r: Dictionary = Arena.resolve_round(sim.world, seed_value, number)
		assert(r.action == "resolved")
		if replay_output != null and index == 0 and opponents[0] == "Penitent":
			var encoded: Dictionary = Codec.encode({"name": "formation_%s_%d" % [str(reflected), number], "world": sim.world, "seed": seed_value, "round": number, "result": r})
			assert(encoded.action == "encoded")
			replay_output.store_line(encoded.text)
		for row in r.events:
			var e: Dictionary = row.event
			if e.type == "WRIGHT_STRUCTURE_BUILT": builders[e.data.unit_id] = true
			if e.type == "MARCHER_RANGED_ATTACK" and builders.has(e.data.attacker.id): guard_shots += 1
			if e.type == "MARCHER_MELEE_ATTACK" and e.data.attacker.attributes.suit == "Wright":
				if not builders.has(e.data.attacker.id): free_melee += 1
				elif not e.data.attacker.attributes.get("wright_released", false): guard_melee += 1
			if e.type != "MARCHING_TICK": continue
			var units: Array = []
			for delta in e.data.units:
				var unit: Dictionary = bases.get(delta.id, delta).duplicate(true)
				unit.attributes.merge(delta.attributes, true)
				units.append(unit)
			for unit in units:
				if not builders.has(unit.id): continue
				var held: Dictionary = Fort.assigned_structure(unit, e.data.field_structures)
				if held.is_empty(): continue
				var incoming: bool = units.any(func(u): return u.owner != unit.owner and not u.attributes.get("hidden", false) and not u.attributes.waiting)
				if incoming and unit.attributes.get("wright_released", false): early_releases += 1
				if incoming and (int(unit.attributes.x_fp)-int(Fort.site_point(unit.owner, 0).x_fp))*(1 if unit.owner == 0 else -1) > 0: exposed_guards += 1
		sim.finish(r)
		if sim.units().is_empty(): break
	check(builders.size() == 3, "4v4 builds both walls and the tower")
	check(early_releases == 0 and exposed_guards == 0, "4v4 guards hold behind living posts while enemies remain")
	check(guard_shots > 0 and guard_melee == 0, "4v4 defenders shoot from cover instead of entering melee")
	check(free_melee > 0, "unassigned fourth Wright still fights in melee")
	print("FORMATION ", JSON.stringify({"seed": index, "opponents": opponents, "reflected": reflected, "builders": builders.size(), "early_releases": early_releases, "exposed_guards": exposed_guards, "guard_shots": guard_shots, "guard_melee": guard_melee, "free_melee": free_melee}))
