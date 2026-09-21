extends "res://Scripts/Sim/U13TumlerChargeTestRunner.gd"

func landed(pid: int) -> Dictionary:
	var w: Dictionary = phase_world()
	var dog: Dictionary = put(w, "Tumler", pid, at(700, pid), {"hp": 100, "max_hp": 100})
	var prey: Dictionary = put(w, "Vulture", 1-pid, at(1100, pid), {"step_fp": 0, "hp": 100, "max_hp": 100, "armor": 0, "attack": 1})
	var buffer = buffer_for(w)
	var events: Array = []
	for tick in range(20): events.append_array(Charge.step(buffer, [], context(w), tick, {}))
	dog = buffer.get_entity(dog.id)
	check(events.any(func(e): return e.event.type == "MONSTER_CHARGE_ENDED" and e.event.data.reason == "target"), "setup reaches prey through the actual charge")
	w.entities = buffer.snapshot()
	return {"world": w, "dog": dog, "prey": prey}

func commitment_checks(pid: int) -> void:
	var setup: Dictionary = landed(pid)
	var w: Dictionary = setup.world
	var dog: Dictionary = setup.dog
	var prey: Dictionary = setup.prey
	var priority: Dictionary = put(w, "Sooge", 1-pid, at(1400, pid), {"step_fp": 0, "hp": 100, "max_hp": 100, "sooge_root_round": 2, "beam_next_tick": 10000})
	put(w, "Vulture", 1-pid, int(dog.attributes.x_fp), {"y_fp": 342, "step_fp": 0, "attack": 1}, 1)
	var buffer = buffer_for(w)
	check(Charge.select_target(dog, buffer.marchers(), 420).id == prey.id, "landing retains prey despite a new Sooge and nearer Vulture")
	check(MonsterFX.preferred(dog, buffer.marchers()).id == prey.id and MonsterFX.hunt_bonus(dog, prey) == 1, "follow-through keeps the ordinary hunt bonus on the same victim")
	var encoded: String = Game.encode_snapshot(w)
	var restored: Dictionary = bytes_to_var(Marshalls.base64_to_raw(JSON.parse_string(encoded).payload))
	check(restored == w and Marching.valid(restored), "save transport preserves engagement")
	for value in [null, "", 2, true]:
		var invalid: Dictionary = dog.attributes.duplicate(true)
		invalid["tumler_engaged_target"] = value
		check(not Monsters.valid_unit(invalid), "invalid engagement identity rejected")
	for value in [null, "0", 2, true]:
		var invalid: Dictionary = dog.attributes.duplicate(true)
		invalid["tumler_engaged_owner"] = value
		check(not Monsters.valid_unit(invalid), "invalid engagement owner rejected")
	var r: Dictionary = phase("followthrough_new_priority_%d" % pid, restored)
	var hits: Array = facts(r, "MARCHER_MELEE_ATTACK").filter(func(d): return d.attacker.id == dog.id)
	check(not hits.is_empty() and hits.all(func(d): return d.target.id == prey.id), "the full combat phase keeps attacking the surviving charge victim")
	if r.action == "resolved":
		var next: Dictionary = phase("followthrough_round_boundary_%d" % pid, r.world, "monster-check", 3)
		var next_hits: Array = facts(next, "MARCHER_MELEE_ATTACK").filter(func(d): return d.attacker.id == dog.id)
		check(not next_hits.is_empty() and next_hits.all(func(d): return d.target.id == prey.id), "engagement survives the next round")
	# A moving victim must not let an unrelated melee hit steal the mark.
	var moved: Dictionary = buffer.get_entity(prey.id)
	moved.attributes.x_fp = at(1250, pid)
	buffer.update(moved.id, moved.owner, moved.attributes)
	check(MonsterFX.intercept(dog, priority, buffer.marchers(), context(w), 20).is_empty(), "bystander hits do not break an established engagement")
	for reason in ["death", "hidden", "target_charmed", "other_lane", "owner", "fear", "rout"]:
		buffer = buffer_for(w)
		var live: Dictionary = buffer.get_entity(dog.id)
		var target: Dictionary = buffer.get_entity(prey.id)
		var fleeing: Dictionary = {}
		if reason == "death": buffer.retire(prey.id)
		elif reason == "hidden": target.attributes.hidden = true
		elif reason == "target_charmed": target.owner = pid
		elif reason == "other_lane": target.attributes.lane = "Castle"
		elif reason == "owner": live.owner = 1-pid
		elif reason == "fear": fleeing[dog.id] = true
		elif reason == "rout": live.attributes["rout_round"] = 2
		if reason != "death": buffer.update(target.id, target.owner, target.attributes)
		buffer.update(live.id, live.owner, live.attributes)
		Charge.step(buffer, [], context(w), 20, fleeing)
		live = buffer.get_entity(dog.id)
		check(live.attributes.get("tumler_engaged_target", "").is_empty(), reason + " releases the commitment")
		check(Monsters.valid_unit(live.attributes), "cleared commitment remains valid after " + reason)
		if reason in ["death", "hidden", "target_charmed", "other_lane"]:
			check(Charge.select_target(live, buffer.marchers(), 420).id == priority.id, "next hunt resumes Sooge-first priority after " + reason)
	# The original rule only protects wind-up and charging from taunt.
	var taunt: Dictionary = put(w, "Kurchin", 1-pid, at(1170, pid), {"step_fp": 0})
	buffer = buffer_for(w)
	check(MonsterFX.preferred(dog, buffer.marchers()).id == taunt.id, "Kurchin can still taunt after landing")
	for reason in ["wall", "blocked", "target_lost", "interrupted", "timeout"]:
		var stopped: Dictionary = dog.duplicate(true)
		Charge.finish(stopped, context(w), 21, reason)
		check(stopped.attributes.get("tumler_engaged_target", "").is_empty(), reason + " does not retain a completed-charge commitment")
	# The replay is relative to phase-start attributes, so the clear must be
	# represented explicitly when a previously marked victim dies this phase.
	w = setup.world.duplicate(true)
	buffer = buffer_for(w)
	buffer.retire(taunt.id)
	var dying: Dictionary = buffer.get_entity(prey.id)
	dying.attributes.hp = 1
	buffer.update(dying.id, dying.owner, dying.attributes)
	w.entities = buffer.snapshot()
	r = phase("followthrough_prey_dies_%d" % pid, w)
	var playback = Playback.new()
	check(playback.build(r.events.map(func(e): return e.event)), "engagement release builds a replay")
	var frames: Array = facts(r, "MARCHING_TICK")
	var final_tick: Dictionary = frames.back().units.filter(func(u): return u.id == dog.id)[0]
	check(final_tick.attributes.get("tumler_engaged_target", "missing") == "", "delta tape explicitly clears the dead prey")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	for pid in [0, 1]: commitment_checks(pid)
	if phase_output != null: phase_output.close()
	print("U13 Tumler follow-through failures: ", failures)
	quit(1 if failures else 0)
