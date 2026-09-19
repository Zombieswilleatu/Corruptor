extends "res://Scripts/Sim/U13UIFeedbackTestRunner.gd"

const Monsters = preload("res://Scripts/Sim/U13MonsterRules.gd")
const MonsterFX = preload("res://Scripts/Sim/U13MonsterEffects.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Kanifous = preload("res://Scripts/Sim/U13Kanifous.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
var phase_output

func put(world: Dictionary, name: String, owner: int, x: int, extra: Dictionary = {}, ordinal: int = 0) -> Dictionary:
	var ids = Work.Ids.new(); ids.restore(world.entities)
	var a: Dictionary = Monsters.profile(name, "Lord", owner, 0, 1) if name in Monsters.NAMES else Marching.profile(name, "Lord", owner, 0, 1, true)
	a.x_fp = x
	a.merge(extra, true)
	var made: Dictionary = ids.create("marcher", "monster-test:" + name + ":" + str(owner), ordinal, owner, a)
	world.entities = ids.snapshot()
	return made.entity

func phase_world() -> Dictionary:
	var world: Dictionary = fixture()
	world.data["marching_round"] = 1
	world.data["marching_regen_round"] = 2
	world.data.kanifous_loss_round = 2
	world.data.monsters.phase_round = 1
	return world

func context(world: Dictionary, seed_value: String = "monster-check") -> Dictionary:
	return {"world": world, "round": 2, "hook": "marching", "seed": seed_value, "player_order": [0, 1], "persistent_effects": [], "full_roster": true}

func selected_seed(id: String, purpose: String, chance: int) -> String:
	for i in range(1000):
		var seed_value: String = "monster-check:" + str(i)
		if MonsterFX.Lamp.draw(seed_value, id + ":2", purpose, 100) < chance: return seed_value
	return "missing"

func phase(name: String, world: Dictionary, seed_value: String = "monster-check", round_number: int = 2) -> Dictionary:
	var c: Dictionary = context(world, seed_value)
	c.round = round_number
	var content = Game.Content.new()
	var result: Dictionary = Marching.resolve(c, Callable(content, "react"))
	check(result.action == "resolved", name + " resolves")
	if result.action == "invalid": print(result); return result
	check(Marching.valid(result.world) and Monsters.valid(result.world), name + " keeps valid unit and field state")
	var replay: Dictionary = Marching.resolve(c, Callable(content, "react"))
	check(replay == result, name + " deterministic replay")
	if phase_output != null:
		var record: Dictionary = {"name": name, "context": c, "result": result}
		var encoded: Dictionary = Codec.encode(record)
		if not encoded.has("text"):
			bad_data(record, "record")
			check(false, "phase transport encodes")
		else: phase_output.store_line(encoded.text)
		phase_output.flush()
	return result

func sooge_ramp_checks() -> void:
	var world: Dictionary = phase_world()
	var unit: Dictionary = put(world, "Sooge", 0, 700, {"birth_round": 2, "movement_ready_round": 3})
	var chances: Array = [25, 40, 55, 70, 85, 100]
	# One fixed game seed misses the first five rolls, then needs the 100% cap.
	var seed_value: String = ""
	for i in range(10000):
		var candidate: String = "sooge-ramp:" + str(i)
		var misses: bool = true
		for attempt in range(6):
			if MonsterFX.Lamp.draw(candidate, "%s:%d" % [unit.id, attempt + 3], "ROOT", 100) < mini(85, chances[attempt]):
				misses = false
				break
		if misses: seed_value = candidate; break
	check(not seed_value.is_empty(), "Sooge ramp has a deterministic high-roll fixture")
	world = phase("sooge_birth_hold", world, seed_value).world
	var a: Dictionary = Kanifous._entity(world, unit.id).attributes
	check(a.sprite_form == "mobile" and a.sooge_root_attempts == 0 and a.sooge_root_round == 0, "birth hold neither rolls nor increases Sooge chance")
	for attempt in range(6):
		var n: int = attempt + 3
		a = Kanifous._entity(world, unit.id).attributes
		check(Monsters.root_chance(a) == chances[attempt], "Sooge eligible roll %d has %d%% chance" % [attempt + 1, chances[attempt]])
		var result: Dictionary = phase("sooge_ramp_%d" % [attempt + 1], world, seed_value, n)
		world = result.world
		a = Kanifous._entity(world, unit.id).attributes
		check(a.sooge_root_attempts == attempt + 1 and a.sooge_root_round == n, "Sooge counts once per active round")
		check(a.sprite_form == ("turret" if attempt == 5 else "mobile"), "Sooge high rolls miss until guaranteed sixth eligible round")
		if attempt == 0:
			var buffer = Marching.Buffer.new(); buffer.restore(world.entities)
			var c: Dictionary = context(world, seed_value); c.round = n
			MonsterFX.step(world, buffer, c, 0, Callable(Game.Content.new(), "react"))
			check(buffer.get_entity(unit.id).attributes.sooge_root_attempts == 1 and buffer.get_entity(unit.id).attributes.sprite_form == "mobile", "same-round replay cannot advance or reroll rooting")
		if attempt == 2:
			var envelope: Dictionary = JSON.parse_string(Game.encode_snapshot(world))
			var loaded: Dictionary = bytes_to_var(Marshalls.base64_to_raw(envelope.payload))
			check(loaded == world and Marching.valid(loaded), "save JSON transport preserves Sooge chance and round state")
			world = loaded
	check(Monsters.root_chance(a) == 100, "Sooge chance caps at 100%")
	for key in ["sooge_root_attempts", "sooge_root_round", "beam_next_tick", "beam_charge_tick", "beam_ready_tick"]:
		for value in [-1, 0.5, "1", true, null]:
			var forged: Dictionary = a.duplicate(true); forged[key] = value
			check(not Monsters.valid_unit(forged), "invalid Sooge counter rejected: " + key)
	# A newly summoned Sooge does not inherit the global round's accumulated odds.
	world = phase_world()
	unit = put(world, "Sooge", 0, 700, {"birth_round": 7, "movement_ready_round": 8})
	var buffer = Marching.Buffer.new(); buffer.restore(world.entities)
	var late: Dictionary = context(world, seed_value); late.round = 8
	MonsterFX.step(world, buffer, late, 0, Callable(Game.Content.new(), "react"))
	a = buffer.get_entity(unit.id).attributes
	check(a.sprite_form == "mobile" and a.sooge_root_attempts == 1 and Monsters.root_chance(a) == 40, "late summon starts at 25%, independent of global round")

func facts(result: Dictionary, kind: String) -> Array:
	return result.get("events", []).filter(func(r): return r.event.type == kind).map(func(r): return r.event.data)

func block_seed(target: Dictionary, attacker: Dictionary, kind: String, tick: int, wanted: bool) -> String:
	for i in range(1000):
		var seed_value: String = "penitent-block:" + str(i)
		if Marching.Ranged.Defense.blocks(target, attacker.id, seed_value, 2, tick, kind) == wanted: return seed_value
	return "missing"

func penitent_block_checks() -> void:
	for pid in [0, 1]:
		for wanted in [true, false]:
			var w: Dictionary = phase_world()
			var target: Dictionary = put(w, "Penitent", pid, 1200, {"birth_round": 2, "movement_ready_round": 3})
			var shooter: Dictionary = put(w, "Vulture", 1 - pid, 1200 + (300 if pid == 0 else -300))
			var seed_value: String = block_seed(target, shooter, "Vulture", 0, wanted)
			var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
			var result: Dictionary = Marching.Ranged.volley(w.duplicate(true), buffer, context(w, seed_value), {}, 0, {}, Callable(Game.Content.new(), "react"))
			var after: Dictionary = buffer.get_entity(target.id).attributes
			check(facts(result, "MARCHER_RANGED_ATTACK")[0].blocked == wanted and after.hp == target.attributes.hp and after.armor == (3 if wanted else 2), "Penitent owner %d %s preserves HP and only blocked shots preserve Armor" % [pid, "block" if wanted else "failed block"])
			check(after.movement_ready_round == 2 and buffer.get_entity(shooter.id).attributes.ranged_next_tick == 450, "blocked or absorbed hit wakes a recruit and spends the shooter's attack")
			var played: Dictionary = phase("penitent_%d_block_%s" % [pid, str(wanted)], w, seed_value)
			var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
			check(playback.build(played.events.map(func(r): return r.event)) and playback.sample(0.22).monster_attacks.any(func(a): return a.ability == "RangedBlock") == wanted, "shield glint appears only for an actual block")
	# One volley can contain a blocked shot and a damaging shot on the same body.
	var w: Dictionary = phase_world()
	var target: Dictionary = put(w, "Penitent", 0, 1200, {"armor": 0, "hp": 100, "max_hp": 100})
	var first: Dictionary = put(w, "Vulture", 1, 1500, {"y_fp": 200})
	var second: Dictionary = put(w, "Vulture", 1, 1500, {"y_fp": 400}, 1)
	var seed_value: String = ""
	for i in range(1000):
		var candidate: String = "independent-block:" + str(i)
		if Marching.Ranged.Defense.blocks(target, first.id, candidate, 2, 0, "Vulture") != Marching.Ranged.Defense.blocks(target, second.id, candidate, 2, 0, "Vulture"):
			seed_value = candidate; break
	var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
	var volley: Dictionary = Marching.Ranged.volley(w.duplicate(true), buffer, context(w, seed_value), {}, 0, {}, Callable(Game.Content.new(), "react"))
	var shots: Array = facts(volley, "MARCHER_RANGED_ATTACK")
	check(shots.size() == 2 and shots.filter(func(d): return d.blocked).size() == 1 and buffer.get_entity(target.id).attributes.hp == 99, "each incoming shot gets its own block roll")
	phase("independent_penitent_volley", w, seed_value)
	for pid in [0, 1]:
		for wanted in [true, false]:
			w = phase_world()
			target = put(w, "Penitent", pid, 1200, {"armor": 0, "step_fp": 0})
			var source: Dictionary = put(w, "Sooge", 1 - pid, 300 if pid == 1 else 2100, {"sprite_form": "turret", "step_fp": 0})
			seed_value = block_seed(target, source, "Beam", 40, wanted)
			var beam: Dictionary = phase("penitent_%d_beam_%s" % [pid, str(wanted)], w, seed_value)
			var hit: Dictionary = facts(beam, "MONSTER_ATTACK").filter(func(d): return d.ability == "Beam")[0]
			check(hit.blocked == wanted and hit.damage_dealt == (0 if wanted else 3), "Penitent can block Sooge damage at detonation")
	# An otherwise successful ranged-block roll does not stop non-ranged damage.
	for ability in ["Poison", "Kopita", "Muno", "Ambush"]:
		w = phase_world()
		target = put(w, "Penitent", 0, 1200, {"armor": 0})
		var source: Dictionary = put(w, "Sooge", 1, 1500)
		seed_value = block_seed(target, source, "Beam", 0, true)
		buffer.restore(w.entities)
		var result: Dictionary = MonsterFX.damage(w, buffer, {"source": source, "target": target.id, "amount": 3, "bypass": ability == "Poison", "ability": ability}, context(w, seed_value), 0, Callable(Game.Content.new(), "react"))
		check(not facts(result, "MONSTER_ATTACK")[0].blocked and buffer.get_entity(target.id).attributes.hp == 2, ability + " does not trigger ranged blocks")
	for name in ["Butcher", "Vulture", "Wright", "Lemek"]:
		w = phase_world(); target = put(w, name, 0, 1200)
		check(not Marching.Ranged.Defense.blocks(target, "attacker", "shield", 2, 0, "Vulture"), name + " does not gain the Penitent boon")

func pool_checks() -> void:
	for pid in [0, 1]:
		var base: Dictionary = phase_world()
		var start: int = 600 if pid == 0 else 1800
		var lemek: Dictionary = put(base, "Lemek", pid, start)
		var regular: Dictionary = put(base, "Penitent", pid, start, {"lane": "Castle"})
		var clear: Dictionary = phase("pool_control_%d" % pid, base)
		for pool_owner in [0, 1]:
			var w: Dictionary = base.duplicate(true)
			for lane in ["Lord", "Castle"]:
				w.data.monsters.fields.append({"id": "pool:" + lane, "kind": "pool", "owner": pool_owner, "lane": lane, "x_fp": start, "y_fp": 300, "expires_round": 3})
			var result: Dictionary = phase("pool_owner_%d_unit_%d" % [pool_owner, pid], w)
			check(Kanifous._entity(result.world, lemek.id).attributes.x_fp == Kanifous._entity(clear.world, lemek.id).attributes.x_fp, "Lemek owner %d ignores owner %d pool throughout Marching" % [pid, pool_owner])
			check(absi(int(Kanifous._entity(result.world, regular.id).attributes.x_fp) - start) < absi(int(Kanifous._entity(clear.world, regular.id).attributes.x_fp) - start), "pool still slows ordinary units of either side")

func beam_boundary_checks() -> void:
	var w: Dictionary = phase_world()
	var unit: Dictionary = put(w, "Sooge", 0, 300, {"sprite_form": "turret", "attack": 3, "armor": 6, "max_armor": 6, "step_fp": 0, "beam_next_tick": 615})
	put(w, "Penitent", 1, 1500, {"hp": 100, "max_hp": 100, "step_fp": 0})
	var pending: Dictionary = phase("beam_charge_across_boundary", w)
	check(facts(pending, "MONSTER_BEAM_FIRED").is_empty() and Kanifous._entity(pending.world, unit.id).attributes.beam_ready_tick == 615, "late charge carries into next round without firing early")
	var saved: Dictionary = JSON.parse_string(Game.encode_snapshot(pending.world))
	var restored: Dictionary = bytes_to_var(Marshalls.base64_to_raw(saved.payload))
	var first: Dictionary = phase("beam_release_after_restore", restored, "monster-check", 3)
	var shots: Array = facts(first, "MONSTER_BEAM_FIRED")
	check(shots.size() == 1 and shots[0].tick == 15, "saved charge releases exactly once at its recorded deadline")
	var second: Dictionary = phase("beam_full_round_cooldown", first.world, "monster-check", 4)
	shots = facts(second, "MONSTER_BEAM_FIRED")
	check(shots.size() == 1 and shots[0].tick == 15, "successive beams are 200 ticks apart across round boundaries")
	w = phase_world()
	unit = put(w, "Sooge", 0, 300, {"sprite_form": "turret", "step_fp": 0, "beam_next_tick": 596})
	var victim: Dictionary = put(w, "Penitent", 1, 1500, {"hp": 100, "max_hp": 100, "step_fp": 0})
	var fired: Dictionary = phase("beam_delayed_across_boundary", w)
	check(facts(fired, "MONSTER_BEAM_FIRED").size() == 1 and facts(fired, "MONSTER_ATTACK").is_empty() and fired.world.data.monsters.pending_beams.size() == 1, "late laser records a pending blast without dealing immediate damage")
	# A released ground scar survives its caster; only units still in it are hit.
	var ids = Work.Ids.new(); ids.restore(fired.world.entities); ids.retire(unit.id)
	fired.world.entities = ids.snapshot()
	var blasted: Dictionary = phase("beam_detonates_without_caster", fired.world, "monster-check", 3)
	var hits: Array = facts(blasted, "MONSTER_ATTACK")
	check(hits.size() == 1 and hits[0].tick == 4 and hits[0].target.id == victim.id and blasted.world.data.monsters.pending_beams.is_empty(), "pending blast detonates once after the caster dies, in the next round")
	var escaped: Dictionary = ids.get_entity(victim.id); escaped.attributes.y_fp = 500
	ids.update(escaped.id, escaped.owner, escaped.attributes)
	var dodged: Dictionary = fired.world.duplicate(true); dodged.entities = ids.snapshot()
	var missed: Dictionary = phase("beam_dodged_ground_scar", dodged, "monster-check", 3)
	check(facts(missed, "MONSTER_BEAM_DETONATED").size() == 1 and facts(missed, "MONSTER_ATTACK").is_empty(), "ground path stays locked and units outside it at detonation escape damage")
	var boundary_playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
	check(boundary_playback.build(blasted.events.map(func(r): return r.event)) and boundary_playback.sample(0.1).monster_attacks.any(func(a): return a.ability == "BeamTrail"), "pending ground scar stays visible across round boundaries")
	# No targets means no stored instant shot when a new enemy arrives.
	w = phase_world()
	unit = put(w, "Sooge", 0, 300, {"sprite_form": "turret", "step_fp": 0, "beam_charge_tick": 400, "beam_ready_tick": 432})
	var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
	MonsterFX.step(w, buffer, context(w), 10, Callable(Game.Content.new(), "react"))
	check(buffer.get_entity(unit.id).attributes.beam_ready_tick == 0, "losing every target cancels the charge")
	w = phase_world()
	unit = put(w, "Sooge", 0, 300, {"sprite_form": "turret", "step_fp": 0})
	put(w, "Penitent", 1, 1500, {"hp": 100, "max_hp": 100, "step_fp": 0})
	buffer.restore(w.entities)
	var charged: Dictionary = MonsterFX.step(w, buffer, context(w), 0, Callable(Game.Content.new(), "react"))
	w = charged.world
	var closer: Dictionary = put(w, "Butcher", 1, 900, {"hp": 100, "max_hp": 100, "step_fp": 0})
	buffer.restore(w.entities)
	var released: Dictionary = MonsterFX.step(w, buffer, context(w), 32, Callable(Game.Content.new(), "react"))
	check(facts(released, "MONSTER_BEAM_FIRED")[0].target.id == closer.id, "release aims at the currently nearest enemy, not the original charge target")
	w = phase_world()
	put(w, "Sooge", 0, 300, {"sprite_form": "turret", "step_fp": 0, "hp": 1, "armor": 0})
	put(w, "Butcher", 1, 380, {"attack": 100, "step_fp": 0})
	var killed: Dictionary = phase("beam_killed_during_charge", w)
	check(facts(killed, "MONSTER_BEAM_FIRED").is_empty(), "killing Sooge during charge prevents the shot")
	var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
	check(playback.build(killed.events.map(func(r): return r.event)) and playback.sample(0.5).monster_attacks.is_empty(), "dead Sooge does not leave a charging glow")

func dotra_visibility_checks() -> void:
	var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
	for pid in [0, 1]:
		var isolated: Dictionary = phase_world()
		var hidden: Dictionary = put(isolated, "Dotra", pid, 1200, {"hidden": true})
		for kind in ["Butcher", "Vulture", "Muno", "Tumler", "Sooge"]:
			var enemy: Dictionary = put(isolated, kind, 1 - pid, 1260)
			check(Marching.FieldMelee.nearest(enemy, [hidden]).is_empty() and Marching.Ranged.nearest(enemy, [hidden]).is_empty() and MonsterFX.nearest(enemy, [hidden]).is_empty(), kind + " cannot select hidden Dotra")
			var visible: Dictionary = hidden.duplicate(true); visible.attributes.hidden = false
			check(Marching.FieldMelee.nearest(enemy, [visible]).id == hidden.id and Marching.Ranged.nearest(enemy, [visible]).id == hidden.id and MonsterFX.nearest(enemy, [visible]).id == hidden.id, kind + " can select Dotra after reveal")
		for attacker in ["Vulture", "Muno"]:
			var w: Dictionary = phase_world()
			var source: Dictionary = put(w, "Dotra", pid, 0 if pid == 0 else 2400, {"hp": 100, "max_hp": 100})
			put(w, attacker, 1 - pid, 400 if pid == 0 else 2000, {"y_fp": 350, "step_fp": 0, "hp": 100, "max_hp": 100})
			var resolved: Dictionary = phase("dotra_%d_visible_to_%s" % [pid, attacker], w, selected_seed(source.id, "HIDE", 25))
			var incoming: Array = resolved.events.filter(func(r): return r.event.type in ["MARCHER_RANGED_ATTACK", "MARCHER_MELEE_ATTACK", "MONSTER_ATTACK"] and r.event.data.target.id == source.id)
			check(not incoming.is_empty() and incoming.all(func(r): return not r.event.data.target.attributes.get("hidden", false)), "actual targeted hits only select revealed Dotra")
			check(playback.build(resolved.events.map(func(r): return r.event)), "Dotra reveal replay builds")
			var first_at: float = 0.18 + 6.0 * float(int(incoming[0].event.data.tick) + 1) / 200.0
			var before: Dictionary = playback.sample(first_at - 0.09)
			check(before.units.any(func(u): return u.id == source.id and u.attributes.get("hidden", false)), "regression sample is still visibly hidden before the reveal")
			var revealed: Dictionary = playback.sample(first_at)
			check(revealed.units.any(func(u): return u.id == source.id and not u.attributes.get("hidden", false)), "Dotra is visible when the recorded attack lands")
			if attacker == "Vulture":
				check(before.projectiles.is_empty(), "knives cannot visually seek a still-hidden Dotra")
				check(not revealed.projectiles.is_empty(), "reveal-tick knife hit still gets visible impact feedback")
			else:
				check(not before.monster_attacks.any(func(a): return a.ability == "MunoDash"), "Muno cannot begin its visible lunge at a still-hidden Dotra")
				check(revealed.monster_attacks.any(func(a): return a.ability == "MunoDash"), "Muno strike appears after Dotra reveals")
		# A reveal followed by a lethal counterattack leaves no visible living
		# unit frame. It still must not show an arrow seeking hidden Dotra.
		var lethal_world: Dictionary = phase_world()
		var victim: Dictionary = put(lethal_world, "Dotra", pid, 0 if pid == 0 else 2400, {"hp": 1, "armor": 0})
		put(lethal_world, "Vulture", 1 - pid, 400 if pid == 0 else 2000, {"y_fp": 350, "step_fp": 0, "attack": 100, "hp": 100, "max_hp": 100})
		var lethal: Dictionary = phase("dotra_%d_lethal_reveal_counter" % pid, lethal_world, selected_seed(victim.id, "HIDE", 25))
		var shot: Dictionary = facts(lethal, "MARCHER_RANGED_ATTACK")[0]
		var impact_at: float = 0.18 + 6.0 * float(int(shot.tick) + 1) / 200.0
		check(Kanifous._entity(lethal.world, victim.id).is_empty() and not shot.target.attributes.hidden, "lethal counterattack waits for the ambush reveal")
		check(playback.build(lethal.events.map(func(r): return r.event)) and playback.sample(impact_at - 0.09).projectiles.is_empty() and not playback.sample(impact_at).projectiles.is_empty(), "lethal reveal still suppresses early knife flight and shows the impact")
		# Towers use a separate target-selection loop from ordinary Vultures.
		var w: Dictionary = phase_world()
		var owner: int = 1 - pid
		var p: Dictionary = Marching.Fort.site_point(owner, 2)
		var builder: Dictionary = put(w, "Wright", owner, p.x_fp)
		var ids = Work.Ids.new(); ids.restore(w.entities); ids.retire(builder.id); w.entities = ids.snapshot()
		w.data["field_structures"] = [{"id": Marching.Fort.Data.instance_id("wright_structure", builder.id, "2"), "kind": "fortification", "owner": owner, "attributes": {"structure": "Tower", "site": 2, "lane": "Lord", "x_fp": p.x_fp, "y_fp": p.y_fp, "hp": 6, "max_hp": 6, "armor": 4, "max_armor": 4, "attack": 1, "ranged_next_tick": 0, "builder_id": builder.id}}]
		var stalker: Dictionary = put(w, "Dotra", pid, int(p.x_fp) + (300 if owner == 0 else -300), {"hidden": true, "step_fp": 0, "hp": 100, "max_hp": 100})
		var concealed: Dictionary = phase("dotra_%d_tower_ignores_hidden" % pid, w)
		check(facts(concealed, "MARCHER_RANGED_ATTACK").is_empty() and Kanifous._entity(concealed.world, stalker.id).attributes.hidden, "tower cannot acquire or damage concealed Dotra")
		w = concealed.world
		var exposed: Dictionary = Kanifous._entity(w, stalker.id)
		exposed.attributes.hidden = false; exposed.attributes["dotra_concealment_round"] = 3
		ids.restore(w.entities); ids.update(exposed.id, exposed.owner, exposed.attributes); w.entities = ids.snapshot()
		var revealed: Dictionary = phase("dotra_%d_tower_targets_revealed" % pid, w, "monster-check", 3)
		check(not facts(revealed, "MARCHER_RANGED_ATTACK").is_empty(), "tower resumes attacks on visible Dotra")
	var w: Dictionary = phase_world()
	put(w, "Dotra", 0, 800, {"hidden": true, "step_fp": 0})
	put(w, "Dotra", 0, 820, {"hidden": true, "step_fp": 0}, 1)
	put(w, "Butcher", 1, 1040, {"hp": 1, "armor": 0, "step_fp": 0})
	var competed: Dictionary = phase("dotra_lost_victim_stays_hidden", w)
	check(facts(competed, "MONSTER_ATTACK").filter(func(d): return d.ability == "Ambush").size() == 1 and competed.world.entities.entities.filter(func(u): return u.attributes.get("monster_id") == "Dotra" and u.attributes.hidden).size() == 1, "a queued ambush whose victim already died leaves its Dotra hidden")


func dotra_stalking_checks() -> void:
	for pid in [0, 1]:
		var w: Dictionary = phase_world()
		var start: int = 0 if pid == 0 else 2400
		var actor: Dictionary = put(w, "Dotra", pid, start)
		var seed_value: String = selected_seed(actor.id, "HIDE", 25)
		var creeping: Dictionary = phase("dotra_%d_half_speed" % pid, w, seed_value)
		var after: Dictionary = Kanifous._entity(creeping.world, actor.id).attributes
		check(after.hidden and absi(int(after.x_fp) - start) == 800 and after.step_fp == 4, "hidden Dotra keeps full movement speed and its saved base speed")
		w = phase_world()
		actor = put(w, "Dotra", pid, start, {"hp": 100, "max_hp": 100})
		var prey: Dictionary = put(w, "Vulture", 1 - pid, 400 if pid == 0 else 2000, {"y_fp": 350, "step_fp": 0, "hp": 100, "max_hp": 100})
		var hunt: Dictionary = phase("dotra_%d_moving_ambush" % pid, w, seed_value)
		var ambushes: Array = facts(hunt, "MONSTER_ATTACK").filter(func(d): return d.ability == "Ambush")
		check(ambushes.size() == 1 and ambushes[0].tick > 0 and ambushes[0].target.id == prey.id and ambushes[0].attacker.attributes.x_fp != start, "concealed Dotra closes distance and triggers one surprise attack")
		if ambushes.is_empty(): continue
		var tick: int = ambushes[0].tick
		check(tick <= 50, "full-speed concealment closes this ambush within a quarter round")
		check(not facts(hunt, "MARCHER_RANGED_ATTACK").any(func(d): return d.target.id == actor.id and d.tick < tick), "ordinary ranged attacks cannot select the stalking Dotra")
		after = Kanifous._entity(hunt.world, actor.id).attributes
		check(not after.hidden, "ambush reveals Dotra when the bonus strike lands")
	var w: Dictionary = phase_world()
	var actor: Dictionary = put(w, "Dotra", 0, 800, {"hidden": true, "step_fp": 0})
	for n in range(2, 10):
		var result: Dictionary = phase("dotra_stays_hidden_%d" % n, w, "monster-check", n)
		check(Kanifous._entity(result.world, actor.id).attributes.hidden, "Dotra stays concealed across rounds until it can ambush")
		w = result.world
		if n == 4:
			var saved: Dictionary = JSON.parse_string(Game.encode_snapshot(w))
			var restored: Dictionary = bytes_to_var(Marshalls.base64_to_raw(saved.payload))
			check(restored == w and Kanifous._entity(restored, actor.id).attributes.hidden, "save round-trip retains concealment")
			w = restored
			var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
			var c: Dictionary = context(w); c.round = n
			var duplicate: Dictionary = MonsterFX.step(w, buffer, c, 0, Callable(Game.Content.new(), "react"))
			check(facts(duplicate, "MONSTER_CONCEALMENT").is_empty() and buffer.get_entity(actor.id).attributes.hidden, "repeating the same round cannot reroll concealment")
	var prey: Dictionary = put(w, "Butcher", 1, 1040, {"step_fp": 0, "hp": 100, "max_hp": 100})
	var immediate: Dictionary = phase("dotra_reveals_with_ambush", w, "monster-check", 10)
	check(facts(immediate, "MONSTER_ATTACK").any(func(d): return d.ability == "Ambush" and d.tick == 0 and d.target.id == prey.id and not d.attacker.attributes.hidden), "Dotra reveals and delivers its bonus strike when prey reaches ambush range")
	w = phase_world()
	actor = put(w, "Dotra", 0, 0, {"birth_round": 2, "movement_ready_round": 3})
	var held: Dictionary = phase("dotra_birth_hold", w)
	check(facts(held, "MONSTER_CONCEALMENT").is_empty() and Kanifous._entity(held.world, actor.id).attributes.x_fp == 0, "new Dotra retains its birth hold")
	for key in ["dotra_concealment_round"]:
		for value in [-1, 0.5, true, "1"]:
			var forged: Dictionary = actor.attributes.duplicate(true); forged[key] = value
			check(not Monsters.valid_unit(forged), "invalid Dotra counter is rejected: " + key)


func muno_dash_checks() -> void:
	var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
	var view = preload("res://Prototype/U13/U13SandboxLaneView.gd").new()
	view.display_settings_path = ""
	root.add_child(view)
	view.size = Vector2(420, 900)
	for pid in [0, 1]:
		var w: Dictionary = phase_world()
		var source: Dictionary = put(w, "Muno", pid, 1000, {"y_fp": 150, "step_fp": 0})
		var target: Dictionary = put(w, "Butcher", 1 - pid, 1360, {"y_fp": 420, "step_fp": 0, "hp": 20, "max_hp": 20, "armor": 0})
		var resolved: Dictionary = phase("muno_dash_%d" % pid, w)
		check(facts(resolved, "MONSTER_ATTACK").filter(func(d): return d.ability == "Muno").size() == 1, "Muno still makes one free strike per round")
		check(Kanifous._entity(resolved.world, source.id).attributes.x_fp == 1000 and Kanifous._entity(resolved.world, source.id).attributes.y_fp == 150, "Muno animation never moves its simulation anchor")
		check(playback.build(resolved.events.map(func(r): return r.event)), "Muno dash playback builds")
		var before: Dictionary = playback.sample(0.04)
		var outward: Dictionary = playback.sample(0.12)
		var contact: Dictionary = playback.sample(0.22)
		var retreat: Dictionary = playback.sample(0.40)
		var returned: Dictionary = playback.sample(0.55)
		var a: Dictionary = outward.units.filter(func(u): return u.id == source.id)[0].attributes
		var b: Dictionary = contact.units.filter(func(u): return u.id == source.id)[0].attributes
		var c: Dictionary = retreat.units.filter(func(u): return u.id == source.id)[0].attributes
		var d: Dictionary = returned.units.filter(func(u): return u.id == source.id)[0].attributes
		check(a.visual_x > 1000 and a.visual_x < b.visual_x and c.visual_x < b.visual_x and c.visual_x > d.visual_x and is_equal_approx(d.visual_x, 1000), "visible Muno moves out, strikes, and returns instead of firing a projectile")
		var delta := Vector2(float(b.visual_x) - float(target.attributes.x_fp), float(b.visual_y) - float(target.attributes.y_fp)) / Vector2(90.0, 42.0)
		check(delta.length() < 1.0 and delta.length() > 0.5, "Muno's strike reaches melee distance without overlapping the victim")
		check(before.units.filter(func(u): return u.id == target.id)[0].attributes.hp == 20 and contact.units.filter(func(u): return u.id == target.id)[0].attributes.hp == 17, "visible dash arrives exactly when the recorded damage lands")
		check(retreat.monster_attacks[0].ability == "MunoDash" and returned.monster_attacks.size() == 1 and playback.sample(0.8).monster_attacks.is_empty(), "retreat afterimages linger briefly then disappear")
		check(playback.sample(0.40) == retreat, "Muno dash and trail respect paused playback")
		for sprites in [false, true]:
			view.set_display_modes(sprites, sprites)
			for frame in [outward, contact, retreat, returned]:
				view.show_frame(frame, 2)
				await process_frame
	view.queue_free()
	await process_frame


func kopita_pulse_checks() -> void:
	var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
	var pictures: Array = []
	for pid in [0, 1]:
		var w: Dictionary = phase_world()
		var caster: Dictionary = put(w, "Kopita", pid, 1200, {"hp": 3, "step_fp": 0})
		var wounded: Dictionary = put(w, "Butcher", pid, 1440, {"hp": 4, "step_fp": 0})
		var full: Dictionary = put(w, "Penitent", pid, 960, {"step_fp": 0})
		var distant: Dictionary = put(w, "Penitent", pid, 1561, {"hp": 2, "step_fp": 0}, 1)
		var other_lane: Dictionary = put(w, "Butcher", pid, 1200, {"lane": "Castle", "hp": 2, "step_fp": 0}, 1)
		var enemy: Dictionary = put(w, "Butcher", 1 - pid, 1200, {"y_fp": 530, "hp": 4, "armor": 0, "step_fp": 0})
		var armored: Dictionary = put(w, "Penitent", 1 - pid, 840, {"step_fp": 0})
		var healed: Dictionary = phase("kopita_%d_heal" % pid, w)
		var pulses: Array = facts(healed, "MONSTER_PULSE")
		check(pulses.size() == 2 and pulses.all(func(p): return p.healing and p.radius_fp == 360) and pulses[0].tick == 0 and pulses[1].tick == 133, "Kopita heals at the start and around ten seconds while allies remain wounded")
		check(pulses[0].source.id == caster.id and pulses[0].healed.size() == 2 and pulses[0].healed.all(func(h): return h.id in [caster.id, wounded.id] and h.amount == 1), "healing tape records only actual HP recovery, including self-healing")
		check(Kanifous._entity(healed.world, caster.id).attributes.hp == 5 and Kanifous._entity(healed.world, wounded.id).attributes.hp == 5, "both pulses heal wounded allies without exceeding their maximum")
		for unchanged in [full, distant, other_lane, enemy]:
			check(Kanifous._entity(healed.world, unchanged.id).attributes.hp == unchanged.attributes.hp, "full-health, distant, other-lane and enemy bodies receive no healing")
		check(playback.build(healed.events.map(func(r): return r.event)), "healing pulse playback builds")
		var frame: Dictionary = playback.sample(0.4)
		pictures.append(frame)
		check(frame.monster_attacks.size() == 1 and frame.monster_attacks[0].healing and frame.monster_attacks[0].impacts.size() == 2, "one green cast highlights the two healed bodies")
		check(playback.sample(0.1).monster_attacks.is_empty() and playback.sample(0.9).monster_attacks.is_empty(), "Kopita feedback appears at the pulse and expires")
		check(playback.sample(0.4) == frame, "paused playback retains the same pulse and recipient positions")
		var old_tape: Array = healed.events.map(func(r): return r.event.duplicate(true))
		for entry in old_tape:
			if entry.type == "MONSTER_PULSE":
				for key in ["source", "radius_fp", "healed"]: entry.data.erase(key)
		check(playback.build(old_tape) and playback.sample(0.4).monster_attacks.size() == 1 and playback.sample(0.4).monster_attacks[0].impacts.is_empty(), "older heal tapes show a cast without inventing recipients")
		var healthy: Dictionary = healed.world.duplicate(true)
		Kanifous._entity(healthy, caster.id).attributes.hp = caster.attributes.max_hp
		var harmed: Dictionary = phase("kopita_%d_harm" % pid, healthy, "monster-check", 3)
		pulses = facts(harmed, "MONSTER_PULSE")
		var hits: Array = facts(harmed, "MONSTER_ATTACK").filter(func(d): return d.ability == "Kopita")
		check(pulses.size() == 2 and pulses.all(func(p): return not p.healing) and hits.size() == 4, "healthy nearby allies select harm at both pulses despite distant or other-lane wounds")
		check(hits.all(func(h): return h.target.id in [enemy.id, armored.id] and h.tick in [0, 133]) and hits.any(func(h): return h.target.id == enemy.id and h.damage_dealt == 1) and hits.any(func(h): return h.target.id == armored.id and h.damage_dealt == 0), "both harm pulses obey range, lane and Armor")
		check(playback.build(harmed.events.map(func(r): return r.event)), "harm pulse playback builds")
		frame = playback.sample(0.4)
		pictures.append(frame)
		check(frame.monster_attacks.size() == 1 and not frame.monster_attacks[0].healing and frame.monster_attacks[0].impacts.size() == 2, "one violet cast highlights all actual damage recipients")
	var w: Dictionary = phase_world()
	put(w, "Kopita", 0, 800, {"birth_round": 2, "movement_ready_round": 3})
	var held: Dictionary = phase("kopita_birth_hold", w)
	check(facts(held, "MONSTER_PULSE").is_empty(), "Kopita does not claim to cast during birth hold")
	var empty: Dictionary = phase("kopita_empty_harm", phase_world_with_kopita())
	check(facts(empty, "MONSTER_PULSE").all(func(p): return not p.healing), "Kopita never wastes an empty healing pulse")
	check(playback.build(empty.events.map(func(r): return r.event)) and playback.sample(0.4).monster_attacks.size() == 1 and playback.sample(0.4).monster_attacks[0].impacts.is_empty(), "an empty lane shows a harmless damage pulse")
	# Exercise the same effect on both renderers, with chits and with sprites.
	for view in [preload("res://Prototype/U13/U13BoardLanes.gd").new(), preload("res://Prototype/U13/U13SandboxLaneView.gd").new()]:
		view.display_settings_path = ""
		root.add_child(view)
		view.size = Vector2(420, 900)
		for sprites in [false, true]:
			view.regular_sprites = sprites; view.monster_sprites = sprites
			for frame in pictures:
				view.show_frame(frame, 2)
				# Independent fixtures reuse IDs; they are not sequential casualties.
				view.deaths.clear()
				await process_frame
				var pulse: Dictionary = frame.monster_attacks[0]
				var bounds: Rect2 = view.travel_rect("Lord")
				var outline: PackedVector2Array = view.kopita_pulse_outline(pulse)
				check(outline.size() > 3 and Array(outline).all(func(p): return bounds.grow(0.01).has_point(p)), "Kopita footprint remains inside its lane in both displays")
				var center: Vector2 = view._monster_point(pulse.source)
				var nearest_y: float = INF
				for point in outline: nearest_y = minf(nearest_y, point.y)
				check(absf(center.y - nearest_y - bounds.size.y * 360.0 / 2400.0) < 0.02, "pulse uses the true 360-unit simulation radius")
				var isolated: Dictionary = frame.duplicate(true)
				isolated.units = frame.units.filter(func(u): return u.id == pulse.source_id)
				view.show_frame(isolated, 2)
				check(view._get_tooltip(view._monster_point(isolated.units[0].attributes)).contains("otherwise harm"), "Kopita hover explains conditional healing")
		view.queue_free()
	await process_frame


func phase_world_with_kopita() -> Dictionary:
	var w: Dictionary = phase_world()
	put(w, "Kopita", 0, 800, {"step_fp": 0})
	return w

func sinodek_portal_checks() -> void:
	for pid in [0, 1]:
		var direction: int = 1 if pid == 0 else -1
		var spawn_x: int = 0 if pid == 0 else 2400
		var w: Dictionary = phase_world()
		var source: Dictionary = put(w, "Sinodek", pid, spawn_x)
		var prey: Dictionary = put(w, "Butcher", 1-pid, spawn_x + direction * 350)
		var seed_value: String = selected_seed(source.id, "PORTAL", 25)
		var held: Dictionary = w.duplicate(true)
		var held_source: Dictionary = Kanifous._entity(held, source.id)
		held_source.attributes.merge({"birth_round": 2, "movement_ready_round": 3}, true)
		var hold: Dictionary = phase("sinodek_birth_hold_%d" % pid, held, seed_value)
		check(facts(hold, "MONSTER_FIELD_CREATED").is_empty(), "Sinodek cannot cast during his existing birth-round hold")
		var crossing: Dictionary = phase("sinodek_cross_own_void_%d" % pid, w, seed_value)
		var fields: Array = facts(crossing, "MONSTER_FIELD_CREATED")
		check(fields.size() == 1 and fields[0].field.get("source_id") == source.id, "portal records the exact Sinodek who created it")
		var survivor: Dictionary = Kanifous._entity(crossing.world, source.id)
		check(not survivor.is_empty() and survivor.attributes.x_fp == spawn_x + direction * 400 and survivor.attributes.hp == source.attributes.hp, "Sinodek crosses his own fear zone and void unharmed on his first active round")
		check(facts(crossing, "MONSTER_BANISHED").size() == 1 and facts(crossing, "MONSTER_BANISHED")[0].unit.id == prey.id, "Sinodek's own void banishes its enemy target and never its creator")
		w = phase_world()
		source = put(w, "Sinodek", pid, 2400 - spawn_x - direction * 50)
		put(w, "Butcher", 1-pid, 2400 - spawn_x)
		var clamped: Dictionary = phase("sinodek_clamped_void_%d" % pid, w, seed_value)
		survivor = Kanifous._entity(clamped.world, source.id)
		check(not survivor.is_empty() and survivor.attributes.waiting and survivor.attributes.x_fp == 2400 - spawn_x, "Sinodek survives a targeted void overlapping him at the far gate and reaches the goal")
		w = phase_world()
		source = put(w, "Sinodek", pid, 1200, {"step_fp": 0, "movement_ready_round": 3})
		var other: Dictionary = put(w, "Sinodek", 1 - pid, 1200, {"movement_ready_round": 3})
		var ally: Dictionary = put(w, "Butcher", pid, 1200, {"y_fp": 270, "movement_ready_round": 3})
		var foe: Dictionary = put(w, "Butcher", 1 - pid, 1200, {"y_fp": 330, "movement_ready_round": 3})
		w.data.monsters.fields = [{"kind": "portal", "id": source.id + ":2:portal", "source_id": source.id, "owner": pid, "lane": "Lord", "x_fp": 1200, "y_fp": 300, "expires_round": 2}]
		var collateral: Dictionary = phase("sinodek_creator_only_%d" % pid, w, seed_value)
		var banished: Array = facts(collateral, "MONSTER_BANISHED").map(func(d): return d.unit.id)
		check(banished.size() == 3 and banished.has(other.id) and banished.has(ally.id) and banished.has(foe.id) and not Kanifous._entity(collateral.world, source.id).is_empty(), "only the creator is immune; allies, enemies and another Sinodek can still be banished")
		w = phase_world()
		source = put(w, "Sinodek", pid, 1200, {"step_fp": 0, "movement_ready_round": 3})
		w.data.monsters.fields = [{"kind": "portal", "id": source.id + ":2:portal", "source_id": source.id, "owner": pid, "lane": "Lord", "x_fp": 1200, "y_fp": 300, "expires_round": 2}]
		var ids = Work.Ids.new(); ids.restore(w.entities)
		source.attributes["charm_owner"] = pid
		source.attributes.direction = -direction
		ids.update(source.id, 1 - pid, source.attributes); w.entities = ids.snapshot()
		var charmed: Dictionary = phase("sinodek_charmed_creator_%d" % pid, w, seed_value)
		check(not Kanifous._entity(charmed.world, source.id).is_empty() and facts(charmed, "MONSTER_BANISHED").is_empty(), "creator immunity follows identity even after charm changes ownership")
		var envelope: Dictionary = JSON.parse_string(Game.encode_snapshot(charmed.world))
		var loaded: Dictionary = bytes_to_var(Marshalls.base64_to_raw(envelope.payload))
		check(loaded == charmed.world and Monsters.valid(loaded), "save transport preserves portal creator identity")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	await kopita_pulse_checks()
	await muno_dash_checks()
	dotra_stalking_checks()
	dotra_visibility_checks()
	penitent_block_checks()
	sooge_ramp_checks()
	pool_checks()
	beam_boundary_checks()
	sinodek_portal_checks()
	var rows: Array = []
	for suit in ["Penitent", "Butcher", "Vulture", "Wright"]:
		for i in range(3): rows.append({"id": suit + str(i), "kind": "card", "attributes": {"suit": suit, "value": 1}})
	for name in Monsters.NAMES:
		var selected: Array = []
		for suit in Monsters.ROSTER[name].recipe:
			for i in range(Monsters.ROSTER[name].recipe[suit]): selected.append(suit + str(i))
		check(Monsters.qualifies(rows, selected, name), name + " exact recipe accepts value-one cards")
		check(not Monsters.qualifies(rows, selected.slice(1), name), name + " rejects missing ingredient")
		check(not Monsters.qualifies(rows, selected + [selected[0]], name), name + " rejects repeated card identity")
		check(Monsters.valid_unit(Monsters.profile(name, "Castle", 0, 1, 2)), name + " has a valid profile")
	var overlap: Array = ["Penitent0", "Penitent1", "Vulture0", "Vulture1", "Wright0", "Wright1"]
	check(Monsters.available(rows, overlap, 0) == ["Lemek", "Varn", "Kopita", "Tumler"], "overlapping recipes offer a choice, not multiple summons")
	var w: Dictionary = phase_world()
	var sooge: Dictionary = put(w, "Sooge", 0, 700)
	check(Monsters.living(w.entities.entities, 0, "Sooge") and not Monsters.living(w.entities.entities, 0, "Sinodek"), "Very hard living caps are separate")
	var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
	var root_seed: String = selected_seed(sooge.id, "ROOT", 25)
	var content = Game.Content.new()
	var first: Dictionary = MonsterFX.step(w, buffer, context(w, root_seed), 0, Callable(content, "react"))
	var rooted: Dictionary = buffer.get_entity(sooge.id)
	check(rooted.attributes.sprite_form == "turret" and rooted.attributes.armor == 6 and rooted.attributes.step_fp == 0, "Sooge roots into turret stats")
	rooted.attributes.armor = 2; buffer.update(rooted.id, rooted.owner, rooted.attributes)
	var future: Dictionary = context(first.world, root_seed); future.round = 3
	MonsterFX.step(first.world, buffer, future, 0, Callable(content, "react"))
	check(buffer.get_entity(sooge.id).attributes.sprite_form == "turret" and buffer.get_entity(sooge.id).attributes.armor == 2, "turret persists without refreshing armor each round")
	w = phase_world()
	var attacker: Dictionary = put(w, "Sooge", 0, 300, {"sprite_form": "turret", "attack": 3, "armor": 6, "max_armor": 6, "step_fp": 0})
	put(w, "Butcher", 0, 520, {"hp": 100, "max_hp": 100, "step_fp": 0})
	var primary: Dictionary = put(w, "Penitent", 1, 720, {"hp": 100, "max_hp": 100, "step_fp": 0})
	var behind_target: Dictionary = put(w, "Wright", 1, 1500, {"hp": 100, "max_hp": 100, "step_fp": 0})
	var edge: Dictionary = put(w, "Wright", 1, 2100, {"hp": 100, "max_hp": 100, "step_fp": 0}, 1)
	var beyond_range: Dictionary = put(w, "Penitent", 1, 2200, {"hp": 100, "max_hp": 100, "step_fp": 0}, 1)
	var off_axis: Dictionary = put(w, "Butcher", 1, 800, {"hp": 100, "max_hp": 100, "y_fp": 500, "step_fp": 0})
	var beam: Dictionary = phase("turret_piercing", w)
	var first_beam: Dictionary = facts(beam, "MONSTER_BEAM_FIRED")[0]
	var first_hits: Array = facts(beam, "MONSTER_ATTACK").filter(func(d): return d.ability == "Beam" and d.tick == first_beam.tick + 8)
	check(facts(beam, "MONSTER_BEAM_FIRED").size() == 1 and first_beam.tick == 32, "Sooge charges for 32 ticks then fires only once per round")
	check(first_beam.target.id == primary.id and first_beam.range_fp == 1800, "Sooge aims at nearest enemy and records tripled range")
	check(first_hits.any(func(d): return d.target.id == behind_target.id), "Sooge beam passes through the first enemy into enemies behind it")
	check(first_hits.any(func(d): return d.target.id == edge.id), "Sooge beam reaches the inclusive 1800 range boundary")
	check(not first_hits.any(func(d): return d.target.id in [beyond_range.id, off_axis.id]), "Sooge beam respects maximum range and beam width")
	check(facts(beam, "MONSTER_ATTACK").any(func(d): return d.ability == "Beam" and d.target.owner == 0), "turret beam also damages allies in its path")
	var beam_playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
	check(beam_playback.build(beam.events.map(func(r): return r.event)), "Sooge beam builds from the authoritative tape")
	var charge: Array = beam_playback.sample(0.69).monster_attacks
	check(charge.size() == 1 and charge[0].ability == "BeamCharge" and charge[0].weight > 0.4 and charge[0].weight < 0.6, "recorded charge builds visibly before damage or laser")
	var trace: Dictionary = beam_playback.sample(1.2)
	check(trace.monster_attacks.size() == 1 and trace.monster_attacks[0].ability == "Beam" and trace.units.any(func(u): return u.id == primary.id and u.attributes.armor == primary.attributes.armor), "fast laser traces the ground before damage")
	check(beam_playback.sample(1.32).monster_attacks[0].ability == "BeamTrail", "ground scar warns of the following detonation")
	var pulses: Array = beam_playback.sample(1.44).monster_attacks.filter(func(a): return a.ability == "BeamBlast")
	check(pulses.size() == 1 and pulses[0].ability == "BeamBlast" and pulses[0].target_id == primary.id and pulses[0].impacts.size() == first_hits.size(), "one delayed explosion retains the laser path and marks all collateral hits")
	check(beam_playback.sample(beam_playback.duration).monster_attacks.is_empty(), "last laser pulse ends before final playback state")
	check(beam.world.entities.entities.any(func(u): return u.id == attacker.id and u.attributes.x_fp == 300 and u.attributes.sprite_form == "turret"), "turret remains rooted throughout Marching")
	w = phase_world()
	var portal_source: Dictionary = put(w, "Sinodek", 0, 600)
	var lost: Dictionary = put(w, "Lemek", 1, 950)
	var portal: Dictionary = phase("portal_banishes", w, selected_seed(portal_source.id, "PORTAL", 25))
	check(facts(portal, "MONSTER_BANISHED").any(func(d): return d.unit.id == lost.id), "portal banishes a body caught inside")
	check(not portal.world.data.kanifous_losses.any(func(r): return r.id == lost.id) and not portal.world.data.monsters.death_ids.has(lost.id), "banishment cannot resurrect or leave a Lemek death pool")
	var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
	check(playback.build(portal.events.map(func(r): return r.event)), "monster playback consumes spatial events")
	check(not playback.death_rows.any(func(r): return r.unit.id == lost.id), "portal playback omits the death animation")
	check(not playback.sample(playback.duration * 0.5).monster_fields.is_empty(), "portal is visible during playback")
	for name in ["Lemek", "Fyra", "Varn", "Kopita", "Tumler", "Kurchin", "Muno", "Dotra"]:
		w = phase_world()
		var unit: Dictionary = put(w, name, 0, 800, {"hp": 20, "max_hp": 20})
		put(w, "Wright", 1, 1030, {"hp": 25, "max_hp": 25})
		put(w, "Vulture", 1, 1250, {"hp": 20, "max_hp": 20, "y_fp": 480})
		if name == "Lemek": put(w, "Butcher", 1, 880, {"attack": 100, "step_fp": 0})
		var seed_value: String = selected_seed(unit.id, "HIDE", 25) if name == "Dotra" else "monster-check"
		var result: Dictionary = phase(name, w, seed_value)
		if name == "Muno": check(facts(result, "MONSTER_ATTACK").filter(func(d): return d.ability == "Muno").size() == 1, "Muno free strike is once per active round")
		if name == "Dotra": check(facts(result, "MONSTER_ATTACK").any(func(d): return d.ability == "Ambush"), "hidden Dotra delivers the ambush")
		if name == "Lemek": check(result.world.data.monsters.fields.any(func(f): return f.kind == "pool"), "Lemek death creates a pool")
	w = phase_world()
	put(w, "Fyra", 0, 800, {"hp": 25, "max_hp": 25})
	put(w, "Fyra", 1, 1030, {"hp": 25, "max_hp": 25})
	phase("reciprocal_charm", w)
	w = phase_world()
	var eaten: Dictionary = put(w, "Lemek", 1, 800, {"movement_ready_round": 9})
	var actor: Dictionary = Marching.KroniActors.create("monster-devour-check", 0, 2, 0)
	actor.x_fp = 700; actor.y_fp = 300; actor.vy_fp = 1
	w.data.kroni_actors = [actor]
	var consumed: Dictionary = phase("consumed_lemek", w)
	var bites: Array = facts(consumed, "MARCHER_DEVOURED").filter(func(d): return d.before.id == eaten.id)
	var pools: Array = facts(consumed, "MONSTER_FIELD_CREATED")
	check(not bites.is_empty() and pools.size() == 1 and pools[0].get("tick", -1) == bites[0].tick, "devoured Lemek creates its pool on the death tick")
	# Longevity is tested at both admission and firing, including reduced maxima.
	for maximum in [6, 17]:
		for health in [0, 6, 7, 8, 9, 17]:
			if health > maximum: continue
			w = fixture()
			var castle: Dictionary = w.entities.entities.filter(func(r): return r.kind == "castle" and r.owner == 0)[0]
			castle.attributes.merge({"integrity": health, "max_integrity": maximum, "status": "standing" if health else "defunct", "construction_state": "active"}, true)
			var source: Dictionary = {"power_id": "WishLongevity", "player_id": 0, "target": {"entity_id": castle.id}, "parameters": {}, "declaration_id": "longevity-check"}
			var eligible: bool = health < mini(8, maximum)
			check(content.validate(source, w, "declaration").legal == eligible and content.validate(source, w, "firing").legal == eligible, "Longevity eligibility %d/%d" % [health, maximum])
			var result: Dictionary = content.resolve({"declaration": source}, {"world": w, "round": 1, "seed": "longevity"})
			check(Kanifous._entity(result.world, castle.id).attributes.integrity == (mini(8, maximum) if eligible else health), "Longevity never harms or exceeds ceiling")
			check(result.world.data.kanifous_prices.size() == (1 if eligible else 0), "only actual healing creates a Price")
	special_checks()
	if phase_output != null: phase_output.close()
	board = Board.new(); root.add_child(board); board._runtime_ok = true
	await process_frame
	board._open_recipes()
	check(board.recipe_menu.visible and board.recipe_menu.column.get_child_count() == 13, "RECIPES opens all ten monster entries")
	check(board.monster_picker.get_parent() == board.action_zone.action_box, "summon chooser belongs to the Combat modal")
	board.queue_free()
	print("U13 monster checks failures: ", failures)
	quit(1 if failures else 0)

func bad_data(value, path: String) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for key in value:
			if typeof(key) != TYPE_STRING: print("BAD KEY ", path, " ", key)
			bad_data(value[key], path + "." + str(key))
	elif typeof(value) == TYPE_ARRAY:
		for i in range(value.size()): bad_data(value[i], path + "." + str(i))
	elif typeof(value) not in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]: print("BAD VALUE ", path, " ", typeof(value))
	elif typeof(value) == TYPE_FLOAT and not is_finite(value): print("BAD FLOAT ", path)

