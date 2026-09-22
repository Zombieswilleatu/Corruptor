extends "res://Scripts/Sim/U13SupportHuntTestRunner.gd"

const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")
const Charge = preload("res://Scripts/Sim/U13TumlerCharge.gd")
const Visual = preload("res://Prototype/U13/U13MarcherSpriteVisuals.gd")
const Metrics = preload("res://Scripts/Sim/U13LaneBattleMetrics.gd")

func buffer_for(w: Dictionary):
	var buffer = Marching.Buffer.new()
	check(buffer.restore(w.entities).action != "invalid", "charge fixture restores")
	return buffer

func direct_checks(pid: int) -> void:
	var w: Dictionary = phase_world()
	var dog: Dictionary = put(w, "Tumler", pid, at(700, pid))
	var prey: Array = []
	for spec in [["Sooge", 1100], ["Kopita", 1050], ["Fyra", 1000], ["Vulture", 950], ["Butcher", 850]]:
		prey.append(put(w, spec[0], 1-pid, at(spec[1], pid)))
	put(w, "Sooge", pid, at(720, pid))
	put(w, "Sooge", 1-pid, at(710, pid), {"lane": "Castle"}, 1)
	put(w, "Sooge", 1-pid, at(730, pid), {"hidden": true}, 2)
	var buffer = buffer_for(w)
	for target in prey:
		check(Charge.select_target(dog, buffer.marchers(), 400).id == target.id, "priority ignores closer lower-priority prey, allies, other lanes and hidden units")
		buffer.retire(target.id)
	w = phase_world()
	dog = put(w, "Tumler", pid, at(700, pid))
	var target: Dictionary = put(w, "Vulture", 1-pid, at(1100, pid), {"step_fp": 0})
	var blocker: Dictionary = put(w, "Butcher", 1-pid, at(730, pid), {"step_fp": 0})
	var taunt: Dictionary = put(w, "Kurchin", 1-pid, at(760, pid), {"step_fp": 0})
	buffer = buffer_for(w)
	var c: Dictionary = context(w)
	var events: Array = Charge.step(buffer, [], c, 0, {})
	var armed: Dictionary = buffer.get_entity(dog.id)
	check(events.size() == 1 and armed.attributes.armor == 6 and armed.attributes.tumler_charge_phase == "windup", "range boundary starts wind-up and adds exactly five Armor")
	check(MonsterFX.preferred(armed, buffer.marchers()).id == target.id, "Kurchin cannot redirect an active charge")
	check(MonsterFX.intercept(armed, blocker, buffer.marchers(), c, 0).is_empty(), "landed melee cannot redirect an active charge")
	for tick in range(1, 7):
		Charge.step(buffer, [], c, tick, {})
		var held: Dictionary = buffer.get_entity(dog.id)
		check(held.attributes.x_fp == dog.attributes.x_fp and held.attributes.y_fp == 300 and held.attributes.tumler_charge_phase == "windup", "all seven wind-up frames hold position")
	check(Charge.step(buffer, [], c, 7, {}).any(func(e): return e.event.type == "MONSTER_CHARGE_LAUNCHED"), "charge releases seven ticks after wind-up begins")
	for remaining in [6, 4, 1, 0]:
		var sample: Dictionary = armed.duplicate(true)
		sample.attributes.armor = remaining
		Charge.finish(sample, c, 8, "test")
		check(sample.attributes.armor == mini(remaining, 1), "expiration removes only unspent temporary Armor")
	for interruption in ["fear", "rout", "owner", "lost", "shroud", "timeout"]:
		buffer = buffer_for(w)
		Charge.step(buffer, [], c, 0, {})
		var fleeing: Dictionary = {}
		var live: Dictionary = buffer.get_entity(dog.id)
		if interruption == "fear": fleeing[dog.id] = true
		if interruption == "rout": live.attributes["rout_round"] = 2
		if interruption == "owner": live.owner = 1-pid
		if interruption == "lost": buffer.retire(target.id)
		if interruption == "shroud":
			var concealed: Dictionary = buffer.get_entity(target.id)
			concealed.attributes["hidden"] = true
			buffer.update(concealed.id, concealed.owner, concealed.attributes)
		buffer.update(live.id, live.owner, live.attributes)
		Charge.step(buffer, [], c, 47 if interruption == "timeout" else 1, fleeing)
		live = buffer.get_entity(dog.id)
		check(Charge.active(live.attributes) and live.attributes.armor == 6 and live.attributes.tumler_charge_next_tick == 600, interruption + " cannot cancel a committed charge or refresh its Armor")
		var start: int = 48 if interruption == "timeout" else 2
		var follow: Array = []
		for tick in range(start, start + 30): follow.append_array(Charge.step(buffer, [], c, tick, fleeing))
		live = buffer.get_entity(dog.id)
		check(not Charge.active(live.attributes) and live.attributes.armor == 1 and follow.any(func(e): return e.event.type == "MONSTER_CHARGE_ENDED" and e.event.data.reason in ["target", "destination"]), interruption + " completes the rush and then removes unspent Armor")
	# The first return to range cannot refill Armor during the cooldown.
	buffer = buffer_for(w)
	Charge.step(buffer, [], c, 0, {})
	var live: Dictionary = buffer.get_entity(dog.id)
	Charge.finish(live, c, 1, "test"); buffer.update(live.id, live.owner, live.attributes)
	check(Charge.step(buffer, [], c, 50, {}).is_empty() and buffer.get_entity(dog.id).attributes.armor == 1, "cooldown prevents repeated Armor grants")
	c.round = 3
	check(Charge.step(buffer, [], c, 0, {}).any(func(e): return e.event.type == "MONSTER_CHARGE_WINDUP"), "charge becomes available after 200 ticks")
	var outside: Dictionary = w.duplicate(true)
	var ids = Work.Ids.new(); ids.restore(outside.entities)
	target.attributes.x_fp = at(1101, pid); ids.update(target.id, target.owner, target.attributes); outside.entities = ids.snapshot()
	check(Charge.step(buffer_for(outside), [], context(outside), 0, {}).is_empty(), "401 distance does not trigger a charge")
	for ability in ["Beam", "Poison"]:
		buffer = buffer_for(w)
		Charge.step(buffer, [], context(w), 0, {})
		var hit_context: Dictionary = context(w, hunt_seed(blocker, dog, ability, 50))
		var hit: Dictionary = MonsterFX.damage(w.duplicate(true), buffer, {"source": blocker, "target": dog.id, "amount": 3, "bypass": ability == "Poison", "ability": ability}, hit_context, 0, Callable(Game.Content.new(), "react"))
		check(hit.action == "resolved", "damage resolves against active temporary Armor")
		var damaged: Dictionary = buffer.get_entity(dog.id)
		check(damaged.attributes.armor == (6 if ability == "Poison" else 3) and damaged.attributes.hp == (7 if ability == "Poison" else 10), "ordinary damage spends temporary Armor first; bypass skips all Armor")
		Charge.finish(damaged, hit_context, 1, "test")
		check(damaged.attributes.armor == 1, "cleanup preserves real Armor after actual damage")
	# Validate the pure presentation cap without requiring texture imports.
	check(Visual.permanent_armor(armed.attributes) == 1.0, "temporary Armor does not permanently enlarge the HP/Armor meter")

