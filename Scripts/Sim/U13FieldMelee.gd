extends RefCounted

const Fort = preload("res://Scripts/Sim/U13FieldFortifications.gd")
const Effects = preload("res://Scripts/Sim/U13MonsterEffects.gd")
const Wish = preload("res://Scripts/Sim/U13Wishmaster.gd")
const Rout = preload("res://Scripts/Sim/U13Rout.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const INTERVAL: int = 8

static func nearest(unit: Dictionary, targets: Array, radius: int = 4000, melee: bool = false) -> Dictionary:
	var best: Dictionary = {}
	var gap: int = radius * radius + 1
	for row in targets:
		if row.owner == unit.owner or row.attributes.lane != unit.attributes.lane or (row.kind == "marcher" and Wish.ignored(unit, row)): continue
		if unit.attributes.get("flying", false) and row.kind == "fortification" and row.attributes.structure == "Wall": continue
		if melee and not Fort.in_melee(unit, row): continue
		var d: int = Fort.gap(unit, row)
		if d <= radius * radius and (d < gap or (d == gap and (best.is_empty() or row.id < best.id))):
			best = row; gap = d
	return best

static func touching(entities, structures: Array) -> Array:
	var units: Array = entities.marchers()
	var targets: Array = units + structures
	var result: Array = []
	for unit in units:
		if not nearest(unit, targets, Fort.CONTACT, true).is_empty(): result.append(unit.id)
	return result

static func resolve(world: Dictionary, entities, context: Dictionary, tick: int, fleeing: Dictionary, reaction: Callable) -> Dictionary:
	var clock: int = int(context.round) * 200 + tick
	var units: Array = entities.marchers()
	var targets: Array = units + Fort.rows(world).duplicate(true)
	var shots: Array = []
	var events: Array = []
	# Every attacker selects from the same pre-hit positions. No lane queue,
	# exclusive duels, or shared cooldown between separate melee fighters.
	for unit in units:
		var a: Dictionary = unit.attributes
		if int(a.get("melee_next_tick", 0)) > clock or fleeing.has(unit.id) or Rout.retreating(a, context.round) or a.get("hidden", false) or a.get("sprite_form") == "turret": continue
		var target: Dictionary = nearest(unit, targets, Fort.CONTACT, true)
		if target.is_empty(): continue
		var obstruction: Dictionary = Fort.blocker(unit, Fort.point(a, target), Fort.rows(world))
		if not obstruction.is_empty(): target = obstruction
		if not Fort.in_melee(unit, target): continue
		var source: Dictionary = entities.get_entity(unit.id)
		var amount: int = Wish.attack_amount(source.attributes)
		source.attributes["melee_next_tick"] = clock + INTERVAL
		if a.suit == "Vulture": source.attributes["ranged_next_tick"] = maxi(int(a.get("ranged_next_tick", 0)), clock + INTERVAL)
		entities.update(source.id, source.owner, source.attributes)
		shots.append({"attacker": unit, "target": target, "amount": amount})
	var deaths: Array = []
	for shot in shots:
		var dealt: int = 0
		var hp_after: int = 0
		if shot.target.kind == "fortification":
			var hit: Dictionary = Fort.damage(world, shot.target.id, shot.attacker, shot.amount, shot.attacker.attributes.armor_bypass, context.round, tick)
			dealt = hit.damage_dealt; hp_after = hit.hp_after
			events.append_array(hit.events)
		else:
			var target: Dictionary = entities.get_entity(shot.target.id)
			if not target.is_empty():
				var a: Dictionary = target.attributes
				var absorbed: int = 0 if shot.attacker.attributes.armor_bypass else mini(int(a.armor), int(shot.amount))
				a.armor -= absorbed
				dealt = int(shot.amount) - absorbed
				a.hp = maxi(0, int(a.hp) - dealt)
				hp_after = a.hp
				a.movement_ready_round = mini(int(a.movement_ready_round), int(context.round))
				if a.hp == 0:
					entities.retire(target.id)
					deaths.append({"victim": target.duplicate(true), "attacker": shot.attacker, "damage_dealt": dealt, "hp_after": 0})
				else: entities.update(target.id, target.owner, a)
				events.append_array(Effects.on_hit(entities, shot.attacker, target.id, dealt, context, tick))
		events.append(Fort.event("MARCHER_MELEE_ATTACK", {"attacker": shot.attacker, "target": shot.target, "damage_dealt": dealt, "hp_after": hp_after, "round": context.round, "tick": tick, "lane": shot.attacker.attributes.lane}))
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
