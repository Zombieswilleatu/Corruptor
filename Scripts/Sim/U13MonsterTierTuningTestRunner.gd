extends "res://Scripts/Sim/U13DotraExposureTestRunner.gd"

func charged(extra: Dictionary = {}) -> Dictionary:
	return {"muno_ward": true, "step_fp": 0, "hp": 10, "max_hp": 10, "armor": 1}.merged(extra, true)

func ward_packets() -> void:
	for pid in [0, 1]:
		for ability in ["Muno", "Ambush", "Beam", "Kopita", "Poison"]:
			var w: Dictionary = phase_world()
			var source: Dictionary = put(w, "Dotra", 1-pid, 1000)
			var victim: Dictionary = put(w, "Muno", pid, 1200, charged({"dotra_exposed_from_tick": 400, "dotra_exposed_until_tick": 600}))
			var options: Dictionary = {"hit": {"source": source, "target": victim.id, "ability": ability, "amount": 3, "bypass": ability == "Poison"}}
			var result: Dictionary = direct("ward_%s_%d" % [ability, pid], "packet", w, options)
			var a: Dictionary = Kanifous._entity(result.world, victim.id).attributes
			check(a.hp == 10 and a.armor == 1 and not a.muno_ward and facts(result, "MONSTER_ATTACK")[0].warded, "one ward cancels the whole packet and exposure bonus without spending Armor")
			result = direct("ward_spent_%s_%d" % [ability, pid], "packet", result.world, options)
			a = Kanifous._entity(result.world, victim.id).attributes
			check(a.hp == (6 if ability == "Poison" else 7), "the next packet lands normally after the only charge is spent")
		for operation in ["melee", "ranged"]:
			var w: Dictionary = phase_world()
			var victim: Dictionary = put(w, "Muno", pid, 1000, charged())
			for i in range(2): put(w, "Butcher" if operation == "melee" else "Vulture", 1-pid, 1060 if operation == "melee" else 1300, {"hp": 100, "max_hp": 100, "step_fp": 0, "y_fp": 290+i*20}, i)
			var result: Dictionary = direct("ward_two_%s_%d" % [operation, pid], operation, w)
			var hits: Array = facts(result, "MARCHER_MELEE_ATTACK" if operation == "melee" else "MARCHER_RANGED_ATTACK").filter(func(h): return h.target.id == victim.id)
			check(hits.size() == 2 and hits.filter(func(h): return h.warded).size() == 1, "two simultaneous attackers consume exactly one charge")
			var a: Dictionary = Kanifous._entity(result.world, victim.id).attributes
			check(a.hp == (8 if operation == "melee" else 10) and a.armor == 0, "the second simultaneous hit spends Armor and HP normally")
	var a: Dictionary = charged({"monster_id": "Muno"})
	check(Incoming.apply(a, 0, 400) == 0 and a.muno_ward, "zero damage cannot waste the ward")
	check(Incoming.amount(a, 3, 400) == 3 and a.muno_ward, "a damage forecast cannot consume the ward")
	for value in [0, 1, "true", null]:
		a = charged({"monster_id": "Muno", "muno_ward": value})
		check(not Incoming.valid(a), "non-boolean ward state is rejected")
	check(not Incoming.valid(charged({"monster_id": "Dotra"})), "other monsters cannot forge Muno's ward")

func ward_retreat_checks() -> void:
	for pid in [0, 1]:
		for operation in ["melee", "ranged"]:
			var w: Dictionary = phase_world()
			var victim: Dictionary = put(w, "Muno", pid, 1000, charged({"rout_round": 2, "rout_effect_id": "ward-rout", "dotra_exposed_from_tick": 400, "dotra_exposed_until_tick": 600}))
			for i in range(2): put(w, "Butcher" if operation == "melee" else "Vulture", 1-pid, 1060 if operation == "melee" else 1300, {"attack": 3, "hp": 100, "max_hp": 100, "step_fp": 0, "y_fp": 290+i*20}, i)
			var result: Dictionary = direct("ward_retreat_%s_%d" % [operation, pid], operation, w)
			var hits: Array = facts(result, "MARCHER_MELEE_ATTACK" if operation == "melee" else "MARCHER_RANGED_ATTACK").filter(func(h): return h.target.id == victim.id)
			var a: Dictionary = Kanifous._entity(result.world, victim.id).attributes
			check(hits.size() == 2 and hits[0].warded and hits[0].damage_dealt == 0 and not hits[1].warded and hits[1].damage_dealt == 4 and a.hp == 6 and a.armor == 0, "one charge cancels both Rout and exposure bonuses; the next hit includes both bonuses")

