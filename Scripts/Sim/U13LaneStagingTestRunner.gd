extends SceneTree

const Sim = preload("res://Scripts/Sim/U13LaneSandbox.gd")
const Stage = Sim.Staging
const UI = preload("res://Prototype/U13/U13LaneSandbox.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + description)

func advance(sim) -> Dictionary:
	var result: Dictionary = Sim.resolve_round(sim.world, sim.seed_value, sim.round_number)
	check(result.action == "resolved", "staged world resolves through production Marching")
	if result.action == "resolved": sim.finish(result)
	return result

func run() -> void:
	var sim = Sim.new("staging-protection", true, true, false, 15)
	sim.spawn("Sooge", 0)
	sim.spawn("Vulture", 0)
	sim.spawn("Wright", 0)
	check(sim.units().is_empty() and sim.staged_units().size() == 3, "new production exists only in protected reserves")
	check(sim.spawn("Sooge", 0).action == "invalid", "staged limited monster reserves its living-copy slot")
	sim.staged_units()[0].attributes.hp = 1
	var original: Array = sim.staged_units().duplicate(true)
	sim.prepare_releases(["March", "March"])
	check(sim.units().is_empty(), "even explicit March cannot release newborns")
	var result: Dictionary = advance(sim)
	check(sim.staged_units() == original, "staged HP, rooting, building and all ability counters remain frozen")
	check(not result.events.any(func(e): return e.event.type in ["MONSTER_BEAM_FIRED", "WRIGHT_BUILD_ASSIGNED", "MARCHER_RANGED_ATTACK"]), "reserves do not attack, build or fire abilities")
	sim.spawn("Butcher", 0)
	sim.prepare_releases(["March", "Hold"])
	check(sim.units().size() == 3 and sim.staged_units().size() == 1, "whole eligible group marches; current-round production stays protected")
	check(sim.units().all(func(u): return u.attributes.movement_ready_round == 2), "released group is immediately ready in its release round")
	var saved: Dictionary = sim.world.duplicate(true)
	sim.prepare_releases(["March", "March"])
	check(sim.world == saved, "release cannot happen twice within the same interval")
	check(Sim.Marching.valid(sim.world), "deployment keeps immutable IDs and a valid engine snapshot")

	# Genuine visible pressure: a weak reserve faces six healthy Butchers.
	sim = Sim.new("staging-pressure", true)
	for i in range(6): sim.spawn("Butcher", 1, true)
	for unit in sim.units(): unit.attributes.x_fp = 1500
	Stage.configure(sim.world, 15)
	sim.spawn("Vulture", 0)
	sim.round_number = 2
	var choice: Dictionary = Stage.decision(sim.world, 0, 2, "Auto")
	check(not choice.release and choice.pressure > choice.force, "bot banks a small force against obvious losing pressure")
	check(Stage.decision(sim.world, 0, 2, "March").release, "manual early release remains available")
	sim.world.entities.entities.clear()
	check(Stage.decision(sim.world, 0, 2, "Auto").release, "bot can release a small ready force when pressure clears")
	sim = Sim.new("staging-under-fire", true)
	sim.spawn("Vulture", 1)
	for unit in sim.units(): unit.attributes.x_fp = 180
	Stage.configure(sim.world, 15)
	sim.spawn("Wright", 0)
	sim.spawn("Sooge", 0)
	for unit in sim.staged_units(): unit.attributes.hp = 1
	sim.world.data.monsters.fields.append({"kind": "portal", "id": "protection-fixture", "owner": 1, "lane": "Lord", "x_fp": 40, "y_fp": 300, "expires_round": 1})
	original = sim.staged_units().duplicate(true)
	sim.prepare_releases(["Hold", "Hold"])
	advance(sim)
	check(sim.staged_units() == original and sim.totals[0].defeated == 0 and sim.totals[0].banished == 0, "enemy at the gate and a portal cannot damage, banish or wake reserves")
	sim.prepare_releases(["Hold", "Hold"])
	advance(sim)
	check(sim.staged_units() == original, "holding an eligible group keeps regeneration and ability clocks frozen")

	sim = Sim.new("staging-field-cap", true)
	for i in range(Sim.LIMIT): sim.spawn("Penitent", 0)
	Stage.configure(sim.world, 15)
	sim.spawn("Butcher", 0); sim.spawn("Butcher", 0)
	sim.round_number = 2
	sim.prepare_releases(["March", "March"])
	check(sim.units().size() == Sim.LIMIT and sim.staged_units().size() == 2, "full field defers the whole release safely without dropping or splitting bodies")
	check(Sim.Marching.valid(sim.world), "capacity deferral preserves a valid entity registry")

	for capacity in [12, 15]:
		sim = Sim.new("staging-overflow", true, true, false, capacity)
		for i in range(capacity): sim.spawn("Penitent", 0)
		sim.random_waves([0])
		sim.prepare_releases(["Hold", "Hold"])
		check(sim.units().is_empty(), "capacity %d: newborn overflow cannot bypass birth hold" % capacity)
		advance(sim)
		var old_count: int = sim.staged_units().size()
		sim.random_waves([0])
		sim.prepare_releases(["Hold", "Hold"])
		check(sim.units().size() == old_count and old_count > capacity, "capacity %d: complete oldest overflow cohort deploys without losing units" % capacity)
		check(sim.units().all(func(u): return u.attributes.staged_round == 1), "capacity %d: forced release contains only old units" % capacity)

	# The same draw streams and IDs survive a seat swap with protected reserves.
	var original_seats = Sim.new("lane-f881e7ec-e3aebe70", true, true, false, 15)
	var swapped = Sim.new("lane-f881e7ec-e3aebe70", true, true, true, 15)
	for number in range(1, 7):
		for arena in [original_seats, swapped]:
			arena.random_waves([0, 1]); arena.prepare_releases()
		check(Sim.mirror(original_seats.world) == swapped.world, "round %d: seat swap mirrors reserve identities, releases and formations" % number)
		advance(original_seats); advance(swapped)
		check(Sim.mirror(original_seats.world) == swapped.world, "round %d: actual swapped combat remains mirrored" % number)

	var arena = UI.new()
	arena.balance_preview = true
	root.add_child(arena)
	await process_frame
	check(arena.sim.world.data.marcher_staging.capacity == 15, "runner defaults to 15 protected slots")
	check(arena.speed.item_count == 5 and UI.SPEEDS == [0.5, 1.0, 2.0, 3.0, 5.0], "playback offers 3x and 5x")
	arena.request_spawn("Vulture")
	check(arena.sim.units().is_empty() and arena.field.staged_units.size() == 1, "manual production is visibly staged")
	var bounds := Rect2(Vector2.ZERO, arena.field.size)
	check(bounds.encloses(arena.field.staging_rect(0)) and bounds.encloses(arena.field.staging_rect(1)), "both staging trays fit inside the runner")
	check(not arena.field.staging_rect(0).intersects(arena.field.travel_rect("Lord")) and not arena.field.staging_rect(1).intersects(arena.field.travel_rect("Lord")), "staging trays stay visibly outside the battlefield")
	check(arena.field.staging_rect(1).end.y + arena.field.sprite_height <= arena.field.travel_rect("Lord").position.y, "far-gate monster sprites have clearance below the enemy reserve tray")
	arena.speed.select(4)
	arena.start()
	var deadline: int = Time.get_ticks_msec() + 10000
	while arena.job != null and Time.get_ticks_msec() < deadline: await process_frame
	check(arena.active, "a reserves-only interval still starts playback")
	arena._process(3.0)
	check(arena.sim.round_number == 2 and not arena.active and arena.sim.units().is_empty(), "5x finishes exactly one interval without releasing fresh units early")
	arena.release_choices[0].select(2)
	arena.start()
	check(arena.sim.units().size() == 1 and arena.sim.staged_units().is_empty(), "queued March releases the group at the next boundary")
	while arena.job != null and Time.get_ticks_msec() < deadline + 10000: await process_frame
	arena.pause()
	arena.queue_free()
	await process_frame
	print("U13 lane staging: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
