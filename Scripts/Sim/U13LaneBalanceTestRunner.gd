extends "res://Scripts/Sim/U13MonsterTestRunner.gd"

const Fort = preload("res://Scripts/Sim/U13FieldFortifications.gd")
const Pacing = preload("res://Scripts/Sim/U13SupportPacing.gd")

func at(x: int, pid: int) -> int:
	return x if pid == 0 else 2400 - x

func roll_seed(source: Dictionary, target: Dictionary, kind: String, roll: int) -> String:
	var label: String = "KURCHIN_ARMORED_DEFLECTION" if target.attributes.monster_id == "Kurchin" else "TUMLER_HUNT_EVASION"
	for i in range(4000):
		var seed_value: String = "lane-defense:" + str(i)
		if MonsterFX.Lamp.draw(seed_value, "2:0:%s:%s:%s" % [kind, source.id, target.id], label, 100) == roll: return seed_value
	check(false, "find exact defense boundary roll")
	return "missing"

func profiles() -> void:
	for name in Monsters.NAMES:
		var expected: int = 15 if name == "Kurchin" else 4 if name == "Varn" else 5 if name in ["Sooge", "Sinodek"] else 10
		var a: Dictionary = Monsters.profile(name, "Lord", 0, 0, 1)
		check(a.hp == expected and a.max_hp == expected, name + " has the adopted starting and maximum HP")
	check(Monsters.ROSTER.Lemek.attack == 4 and Monsters.ROSTER.Tumler.attack == 2 and Monsters.ROSTER.Kurchin.armor == 6, "adopted offense and Armor retain the selected roles")

func taunt_checks() -> void:
	for pid in [0, 1]:
		for armor in [0, 6]:
			var w: Dictionary = phase_world()
			var tank: Dictionary = put(w, "Kurchin", pid, at(900, pid), {"hp": 100, "max_hp": 100, "armor": armor, "step_fp": 0})
			var ally: Dictionary = put(w, "Penitent", pid, at(1000, pid), {"hp": 100, "max_hp": 100, "attack": 1, "step_fp": 0})
			var attackers: Array = []
			for i in range(3): attackers.append(put(w, "Butcher", 1-pid, at(1060, pid), {"hp": 100, "max_hp": 100, "attack": 1, "y_fp": 285+i*15}, i))
			var r: Dictionary = phase("taunt_engaged_%d_%d" % [pid, armor], w)
			var strikes: Array = facts(r, "MARCHER_MELEE_ATTACK").filter(func(d): return d.attacker.owner == 1-pid)
			check(not strikes.is_empty() and strikes.all(func(d): return d.target.id == tank.id), "all engaged enemies leave their old target to attack Kurchin, even without Armor")
			for attacker in attackers:
				var after: Dictionary = Kanifous._entity(r.world, attacker.id)
				check(Fort.in_melee(after, tank), "taunted enemy closes on Kurchin instead of remaining at the old contact")
			var ids = Work.Ids.new(); ids.restore(w.entities); ids.retire(tank.id); w.entities = ids.snapshot()
			var released: Dictionary = phase("taunt_removed_%d_%d" % [pid, armor], w)
			check(facts(released, "MARCHER_MELEE_ATTACK").any(func(d): return d.attacker.owner == 1-pid and d.target.id == ally.id and d.tick == 0), "removing Kurchin immediately restores ordinary melee targeting")
		for gap in [360, 361]:
			var w: Dictionary = phase_world()
			var tank: Dictionary = put(w, "Kurchin", pid, at(700, pid))
			var enemy: Dictionary = put(w, "Butcher", 1-pid, at(700+gap, pid))
			check(MonsterFX.preferred(enemy, [tank, enemy]).is_empty() == (gap == 361), "taunt radius includes 360 and excludes 361")
			tank.attributes.lane = "Castle"
			check(MonsterFX.preferred(enemy, [tank, enemy]).is_empty(), "taunt never crosses lanes")
			tank.attributes.lane = "Lord"; tank.attributes.hidden = true
			check(MonsterFX.preferred(enemy, [tank, enemy]).is_empty(), "hidden Kurchin cannot draw attacks")
		# Taunt must not let an enemy pass through an intact wall.
		var w: Dictionary = phase_world()
		var tank: Dictionary = put(w, "Kurchin", pid, at(560, pid), {"y_fp": 150, "step_fp": 0})
		var enemy: Dictionary = put(w, "Butcher", 1-pid, at(760, pid), {"y_fp": 150, "attack": 1, "hp": 100, "max_hp": 100})
		var builder: Dictionary = put(w, "Wright", pid, at(0, pid), {"movement_ready_round": 10})
		var wall: Dictionary = {"id": Work.Data.instance_id("wright_structure", builder.id, "0"), "kind": "fortification", "owner": pid, "attributes": {"structure": "Wall", "site": 0, "lane": "Lord", "x_fp": at(640, pid), "y_fp": 150, "hp": 6, "max_hp": 6, "armor": 2, "max_armor": 2, "attack": 0, "ranged_next_tick": 0, "builder_id": builder.id}}
		w.data["field_structures"] = [wall]
		var r: Dictionary = phase("taunt_wall_%d" % pid, w)
		var strikes: Array = facts(r, "MARCHER_MELEE_ATTACK").filter(func(d): return d.attacker.id == enemy.id)
		check(not strikes.is_empty() and strikes.all(func(d): return d.target.id == wall.id), "taunted ground enemy attacks the blocking wall first")
		check((int(Kanifous._entity(r.world, enemy.id).attributes.x_fp)-int(wall.attributes.x_fp)) * (1 if pid == 0 else -1) > 0, "taunt cannot cross the intact wall")
		w = phase_world()
		tank = put(w, "Kurchin", pid, at(900, pid), {"step_fp": 0})
		enemy = put(w, "Butcher", 1-pid, at(1060, pid), {"rout_round": 2, "rout_effect_id": "taunt-retreat"})
		w.data["rout_profile"] = Marching.Rout.VERSION
		r = phase("taunt_retreat_%d" % pid, w)
		check(facts(r, "MARCHER_MELEE_ATTACK").is_empty() and Fort.gap(Kanifous._entity(r.world, enemy.id), tank) > Fort.gap(enemy, tank), "retreat still takes priority over taunt")