func geometry_checks(pid: int) -> void:
	for x in [0, 2400]:
		var w: Dictionary = phase_world()
		var dog: Dictionary = put(w, "Tumler", pid, x, {"y_fp": 100})
		var target: Dictionary = put(w, "Vulture", 1-pid, x, {"y_fp": 480})
		var body: Dictionary = put(w, "Butcher", 1-pid, x, {"y_fp": 250})
		var buffer = buffer_for(w)
		var all_events: Array = []
		for tick in range(25): all_events.append_array(Charge.step(buffer, [], context(w), tick, {}))
		var after: Dictionary = buffer.get_entity(dog.id)
		check(Fort.in_melee(after, target) and Fort.distance(after.attributes, target.attributes) >= 42 * 42, "vertical charge stops at the target's melee footprint without overlapping")
		check(buffer.get_entity(body.id).attributes.x_fp == (84 if x == 0 else 2316), "edge displacement selects the inward side")
		check(buffer.get_entity(target.id).attributes == target.attributes, "target coordinates and attributes remain untouched by the charge")
	var w: Dictionary = phase_world()
	var dog: Dictionary = put(w, "Tumler", pid, at(700, pid))
	var target: Dictionary = put(w, "Vulture", 1-pid, at(1100, pid))
	var body: Dictionary = put(w, "Butcher", 1-pid, at(750, pid))
	for i in range(6): put(w, "Penitent", 1-pid, at(750, pid), {"y_fp": 300 + [84, -84, 126, -126, 168, -168][i]}, i)
	var buffer = buffer_for(w)
	var all_events: Array = []
	for tick in range(30): all_events.append_array(Charge.step(buffer, [], context(w), tick, {}))
	check(all_events.any(func(e): return e.event.type == "MONSTER_CHARGE_ENDED" and e.event.data.reason == "target") and not all_events.any(func(e): return e.event.type == "MONSTER_CHARGE_ENDED" and e.event.data.reason == "blocked"), "a packed screen cannot cancel the charge")
	check(buffer.get_entity(dog.id).attributes.armor == 1 and buffer.get_entity(body.id).attributes != body.attributes, "a crowded charge finds a wider shove and completes normally")

