extends "res://Scripts/Sim/U13MonsterTestRunner.gd"

const Incoming = preload("res://Scripts/Sim/U13IncomingDamage.gd")
const Exposure = preload("res://Prototype/U13/U13ExposureVisuals.gd")
var packet_output

func exposed(extra: Dictionary = {}) -> Dictionary:
	return {"hp": 100, "max_hp": 100, "armor": 0, "step_fp": 0, "dotra_exposed_from_tick": 400, "dotra_exposed_until_tick": 600}.merged(extra, true)

func direct(name: String, operation: String, w: Dictionary, options: Dictionary = {}) -> Dictionary:
	var c: Dictionary = context(w, options.get("seed", "exposure-check"))
	var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
	var content = Game.Content.new()
	var react: Callable = Callable(content, "react")
	var result: Dictionary
	var tick: int = int(options.get("tick", 0))
	match operation:
		"packet": result = MonsterFX.damage(w.duplicate(true), buffer, options.hit.duplicate(true), c, tick, react)
		"melee": result = Marching.FieldMelee.resolve(w.duplicate(true), buffer, c, tick, {}, react)
		"ranged": result = Marching.Ranged.volley(w.duplicate(true), buffer, c, {}, tick, {}, react)
		"hazard": result = preload("res://Scripts/Sim/U13Hazards.gd").pulse(c, options.active, "exposure-hazard", react)
		"reaction": result = content.react(w.duplicate(true), options.fact, c.seed, c.player_order)
		"web": result = preload("res://Scripts/Sim/U13Orias.gd").new().resolve(options.record, c.merged({"hook": options.record.fire_hook}, true))
	check(result.action == "resolved", name + " resolves")
	if result.action != "resolved": print(result); return result
	if packet_output != null:
		packet_output.store_line(Codec.encode({"name": name, "operation": operation, "context": c, "options": options, "result": {"world": result.world, "events": result.events}}).text)
		packet_output.flush()
	return result

func pulse_checks() -> void:
	for pid in [0, 1]:
		var direction: int = 1 if pid == 0 else -1
		var w: Dictionary = phase_world()
		var actor: Dictionary = put(w, "Dotra", pid, 1200, {"hidden": true, "hp": 100, "max_hp": 100, "step_fp": 0})
		var victim: Dictionary = put(w, "Butcher", 1-pid, 1200 + direction * 240, {"hp": 100, "max_hp": 100, "armor": 0, "step_fp": 0})
		var edge: Dictionary = put(w, "Butcher", 1-pid, 1200 + direction * 360, {"hp": 100, "max_hp": 100, "step_fp": 0}, 1)
		var outside: Dictionary = put(w, "Butcher", 1-pid, 1200 + direction * 361, {"hp": 100, "max_hp": 100, "step_fp": 0}, 2)
		var friend: Dictionary = put(w, "Butcher", pid, 1200, {"y_fp": 400, "step_fp": 0})
		var other: Dictionary = put(w, "Butcher", 1-pid, 1200, {"lane": "Castle", "step_fp": 0}, 3)
		var result: Dictionary = phase("exposure_emergence_%d" % pid, w)
		var pulses: Array = facts(result, "MONSTER_EXPOSURE_PULSE")
		var hits: Array = facts(result, "MONSTER_ATTACK").filter(func(d): return d.ability == "Ambush")
		check(pulses.size() == 1 and pulses[0].tick == 0 and pulses[0].until_tick == 600, "one emergence creates one full-round exposure pulse")
		check(hits.size() == 1 and hits[0].damage_dealt == 5, "the pulse does not amplify its own opening ambush")
		var marked: Array = pulses[0].affected.map(func(u): return u.id)
		check(victim.id in marked and edge.id in marked and outside.id not in marked and friend.id not in marked and other.id not in marked, "pulse includes the 360 boundary and excludes allies, other lanes and outside bodies")
		var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
		check(playback.build(result.events.map(func(e): return e.event)), "exposure replay builds")
		var at: float = playback.tick_time(0)
		check(not playback.sample(at-0.0001).units.any(func(u): return Exposure.active(u)), "status icons do not appear before emergence")
		var frame: Dictionary = playback.sample(at+0.0001)
		check(frame.monster_attacks.any(func(a): return a.ability == "DotraExpose") and frame.units.any(func(u): return u.id == victim.id and Exposure.active(u)), "pulse and cracked-shield marker appear on the recorded hit")
		for View in [preload("res://Prototype/U13/U13BoardLanes.gd"), preload("res://Prototype/U13/U13SandboxLaneView.gd")]:
			var view = View.new(); view.display_settings_path = ""; root.add_child(view); view.size = Vector2(640, 900)
			view.show_frame(frame, 2); await process_frame
			check(view._units.any(func(u): return u.id == victim.id and Exposure.active(u)), "both lane views render exposed enemies for either seat")
			view.reset_effects(); check(view._units.is_empty(), "reset clears exposure presentation"); view.free()
	# A saved mid-round application must expire at the same tick next round.
	var w: Dictionary = phase_world()
	var target: Dictionary = put(w, "Butcher", 1, 1200, exposed({"dotra_exposed_from_tick": 450, "dotra_exposed_until_tick": 650}))
	var saved: Dictionary = JSON.parse_string(Game.encode_snapshot(w))
	var loaded: Dictionary = bytes_to_var(Marshalls.base64_to_raw(saved.payload))
	check(loaded == w and Marching.valid(loaded), "save transport preserves the exact exposure deadline")
	var later: Dictionary = phase("exposure_expiration", loaded, "exposure-check", 3)
	var replay = preload("res://Prototype/U13/U13SmokePlayback.gd").new(); replay.build(later.events.map(func(e): return e.event))
	check(replay.sample(replay.tick_time(50)-0.0001).units.any(func(u): return u.id == target.id and Exposure.active(u)), "exposure remains visible until the final active tick")
	check(not replay.sample(replay.tick_time(50)+0.0001).units.any(func(u): return Exposure.active(u)), "exposure disappears at the exact next-round deadline")
	check(not Incoming.active(target.attributes, 449) and Incoming.amount(target.attributes, 1, 450) == 2 and Incoming.amount(target.attributes, 1, 649) == 2 and Incoming.amount(target.attributes, 1, 650) == 1, "incoming damage observes inclusive start and exclusive expiry")
	var actor: Dictionary = put(w, "Dotra", 0, 1000)
	var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
	MonsterFX.expose(buffer, actor, 2, 75); MonsterFX.expose(buffer, actor, 2, 90)
	var a: Dictionary = buffer.get_entity(target.id).attributes
	check(a.dotra_exposed_until_tick == 690 and Incoming.amount(a, 1, 500) == 2, "multiple Dotras refresh duration but cannot stack the bonus")
	a["hidden"] = true
	check(not Exposure.active({"attributes": a}), "exposure does not reveal a hidden enemy")
	for value in [-1, 0.5, true, "1"]:
		for key in ["dotra_exposed_from_tick", "dotra_exposed_until_tick"]:
			var forged: Dictionary = a.duplicate(true); forged[key] = value
			check(not Incoming.valid(forged), "invalid exposure clocks are rejected")