func ward_lunge_and_playback() -> void:
	for pid in [0, 1]:
		var w: Dictionary = phase_world()
		var actor: Dictionary = put(w, "Muno", pid, 1000, {"step_fp": 0})
		var enemy: Dictionary = put(w, "Butcher", 1-pid, 1360, {"step_fp": 0, "hp": 100, "max_hp": 100})
		var result: Dictionary = phase("ward_lunge_%d" % pid, w)
		check(facts(result, "MONSTER_WARD_GAINED").size() == 1 and Kanifous._entity(result.world, actor.id).attributes.muno_ward, "an actual lunge grants one persistent charge")
		var replay = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
		check(replay.build(result.events.map(func(r): return r.event)), "ward replay builds")
		var held: Dictionary = replay.sample(2.0)
		check(held.monster_attacks.any(func(a): return a.ability == "MunoAfterimage") and replay.sample(2.0) == held, "returned afterimages remain visible and respect pause")
		for View in [preload("res://Prototype/U13/U13BoardLanes.gd"), preload("res://Prototype/U13/U13SandboxLaneView.gd")]:
			var view = View.new(); view.display_settings_path = ""; root.add_child(view); view.size = Vector2(640, 900)
			for sprites in [false, true]:
				view.set_display_modes(sprites, sprites); view.show_frame(held, 2); await process_frame
				check(view.monster_attacks.any(func(a): return a.ability == "MunoAfterimage"), "both lane renderers retain sprite or chit echoes without a shield icon")
			view.reset_effects(); check(view._units.is_empty(), "reset clears the afterimages"); view.free()
		var saved: Dictionary = JSON.parse_string(Game.encode_snapshot(result.world))
		w = bytes_to_var(Marshalls.base64_to_raw(saved.payload))
		check(w == result.world and Marching.valid(w), "save transport preserves the held charge")
		var ids = Work.Ids.new(); ids.restore(w.entities); ids.retire(enemy.id); w.entities = ids.snapshot()
		result = phase("ward_idle_next_round_%d" % pid, w, "monster-check", 3)
		check(Kanifous._entity(result.world, actor.id).attributes.muno_ward, "the ward persists across rounds without another target")
		w = result.world
		ids.restore(w.entities); var body: Dictionary = ids.get_entity(actor.id); body.attributes["muno_next_tick"] = 1000; ids.update(body.id, body.owner, body.attributes); w.entities = ids.snapshot()
		put(w, "Vulture", 1-pid, 1300, {"step_fp": 0})
		result = phase("ward_consumed_%d" % pid, w, "monster-check", 4)
		replay.build(result.events.map(func(r): return r.event))
		check(replay.sample(0.0).monster_attacks.any(func(a): return a.ability == "MunoAfterimage"), "held afterimage is visible before the incoming shot")
		check(not replay.sample(replay.tick_time(0)+0.0001).monster_attacks.any(func(a): return a.ability == "MunoAfterimage"), "afterimages disappear on the frame that absorbs the hit")
		var first: Dictionary = facts(result, "MARCHER_RANGED_ATTACK")[0]
		check(first.warded and first.damage_dealt == 0, "the disappearance corresponds to a real absorbed hit")
	# A canceled queued lunge never manufactures a charge.
	var w: Dictionary = phase_world()
	var actor: Dictionary = put(w, "Muno", 0, 1000)
	var hidden: Dictionary = put(w, "Dotra", 1, 1200, {"dotra_shroud_from_tick": 400, "dotra_shroud_until_tick": 467})
	var canceled: Dictionary = direct("ward_canceled_lunge", "packet", w, {"hit": {"source": actor, "target": hidden.id, "ability": "Muno", "amount": 3, "bypass": false}})
	check(facts(canceled, "MONSTER_ATTACK").is_empty() and not Kanifous._entity(canceled.world, actor.id).attributes.muno_ward, "untargetable victim cancels the lunge and ward grant")
	for already in [false, true]:
		w = phase_world(); actor = put(w, "Muno", 0, 1000, {"muno_ward": already})
		var enemy: Dictionary = put(w, "Tumler", 1, 1200)
		var seed_value: String = ""
		for i in range(1000):
			var candidate: String = "ward-evade:" + str(i)
			if MonsterFX.evades(enemy, actor, [], context(w, candidate), 0, "Muno"): seed_value = candidate; break
		var struck: Dictionary = direct("ward_evaded_lunge_" + str(already), "packet", w, {"seed": seed_value, "hit": {"source": actor, "target": enemy.id, "ability": "Muno", "amount": 3, "bypass": false}})
		check(Kanifous._entity(struck.world, actor.id).attributes.muno_ward and facts(struck, "MONSTER_WARD_GAINED").size() == (0 if already else 1), "an evaded lunge grants a charge but cannot stack a held one")

