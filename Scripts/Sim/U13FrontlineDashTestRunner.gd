extends "res://Scripts/Sim/U13MonsterTierTuningTestRunner.gd"

func melee_block_seed(source: Dictionary, target: Dictionary, roll: int) -> String:
	for i in range(4000):
		var candidate: String = "frontline-block:" + str(i)
		if MonsterFX.Lamp.draw(candidate, "2:0:VultureMelee:%s:%s" % [source.id, target.id], "PENITENT_RANGED_BLOCK", 100) == roll: return candidate
	check(false, "find exact Penitent block boundary roll")
	return "missing"

func melee_block_checks() -> void:
	for pid in [0, 1]:
		for roll in [49, 50]:
			for bonuses in [false, true]:
				var w: Dictionary = phase_world()
				var extra: Dictionary = {"hp": 10, "max_hp": 10, "armor": 2, "step_fp": 0, "birth_round": 2, "movement_ready_round": 3}
				if bonuses: extra.merge({"dotra_exposed_from_tick": 400, "dotra_exposed_until_tick": 600, "rout_round": 2, "rout_effect_id": "block-rout"})
				var target: Dictionary = put(w, "Penitent", pid, 1000, extra)
				var source: Dictionary = put(w, "Vulture", 1-pid, 1060, {"attack": 3, "hp": 100, "max_hp": 100, "step_fp": 0})
				var seed_value: String = melee_block_seed(source, target, roll)
				var result: Dictionary = direct("vulture_melee_block_%d_%d_%s" % [pid, roll, bonuses], "melee", w, {"seed": seed_value})
				var hits: Array = facts(result, "MARCHER_MELEE_ATTACK").filter(func(h): return h.target.id == target.id)
				var after: Dictionary = Kanifous._entity(result.world, target.id).attributes
				var blocked: bool = roll == 49
				check(hits.size() == 1 and hits[0].blocked == blocked, "melee block includes roll 49 and excludes roll 50")
				check(after.armor == (2 if blocked else 0) and after.hp == (10 if blocked else (7 if bonuses else 9)), "block prevents Armor, HP, exposure and Rout damage; unblocked hits remain normal")
				check(after.movement_ready_round == 2 and Kanifous._entity(result.world, source.id).attributes.melee_next_tick == 434, "blocked melee wakes the recruit and spends the Vulture attack")
				if blocked and not bonuses:
					var full: Dictionary = phase("vulture_melee_block_playback_%d" % pid, w, seed_value)
					var replay = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
					check(replay.build(full.events.map(func(r): return r.event)), "melee block replay builds")
					check(replay.sample(replay.tick_time(0)+0.01).monster_attacks.any(func(a): return a.ability == "RangedBlock" and a.target_id == target.id), "Vulture melee block has the shield feedback")
		for attacker_name in ["Butcher", "Penitent", "Wright", "Lemek", "Muno"]:
			var w: Dictionary = phase_world()
			var target: Dictionary = put(w, "Penitent", pid, 1000, {"hp": 100, "max_hp": 100, "armor": 0, "step_fp": 0})
			var source: Dictionary = put(w, attacker_name, 1-pid, 1060, {"attack": 3, "hp": 100, "max_hp": 100, "step_fp": 0})
			var result: Dictionary = direct("non_vulture_melee_%d_%s" % [pid, attacker_name], "melee", w, {"seed": melee_block_seed(source, target, 0)})
			var hit: Dictionary = facts(result, "MARCHER_MELEE_ATTACK").filter(func(h): return h.target.id == target.id)[0]
			check(not hit.blocked and hit.damage_dealt == 3, "other melee attackers do not gain a Penitent block roll")
		var w: Dictionary = phase_world()
		var target: Dictionary = put(w, "Penitent", pid, 1000, {"hp": 10, "max_hp": 10, "armor": 0, "step_fp": 0})
		var sources: Array = []
		for i in range(2): sources.append(put(w, "Vulture", 1-pid, 1060, {"hp": 100, "max_hp": 100, "armor": 0, "step_fp": 0, "y_fp": 285+i*30}, i))
		var seed_value: String = ""
		for i in range(1000):
			var candidate: String = "two-melee-blocks:" + str(i)
			if Marching.Ranged.Defense.blocks_vulture_melee(target, sources[0], candidate, 2, 0) and not Marching.Ranged.Defense.blocks_vulture_melee(target, sources[1], candidate, 2, 0): seed_value = candidate; break
		check(not seed_value.is_empty(), "find mixed simultaneous melee-block rolls")
		var result: Dictionary = direct("independent_melee_blocks_%d" % pid, "melee", w, {"seed": seed_value})
		var hits: Array = facts(result, "MARCHER_MELEE_ATTACK").filter(func(h): return h.target.id == target.id)
		check(hits.size() == 2 and hits.filter(func(h): return h.blocked).size() == 1 and Kanifous._entity(result.world, target.id).attributes.hp == 9, "each simultaneous Vulture melee hit gets its own keyed roll")

