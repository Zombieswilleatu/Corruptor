extends RefCounted

const Shroud = preload("res://Scripts/Sim/U13DotraShroud.gd")

const Defense = preload("res://Scripts/Sim/U13PenitentDefense.gd")

const Incoming = preload("res://Scripts/Sim/U13IncomingDamage.gd")

const Fort = preload("res://Scripts/Sim/U13FieldFortifications.gd")
const Effects = preload("res://Scripts/Sim/U13MonsterEffects.gd")
const Wish = preload("res://Scripts/Sim/U13Wishmaster.gd")
const Rout = preload("res://Scripts/Sim/U13Rout.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Matchups = preload("res://Scripts/Sim/U13MarcherMatchups.gd")
const INTERVAL: int = 34 # Up to six ordinary swings per 200-tick round.

static func nearest(unit: Dictionary, targets: Array, radius: int = 4000, melee: bool = false) -> Dictionary:
	var best: Dictionary = {}
	var radius_squared: int = radius * radius
	var gap: int = radius_squared + 1
	var a: Dictionary = unit.attributes
	var owner: int = unit.owner
	var lane: String = a.lane
	var x: int = int(a.x_fp)
	var y: int = int(a.y_fp)
	var flying: bool = a.get("flying", false)
	for row in targets:
		if row.owner == owner: continue
		var b: Dictionary = row.attributes
		if b.lane != lane: continue
		# Match Fort.point's rectangle distance without allocating a point for
		# every candidate. Keep the same integer conversion and tie ordering.
		var wall: bool = row.kind == "fortification" and b.structure == "Wall"
		if flying and wall: continue
		var dx: int = x - (clampi(x, int(b.x_fp) - 24, int(b.x_fp) + 24) if wall else int(b.x_fp))
		var dy: int = y - (clampi(y, int(b.y_fp) - 150, int(b.y_fp) + 150) if wall else int(b.y_fp))
		var d: int = dx * dx + dy * dy
		if d > radius_squared or d > gap: continue
		if d == gap and not best.is_empty() and row.id >= best.id: continue
		if melee and dx * dx * Fort.LATERAL_CONTACT * Fort.LATERAL_CONTACT + dy * dy * Fort.CONTACT * Fort.CONTACT > Fort.CONTACT * Fort.CONTACT * Fort.LATERAL_CONTACT * Fort.LATERAL_CONTACT: continue
		# Visibility and bypass checks only matter for candidates that can win.
		if Shroud.active(b) or (row.kind == "marcher" and Wish.ignored(unit, row)): continue
		best = row; gap = d
	return best

static func touching(entities, structures: Array) -> Array:
	var units: Array = entities._read_marchers()
	var targets: Array = units + structures
	var result: Array = []
	for unit in units:
		if not nearest(unit, targets, Fort.CONTACT, true).is_empty(): result.append(unit.id)
	return result

static func resolve(world: Dictionary, entities, context: Dictionary, tick: int, fleeing: Dictionary, reaction: Callable) -> Dictionary:
	var clock: int = int(context.round) * 200 + tick
	var units: Array = entities._read_marchers()
	var targets: Array = units + Fort.rows(world).duplicate(true)
	var has_taunt: bool = units.any(func(r): return r.attributes.get("monster_id") == "Kurchin")
	var shots: Array = []
	var events: Array = []
	# Every attacker selects from the same pre-hit positions. No lane queue,
	# exclusive duels, or shared cooldown between separate melee fighters.
	for unit in units:
		var a: Dictionary = unit.attributes
		if Effects.Charge.active(a): continue
		if Fort.ranged_guard(unit, Fort.rows(world), context.round): continue
		if int(a.get("melee_next_tick", 0)) > clock or fleeing.has(unit.id) or Rout.retreating(a, context.round) or a.get("hidden", false) or a.get("sprite_form") == "turret": continue
		var target: Dictionary = nearest(unit, targets, Fort.CONTACT, true)
		if has_taunt or a.get("monster_id") == "Tumler":
			var hunted: Dictionary = Effects.preferred(unit, units)
			if not hunted.is_empty(): target = hunted
		if target.is_empty(): continue
		var obstruction: Dictionary = Fort.blocker(unit, Fort.point(a, target), Fort.rows(world))
		if not obstruction.is_empty(): target = obstruction
		if not Fort.in_melee(unit, target): continue
		var source: Dictionary = entities.get_entity(unit.id)
		var amount: int = Wish.attack_amount(source.attributes) + Matchups.bonus(source, target) + Effects.hunt_bonus(source, target)
		source.attributes["melee_next_tick"] = clock + INTERVAL
		if a.suit == "Vulture": source.attributes["ranged_next_tick"] = maxi(int(a.get("ranged_next_tick", 0)), clock + INTERVAL)
		entities.update(source.id, source.owner, source.attributes)
		shots.append({"attacker": unit, "target": target, "amount": amount})
	var deaths: Array = []
	for shot in shots:
		var dealt: int = 0
		var hp_after: int = 0
		var evaded: bool = false
		var blocked: bool = false
		var warded: bool = false
		if shot.target.kind == "fortification":
			var hit: Dictionary = Fort.damage(world, shot.target.id, shot.attacker, shot.amount, shot.attacker.attributes.armor_bypass, context.round, tick)
			dealt = hit.damage_dealt; hp_after = hit.hp_after
			events.append_array(hit.events)
		else:
			var target: Dictionary = entities.get_entity(shot.target.id)
			if not target.is_empty():
				var a: Dictionary = target.attributes
				var live_rows: Array = entities.marchers() if a.get("monster_id") == "Tumler" else []
				evaded = Effects.evades(target, shot.attacker, live_rows, context, tick, "Melee", Fort.rows(world), fleeing)
				blocked = Defense.blocks_vulture_melee(target, shot.attacker, context.seed, context.round, tick)
				var had_ward: bool = a.get("muno_ward", false)
				var amount: int = 0 if blocked or evaded else Incoming.apply(a, int(shot.amount), clock, true, int(context.round))
				warded = had_ward and not a.get("muno_ward", false)
				if not blocked and not evaded and not fleeing.has(target.id): events.append_array(Effects.intercept(target, shot.attacker, live_rows, context, tick, Fort.rows(world)))
				var absorbed: int = 0 if shot.attacker.attributes.armor_bypass else mini(int(a.armor), amount)
				a.armor -= absorbed
				dealt = amount - absorbed
				a.hp = maxi(0, int(a.hp) - dealt)
				hp_after = a.hp
				a.movement_ready_round = mini(int(a.movement_ready_round), int(context.round))
				if a.hp == 0:
					entities.retire(target.id)
					deaths.append({"victim": target.duplicate(true), "attacker": shot.attacker, "damage_dealt": dealt, "hp_after": 0})
				else: entities.update(target.id, target.owner, a)
				if not blocked and not evaded: events.append_array(Effects.on_hit(entities, shot.attacker, target.id, dealt, context, tick))
		events.append(Fort.event("MARCHER_MELEE_ATTACK", {"attacker": shot.attacker, "target": shot.target, "damage_dealt": dealt, "evaded": evaded, "blocked": blocked, "warded": warded, "hp_after": hp_after, "round": context.round, "tick": tick, "lane": shot.attacker.attributes.lane}))
	world.entities = entities.snapshot()
	for death in deaths:
		death.merge({"event_id": Data.instance_id("field_melee_kill", str(clock), death.victim.id), "round": context.round, "tick": tick, "hook": context.hook, "cause": "combat"})
		var fact: Dictionary = Fort.event("MARCHER_DEFEATED", death).event
		events.append({"event": fact, "views": [fact, fact]})
		var result = reaction.call(world, fact, context.seed, context.player_order)
		if typeof(result) != TYPE_DICTIONARY or result.get("action") != "resolved": return Data.invalid("field_melee_reaction_invalid")
		world = result.world
		events.append_array(result.events)
	if not deaths.is_empty() and entities.restore(world.entities).action == "invalid": return Data.invalid("field_melee_entities_invalid")
	return {"action": "resolved", "world": world, "events": events}