func phase_checks(pid: int, edge: bool) -> void:
	var w: Dictionary = phase_world()
	var y: int = 0 if edge else 300
	var quiet: Dictionary = {"hp": 100, "max_hp": 100, "armor": 100, "attack": 1, "step_fp": 0, "y_fp": y}
	var dog: Dictionary = put(w, "Tumler", pid, at(700, pid), {"y_fp": y, "hp": 100, "max_hp": 100})
	var target: Dictionary = put(w, "Sooge", 1-pid, at(1080, pid), quiet.merged({"sooge_root_round": 2, "beam_next_tick": 10000}))
	var ally: Dictionary = put(w, "Butcher", pid, at(825, pid), quiet)
	var enemy: Dictionary = put(w, "Penitent", 1-pid, at(935, pid), quiet)
	put(w, "Vulture", 1-pid, at(1010, pid), quiet)
	var r: Dictionary = phase("charge_screen_%d_%s" % [pid, str(edge)], w)
	if r.action != "resolved": return
	var pushes: Array = facts(r, "MONSTER_CHARGE_DISPLACED")
	check(pushes.any(func(e): return e.displaced_id == ally.id) and pushes.any(func(e): return e.displaced_id == enemy.id), "charge sweeps allied and enemy frontliners sideways")
	check(not pushes.any(func(e): return e.displaced_id == target.id), "chosen target is never knocked back")
	check(facts(r, "MONSTER_CHARGE_WINDUP").size() == 1 and facts(r, "MONSTER_CHARGE_LAUNCHED").size() == 1, "one charge through the full phase")
	check(facts(r, "MONSTER_CHARGE_ENDED").any(func(e): return e.reason == "target"), "charge ends at the chosen target")
	check(facts(r, "MARCHER_MELEE_ATTACK").any(func(e): return e.attacker.id == dog.id and e.target.id == target.id), "Tumler stays and fights his chosen target")
	check(not facts(r, "MARCHER_MELEE_ATTACK").any(func(e): return e.attacker.id == dog.id and e.tick < 7), "no free melee swings during wind-up")
	var frames: Array = facts(r, "MARCHING_TICK")
	check(frames.all(func(f): return f.units.all(func(u): return int(u.attributes.x_fp) >= 0 and int(u.attributes.x_fp) <= 2400 and int(u.attributes.y_fp) >= 0 and int(u.attributes.y_fp) <= 600)), "every frame stays within the arena")
	var playback = Playback.new()
	check(playback.build(r.events.map(func(e): return e.event)), "live-board playback accepts the full charge tape")
	var end: Dictionary = facts(r, "MONSTER_CHARGE_ENDED")[0]
	var before: Dictionary = frames[int(end.tick)-1].units.filter(func(u): return u.id == dog.id)[0]
	var after: Dictionary = frames[int(end.tick)].units.filter(func(u): return u.id == dog.id)[0]
	var at_time: float = playback.FLIGHT_SECONDS + playback.MOVE_SECONDS * float(int(end.tick)+1) / 200.0
	var armor_feedback: int = 0
	for feedback in playback.feedback_rows:
		if feedback.id == dog.id and is_equal_approx(feedback.at, at_time): armor_feedback += int(feedback.armor)
	check(armor_feedback == int(after.attributes.armor) - int(before.attributes.armor) + int(end.armor_removed), "Armor expiry shows no false damage while simultaneous real hits retain feedback")
	check(playback.sample(at_time + 0.001).units.filter(func(u): return u.id == dog.id)[0].attributes.get("tumler_charge_phase", "") == "", "replay clears the brace/charge visual after landing")