func damage_checks() -> void:
	# Explicit packet expectations cover ordinary Armor, bypass, and zero damage.
	for spec in [["Kopita", 1, false, 0, 98, 0], ["Poison", 1, true, 3, 98, 3], ["Beam", 3, false, 2, 98, 0], ["Muno", 3, false, 0, 96, 0], ["Ambush", 5, false, 0, 94, 0], ["Muno", 0, false, 0, 100, 0]]:
		var w: Dictionary = phase_world()
		var source: Dictionary = put(w, "Dotra", 0, 1000)
		var victim: Dictionary = put(w, "Butcher", 1, 1200, exposed({"armor": spec[3]}))
		var result: Dictionary = direct("exposed_packet_%s_%d" % [spec[0], spec[1]], "packet", w, {"hit": {"source": source, "target": victim.id, "ability": spec[0], "amount": spec[1], "bypass": spec[2]}})
		var after: Dictionary = Kanifous._entity(result.world, victim.id).attributes
		check(after.hp == spec[4] and after.armor == spec[5], "extra damage applies once, before Armor, including poison bypass and zero-packet immunity")
	for operation in ["melee", "ranged"]:
		var w: Dictionary = phase_world()
		var source: Dictionary = put(w, "Butcher" if operation == "melee" else "Vulture", 0, 1000)
		var victim: Dictionary = put(w, "Butcher", 1, 1060 if operation == "melee" else 1300, exposed())
		var result: Dictionary = direct("exposed_" + operation, operation, w)
		check(Kanifous._entity(result.world, victim.id).attributes.hp == (96 if operation == "melee" else 97), "ordinary combat adds one point to the actual matchup damage")
	for blocked in [true, false]:
		var w: Dictionary = phase_world()
		var source: Dictionary = put(w, "Vulture", 0, 900)
		var victim: Dictionary = put(w, "Penitent", 1, 1200, exposed({"armor": 3}))
		var result: Dictionary = direct("exposed_block_" + str(blocked), "ranged", w, {"seed": block_seed(victim, source, "Vulture", 0, blocked)})
		var a: Dictionary = Kanifous._entity(result.world, victim.id).attributes
		check(a.hp == 100 and a.armor == (3 if blocked else 1), "a block prevents the whole amplified hit; an unblocked hit still consumes Armor")
	for wanted in [true, false]:
		var w: Dictionary = phase_world()
		var source: Dictionary = put(w, "Dotra", 0, 1000)
		var victim: Dictionary = put(w, "Kurchin", 1, 1200, exposed({"armor": 6}))
		var seed_value: String = ""
		for i in range(1000):
			var candidate: String = "exposure-evade:" + str(i)
			if MonsterFX.evades(victim, source, [], context(w, candidate), 0, "Muno") == wanted: seed_value = candidate; break
		var result: Dictionary = direct("exposed_evade_" + str(wanted), "packet", w, {"seed": seed_value, "hit": {"source": source, "target": victim.id, "ability": "Muno", "amount": 3, "bypass": false}})
		var a: Dictionary = Kanifous._entity(result.world, victim.id).attributes
		check(a.hp == 100 and a.armor == (6 if wanted else 2), "evasion stops the entire amplified packet")
	# Towers share volley resolution but have a distinct attack source category.
	var tower_world: Dictionary = phase_world()
	var p: Dictionary = Marching.Fort.site_point(0, 2)
	var builder: Dictionary = put(tower_world, "Wright", 0, p.x_fp)
	var ids = Work.Ids.new(); ids.restore(tower_world.entities); ids.retire(builder.id); tower_world.entities = ids.snapshot()
	tower_world.data["field_structures"] = [{"id": Marching.Fort.Data.instance_id("wright_structure", builder.id, "2"), "kind": "fortification", "owner": 0, "attributes": {"structure": "Tower", "site": 2, "lane": "Lord", "x_fp": p.x_fp, "y_fp": p.y_fp, "hp": 6, "max_hp": 6, "armor": 4, "max_armor": 4, "attack": 1, "ranged_next_tick": 0, "builder_id": builder.id}}]
	var tower_target: Dictionary = put(tower_world, "Butcher", 1, int(p.x_fp) + 300, exposed())
	var tower_hit: Dictionary = direct("exposed_tower", "ranged", tower_world)
	check(Kanifous._entity(tower_hit.world, tower_target.id).attributes.hp == 98, "tower shots also deal one additional damage")
	# Reflection reads the killing tick, not the beginning of its round.
	for until in [600, 410]:
		var w: Dictionary = Game.Economy.initialize(Game.Scenario.loadout_world(["Odradek", "Deimos"], [Slots.TYPES, Slots.TYPES]), "exposure-interlock").world
		w.data["marching_round"] = 1
		var victim: Dictionary = put(w, "Butcher", 0, 1200, {"hp": 1, "armor": 0})
		var killer: Dictionary = put(w, "Butcher", 1, 1200, exposed({"armor": 2, "dotra_exposed_until_tick": until}))
		var dead: Dictionary = preload("res://Scripts/Sim/U13BattleEvents.gd").apply(w, {"command_id": "exposure-kill", "kind": "marcher_damage", "target_id": victim.id, "attacker_id": killer.id, "damage": 4, "cause": "combat"}, 2, "marching")
		dead.event.data["tick"] = 10
		var result: Dictionary = direct("exposed_interlock_%d" % until, "reaction", dead.world, {"fact": dead.event})
		check(Kanifous._entity(result.world, killer.id).attributes.hp == (97 if until == 600 else 98), "reflected damage respects exposure at the actual reaction tick")
	var w: Dictionary = phase_world()
	var victim: Dictionary = put(w, "Butcher", 1, 1200, exposed({"armor": 1}))
	var active: Dictionary = {"effect_id": "exposure-inferno", "target": {"kind": "lane", "lane": "Lord"}, "stage_index": 0, "stages": [{"intensity": 1}], "declaration": {"player_id": 0, "power_id": "Inferno"}}
	var hazard: Dictionary = direct("exposed_inferno", "hazard", w, {"active": active})
	check(Kanifous._entity(hazard.world, victim.id).attributes.hp == 99 and Kanifous._entity(hazard.world, victim.id).attributes.armor == 0, "lord hazard damage also gains the bonus before Armor")
	var source: Dictionary = preload("res://Scripts/Sim/U13OriasCandidates.gd").source(0, 2, {"lane": "Lord", "field_position": {"x_fp": 1200, "y_fp": 300}})
	var pending = preload("res://Scripts/Sim/U13PendingEffects.gd").new()
	var web: Dictionary = direct("exposed_web", "web", w, {"record": pending.schedule(source).effect})
	check(Kanifous._entity(web.world, victim.id).attributes.hp == 99 and Kanifous._entity(web.world, victim.id).attributes.armor == 0, "Web damage also gains the bonus before Armor")
	check(Incoming.phase_clock(w, 2) == 400, "powers before Marching use its starting boundary")
	w.data.marching_round = 2
	check(Incoming.phase_clock(w, 2) == 600 and Incoming.phase_clock(w, 3) == 600, "powers between rounds share the same exposure clock")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0: phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	if args.size() > 1: packet_output = FileAccess.open(args[1], FileAccess.WRITE)
	await pulse_checks()
	damage_checks()
	if phase_output != null: phase_output.close()
	if packet_output != null: packet_output.close()
	print("U13 Dotra exposure failures: ", failures)
	quit(0 if failures == 0 else 1)
