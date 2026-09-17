extends SceneTree

const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Monsters = preload("res://Scripts/Sim/U13MonsterRules.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
var failures: int = 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

static func reaction(world: Dictionary, _fact: Dictionary, _seed: String, _order: Array) -> Dictionary:
	return {"action": "resolved", "world": world, "events": []}

func march(a: Dictionary, pid: int, data: Dictionary = {}) -> Dictionary:
	var ids = Ids.new()
	ids.create("marcher", "movement_balance", 0, pid, a)
	data = data.duplicate(true)
	data["ranged_profile"] = Marching.Ranged.VERSION
	var result: Dictionary = Marching.resolve({"world": {"entities": ids.snapshot(), "data": data}, "round": 1, "hook": "marching", "seed": "movement_balance", "player_order": [0, 1]}, Callable(self, "reaction"))
	check(result.action == "resolved", "movement fixture resolves")
	return result.world.entities.entities[0].attributes if result.action == "resolved" else {}

func run() -> void:
	# Isolate travel from attacks and abilities, for both owners and every body.
	var names: Array = Marching.SUITS + Monsters.NAMES
	for name in names:
		for pid in [0, 1]:
			var a: Dictionary = Marching.profile(name, "Castle", pid, 0, 1, true) if name in Marching.SUITS else Monsters.profile(name, "Castle", pid, 0, 1)
			var before: int = int(a.x_fp)
			var moved: Dictionary = march(a, pid)
			check(not moved.is_empty() and absi(int(moved.x_fp) - before) == int(a.step_fp) * 150, "%s owner %d travels 75%% over 200 ticks" % [name, pid])
	var penitent: Dictionary = Marching.profile("Penitent", "Lord", 0, 0, 1, true)
	penitent.merge({"x_fp": 1200, "rout_round": 1, "rout_effect_id": "balance_rout"}, true)
	check(march(penitent, 0, {"rout_profile": Marching.Rout.VERSION}).x_fp == 750, "retreat also moves 450 instead of 600")
	var rooted: Dictionary = Monsters.profile("Sooge", "Castle", 0, 0, 1, true)
	check(march(rooted, 0).x_fp == 0, "rooted Sooge remains stationary")
	# Odd base speed and several simultaneous modifiers must not truncate per tick.
	var distance: int = 0
	for clock in range(800):
		distance += Marching.LaneAuras.speed(3, 25, true, clock, true, false, 75, true)
	check(distance == 281, "3 speed, 25% bonus, recovery, Web and pool retain fractional movement")
	print("U13 marching balance failures: %d" % failures)
	quit(0 if failures == 0 else 1)
