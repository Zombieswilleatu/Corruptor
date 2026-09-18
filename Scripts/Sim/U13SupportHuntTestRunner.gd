extends "res://Scripts/Sim/U13MonsterTestRunner.gd"

const Pacing = preload("res://Scripts/Sim/U13SupportPacing.gd")
const Fort = preload("res://Scripts/Sim/U13FieldFortifications.gd")
const Melee = preload("res://Scripts/Sim/U13FieldMelee.gd")

func at(x: int, pid: int) -> int:
	return x if pid == 0 else 2400 - x

func hunt_seed(source: Dictionary, target: Dictionary, kind: String, roll: int) -> String:
	var key: String = "2:0:%s:%s:%s" % [kind, source.id, target.id]
	for i in range(2000):
		var seed_value: String = "hunt-check:" + str(i)
		if MonsterFX.Lamp.draw(seed_value, key, "TUMLER_HUNT_EVASION", 100) == roll: return seed_value
	check(false, "find a seeded evasion boundary")
	return "missing"

func no_portal(unit: Dictionary) -> String:
	for i in range(100):
		var seed_value: String = "pacing:" + str(i)
		if MonsterFX.Lamp.draw(seed_value, unit.id + ":2", "PORTAL", 100) >= 25: return seed_value
	return "missing"

func set_target(w: Dictionary, dog: Dictionary, target: Dictionary) -> void:
	var ids = Work.Ids.new(); ids.restore(w.entities)
	dog.attributes["hunt_target"] = target.id
	ids.update(dog.id, dog.owner, dog.attributes)
	w.entities = ids.snapshot()

func pacing_checks() -> void:
	for pid in [0, 1]:
		for name in ["Vulture", "Kopita", "Sinodek", "Sooge"]:
			var w: Dictionary = phase_world()
			var extra: Dictionary = {"sooge_root_round": 2} if name == "Sooge" else {}
			var support: Dictionary = put(w, name, pid, at(780, pid), extra)
			var guard: Dictionary = put(w, "Penitent", pid, at(700, pid))
			var seed_value: String = no_portal(support)
			var r: Dictionary = phase("paced_%s_%d" % [name, pid], w, seed_value)
			var after: Dictionary = Kanifous._entity(r.world, support.id)
			var screen: Dictionary = Kanifous._entity(r.world, guard.id)
			check((int(screen.attributes.x_fp) - int(after.attributes.x_fp)) * support.attributes.direction >= Pacing.TRAIL, name + " lets a slower frontliner take the lead on side " + str(pid))
			check((int(after.attributes.x_fp) - int(support.attributes.x_fp)) * support.attributes.direction > 0, name + " keeps advancing with its screen")
			check(after.attributes.step_fp == support.attributes.step_fp, "pacing never changes the saved movement stat")
			var ids = Work.Ids.new(); ids.restore(w.entities); ids.retire(guard.id); w.entities = ids.snapshot()
			r = phase("alone_%s_%d" % [name, pid], w, seed_value)
			after = Kanifous._entity(r.world, support.id)
			check((int(after.attributes.x_fp) - int(support.attributes.x_fp)) * support.attributes.direction == int(support.attributes.step_fp) * 200, name + " resumes full movement when its screen is gone")
		var w: Dictionary = phase_world()
		var vulture: Dictionary = put(w, "Vulture", pid, at(700, pid))
		put(w, "Kopita", pid, at(700, pid), {"y_fp": 350})
		put(w, "Penitent", pid, at(700, pid), {"lane": "Castle"})
		var r: Dictionary = phase("support_only_%d" % pid, w)
		check(absi(int(Kanifous._entity(r.world, vulture.id).attributes.x_fp) - int(vulture.attributes.x_fp)) == 800, "supports and another lane cannot create a traffic queue")
		w = phase_world()
		vulture = put(w, "Kopita", pid, at(700, pid))
		put(w, "Penitent", pid, at(900, pid), {"hp": 100, "max_hp": 100, "armor": 100, "attack": 1})
		put(w, "Butcher", 1 - pid, at(980, pid), {"hp": 100, "max_hp": 100, "armor": 100, "attack": 1, "step_fp": 0})
		r = phase("screen_in_combat_%d" % pid, w)
		check(not facts(r, "MARCHER_MELEE_ATTACK").any(func(d): return d.attacker.id == vulture.id), "Kopita stays behind its engaged screen")
		check(not facts(r, "MARCHER_MELEE_ATTACK").any(func(d): return d.target.id == vulture.id), "screened support does not creep into enemy melee")
		# Retreat and fleeing allies are never a protective screen.
		var support: Dictionary = put(phase_world(), "Vulture", pid, at(700, pid))
		var guard: Dictionary = put(phase_world(), "Penitent", pid, at(700, pid))
		guard.attributes["rout_round"] = 2
		check(Pacing.speed(support, [support, guard], 4, 400, 2) == 4, "retreating frontliners do not slow supports")
		guard.attributes.erase("rout_round")
		check(Pacing.speed(support, [support, guard], 4, 400, 2, {guard.id: true}) == 4, "fleeing frontliners do not slow supports")