func live_stats_check(pid: int) -> void:
	var w: Dictionary = phase_world()
	for i in range(2):
		put(w, "Tumler", pid, at(700, pid), {"y_fp": 180 + 240*i}, i)
		put(w, "Butcher", 1-pid, at(890, pid), {"y_fp": 180 + 240*i}, i)
	put(w, "Sooge", 1-pid, at(1080, pid), {"y_fp": 420, "sooge_root_attempts": 5})
	put(w, "Kopita", 1-pid, at(1150, pid), {"y_fp": 250})
	put(w, "Vulture", 1-pid, at(1080, pid), {"y_fp": 150})
	var r: Dictionary = phase("charge_live_stats_%d" % pid, w)
	if r.action != "resolved": return
	check(not facts(r, "MONSTER_CHARGE_WINDUP").is_empty() and not facts(r, "MARCHER_DEFEATED").is_empty(), "normal-stat battle exercises charge, damage, and death reactions")
	var observer = Metrics.new()
	observer.consume(r.events, 2)
	check(observer.units.values().all(func(u): return int(u.counts.get("unaccounted_packets", 0)) == 0), "charge battles preserve contribution damage accounting")

func interruption_phases(pid: int) -> void:
	var w: Dictionary = phase_world()
	var dog: Dictionary = put(w, "Tumler", pid, at(700, pid))
	put(w, "Sooge", 1-pid, at(1080, pid), {"sooge_root_round": 2, "step_fp": 0})
	var charmer: Dictionary = put(w, "Fyra", 1-pid, at(750, pid), {"step_fp": 0})
	var seed_value: String = ""
	for i in range(1000):
		var candidate: String = "charge-charm:" + str(i)
		if MonsterFX.Lamp.draw(candidate, "2:0:Melee:%s:%s" % [charmer.id, dog.id], "TUMLER_HUNT_EVASION", 100) >= 50 and MonsterFX.Lamp.draw(candidate, "%s:2:0:%s" % [charmer.id, dog.id], "CHARM", 100) < 30:
			seed_value = candidate; break
	check(not seed_value.is_empty(), "fixture selects a real landed charm during wind-up")
	var r: Dictionary = phase("charge_charmed_%d" % pid, w, seed_value)
	check(facts(r, "MONSTER_CHARMED").any(func(e): return e.unit_id == dog.id) and facts(r, "MONSTER_CHARGE_LAUNCHED").any(func(e): return e.unit_id == dog.id) and facts(r, "MONSTER_CHARGE_ENDED").any(func(e): return e.reason == "destination"), "Fyra charm preserves momentum toward the last enemy position")
	check(not facts(r, "MARCHER_MELEE_ATTACK").any(func(e): return e.attacker.id == dog.id and e.attacker.owner == e.target.owner), "a charmed charge never strikes its new ally")
	w = phase_world()
	dog = put(w, "Tumler", pid, at(700, pid))
	var target: Dictionary = put(w, "Sooge", 1-pid, at(1080, pid), {"sooge_root_round": 2, "step_fp": 0, "hp": 1, "armor": 0})
	put(w, "Vulture", pid, at(850, pid))
	r = phase("charge_target_dies_%d" % pid, w)
	check(facts(r, "MARCHER_DEFEATED").any(func(e): return e.victim.id == target.id) and facts(r, "MONSTER_CHARGE_ENDED").any(func(e): return e.reason == "destination"), "a killed target leaves a last-known destination for the committed rush")
	check(facts(r, "MONSTER_CHARGE_LAUNCHED").size() == 1 and facts(r, "MONSTER_CHARGE_WINDUP").size() == 1, "finishing toward a dead target neither restarts the charge nor refreshes Armor")