func muno_cooldown_checks() -> void:
	for pid in [0, 1]:
		var w: Dictionary = phase_world()
		var actor: Dictionary = put(w, "Muno", pid, 1000, {"step_fp": 0, "muno_next_tick": 599})
		put(w, "Butcher", 1-pid, 1360, {"step_fp": 0, "hp": 1000, "max_hp": 1000, "armor": 0})
		var first: Dictionary = phase("muno_late_dash_%d" % pid, w)
		check(facts(first, "MONSTER_ATTACK").filter(func(h): return h.ability == "Muno").map(func(h): return h.tick) == [199], "late dash fires only at its deadline")
		check(Kanifous._entity(first.world, actor.id).attributes.muno_next_tick == 699, "late dash stores an absolute 100-tick deadline")
		var saved: Dictionary = JSON.parse_string(Game.encode_snapshot(first.world))
		var restored: Dictionary = bytes_to_var(Marshalls.base64_to_raw(saved.payload))
		check(restored == first.world, "save transport preserves the cooldown and held afterimage")
		var next: Dictionary = phase("muno_resumed_cooldown_%d" % pid, restored, "monster-check", 3)
		check(facts(next, "MONSTER_ATTACK").filter(func(h): return h.ability == "Muno").map(func(h): return h.tick) == [99, 199], "round transition cannot reset or accelerate the dash")
		check(facts(next, "MONSTER_WARD_GAINED").is_empty() and Kanifous._entity(next.world, actor.id).attributes.muno_ward, "faster dashes cannot stack a held afterimage charge")
		w = phase_world()
		actor = put(w, "Muno", pid, 1000, {"step_fp": 0})
		var idle: Dictionary = phase("muno_no_target_%d" % pid, w)
		check(Kanifous._entity(idle.world, actor.id).attributes.muno_next_tick == 0 and facts(idle, "MONSTER_ATTACK").is_empty(), "an empty lane spends no dash cooldown")
		put(idle.world, "Butcher", 1-pid, 1360, {"step_fp": 0, "hp": 1000, "max_hp": 1000, "armor": 0})
		next = phase("muno_target_arrives_%d" % pid, idle.world, "monster-check", 3)
		check(facts(next, "MONSTER_ATTACK").filter(func(h): return h.ability == "Muno").map(func(h): return h.tick) == [0, 100], "new target gets an immediate dash followed by a properly spaced repeat")
	for value in [-1, true, 1.5, null]:
		var a: Dictionary = Monsters.profile("Muno", "Lord", 0, 0, 1)
		a.muno_next_tick = value
		check(not Monsters.valid_unit(a), "invalid dash deadlines are rejected")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0: phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	if args.size() > 1: packet_output = FileAccess.open(args[1], FileAccess.WRITE)
	melee_block_checks()
	muno_cooldown_checks()
	ward_packets()
	ward_retreat_checks()
	await ward_lunge_and_playback()
	ward_lord_packets()
	fast_poison_checks()
	if phase_output != null: phase_output.close()
	if packet_output != null: packet_output.close()
	print("U13 frontline and dash failures: ", failures)
	quit(1 if failures else 0)