func defense_checks() -> void:
	for pid in [0, 1]:
		for kind in ["Melee", "Vulture"]:
			for roll in [74, 75]:
				var w: Dictionary = phase_world()
				var tank: Dictionary = put(w, "Kurchin", pid, at(900, pid), {"hp": 100, "max_hp": 100, "armor": 2, "step_fp": 0})
				var source: Dictionary = put(w, "Butcher" if kind == "Melee" else "Vulture", 1-pid, at(960 if kind == "Melee" else 1200, pid), {"step_fp": 0, "attack": 3, "hp": 100, "max_hp": 100})
				var seed_value: String = roll_seed(source, tank, kind, roll)
				var r: Dictionary = phase("armor_boundary_%d_%s_%d" % [pid, kind, roll], w, seed_value)
				var hits: Array = facts(r, "MARCHER_MELEE_ATTACK" if kind == "Melee" else "MARCHER_RANGED_ATTACK").filter(func(d): return d.target.id == tank.id and d.tick == 0)
				check(hits.size() == 1 and hits[0].evaded == (roll == 74) and hits[0].damage_dealt == (0 if roll == 74 else 1), "75% boundary deflects 74; 75 lands, spends Armor, and spills to HP")
				var first_tick: Dictionary = facts(r, "MARCHING_TICK")[0]
				var after: Dictionary = first_tick.units.filter(func(u): return u.id == tank.id)[0]
				check(after.attributes.armor == (2 if roll == 74 else 0) and after.attributes.hp == (100 if roll == 74 else 99), "deflected hit consumes neither Armor nor HP")
				if roll == 74:
					var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
					check(playback.build(r.events.map(func(e): return e.event)) and playback.sample(playback.FLIGHT_SECONDS + playback.MOVE_SECONDS/200.0 + 0.01).monster_attacks.any(func(a): return a.ability == "ArmorDeflect"), "successful deflection has shield feedback in lane playback")
		# First simultaneous hit spends the last Armor; later favorable rolls cannot deflect.
		var w: Dictionary = phase_world()
		var tank: Dictionary = put(w, "Kurchin", pid, at(900, pid), {"hp": 100, "max_hp": 100, "armor": 1, "step_fp": 0})
		for i in range(2): put(w, "Butcher", 1-pid, at(960, pid), {"hp": 100, "max_hp": 100, "attack": 1, "step_fp": 0, "y_fp": 285+i*30}, i)
		var attackers: Array = w.entities.entities.filter(func(u): return u.kind == "marcher" and u.owner == 1-pid)
		attackers.sort_custom(func(a,b): return a.id < b.id)
		var seed_value: String = "missing"
		for i in range(1000):
			var candidate: String = "depletion:" + str(i)
			var first: int = MonsterFX.Lamp.draw(candidate, "2:0:Melee:%s:%s" % [attackers[0].id, tank.id], "KURCHIN_ARMORED_DEFLECTION", 100)
			var second: int = MonsterFX.Lamp.draw(candidate, "2:0:Melee:%s:%s" % [attackers[1].id, tank.id], "KURCHIN_ARMORED_DEFLECTION", 100)
			if first >= 75 and second < 75: seed_value = candidate; break
		check(seed_value != "missing", "find landed-then-deflected depletion fixture")
		var r: Dictionary = phase("armor_same_tick_depletion_%d" % pid, w, seed_value)
		var hits: Array = facts(r, "MARCHER_MELEE_ATTACK").filter(func(d): return d.target.id == tank.id and d.tick == 0)
		check(hits.size() == 2 and hits.all(func(d): return not d.evaded) and hits[0].damage_dealt == 0 and hits[1].damage_dealt == 1, "Armor depletion disables deflection immediately within one volley")
		for name in ["Kurchin", "Tumler"]:
			for ability in ["Muno", "Beam", "Poison"]:
				w = phase_world()
				tank = put(w, name, pid, at(900, pid), {"waiting": true, "waiting_since_round": 1, "rout_round": 2})
				var source: Dictionary = put(w, "Muno", 1-pid, at(960, pid))
				seed_value = roll_seed(source, tank, ability, 0)
				var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
				w.data["kroni_actors"] = [{"fleeing": {tank.id: {}}, "fled_this_tick": []}]
				var result: Dictionary = MonsterFX.damage(w, buffer, {"source": source, "target": tank.id, "amount": 1, "bypass": ability == "Poison", "ability": ability}, context(w, seed_value), 0, Callable(Game.Content.new(), "react"))
				var hit: Dictionary = facts(result, "MONSTER_ATTACK")[0]
				check(hit.evaded == (ability != "Poison"), name + " defends during hold/retreat/fear but cannot evade ongoing poison")