func round_boundary_check(pid: int) -> void:
	var w: Dictionary = phase_world()
	var dog: Dictionary = put(w, "Tumler", pid, at(700, pid), {"step_fp": 1, "tumler_charge_next_tick": 595, "hp": 100, "max_hp": 100})
	put(w, "Sooge", 1-pid, at(1100, pid), {"step_fp": 0, "sooge_root_round": 3, "hp": 100, "max_hp": 100, "armor": 100})
	var first: Dictionary = phase("charge_round_boundary_start_%d" % pid, w)
	var carried: Dictionary = Kanifous._entity(first.world, dog.id)
	check(carried.attributes.get("tumler_charge_phase") == "windup" and carried.attributes.armor == 6, "a late wind-up retains its state and temporary Armor across the round break")
	var second: Dictionary = phase("charge_round_boundary_finish_%d" % pid, first.world, "monster-check", 3)
	check(facts(second, "MONSTER_CHARGE_LAUNCHED").any(func(e): return e.tick == 2), "remaining wind-up resumes at the exact next-round tick")
	check(facts(second, "MONSTER_CHARGE_WINDUP").is_empty() and facts(second, "MONSTER_CHARGE_ENDED").any(func(e): return e.reason == "target"), "resumed charge lands without refreshing Armor")
	check(Kanifous._entity(second.world, dog.id).attributes.armor <= 1, "temporary Armor is removed on actual landing after the round break")

func wall_check(pid: int) -> void:
	var w: Dictionary = phase_world()
	var dog: Dictionary = put(w, "Tumler", pid, at(1400, pid), {"y_fp": 150, "hp": 100, "max_hp": 100})
	var target: Dictionary = put(w, "Vulture", 1-pid, at(1800, pid), {"y_fp": 150, "hp": 100, "max_hp": 100, "armor": 100, "step_fp": 0})
	var builder: Dictionary = put(w, "Wright", 1-pid, at(1900, pid), {"movement_ready_round": 99})
	var p: Dictionary = Fort.site_point(1-pid, 0)
	w.data["field_structures"] = [{"id": Work.Data.instance_id("wright_structure", builder.id, "0"), "kind": "fortification", "owner": 1-pid, "attributes": {"structure": "Wall", "site": 0, "lane": "Lord", "x_fp": p.x_fp, "y_fp": p.y_fp, "hp": Fort.WALL_HP, "max_hp": Fort.WALL_HP, "armor": Fort.WALL_ARMOR, "max_armor": Fort.WALL_ARMOR, "attack": 0, "ranged_next_tick": 0, "builder_id": builder.id}}]
	var r: Dictionary = phase("charge_wall_%d" % pid, w)
	check(facts(r, "MONSTER_CHARGE_ENDED").any(func(e): return e.reason == "wall"), "enemy wall stops the charge")
	check(not facts(r, "MARCHER_MELEE_ATTACK").any(func(e): return e.attacker.id == dog.id and e.target.id == target.id), "Tumler cannot strike through the standing wall")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	for pid in [0, 1]:
		direct_checks(pid)
		geometry_checks(pid)
		phase_checks(pid, false)
		phase_checks(pid, true)
		wall_check(pid)
		live_stats_check(pid)
		interruption_phases(pid)
		round_boundary_check(pid)
	if phase_output != null: phase_output.close()
	print("U13 Tumler charge failures: ", failures)
	quit(1 if failures else 0)