func ward_lord_packets() -> void:
	var w: Dictionary = phase_world()
	var victim: Dictionary = put(w, "Muno", 1, 1200, charged())
	var active: Dictionary = {"effect_id": "ward-inferno", "target": {"kind": "lane", "lane": "Lord"}, "stage_index": 0, "stages": [{"intensity": 3}], "declaration": {"player_id": 0, "power_id": "Inferno"}}
	var result: Dictionary = direct("ward_inferno", "hazard", w, {"active": active})
	check(Kanifous._entity(result.world, victim.id).attributes.hp == 10 and not Kanifous._entity(result.world, victim.id).attributes.muno_ward, "Lord damage consumes the same single charge")
	var source: Dictionary = preload("res://Scripts/Sim/U13OriasCandidates.gd").source(0, 2, {"lane": "Lord", "field_position": {"x_fp": 1200, "y_fp": 300}})
	var pending = preload("res://Scripts/Sim/U13PendingEffects.gd").new()
	result = direct("ward_web", "web", w, {"record": pending.schedule(source).effect})
	check(Kanifous._entity(result.world, victim.id).attributes.hp == 10 and not Kanifous._entity(result.world, victim.id).attributes.muno_ward, "Web also spends the ward without Armor loss")
	w = Game.Economy.initialize(Game.Scenario.loadout_world(["Orias", "Gremory"], [Slots.TYPES, Slots.TYPES]), "ward-fracture").world
	victim = put(w, "Muno", 1, 1200, charged())
	var throne = preload("res://Scripts/Sim/U13VacantThrone.gd")
	check(throne.begin(w, 1), "Fracture fixture opens the prior round")
	check(throne.finish(w, 1).action != "invalid", "Fracture fixture completes the prior round")
	check(throne.begin(w, 2), "Fracture fixture enters the current Marching round")
	var banished: Dictionary = preload("res://Scripts/Sim/U13BattleEvents.gd").apply(w, {"command_id": "ward-fracture", "kind": "banish_lord", "target_id": w.players[1].lord_entity_id, "fracture_target": "subjects"}, 2, "marching")
	result = direct("ward_fracture", "reaction", banished.world, {"fact": banished.event})
	var hits: Array = facts(result, "FRACTURE_HIT")
	check(hits.size() == 2 and hits[0].after == 10 and hits[1].after == 9 and not Kanifous._entity(result.world, victim.id).attributes.muno_ward, "Fracture persists consumption before a later point hits the same body")

