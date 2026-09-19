extends "res://Scripts/Sim/U13MonsterTestRunner.gd"

func responsive_pulses() -> void:
	for pid in [0, 1]:
		var direction: int = 1 if pid == 0 else -1
		var w: Dictionary = phase_world()
		var healer: Dictionary = put(w, "Kopita", pid, 1200, {"hp": 9, "step_fp": 0})
		var enemy: Dictionary = put(w, "Butcher", 1-pid, 1200 + direction * 300, {"step_fp": 0, "armor": 0})
		var result: Dictionary = phase("kopita_heal_then_harm_%d" % pid, w)
		var pulses: Array = facts(result, "MONSTER_PULSE")
		check(pulses.size() == 2 and pulses[0].tick == 0 and pulses[0].healing and pulses[1].tick == 133 and not pulses[1].healing, "Kopita reevaluates wounds at each pulse and switches to harm once everyone is healthy")
		check(Kanifous._entity(result.world, healer.id).attributes.hp == 10 and Kanifous._entity(result.world, enemy.id).attributes.hp == 4, "healing and harm each apply exactly one point")
		var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
		check(playback.build(result.events.map(func(r): return r.event)), "both pulses build a valid replay")
		var at: float = playback.tick_time(133)
		check(absf(15.0 * at / playback.duration - 10.0) < 0.5, "second pulse lands around ten seconds on the 15-second test clock")
		check(playback.sample(at - 0.0001).monster_attacks.is_empty() and playback.sample(at + 0.0001).monster_attacks.any(func(a): return a.ability == "KopitaPulse" and not a.healing), "second pulse appears at its own recorded time")
		w = phase_world()
		healer = put(w, "Kopita", pid, 1200, {"step_fp": 0})
		put(w, "Vulture", 1-pid, 1200 + direction * 300)
		result = phase("kopita_harm_then_heal_%d" % pid, w)
		pulses = facts(result, "MONSTER_PULSE")
		check(pulses.size() == 2 and not pulses[0].healing and pulses[1].healing and pulses[1].healed.any(func(h): return h.id == healer.id), "damage taken during the round makes the second pulse heal")
		w = phase_world()
		healer = put(w, "Kopita", pid, 1200, {"step_fp": 0})
		var edge: Dictionary = put(w, "Butcher", pid, 1200 + direction * 360, {"hp": 4, "step_fp": 0})
		put(w, "Butcher", pid, 1200 + direction * 361, {"hp": 4, "step_fp": 0}, 1)
		put(w, "Butcher", pid, 1200, {"hp": 4, "step_fp": 0, "lane": "Castle"}, 2)
		result = phase("kopita_wound_selection_range_%d" % pid, w)
		pulses = facts(result, "MONSTER_PULSE")
		check(pulses.size() == 2 and pulses[0].healing and pulses[0].healed.size() == 1 and pulses[0].healed[0].id == edge.id and not pulses[1].healing, "only a wounded ally within the true radius selects healing")
		w = phase_world()
		healer = put(w, "Kopita", pid, 1200, {"birth_round": 2, "movement_ready_round": 3, "hp": 100, "max_hp": 100})
		put(w, "Vulture", 1-pid, 1200 + direction * 300)
		result = phase("kopita_woken_birth_hold_%d" % pid, w)
		check(facts(result, "MONSTER_PULSE").is_empty(), "being attacked cannot bypass the birth hold to cast the later pulse")

func pulse_save_checks() -> void:
	var w: Dictionary = phase_world()
	var healer: Dictionary = put(w, "Kopita", 0, 1200, {"hp": 5, "step_fp": 0})
	var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
	var react: Callable = Callable(Game.Content.new(), "react")
	var first: Dictionary = MonsterFX.step(w, buffer, context(w), 0, react)
	check(facts(first, "MONSTER_PULSE").size() == 1, "first scheduled pulse occurs")
	w.entities = buffer.snapshot()
	var saved: Dictionary = JSON.parse_string(Game.encode_snapshot(w))
	var restored: Dictionary = bytes_to_var(Marshalls.base64_to_raw(saved.payload))
	check(restored == w and Monsters.valid(restored), "save transport retains the pulse clock")
	buffer.restore(restored.entities)
	for tick in [0, 1, 132]:
		var idle: Dictionary = MonsterFX.step(restored, buffer, context(restored), tick, react)
		check(facts(idle, "MONSTER_PULSE").is_empty(), "reload cannot duplicate a pulse or cast between scheduled times")
	var second: Dictionary = MonsterFX.step(restored, buffer, context(restored), 133, react)
	check(facts(second, "MONSTER_PULSE").size() == 1 and buffer.get_entity(healer.id).attributes.hp == 7, "reload preserves the second pulse's single heal")
	check(facts(MonsterFX.step(restored, buffer, context(restored), 133, react), "MONSTER_PULSE").is_empty(), "the second pulse cannot be repeated")
	var next: Dictionary = context(restored); next.round = 3
	check(facts(MonsterFX.step(restored, buffer, next, 0, react), "MONSTER_PULSE").size() == 1, "a new round starts a fresh pair of pulse opportunities")
	for key in ["kopita_pulses", "kopita_last_pulse_tick"]:
		for value in [-1, 0.5, "1", true, null]:
			var forged: Dictionary = healer.attributes.duplicate(true); forged[key] = value
			check(not Monsters.valid_unit(forged), "invalid pulse counters are rejected")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	responsive_pulses()
	pulse_save_checks()
	if phase_output != null: phase_output.close()
	print("U13 responsive pulse check failures: ", failures)
	quit(0 if failures == 0 else 1)
