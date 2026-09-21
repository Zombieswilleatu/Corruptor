extends "res://Scripts/Sim/U13TumlerFollowThroughTestRunner.gd"

func crowded_phase(pid: int) -> void:
	var w: Dictionary = phase_world()
	var dog: Dictionary = put(w, "Tumler", pid, at(700, pid), {"hp": 100, "max_hp": 100})
	var prey: Dictionary = put(w, "Sooge", 1-pid, at(1100, pid), {"step_fp": 0, "hp": 100, "max_hp": 100, "armor": 100, "sooge_root_round": 2, "beam_next_tick": 10000})
	# Ordinary field bodies occupy all six original lateral landing spots.
	for i in range(7):
		put(w, "Penitent", 1-pid, at(750, pid), {"y_fp": 300 + [0, 84, -84, 126, -126, 168, -168][i], "step_fp": 0, "hp": 100, "max_hp": 100, "armor": 100, "attack": 1}, i)
	var r: Dictionary = phase("committed_crowd_%d" % pid, w)
	check(facts(r, "MONSTER_CHARGE_ENDED").any(func(d): return d.unit_id == dog.id and d.reason == "target"), "crowded full-phase charge reaches the backliner")
	check(not facts(r, "MONSTER_CHARGE_ENDED").any(func(d): return d.reason in ["blocked", "timeout", "interrupted"]), "crowding never returns Tumler to ordinary avoidance")
	check(facts(r, "MARCHER_MELEE_ATTACK").any(func(d): return d.attacker.id == dog.id and d.target.id == prey.id), "the crowded rush follows through into attacks on its marked victim")
	# The same scenario still permits death during the wind-up.
	w = phase_world()
	dog = put(w, "Tumler", pid, at(700, pid), {"hp": 1, "armor": 0})
	prey = put(w, "Vulture", 1-pid, at(1100, pid), {"step_fp": 0, "hp": 100, "max_hp": 100})
	var killer: Dictionary = put(w, "Butcher", 1-pid, at(740, pid), {"step_fp": 0, "attack": 100})
	r = phase("committed_killed_%d" % pid, w, hunt_seed(killer, dog, "Melee", 50))
	check(facts(r, "MARCHER_DEFEATED").any(func(d): return d.victim.id == dog.id), "a committed charger remains killable")
	check(facts(r, "MONSTER_CHARGE_LAUNCHED").is_empty(), "a killed charger cannot complete its rush")

func forced_motion_checks(pid: int) -> void:
	var w: Dictionary = phase_world()
	var dog: Dictionary = put(w, "Tumler", pid, at(700, pid))
	put(w, "Vulture", 1-pid, at(1100, pid), {"step_fp": 0})
	var buffer = buffer_for(w)
	Charge.step(buffer, [], context(w), 0, {})
	var armed: Dictionary = buffer.get_entity(dog.id)
	var actor: Dictionary = {"active": false, "radius_fp": 100, "x_fp": at(300, pid), "y_fp": 300, "fleeing": {dog.id: {"remaining_ms": 1000, "carry_x": 0.0, "carry_y": 0.0, "unit": armed}}}
	check(Marching.KroniActors._flee_slice(actor, buffer, 30).is_empty() and buffer.get_entity(dog.id).attributes == armed.attributes, "Kroni fear cannot move the braced charger")
	check(actor.fleeing[dog.id].remaining_ms == 970, "suppressed fear still spends its duration")
	w.entities = buffer.snapshot()
	w.data.monsters.fields.append({"kind": "portal", "id": "commitment-fear", "owner": 1-pid, "source_id": "absent", "target_id": dog.id, "lane": "Lord", "x_fp": at(820, pid), "y_fp": 300, "expires_round": 2})
	var result: Dictionary = MonsterFX.step(w, buffer, context(w), 1, Callable(Game.Content.new(), "react"))
	check(result.action == "resolved" and not result.fleeing.has(dog.id) and buffer.get_entity(dog.id).attributes.x_fp == armed.attributes.x_fp, "portal fear cannot displace the braced charger")
	# Banishment still removes a body; it is not mere collision or avoidance.
	w = result.world
	w.data.monsters.fields[0].x_fp = armed.attributes.x_fp
	result = MonsterFX.step(w, buffer, context(w), 2, Callable(Game.Content.new(), "react"))
	check(buffer.get_entity(dog.id).is_empty(), "entering a portal can still remove a charger")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	for pid in [0, 1]:
		crowded_phase(pid)
		forced_motion_checks(pid)
	if phase_output != null: phase_output.close()
	print("U13 Tumler commitment failures: ", failures)
	quit(1 if failures else 0)