func hunting_checks() -> void:
	for pid in [0, 1]:
		# Reaching a detour at the lane edge must resume toward the prey,
		# rather than take the same leftward minimum step for both owners.
		var edge_world: Dictionary = phase_world()
		var edge_dog: Dictionary = put(edge_world, "Tumler", pid, at(1000, pid), {"y_fp": 30, "hp": 100, "max_hp": 100, "armor": 100})
		var edge_prey: Dictionary = put(edge_world, "Kopita", 1 - pid, at(1900, pid), {"y_fp": 30, "step_fp": 0, "hp": 100, "max_hp": 100, "armor": 100})
		put(edge_world, "Butcher", 1 - pid, at(1000, pid), {"y_fp": 130, "step_fp": 0})
		set_target(edge_world, edge_dog, edge_prey)
		var heading: Dictionary = MonsterFX.steer(edge_dog, edge_prey.attributes, edge_world.entities.entities.filter(func(u): return u.kind == "marcher"), [])
		check(heading.x_fp == edge_prey.attributes.x_fp and heading.y_fp == 30, "Tumler resumes hunting after reaching a clamped detour on side " + str(pid))
		var edge_result: Dictionary = phase("hunt_detour_arrived_%d" % pid, edge_world)
		var edge_after: Dictionary = Kanifous._entity(edge_result.world, edge_dog.id)
		check(not edge_after.is_empty() and (int(edge_after.attributes.x_fp) - int(edge_dog.attributes.x_fp)) * int(edge_dog.attributes.direction) > 0, "Tumler advances toward the target after completing the detour")
		for roll in [49, 50]:
			var w: Dictionary = phase_world()
			var dog: Dictionary = put(w, "Tumler", pid, at(900, pid), {"hp": 100, "max_hp": 100, "armor": 100})
			var prey: Dictionary = put(w, "Vulture", 1 - pid, at(1900, pid), {"step_fp": 0, "hp": 100, "max_hp": 100})
			var blocker: Dictionary = put(w, "Butcher", 1 - pid, at(960, pid), {"step_fp": 0, "attack": 1, "hp": 100, "max_hp": 100, "armor": 100})
			set_target(w, dog, prey)
			var r: Dictionary = phase("hunt_melee_%d_%d" % [pid, roll], w, hunt_seed(blocker, dog, "Melee", roll))
			var strikes: Array = facts(r, "MARCHER_MELEE_ATTACK").filter(func(d): return d.target.id == dog.id and d.tick == 0)
			check(strikes.size() == 1 and strikes[0].evaded == (roll == 49), "exact 50% boundary: 49 dodges, 50 connects")
			check(not facts(r, "MARCHER_MELEE_ATTACK").any(func(d): return d.attacker.id == dog.id and d.tick == 0), "Tumler does not attack a bystander before interception")
			var redirects: Array = facts(r, "MONSTER_HUNT_RETARGETED").filter(func(d): return d.tick == 0)
			check(redirects.is_empty() if roll == 49 else (redirects.size() == 1 and redirects[0].target_id == blocker.id), "only a landed melee hit immediately changes the hunt")
			if roll == 50:
				check(strikes[0].damage_dealt == 0, "Armor-only contact still intercepts the hunt")
				check(Kanifous._entity(r.world, dog.id).attributes.hunt_target == blocker.id, "interception persists instead of reverting to support preference")
				check(facts(r, "MARCHER_MELEE_ATTACK").any(func(d): return d.attacker.id == dog.id and d.target.id == blocker.id), "intercepted Tumler fights the attacker")
				check(not facts(r, "MARCHER_MELEE_ATTACK").any(func(d): return d.target.id == dog.id and d.evaded), "melee contact with the new target ends evasion")
			else:
				var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
				check(playback.build(r.events.map(func(e): return e.event)), "dodging hunt builds an authoritative playback")
				check(playback.sample(playback.FLIGHT_SECONDS + playback.MOVE_SECONDS / 200.0 + 0.01).monster_attacks.any(func(a): return a.ability == "HuntDodge"), "a successful dodge has visible feedback")
		for roll in [49, 50]:
			var w: Dictionary = phase_world()
			var dog: Dictionary = put(w, "Tumler", pid, at(900, pid), {"hp": 100, "max_hp": 100, "armor": 0})
			var prey: Dictionary = put(w, "Kopita", 1 - pid, at(1900, pid), {"step_fp": 0, "hp": 100, "max_hp": 100})
			var archer: Dictionary = put(w, "Vulture", 1 - pid, at(1000, pid), {"y_fp": 450, "step_fp": 0})
			set_target(w, dog, prey)
			var r: Dictionary = phase("hunt_ranged_%d_%d" % [pid, roll], w, hunt_seed(archer, dog, "Vulture", roll))
			var strikes: Array = facts(r, "MARCHER_RANGED_ATTACK").filter(func(d): return d.target.id == dog.id and d.tick == 0)
			check(strikes.size() == 1 and strikes[0].evaded == (roll == 49) and strikes[0].damage_dealt == (0 if roll == 49 else 1), "ranged hits roll evasion before applying damage")
			check(facts(r, "MONSTER_HUNT_RETARGETED").is_empty() and Kanifous._entity(r.world, dog.id).attributes.hunt_target == prey.id, "ranged damage never redirects the hunt")
		var w: Dictionary = phase_world()
		var dog: Dictionary = put(w, "Tumler", pid, at(900, pid), {"hp": 100, "max_hp": 100, "armor": 0})
		var prey: Dictionary = put(w, "Vulture", 1 - pid, at(960, pid), {"step_fp": 0, "hp": 100, "max_hp": 100, "armor": 100})
		set_target(w, dog, prey)
		var seed_value: String = hunt_seed(prey, dog, "Melee", 49)
		var r: Dictionary = phase("hunt_arrived_%d" % pid, w, seed_value)
		check(not facts(r, "MARCHER_MELEE_ATTACK").any(func(d): return d.target.id == dog.id and d.evaded), "reaching the target disables even a successful dodge roll")
		check(facts(r, "MONSTER_HUNT_RETARGETED").is_empty(), "fighting at the destination is no longer hunting")
		prey.attributes.x_fp = at(1900, pid)
		var rows: Array = [dog, prey]
		check(MonsterFX.hunting(dog, rows, 2), "valid distant prey enables hunting")
		var wall: Dictionary = {"id": "wall", "kind": "fortification", "owner": 1 - pid, "attributes": {"structure": "Wall", "lane": "Lord", "x_fp": at(980, pid), "y_fp": 300}}
		check(not MonsterFX.hunting(dog, rows, 2, [wall]), "being pinned at a hostile wall ends hunting evasion")
		var saved: Dictionary = Codec.decode(Codec.encode(w).text).value
		check(Kanifous._entity(saved, dog.id).attributes.hunt_target == prey.id, "save transport retains the chosen hunt target")
		for field in ["waiting", "movement_ready_round", "step_fp", "rout_round"]:
			var idle: Dictionary = dog.duplicate(true)
			idle.attributes[field] = {"waiting": true, "movement_ready_round": 3, "step_fp": 0, "rout_round": 2}[field]
			check(not MonsterFX.hunting(idle, [idle, prey], 2), "no hunt evasion while " + field)
		check(not MonsterFX.hunting(dog, [dog], 2), "a dead or missing target gives no evasion")
		prey.attributes["hidden"] = true
		check(not MonsterFX.hunting(dog, rows, 2), "a hidden target gives no evasion")
		prey.attributes.hidden = false
		check(not MonsterFX.evades(dog, prey, rows, context(w, seed_value), 0, "Poison"), "existing poison cannot be dodged")
		# Dash/ambush strikes are melee; beams and pulses are ranged damage.
		for ability in ["Muno", "Ambush", "Beam", "Kopita"]:
			for roll in [49, 50]:
				w = phase_world()
				dog = put(w, "Tumler", pid, at(900, pid), {"hp": 100, "max_hp": 100, "armor": 100})
				prey = put(w, "Vulture", 1 - pid, at(1900, pid), {"step_fp": 0})
				var caster: Dictionary = put(w, "Muno" if ability == "Muno" else "Dotra" if ability == "Ambush" else "Sooge" if ability == "Beam" else "Kopita", 1 - pid, at(1200, pid))
				set_target(w, dog, prey)
				var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
				var result: Dictionary = MonsterFX.damage(w, buffer, {"source": caster, "target": dog.id, "amount": 1, "bypass": false, "ability": ability}, context(w, hunt_seed(caster, dog, ability, roll)), 0, Callable(Game.Content.new(), "react"))
				var hit: Dictionary = facts(result, "MONSTER_ATTACK")[0]
				check(hit.evaded == (roll == 49) and buffer.get_entity(dog.id).attributes.armor == (100 if roll == 49 else 99), ability + " dodge preserves both HP and Armor")
				check(buffer.get_entity(dog.id).attributes.hunt_target == (caster.id if roll == 50 and ability in ["Muno", "Ambush"] else prey.id), ability + " uses the correct interception category")
		for fear in ["Kroni", "Portal"]:
			w = phase_world()
			dog = put(w, "Tumler", pid, at(900, pid))
			prey = put(w, "Vulture", 1 - pid, at(1900, pid), {"step_fp": 0})
			var caster: Dictionary = put(w, "Muno", 1 - pid, at(1200, pid))
			set_target(w, dog, prey)
			if fear == "Kroni": w.data["kroni_actors"] = [{"fleeing": {dog.id: {}}, "fled_this_tick": []}]
			else: w.data.monsters.fields.append({"kind": "portal", "lane": "Lord", "x_fp": at(1100, pid), "y_fp": 300})
			var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
			var result: Dictionary = MonsterFX.damage(w, buffer, {"source": caster, "target": dog.id, "amount": 1, "bypass": false, "ability": "Muno"}, context(w, hunt_seed(caster, dog, "Muno", 49)), 0, Callable(Game.Content.new(), "react"))
			check(not facts(result, "MONSTER_ATTACK")[0].evaded and facts(result, "MONSTER_HUNT_RETARGETED").is_empty(), fear + " fleeing does not count as pursuing prey")

