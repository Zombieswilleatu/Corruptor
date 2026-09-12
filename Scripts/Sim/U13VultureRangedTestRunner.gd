extends SceneTree

const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")
const Projectile = preload("res://Prototype/U13/U13VultureProjectile.gd")
const Lanes = preload("res://Prototype/U13/U13BoardLanes.gd")
var failures: int = 0

func _init() -> void:
	call_deferred("_run_suite")

func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func _world() -> Dictionary:
	return {"entities": Ids.new().snapshot(), "data": {"ranged_profile": Marching.Ranged.VERSION}}

func _add(world: Dictionary, name: String, owner: int, suit: String, x: int, changes: Dictionary = {}) -> String:
	var ids = Ids.new()
	ids.restore(world.entities)
	var a: Dictionary = Marching.profile(suit, "Castle", owner, 0, 1, true)
	a.x_fp = x
	a.merge(changes, true)
	var row: Dictionary = ids.create("marcher", name, 0, owner, a)
	world.entities = ids.snapshot()
	return row.entity.id

static func _reaction(world: Dictionary, _fact: Dictionary, _seed: String, _order: Array) -> Dictionary:
	return {"action": "resolved", "world": world, "events": []}

func _run(world: Dictionary, round_number: int = 1) -> Dictionary:
	return Marching.resolve({"world": world, "round": round_number, "hook": "marching", "seed": "ranged_fixture", "player_order": [0, 1]}, Callable(self, "_reaction"))

func _facts(result: Dictionary, kind: String) -> Array:
	var rows: Array = []
	for row in result.events:
		if row.event.type == kind:
			rows.append(row.event.data)
	return rows

