extends "res://Scripts/Sim/U13MonsterTestRunner.gd"

const Stage = preload("res://Scripts/Sim/U13LaneStaging.gd")

func saved_world(w: Dictionary) -> Dictionary:
	var saved: Dictionary = JSON.parse_string(Game.encode_snapshot(w))
	var restored: Dictionary = bytes_to_var(Marshalls.base64_to_raw(saved.payload))
	check(restored == w and Marching.valid(restored), "save transport preserves Dotra's timer and spent concealment")
	return restored

func timing_checks() -> void:
	for pid in [0, 1]:
		for seed_value in ["timed-hide:0", "timed-hide:1"]:
			var tag: String = "%d:%s" % [pid, seed_value]
			var w: Dictionary = phase_world()
			var start: int = 800 if pid == 0 else 1600
			var actor: Dictionary = put(w, "Dotra", pid, start, {"birth_round": 2, "movement_ready_round": 3, "step_fp": 0})
			var result: Dictionary = phase("timed_birth_hold:" + tag, w, seed_value)
			var a: Dictionary = Kanifous._entity(result.world, actor.id).attributes
			check(not a.has("dotra_hide_at_tick") and facts(result, "MONSTER_CONCEALMENT").is_empty(), "birth hold does not start the hide timer")
			result = phase("timed_first_interval:" + tag, result.world, seed_value, 3)
			a = Kanifous._entity(result.world, actor.id).attributes
			check(a.dotra_hide_at_tick == 800 and not a.get("hidden", false) and facts(result, "MONSTER_CONCEALMENT").is_empty(), "Dotra stays visible for all 200 ticks of his first field interval")
			result = phase("timed_hide:" + tag, saved_world(result.world), seed_value, 4)
			var hides: Array = facts(result, "MONSTER_CONCEALMENT")
			a = Kanifous._entity(result.world, actor.id).attributes
			check(hides.size() == 1 and hides[0].tick == 0 and a.hidden and a.dotra_concealment_round == 4, "both seats and seeds hide exactly at the next interval boundary")
			var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
			check(playback.build(result.events.map(func(r): return r.event)), "timed concealment replay builds")
			var at: float = playback.tick_time(0)
			check(not playback.sample(at - 0.0001).units[0].attributes.get("hidden", false) and playback.sample(at + 0.0001).units[0].attributes.hidden, "playback conceals Dotra on the recorded trigger tick")
			result = phase("timed_stalking:" + tag, result.world, seed_value, 5)
			check(Kanifous._entity(result.world, actor.id).attributes.hidden and facts(result, "MONSTER_CONCEALMENT").is_empty(), "concealment persists without another trigger while no enemy is in range")
			w = result.world
			var prey: Dictionary = put(w, "Butcher", 1 - pid, start + (240 if pid == 0 else -240), {"hp": 100, "max_hp": 100, "armor": 0, "step_fp": 0})
			result = phase("timed_ambush:" + tag, w, seed_value, 6)
			var ambushes: Array = facts(result, "MONSTER_ATTACK").filter(func(d): return d.ability == "Ambush")
			var pulses: Array = facts(result, "MONSTER_EXPOSURE_PULSE")
			check(ambushes.size() == 1 and ambushes[0].damage_dealt == 5 and ambushes[0].target.id == prey.id and pulses.size() == 1, "guaranteed hide still produces the 5-damage ambush and exposure pulse")
			result = phase("timed_spent:" + tag, saved_world(result.world), seed_value, 7)
			check(not Kanifous._entity(result.world, actor.id).attributes.hidden and facts(result, "MONSTER_CONCEALMENT").is_empty() and facts(result, "MONSTER_EXPOSURE_PULSE").is_empty(), "the one concealment stays spent after emergence and save/load")