func cluster_checks() -> void:
	for pid in [0, 1]:
		var w: Dictionary = phase_world()
		var durable: Dictionary = {"hp": 100, "max_hp": 100}
		put(w, "Butcher", pid, at(500, pid), dict_with_y(durable, 270))
		put(w, "Penitent", pid, at(500, pid), dict_with_y(durable, 330))
		var dog: Dictionary = put(w, "Tumler", pid, at(500, pid), durable)
		put(w, "Butcher", 1 - pid, at(880, pid), dict_with_y(durable, 270))
		put(w, "Penitent", 1 - pid, at(880, pid), dict_with_y(durable, 330))
		var prey: Dictionary = put(w, "Vulture", 1 - pid, at(1000, pid), dict_with_y(durable, 270))
		put(w, "Vulture", 1 - pid, at(1000, pid), dict_with_y(durable, 330), 1)
		set_target(w, dog, prey)
		var approaching: Dictionary = dog.duplicate(true)
		approaching.attributes.x_fp = at(750, pid)
		var rows: Array = w.entities.entities.filter(func(u): return u.kind == "marcher")
		var heading: Dictionary = MonsterFX.steer(approaching, prey.attributes, rows, [])
		check(heading == prey.attributes, "nearby enemy bodies cannot divert a hunt from clustered prey")
		var pool: Dictionary = {"kind": "pool", "lane": "Lord", "x_fp": at(880, pid), "y_fp": 300}
		heading = MonsterFX.steer(approaching, prey.attributes, rows, [pool])
		check(heading != prey.attributes, "direct pursuit still avoids a slowing pool")
		var r: Dictionary = phase("hunt_cluster_%d" % pid, w, "cluster-regression")
		var hits: Array = facts(r, "MARCHER_MELEE_ATTACK").filter(func(d): return d.attacker.id == dog.id)
		check(not hits.is_empty() and hits[0].tick < 80, "Tumler enters the clustered fight promptly on side " + str(pid))

func dict_with_y(base: Dictionary, y: int) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	result["y_fp"] = y
	return result

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	pacing_checks()
	hunting_checks()
	cluster_checks()
	if phase_output != null: phase_output.close()
	print("U13 Support/Hunt failures: ", failures)
	quit(0 if failures == 0 else 1)