func special_checks() -> void:
	var world: Dictionary = phase_world()
	var dead: Dictionary = put(world, "Sooge", 0, 900, {"sprite_form": "turret", "step_fp": 0, "attack": 3, "armor": 0})
	var ids = Work.Ids.new(); ids.restore(world.entities); ids.retire(dead.id); world.entities = ids.snapshot()
	world.data.kanifous_losses = [dead]
	var content = Game.Content.new()
	var source: Dictionary = {"power_id": "WishResurrection", "player_id": 0, "target": {"lane": "Lord"}, "parameters": {}, "declaration_id": "resurrect-monster"}
	var revived: Dictionary = content.resolve({"declaration": source}, {"world": world, "round": 2, "seed": "monster-resurrection"})
	var bodies: Array = revived.world.entities.entities.filter(func(r): return r.attributes.get("monster_id") == "Sooge")
	check(bodies.size() == 1 and bodies[0].attributes.sprite_form == "turret" and bodies[0].attributes.armor == 6 and bodies[0].attributes.movement_ready_round == 3, "resurrection preserves turret form and restores monster stats")
	check(Kanifous.Lamp.valid(revived.world), "monster corpses and resurrection remain valid save data")
	source.declaration_id = "second-resurrection"
	var again: Dictionary = content.resolve({"declaration": source}, {"world": revived.world, "round": 2, "seed": "monster-resurrection"})
	check(again.events.back().event.data.count == 0 and again.world.data.kanifous_prices.size() == 1, "resurrection cannot duplicate a living Very hard monster or create a no-op Price")
	world = phase_world()
	dead = put(world, "Sooge", 0, 900, {"sooge_root_attempts": 4, "sooge_root_round": 2})
	ids.restore(world.entities); ids.retire(dead.id); world.entities = ids.snapshot()
	world.data.kanifous_losses = [dead]
	revived = content.resolve({"declaration": source}, {"world": world, "round": 2, "seed": "monster-resurrection"})
	bodies = revived.world.entities.entities.filter(func(r): return r.attributes.get("monster_id") == "Sooge")
	check(bodies.size() == 1 and bodies[0].attributes.sprite_form == "mobile" and Monsters.root_chance(bodies[0].attributes) == 85 and bodies[0].attributes.sooge_root_round == 2 and bodies[0].attributes.movement_ready_round == 3, "mobile Sooge resurrection preserves earned rooting chance and birth hold")
	world = phase_world()
	put(world, "Sooge", 0, 800)
	var enemy_turret: Dictionary = put(world, "Sooge", 1, 850)
	var shifted: Dictionary = content._shift({"action": "resolved", "world": world, "events": []}, {"lane": "Lord", "field_position": {"x_fp": 850, "y_fp": 300}}, 0, 2, "monster-cap-shift")
	check(shifted.action == "resolved" and shifted.events.back().event.data.affected_ids.is_empty(), "allegiance powers cannot exceed the living monster cap")
	enemy_turret.owner = 0; enemy_turret.attributes["charm_owner"] = 1
	check(Monsters.living([enemy_turret], 1, "Sooge"), "charm reserves the original owner's living slot")
	world = phase_world()
	var caster: Dictionary = put(world, "Fyra", 0, 800)
	var victim: Dictionary = put(world, "Wright", 1, 1000)
	var buffer = Marching.Buffer.new(); buffer.restore(world.entities)
	var seed_value: String = ""
	for i in range(1000):
		if MonsterFX.Lamp.draw(str(i), "%s:2:0:%s" % [caster.id, victim.id], "CHARM", 100) < Monsters.TUNING.fyra_charm_chance: seed_value = str(i); break
	var charm: Array = MonsterFX.on_hit(buffer, caster, victim.id, 1, context(world, seed_value), 0)
	check(charm.size() == 1 and buffer.get_entity(victim.id).owner == 0, "Fyra charm changes allegiance")
	world.entities = buffer.snapshot()
	MonsterFX.end_round(world, 2)
	check(world.entities.entities.any(func(r): return r.id == victim.id and r.owner == 1 and not r.attributes.has("charm_owner")), "charm restores ownership before the next round")
	world = phase_world(); caster = put(world, "Varn", 0, 0); victim = put(world, "Wright", 1, 1500)
	buffer.restore(world.entities)
	for i in range(1000):
		if MonsterFX.Lamp.draw(str(i), "%s:2:0:%s" % [caster.id, victim.id], "POISON", 100) < 10: seed_value = str(i); break
	check(not MonsterFX.on_hit(buffer, caster, victim.id, 1, context(world, seed_value), 0).is_empty(), "Varn applies poison after a damaging hit")
	world.entities = buffer.snapshot()
	var c: Dictionary = context(world); c.round = 3
	var poisoned: Dictionary = MonsterFX.step(world, buffer, c, 0, Callable(content, "react"))
	check(buffer.get_entity(victim.id).attributes.hp == 4 and buffer.get_entity(victim.id).attributes.armor == 2, "poison damages HP through armor next round")
	c.round = 4; MonsterFX.step(poisoned.world, buffer, c, 0, Callable(content, "react"))
	check(buffer.get_entity(victim.id).attributes.hp == 3, "poison lasts a second round")
	c.round = 5; MonsterFX.step(poisoned.world, buffer, c, 0, Callable(content, "react"))
	check(buffer.get_entity(victim.id).attributes.hp == 3 and not buffer.get_entity(victim.id).attributes.has("poison_until_round"), "poison expires without stacking")
	check(not MonsterFX.slowed({"flying": true, "lane": "Lord", "x_fp": 200, "y_fp": 300}, [{"kind": "pool", "lane": "Lord", "x_fp": 200, "y_fp": 300}]), "Fyra ignores ground pools")