func _run_suite() -> void:
	var content = preload("res://Scripts/Sim/U13Kanifous.gd").new()
	var current: Dictionary = preload("res://Scripts/Sim/U13KanifousScenario.gd").world()
	_check(content.valid_world(current), "current all-Lord world enables ranged Vultures")
	current.data.erase("ranged_profile")
	_check(not content.valid_world(current), "current world cannot remove ranged policy")
	var a: Dictionary = Marching.profile("Vulture", "Castle", 0, 0, 1, true)
	_check(a.attack == 2 and a.armor == 1 and a.step_fp == 4 and not a.armor_bypass, "Vulture 2 attack / 1 defense / 2 speed, no piercing")
	var world: Dictionary = _world()
	_add(world, "bird", 0, "Vulture", 500)
	_add(world, "guard", 1, "Penitent", 1400, {"step_fp": 0, "hp": 100, "max_hp": 100})
	var result: Dictionary = _run(world)
	_check(result.action == "resolved", "ranged Marching resolves")
	if result.action != "resolved":
		print(result)
		quit(1)
		return
	var shots: Array = _facts(result, "MARCHER_RANGED_ATTACK")
	_check(not shots.is_empty(), "Vulture advances and fires at range")
	var first: Dictionary = shots[0]
	_check(Marching.Ranged.distance(first.attacker.attributes, first.target.attributes) <= 800 * 800 and first.attacker.attributes.x_fp >= 600, "four-unit firing range")
	_check(first.damage_dealt == 0 and shots[1].damage_dealt == 1, "ranged attacks strip armor before health")
	_check(_facts(result, "MARCHER_CLASH").is_empty(), "Vulture holds range against stationary target")
	_check(shots[0].attacker.attributes.x_fp == shots.back().attacker.attributes.x_fp, "Vulture stops while firing")
	var cadence: bool = true
	for i in range(1, shots.size()):
		cadence = cadence and shots[i].tick - shots[i - 1].tick == 8
	_check(cadence, "one attack per eight ticks")
	_check(result == _run(world), "identical ranged tape and final state on replay")
	var restored: Dictionary = Marching.Data.copy_data(JSON.parse_string(JSON.stringify(result.world)))
	_check(Marching.valid(restored) and _run(restored, 2) == _run(result.world, 2), "ranged cooldown survives JSON round boundary")
	var playback = Playback.new()
	var tape: Array = []
	for row in result.events:
		tape.append(row.event)
	_check(playback.build(tape), "ranged tape builds presentation")
	var flight: Dictionary = playback.projectile_rows[0]
	var picture: Dictionary = playback.sample((flight.start + flight.end) / 2.0)
	_check(picture.projectiles.size() == 1 and is_equal_approx(picture.projectiles[0].weight, 0.5), "dagger flies halfway before recorded impact")
	_check(playback.sample(playback.duration).projectiles.is_empty(), "dagger ends without coin loop")
	_check(Projectile.KNIFE_CROP.end.x <= 2048.0 / 5.0, "knife crop stays in frame zero")
	var lanes = Lanes.new()
	root.add_child(lanes)
	lanes.show_frame(picture, 1)
	await process_frame
	await process_frame
	_check(lanes.projectiles.size() == 1, "main board receives projectile frame")
	lanes.reset_effects()
	_check(lanes.projectiles.is_empty(), "board reset clears projectiles")
	lanes.free()
	world = _world()
	_add(world, "bird", 0, "Vulture", 1000)
	_add(world, "guard", 1, "Penitent", 1100, {"step_fp": 0})
	result = _run(world)
	var clashes: Array = _facts(result, "MARCHER_CLASH")
	_check(not clashes.is_empty() and _facts(result, "MARCHER_RANGED_ATTACK").is_empty(), "Vulture still fights in melee")
	_check(clashes[0].exchanges[0].hp[1] == 5 and clashes[0].exchanges[0].armor[1] == 1, "melee also respects armor")
	world = _world()
	_add(world, "left", 0, "Vulture", 800, {"hp": 2, "armor": 0})
	_add(world, "right", 1, "Vulture", 1400, {"hp": 2, "armor": 0})
	result = _run(world)
	_check(_facts(result, "MARCHER_RANGED_ATTACK").size() == 2 and _facts(result, "MARCHER_DEFEATED").size() == 2 and result.world.entities.entities.is_empty(), "reciprocal lethal volley kills both exactly once")
	world = _world()
	_add(world, "left", 0, "Vulture", 800)
	_add(world, "other_lane", 1, "Penitent", 1400, {"lane": "Lord"})
	_check(_facts(_run(world), "MARCHER_RANGED_ATTACK").is_empty(), "Vultures cannot shoot across lanes")
	world = _world()
	world.data["rout_profile"] = Marching.Rout.VERSION
	_add(world, "routed", 0, "Vulture", 800, {"rout_round": 1, "rout_effect_id": "test_rout"})
	_add(world, "guard", 1, "Penitent", 1400, {"step_fp": 0})
	_check(_facts(_run(world), "MARCHER_RANGED_ATTACK").is_empty(), "retreating Vulture cannot fire")
	world = _world()
	_add(world, "bird", 0, "Vulture", 500)
	_add(world, "approaching", 1, "Penitent", 1300, {"hp": 100, "max_hp": 100, "step_fp": 20})
	result = _run(world)
	shots = _facts(result, "MARCHER_RANGED_ATTACK")
	clashes = _facts(result, "MARCHER_CLASH")
	_check(not shots.is_empty() and not clashes.is_empty(), "ranged Vulture switches to melee when enemy closes")
	_check(clashes[0].tick - shots.back().tick >= 8, "ranged-to-melee transition shares attack cooldown")
	world = _world()
	_add(world, "bird", 0, "Vulture", 500)
	_add(world, "fragile", 1, "Penitent", 1300, {"hp": 1, "armor": 0, "step_fp": 0})
	result = _run(world)
	_check(result.world.entities.entities[0].attributes.x_fp > 500, "Vulture resumes marching after target dies")
	print("U13 Vulture ranged failures: %d" % failures)
	quit(0 if failures == 0 else 1)