func staging_checks() -> void:
	for pid in [0, 1]:
		var w: Dictionary = phase_world()
		Stage.configure(w, 15)
		var actor: Dictionary = put(w, "Dotra", pid, 0 if pid == 0 else 2400, {"step_fp": 0})
		Stage.store_units(w, [actor.id], 2)
		var original: Array = Stage.rows(w).duplicate(true)
		for n in [2, 3, 4]:
			Stage.prepare(w, n, ["Hold", "Hold"])
			w = phase("timed_staged:%d:%d" % [pid, n], w, "timed-staging", n).world
		check(Stage.rows(w) == original and not Stage.rows(w)[0].attributes.has("dotra_hide_at_tick"), "three protected intervals do not consume any of the hide delay")
		Stage.prepare(w, 5, ["March", "March"])
		var result: Dictionary = phase("timed_released:%d" % pid, w, "timed-staging", 5)
		var a: Dictionary = Kanifous._entity(result.world, actor.id).attributes
		check(a.dotra_hide_at_tick == 1200 and not a.get("hidden", false), "late release starts a fresh 15-second field interval")
		result = phase("timed_after_release:%d" % pid, result.world, "timed-staging", 6)
		check(facts(result, "MONSTER_CONCEALMENT").size() == 1 and Kanifous._entity(result.world, actor.id).attributes.hidden, "Dotra hides after the release interval for either seat")

func partial_interval_check() -> void:
	# A recruit awakened mid-round gets a full 200 ticks, not a shortened wait.
	var w: Dictionary = phase_world()
	var actor: Dictionary = put(w, "Dotra", 0, 800, {"step_fp": 0})
	var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
	var content = Game.Content.new()
	MonsterFX.step(w, buffer, context(w), 37, Callable(content, "react"))
	w.entities = buffer.snapshot()
	check(Kanifous._entity(w, actor.id).attributes.dotra_hide_at_tick == 637, "mid-round activation schedules a full interval from its first active tick")
	w.data.marching_round = 2
	var result: Dictionary = phase("timed_mid_round", saved_world(w), "timed-hide:mid-round", 3)
	var hides: Array = facts(result, "MONSTER_CONCEALMENT")
	check(hides.size() == 1 and hides[0].tick == 37, "mid-round hide fires exactly 200 ticks later after save/load")
	var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
	check(playback.build(result.events.map(func(r): return r.event)), "mid-round timer replay builds")
	var at: float = playback.tick_time(37)
	check(not playback.sample(at - 0.0001).units[0].attributes.get("hidden", false) and playback.sample(at + 0.0001).units[0].attributes.hidden, "mid-round playback stays visible until the timer expires")

func target_order_checks() -> void:
	for pid in [0, 1]:
		for kind in ["Muno", "Sinodek", "Sooge", "Tumler"]:
			var w: Dictionary = phase_world()
			var actor: Dictionary = put(w, "Dotra", pid, 800 if pid == 0 else 1600, {"step_fp": 0, "dotra_hide_at_tick": 400})
			var extra: Dictionary = {"step_fp": 0}
			if kind == "Sooge": extra.merge({"sprite_form": "turret", "attack": 3, "armor": 6, "max_armor": 6})
			var enemy: Dictionary = put(w, kind, 1 - pid, 1200, extra)
			var result: Dictionary = phase("timed_target_order:%d:%s" % [pid, kind], w, selected_seed(enemy.id, "PORTAL", 25))
			var alive: Dictionary = Kanifous._entity(result.world, actor.id)
			check(not alive.is_empty() and alive.attributes.hidden and alive.attributes.hp == 10 and alive.attributes.armor == 2, "concealment precedes " + kind + " target selection for either seat")
			check(facts(result, "MONSTER_ATTACK").is_empty() and facts(result, "MONSTER_FIELD_CREATED").is_empty() and facts(result, "MONSTER_BEAM_FIRED").is_empty(), kind + " cannot acquire Dotra on his hide tick")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0: phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	timing_checks()
	staging_checks()
	partial_interval_check()
	target_order_checks()
	if phase_output != null: phase_output.close()
	print("U13 Dotra timing failures: ", failures)
	quit(0 if failures == 0 else 1)