func formation_checks() -> void:
	for pid in [0, 1]:
		for name in ["Butcher", "Wright"]:
			var w: Dictionary = phase_world()
			var follower: Dictionary = put(w, name, pid, at(780, pid), {"wright_built": true, "wright_released": true, "wright_site": 0, "wright_owner": pid, "wright_progress": 32, "wright_guard_until": 0} if name == "Wright" else {})
			var leader: Dictionary = put(w, "Penitent", pid, at(700, pid))
			var r: Dictionary = phase("penitent_leads_%s_%d" % [name, pid], w)
			var after: Dictionary = Kanifous._entity(r.world, follower.id)
			var ahead: Dictionary = Kanifous._entity(r.world, leader.id)
			check((int(ahead.attributes.x_fp)-int(after.attributes.x_fp))*int(follower.attributes.direction) >= 90, name + " gives the Penitent a 90-unit lead")
			leader.attributes.contact_tick = 400
			check(Pacing.speed(follower, [follower, leader], 4, 400, 2) == 4, name + " joins the fight at full speed once the leader engages")
			leader.attributes.contact_tick = -1
			check(Pacing.speed(follower, [follower, leader], 4, 400, 2, {leader.id: true}) == 4, "fleeing leader cannot hold back followers")
			if name == "Wright":
				follower.attributes.wright_released = false
				check(Pacing.speed(follower, [follower, leader], 4, 400, 2) == 4, "building and extended repair duty are exempt from approach pacing")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	profiles()
	taunt_checks()
	defense_checks()
	formation_checks()
	if phase_output != null: phase_output.close()
	print("U13 lane balance failures: ", failures)
	quit(1 if failures else 0)