func fast_poison_checks() -> void:
	for pid in [0, 1]:
		var w: Dictionary = phase_world()
		var source: Dictionary = put(w, "Varn", 1-pid, 0)
		var ids = Work.Ids.new(); ids.restore(w.entities); ids.retire(source.id); w.entities = ids.snapshot()
		var victim: Dictionary = put(w, "Butcher", pid, 1200, {"hp": 10, "max_hp": 10, "armor": 6, "step_fp": 0, "poison_source": source, "poison_next_tick": 400, "poison_ticks_left": 3})
		var result: Dictionary = phase("fast_poison_three_ticks_%d" % pid, w)
		var hits: Array = facts(result, "MONSTER_ATTACK").filter(func(h): return h.ability == "Poison")
		check(hits.map(func(h): return h.tick) == [0, 27, 54] and hits.all(func(h): return h.damage_dealt == 1), "poison deals exactly three Armor-bypassing ticks about two seconds apart")
		var a: Dictionary = Kanifous._entity(result.world, victim.id).attributes
		check(a.hp == 7 and a.armor == 6 and a.poison_ticks_left == 0, "poison continues after its source dies and then expires")
		w = phase_world()
		source = put(w, "Varn", 1-pid, 0)
		ids.restore(w.entities); ids.retire(source.id); w.entities = ids.snapshot()
		victim = put(w, "Muno", pid, 1200, charged({"poison_source": source, "poison_next_tick": 599, "poison_ticks_left": 3}))
		result = phase("fast_poison_boundary_%d" % pid, w)
		check(facts(result, "MONSTER_ATTACK").filter(func(h): return h.ability == "Poison").size() == 1 and Kanifous._entity(result.world, victim.id).attributes.hp == 10, "the first late tick is absorbed by Muno's held ward")
		var saved: Dictionary = JSON.parse_string(Game.encode_snapshot(result.world))
		w = bytes_to_var(Marshalls.base64_to_raw(saved.payload))
		result = phase("fast_poison_resumed_%d" % pid, w, "monster-check", 3)
		hits = facts(result, "MONSTER_ATTACK").filter(func(h): return h.ability == "Poison")
		check(hits.map(func(h): return h.tick) == [26, 53] and Kanifous._entity(result.world, victim.id).attributes.hp == 8, "save/load preserves both remaining deadlines across the interval boundary")
		w = phase_world()
		source = put(w, "Varn", 1-pid, 1000, {"step_fp": 0})
		victim = put(w, "Butcher", pid, 1060, {"hp": 2, "max_hp": 2, "armor": 0, "step_fp": 0})
		var seed_value: String = ""
		for i in range(1000):
			var candidate: String = "fast-poison:" + str(i)
			if MonsterFX.Lamp.draw(candidate, "%s:2:0:%s" % [source.id, victim.id], "POISON", 100) < 10: seed_value = candidate; break
		result = phase("fast_poison_immediate_kill_%d" % pid, w, seed_value)
		hits = facts(result, "MONSTER_ATTACK").filter(func(h): return h.ability == "Poison")
		check(not hits.is_empty() and hits[0].tick == 0 and facts(result, "MARCHER_DEFEATED").any(func(d): return d.victim.id == victim.id and d.tick == 0), "a fresh proc resolves in its melee tick and lethal poison emits a real death")
	var w: Dictionary = phase_world()
	var source: Dictionary = put(w, "Varn", 0, 0)
	var victim: Dictionary = put(w, "Butcher", 1, 1200, {"hp": 10, "max_hp": 10, "poison_source": source, "poison_next_tick": 427, "poison_ticks_left": 2})
	var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
	var seed_value: String = ""
	for i in range(1000):
		var candidate: String = "poison-refresh:" + str(i)
		if MonsterFX.Lamp.draw(candidate, "%s:2:10:%s" % [source.id, victim.id], "POISON", 100) < 10: seed_value = candidate; break
	MonsterFX.on_hit(buffer, source, victim.id, 1, context(w, seed_value), 10)
	var a: Dictionary = buffer.get_entity(victim.id).attributes
	check(a.poison_ticks_left == 3 and a.poison_next_tick == 427, "reapplication replenishes one effect without stacking or delaying its next tick")
	var ticked: Dictionary = MonsterFX.poison(w, buffer, context(w), 10, Callable(Game.Content.new(), "react"))
	check(facts(ticked, "MONSTER_ATTACK").is_empty(), "refresh cannot manufacture another immediate tick")
	for value in [-1, 4, true, 0.5]:
		var forged: Dictionary = a.duplicate(true); forged.poison_ticks_left = value
		check(not Monsters.valid_unit(forged), "invalid poison count is rejected on ordinary units")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0: phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	if args.size() > 1: packet_output = FileAccess.open(args[1], FileAccess.WRITE)
	ward_packets()
	ward_retreat_checks()
	await ward_lunge_and_playback()
	ward_lord_packets()
	fast_poison_checks()
	if phase_output != null: phase_output.close()
	if packet_output != null: packet_output.close()
	print("U13 monster tier tuning failures: ", failures)
	quit(1 if failures else 0)
