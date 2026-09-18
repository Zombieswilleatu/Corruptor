extends RefCounted

const Rules = preload("res://Scripts/Sim/U13MonsterRules.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Lamp = preload("res://Scripts/Sim/U13Wishmaster.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")

static func event(kind: String, data: Dictionary) -> Dictionary:
	var fact: Dictionary = {"type": kind, "text": "", "data": data.duplicate(true)}
	return {"event": fact, "views": [fact, fact]}

static func distance(a: Dictionary, b: Dictionary) -> int:
	return (int(a.x_fp) - int(b.x_fp)) ** 2 + (int(a.y_fp) - int(b.y_fp)) ** 2

static func enemies(unit: Dictionary, rows: Array, radius: int = 4000) -> Array:
	return rows.filter(func(r): return r.owner != unit.owner and r.attributes.lane == unit.attributes.lane and not r.attributes.get("hidden", false) and distance(unit.attributes, r.attributes) <= radius * radius)

static func nearest(unit: Dictionary, rows: Array, radius: int = 4000) -> Dictionary:
	var result: Dictionary = {}
	var best: int = radius * radius + 1
	for row in enemies(unit, rows, radius):
		var d: int = distance(unit.attributes, row.attributes)
		if d < best: result = row; best = d
	return result

# A local taunt does not let a distant Kurchin steal targets across the lane.
static func preferred(unit: Dictionary, rows: Array) -> Dictionary:
	var taunts: Array = enemies(unit, rows, Rules.TUNING.taunt_radius).filter(func(r): return r.attributes.get("monster_id") == "Kurchin")
	if not taunts.is_empty(): return nearest(unit, taunts)
	var id: String = unit.attributes.get("hunt_target", "")
	if unit.attributes.get("monster_id") == "Tumler":
		for row in enemies(unit, rows):
			if row.id == id: return row
	return {}

static func slowed(a: Dictionary, fields: Array) -> bool:
	if a.get("flying", false) or a.get("monster_id") == "Lemek": return false
	return fields.any(func(f): return f.kind == "pool" and f.lane == a.lane and distance(a, f) <= Rules.TUNING.pool_radius ** 2)

# Death ledgers are also written by direct powers and Prices. Banishment and
# spent siege/hunt support never enter this ledger and cannot leave a pool.
static func deaths(world: Dictionary, round_number: int, tick: int = -1) -> Array:
	if not Rules.enabled(world): return []
	var state: Dictionary = world.data.monsters
	var events: Array = []
	for lost in world.data.get("kanifous_losses", []):
		if lost.attributes.get("monster_id") != "Lemek" or lost.id in state.death_ids: continue
		state.death_ids.append(lost.id)
		var f: Dictionary = {"kind": "pool", "id": lost.id + ":pool", "owner": lost.owner, "lane": lost.attributes.lane, "x_fp": lost.attributes.x_fp, "y_fp": lost.attributes.y_fp, "expires_round": round_number + 1}
		state.fields.append(f)
		var details: Dictionary = {"field": f, "round": round_number}
		if tick >= 0: details["tick"] = tick
		events.append(event("MONSTER_FIELD_CREATED", details))
	return events

static func end_round(world: Dictionary, round_number: int) -> Array:
	if not Rules.enabled(world): return []
	var ids = Ids.new(); ids.restore(world.entities)
	var events: Array = []
	for unit in world.entities.entities:
		if unit.kind != "marcher" or not unit.attributes.has("charm_owner"): continue
		var a: Dictionary = unit.attributes
		var owner: int = a.charm_owner
		a.erase("charm_owner")
		a.direction = 1 if owner == 0 else -1
		a.waiting = false
		a.waiting_since_round = 0
		a.contact_tick = -1
		ids.update(unit.id, owner, a)
		events.append(event("MONSTER_CHARM_ENDED", {"unit_id": unit.id, "owner": owner, "round": round_number}))
	world.entities = ids.snapshot()
	# Owner changes invalidate outstanding duel identities.
	if not events.is_empty(): world.data.marching_duels = {}
	return events

static func on_hit(entities, source: Dictionary, target_id: String, damage: int, context: Dictionary, tick: int) -> Array:
	var target: Dictionary = entities.get_entity(target_id)
	if target.is_empty(): return []
	var name: String = source.attributes.get("monster_id", "")
	var key: String = "%s:%d:%d:%s" % [source.id, context.round, tick, target_id]
	if name == "Varn" and damage > 0 and Lamp.draw(context.seed, key, "POISON", 100) < Rules.TUNING.varn_poison_chance:
		target.attributes["poison_until_round"] = int(context.round) + 2
		var credited: Dictionary = source.duplicate(true)
		credited.attributes.erase("poison_source")
		credited.attributes.erase("poison_until_round")
		target.attributes["poison_source"] = credited
		entities.update(target.id, target.owner, target.attributes)
		return [event("MONSTER_POISONED", {"unit_id": target.id, "source_id": source.id, "round": context.round, "tick": tick})]
	if name == "Fyra" and not target.attributes.has("charm_owner") and Lamp.draw(context.seed, key, "CHARM", 100) < Rules.TUNING.fyra_charm_chance:
		var monster: String = target.attributes.get("monster_id", "")
		if Rules.limited(monster) and Rules.living(entities.marchers(), source.owner, monster): return []
		target.attributes["charm_owner"] = target.owner
		target.attributes.direction = 1 if source.owner == 0 else -1
		target.attributes.waiting = false
		target.attributes.waiting_since_round = 0
		target.attributes.contact_tick = -1
		entities.update(target.id, source.owner, target.attributes)
		return [event("MONSTER_CHARMED", {"unit_id": target.id, "source_id": source.id, "owner": source.owner, "round": context.round, "tick": tick})]
	return []

static func step(world: Dictionary, entities, context: Dictionary, tick: int, reaction: Callable) -> Dictionary:
	var events: Array = []
	if not Rules.enabled(world): return {"action": "resolved", "world": world, "events": events, "fleeing": {}}
	var state: Dictionary = world.data.monsters
	var n: int = context.round
	var clock: int = n * 200 + tick
	var hits: Array = []
	var fleeing: Dictionary = {}
	if tick == 0:
		state.phase_round = n
		state.fields = state.fields.filter(func(f): return f.expires_round >= n)
		for unit in entities.marchers():
			var a: Dictionary = unit.attributes
			if a.get("poison_until_round", 0) >= n:
				hits.append({"source": a.poison_source, "target": unit.id, "amount": 1, "bypass": true, "ability": "Poison"})
			elif a.has("poison_until_round"):
				a.erase("poison_until_round"); a.erase("poison_source")
			if a.get("monster_id", "").is_empty() or a.movement_ready_round > n:
				entities.update(unit.id, unit.owner, a)
				continue
			var key: String = "%s:%d" % [unit.id, n]
			match a.monster_id:
				"Dotra":
					a["hidden"] = Lamp.draw(context.seed, key, "HIDE", 100) < (50 if a.get("hidden", false) else Rules.TUNING.dotra_hide_chance)
					events.append(event("MONSTER_CONCEALMENT", {"unit_id": unit.id, "hidden": a.hidden, "round": n, "tick": tick}))
				"Sooge":
					if a.sprite_form != "turret" and int(a.get("sooge_root_round", 0)) < n:
						var chance: int = Rules.root_chance(a)
						# Count eligible rolls, not global rounds or simulation ticks.
						a["sooge_root_attempts"] = int(a.get("sooge_root_attempts", 0)) + 1
						a["sooge_root_round"] = n
						if Lamp.draw(context.seed, key, "ROOT", 100) < chance:
							a.merge({"sprite_form": "turret", "attack": 3, "armor": 6, "max_armor": 6, "step_fp": 0}, true)
							events.append(event("MONSTER_ROOTED", {"unit_id": unit.id, "round": n, "tick": tick}))
				"Sinodek":
					if Lamp.draw(context.seed, key, "PORTAL", 100) < Rules.TUNING.sinodek_portal_chance:
						var f: Dictionary = {"kind": "portal", "id": key + ":portal", "owner": unit.owner, "lane": a.lane, "x_fp": clampi(int(a.x_fp) + int(a.direction) * int(Rules.TUNING.portal_ahead), 0, 2400), "y_fp": a.y_fp, "expires_round": n}
						state.fields.append(f)
						events.append(event("MONSTER_FIELD_CREATED", {"field": f, "round": n}))
			entities.update(unit.id, unit.owner, a)
	# Deterministic ID order for pulses, jumps, ambushes and beam preparation.
	for original in entities.marchers():
		var unit: Dictionary = entities.get_entity(original.id)
		var a: Dictionary = unit.attributes
		if a.movement_ready_round > n or not a.has("monster_id"): continue
		var rows: Array = entities.marchers()
		match a.monster_id:
			"Tumler":
				var choices: Array = enemies(unit, rows)
				if not choices.any(func(r): return r.id == a.get("hunt_target", "")):
					var supports: Array = choices.filter(func(r): return r.attributes.suit == "Vulture" or r.attributes.get("monster_id") in ["Kopita", "Fyra", "Sooge", "Sinodek"])
					var chosen: Dictionary = nearest(unit, supports if not supports.is_empty() else choices)
					a["hunt_target"] = chosen.get("id", "")
			"Kopita":
				if tick == 0:
					var healing: bool = int(a.get("kopita_pulses", 0)) % 2 == 0
					a["kopita_pulses"] = int(a.get("kopita_pulses", 0)) + 1
					for other in rows:
						if other.attributes.lane != a.lane or distance(a, other.attributes) > Rules.TUNING.kopita_radius ** 2: continue
						if healing and other.owner == unit.owner:
							other.attributes.hp = mini(int(other.attributes.max_hp), int(other.attributes.hp) + 1)
							if other.id == unit.id: a.hp = other.attributes.hp
							entities.update(other.id, other.owner, other.attributes)
						elif not healing and other.owner != unit.owner: hits.append({"source": unit, "target": other.id, "amount": 1, "bypass": false, "ability": "Kopita"})
					events.append(event("MONSTER_PULSE", {"unit_id": unit.id, "healing": healing, "round": n, "tick": tick}))
			"Muno":
				if int(a.get("muno_round", 0)) != n:
					var target: Dictionary = nearest(unit, rows, Rules.TUNING.muno_radius)
					if not target.is_empty():
						a["muno_round"] = n
						hits.append({"source": unit, "target": target.id, "amount": a.attack, "bypass": false, "ability": "Muno"})
			"Dotra":
				if a.get("hidden", false):
					var target: Dictionary = nearest(unit, rows, Rules.TUNING.dotra_ambush_radius)
					if not target.is_empty():
						a.hidden = false
						hits.append({"source": unit, "target": target.id, "amount": 5, "bypass": false, "ability": "Ambush"})
			"Sooge":
				if a.sprite_form == "turret" and int(a.get("beam_next_tick", 0)) - int(Rules.TUNING.beam_charge_ticks) <= clock:
					var target: Dictionary = nearest(unit, rows, Rules.TUNING.beam_range)
					if target.is_empty():
						# Losing all targets cancels the wind-up without spending a shot.
						a["beam_charge_tick"] = 0
						a["beam_ready_tick"] = 0
					elif int(a.get("beam_ready_tick", 0)) == 0:
						a["beam_charge_tick"] = clock
						a["beam_ready_tick"] = clock + int(Rules.TUNING.beam_charge_ticks)
					elif clock >= int(a.beam_ready_tick):
						# Reacquire at release: the closest live enemy sets the ray.
						a["beam_next_tick"] = clock + int(Rules.TUNING.beam_interval_ticks)
						a["beam_charge_tick"] = 0
						a["beam_ready_tick"] = 0
						# Lock the ground path at release. Its explosion survives the caster.
						var beam: Dictionary = {"attacker": unit.duplicate(true), "target": target.duplicate(true), "range_fp": Rules.TUNING.beam_range, "detonate_tick": clock + int(Rules.TUNING.beam_blast_delay_ticks)}
						state.pending_beams.append(beam)
						var details: Dictionary = beam.duplicate(true)
						details.merge({"round": n, "tick": tick})
						events.append(event("MONSTER_BEAM_FIRED", details))
		entities.update(unit.id, unit.owner, a)
	var pending: Array = []
	for beam in state.pending_beams:
		if int(beam.detonate_tick) > clock:
			pending.append(beam)
			continue
		var details: Dictionary = beam.duplicate(true)
		details.merge({"round": n, "tick": tick})
		events.append(event("MONSTER_BEAM_DETONATED", details))
		var source: Dictionary = beam.attacker
		var a: Dictionary = source.attributes
		var vx: int = int(beam.target.attributes.x_fp) - int(a.x_fp)
		var vy: int = int(beam.target.attributes.y_fp) - int(a.y_fp)
		var length2: int = maxi(1, vx * vx + vy * vy)
		for other in entities.marchers():
			if other.id == source.id or other.attributes.lane != a.lane: continue
			var dx: int = int(other.attributes.x_fp) - int(a.x_fp)
			var dy: int = int(other.attributes.y_fp) - int(a.y_fp)
			var cross: int = dx * vy - dy * vx
			if dx * vx + dy * vy >= 0 and dx * dx + dy * dy <= int(beam.range_fp) ** 2 and cross * cross <= Rules.TUNING.beam_half_width ** 2 * length2:
				hits.append({"source": source, "target": other.id, "amount": 1 if other.owner == source.owner else 3, "bypass": false, "ability": "Beam"})
	state.pending_beams = pending
	for hit in hits:
		var result: Dictionary = damage(world, entities, hit, context, tick, reaction)
		if result.action == "invalid": return result
		world = result.world
		events.append_array(result.events)
	state = world.data.monsters
	for f in state.fields:
		if f.kind != "portal": continue
		for unit in entities.marchers():
			var a: Dictionary = unit.attributes
			if a.lane != f.lane: continue
			var gap: int = distance(a, f)
			if gap <= Rules.TUNING.portal_radius ** 2:
				entities.retire(unit.id)
				events.append(event("MONSTER_BANISHED", {"unit": unit, "portal_id": f.id, "round": n, "tick": tick}))
			elif gap <= Rules.TUNING.portal_fear_radius ** 2 and a.step_fp > 0 and a.movement_ready_round <= n:
				var dx: int = int(a.x_fp) - int(f.x_fp)
				var dy: int = int(a.y_fp) - int(f.y_fp)
				if absi(dx) >= absi(dy): a.x_fp = clampi(int(a.x_fp) + (1 if dx >= 0 else -1) * int(a.step_fp), 0, 2400)
				else: a.y_fp = clampi(int(a.y_fp) + (1 if dy >= 0 else -1) * int(a.step_fp), 0, 600)
				a.contact_tick = -1
				entities.update(unit.id, unit.owner, a)
				fleeing[unit.id] = true
	world.entities = entities.snapshot()
	events.append_array(deaths(world, n))
	return {"action": "resolved", "world": world, "events": events, "fleeing": fleeing}

static func damage(world: Dictionary, entities, hit: Dictionary, context: Dictionary, tick: int, reaction: Callable) -> Dictionary:
	var events: Array = []
	var target: Dictionary = entities.get_entity(hit.target)
	if target.is_empty(): return {"action": "resolved", "world": world, "events": events}
	var before: Dictionary = target.duplicate(true)
	var absorbed: int = 0 if hit.bypass else mini(int(target.attributes.armor), int(hit.amount))
	var dealt: int = int(hit.amount) - absorbed
	target.attributes.armor -= absorbed
	target.attributes.hp = maxi(0, int(target.attributes.hp) - dealt)
	target.attributes.movement_ready_round = mini(int(target.attributes.movement_ready_round), int(context.round))
	if target.attributes.hp == 0: entities.retire(target.id)
	else: entities.update(target.id, target.owner, target.attributes)
	events.append(event("MONSTER_ATTACK", {"attacker": hit.source, "target": before, "ability": hit.ability, "damage_dealt": dealt, "hp_after": target.attributes.hp, "round": context.round, "tick": tick}))
	world.entities = entities.snapshot()
	if target.attributes.hp == 0:
		var fact: Dictionary = event("MARCHER_DEFEATED", {"event_id": Data.instance_id("monster_kill", "%d:%d:%s" % [context.round, tick, hit.source.id], target.id), "round": context.round, "hook": "marching", "tick": tick, "victim": before, "attacker": hit.source, "cause": "combat", "damage_dealt": dealt}).event
		events.append({"event": fact, "views": [fact, fact]})
		var reacted: Dictionary = reaction.call(world, fact, context.seed, context.player_order)
		if reacted.get("action") != "resolved": return Data.invalid("monster_reaction_invalid")
		world = reacted.world
		events.append_array(reacted.events)
		if entities.restore(world.entities).action == "invalid": return Data.invalid("monster_entities_invalid")
	return {"action": "resolved", "world": world, "events": events}

# Local detours only: Tumler can still be intercepted or cornered.
static func steer(unit: Dictionary, destination: Dictionary, rows: Array, fields: Array) -> Dictionary:
	if unit.attributes.get("monster_id") != "Tumler" or destination.is_empty(): return destination
	var a: Dictionary = unit.attributes
	var obstacles: Array = []
	for other in enemies(unit, rows, 340):
		if other.id != a.get("hunt_target", "") and distance(other.attributes, destination) != 0:
			obstacles.append({"x_fp": other.attributes.x_fp, "y_fp": other.attributes.y_fp, "radius": 180})
	for field in fields:
		if field.kind == "pool" and field.lane == a.lane and distance(a, field) <= 400 * 400:
			obstacles.append({"x_fp": field.x_fp, "y_fp": field.y_fp, "radius": 240})
	for obstacle in obstacles:
		if (int(obstacle.x_fp) - int(a.x_fp)) * (int(destination.x_fp) - int(a.x_fp)) < 0 or absi(int(obstacle.y_fp) - int(a.y_fp)) >= int(obstacle.radius): continue
		var side: int = -1 if a.y_fp <= obstacle.y_fp else 1
		var y: int = clampi(int(obstacle.y_fp) + side * int(obstacle.radius), 30, 570)
		if absi(y - int(obstacle.y_fp)) < (int(obstacle.radius) >> 1): y = clampi(int(obstacle.y_fp) - side * int(obstacle.radius), 30, 570)
		return {"x_fp": obstacle.x_fp, "y_fp": y}
	return destination
