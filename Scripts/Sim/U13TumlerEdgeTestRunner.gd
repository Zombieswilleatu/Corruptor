extends "res://Scripts/Sim/U13SupportHuntTestRunner.gd"

const Spacing = preload("res://Scripts/Sim/U13MarcherSpacing.gd")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	for pid in [0, 1]:
		for bottom in [false, true]:
			for start in [800, 1000]:
				var w: Dictionary = phase_world()
				var y: int = 570 if bottom else 30
				var dog: Dictionary = put(w, "Tumler", pid, at(start, pid), {"y_fp": y, "hp": 100, "max_hp": 100, "armor": 100})
				var prey: Dictionary = put(w, "Vulture", 1-pid, at(1000, pid), {"y_fp": 250 if bottom else 350, "step_fp": 0, "hp": 100, "max_hp": 100, "armor": 100})
				set_target(w, dog, prey)
				w.data.monsters.fields = [{"kind": "pool", "id": "edge-pool", "owner": 1-pid, "lane": "Lord", "x_fp": at(1000, pid), "y_fp": 420 if bottom else 180, "expires_round": 3}]
				var r: Dictionary = phase("pool_edge_%d_%s_%d" % [pid, str(bottom), start], w)
				var after: Dictionary = Kanifous._entity(r.world, dog.id)
				check(not after.is_empty() and (int(after.attributes.y_fp)-y)*(1 if not bottom else -1) > 200, "Tumler leaves the pool detour at the arena edge")
				check(facts(r, "MARCHER_MELEE_ATTACK").any(func(e): return e.attacker.id == dog.id and e.target.id == prey.id), "Tumler reaches and attacks the prey inside the pool")
				check(MonsterFX.slowed(after.attributes, w.data.monsters.fields), "escaping avoidance does not remove the pool slowdown")
			var w: Dictionary = phase_world()
			var y: int = 600 if bottom else 0
			var dog: Dictionary = put(w, "Tumler", pid, at(1000, pid), {"y_fp": y, "hp": 100, "max_hp": 100, "armor": 100}, 0 if bottom else 1)
			put(w, "Butcher", pid, at(1042, pid), {"y_fp": y, "step_fp": 0, "hp": 100, "max_hp": 100, "armor": 100})
			var prey: Dictionary = put(w, "Vulture", 1-pid, at(1500, pid), {"y_fp": y, "step_fp": 0, "hp": 100, "max_hp": 100, "armor": 100})
			set_target(w, dog, prey)
			var r: Dictionary = phase("body_edge_%d_%s" % [pid, str(bottom)], w)
			var first: Dictionary = facts(r, "MARCHING_TICK")[0].units.filter(func(u): return u.id == dog.id)[0]
			check(int(first.attributes.y_fp) != y, "first blocked tick takes the free inward sidestep")
			check(facts(r, "MARCHER_MELEE_ATTACK").any(func(e): return e.attacker.id == dog.id and e.target.id == prey.id), "Tumler clears a friendly body at the edge and reaches prey")
			slide_checks(pid, bottom)
		# Keep real pool detours, but ignore pools behind or beyond the prey.
		var w: Dictionary = phase_world()
		var dog: Dictionary = put(w, "Tumler", pid, at(800, pid), {"y_fp": 160})
		var prey: Dictionary = put(w, "Vulture", 1-pid, at(1600, pid), {"y_fp": 160})
		var field: Dictionary = {"kind": "pool", "lane": "Lord", "x_fp": at(1000, pid), "y_fp": 180}
		var heading: Dictionary = MonsterFX.steer(dog, prey.attributes, [dog, prey], [field])
		check(heading.x_fp == field.x_fp and heading.y_fp == 30, "a pool ahead still produces an avoidance detour")
		prey.attributes.x_fp = at(1100, pid)
		for x in [700, 1150]:
			field.x_fp = at(x, pid)
			check(MonsterFX.steer(dog, prey.attributes, [dog, prey], [field]) == prey.attributes, "pools behind or beyond the prey do not divert the hunt")
	if phase_output != null: phase_output.close()
	print("U13 Tumler edge failures: ", failures)
	quit(1 if failures else 0)

func slide_checks(pid: int, bottom: bool) -> void:
	for vertical in [false, true]:
		var w: Dictionary = phase_world()
		var x: int = (2400 if bottom else 0) if vertical else 1000
		var y: int = 300 if vertical else (600 if bottom else 0)
		var dog: Dictionary = put(w, "Tumler", pid, x, {"y_fp": y})
		# Select the deterministic outward-first sidestep for this edge/seat.
		var positive: bool = bottom if not vertical or pid == 0 else not bottom
		dog.id = "edge0" if positive else "edge1"
		var blocker: Dictionary = put(w, "Butcher", pid, x if vertical else x+42, {"y_fp": y+42 if vertical else y})
		var proposed: Dictionary = dog.attributes.duplicate(true)
		if vertical: proposed.y_fp += 6
		else: proposed.x_fp += 6
		var moved: Dictionary = Spacing.slide(dog, proposed, [dog, blocker], [], 6)
		check(Fort.distance(moved, dog.attributes) == 36 and Spacing.clear(dog, moved, [dog, blocker], []), "all four edges reject zero-distance sidesteps and preserve collision clearance")
		# If both perpendicular steps are genuinely blocked, remain in place.
		var stopper: Dictionary = put(w, "Butcher", pid, x+( -42 if bottom else 42) if vertical else x, {"y_fp": y if vertical else y+(-42 if bottom else 42)}, 1)
		moved = Spacing.slide(dog, proposed, [dog, blocker, stopper], [], 6)
		check(Fort.distance(moved, dog.attributes) == 0, "a fully blocked unit does not clip through an ally")
