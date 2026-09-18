extends "res://Scripts/Sim/U13SupportHuntTestRunner.gd"

# Invoke only in an isolated project created by verify_monster_pair_balance.
# These assertions intentionally describe experimental rules, not live tuning.
func permanent_checks() -> void:
	for pid in [0, 1]:
		for kind in ["Melee", "Vulture", "Tower", "Muno", "Ambush", "Beam", "Kopita", "Poison"]:
			for roll in [49, 50]:
				var w: Dictionary = phase_world()
				var dog: Dictionary = put(w, "Tumler", pid, at(900, pid))
				var enemy: Dictionary = put(w, "Butcher", 1-pid, at(960, pid))
				var c: Dictionary = context(w, hunt_seed(enemy, dog, kind, roll))
				var expected: bool = roll == 49 and kind != "Poison"
				dog.attributes["hunt_target"] = enemy.id
				for extra in [{}, {"waiting": true}, {"movement_ready_round": 3}, {"rout_round": 2}, {"hidden": true}, {"step_fp": 0}]:
					var copy: Dictionary = dog.duplicate(true)
					copy.attributes.merge(extra, true)
					check(MonsterFX.evades(copy, enemy, [copy, enemy], c, 0, kind, [], {dog.id: true}) == expected, "permanent evasion boundary in every movement state: " + kind)
				check(not MonsterFX.evades(enemy, dog, [dog, enemy], c, 0, kind), "ordinary units do not gain evasion")
				# Monster abilities have an additional fear gate in production.
				# The permanent experiment must remove that gate as well.
				w.data.monsters.fields = [{"kind": "portal", "lane": dog.attributes.lane, "x_fp": dog.attributes.x_fp, "y_fp": dog.attributes.y_fp}]
				var ids = Marching.Buffer.new(); ids.restore(w.entities)
				var hit: Dictionary = {"source": enemy, "target": dog.id, "amount": 1, "bypass": false, "ability": kind}
				var r: Dictionary = MonsterFX.damage(w, ids, hit, c, 0, Callable(Game.Content.new(), "react"))
				var attacks: Array = facts(r, "MONSTER_ATTACK")
				check(attacks.size() == 1 and attacks[0].evaded == expected, "ability evasion remains active while feared: " + kind)

func leader_checks() -> void:
	for pid in [0, 1]:
		for name in ["Butcher", "Wright"]:
			var w: Dictionary = phase_world()
			var follower: Dictionary = put(w, name, pid, at(700, pid), {"wright_built": true, "wright_guard_until": 0})
			var leader: Dictionary = put(w, "Penitent", pid, at(700, pid))
			check(Pacing.speed(follower, [follower, leader], 4, 400, 2) == 1, "follower slows to let Penitent pass")
			check(Pacing.speed(follower, [follower], 4, 400, 2) == 4, "no Penitent means full speed")
			leader.attributes.contact_tick = 400
			check(Pacing.speed(follower, [follower, leader], 4, 400, 2) == 4, "melee contact releases follower")
			leader.attributes.contact_tick = -1
			for extra in [{"waiting": true}, {"movement_ready_round": 3}, {"rout_round": 2}, {"hidden": true}, {"y_fp": 600}, {"lane": "Castle"}]:
				var copy: Dictionary = leader.duplicate(true); copy.attributes.merge(extra, true)
				check(Pacing.speed(follower, [follower, copy], 4, 400, 2) == 4, "unavailable Penitent cannot slow follower")
			check(Pacing.speed(follower, [follower, leader], 4, 400, 2, {leader.id: true}) == 4, "fleeing Penitent cannot slow follower")
			if name == "Wright":
				follower.attributes.wright_built = false
				check(Pacing.speed(follower, [follower, leader], 4, 400, 2) == 4, "building keeps normal speed")
				follower.attributes.wright_built = true
				follower.attributes.wright_guard_until = 500
				check(Pacing.speed(follower, [follower, leader], 4, 400, 2) == 4, "guarding keeps normal speed")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1 or args[0] not in ["always", "leader"]:
		push_error("Expected always or leader in the matching isolated project")
		quit(1)
		return
	if args[0] == "always": permanent_checks()
	else: leader_checks()
	print("U13 pair experiment failures: ", failures)
	quit(0 if failures == 0 else 1)
