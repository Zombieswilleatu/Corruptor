extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Wishmaster = preload("res://Scripts/Sim/U13Wishmaster.gd")
const Rout = preload("res://Scripts/Sim/U13Rout.gd")
const Defense = preload("res://Scripts/Sim/U13PenitentDefense.gd")
const Fort = preload("res://Scripts/Sim/U13FieldFortifications.gd")
const VERSION: String = "U13_VULTURE_RANGED_V7_FRIENDLY_PASSAGE"
const ATTACK: int = 1
const RANGE_FP: int = 400 # Two units at 200 fixed-point units per unit.
const CONTACT_FP: int = Fort.CONTACT
const EXCHANGE_TICKS: int = 8
const RANGED_INTERVAL_TICKS: int = 32


static func enabled(world: Dictionary) -> bool:
	return world.get("data", {}).get("ranged_profile") == VERSION


static func configure(world: Dictionary) -> void:
	world.data["ranged_profile"] = VERSION
	for unit in world.entities.entities:
		if unit.kind == "marcher" and unit.attributes.suit == "Vulture":
			unit.attributes.attack = ATTACK
			unit.attributes.step_fp = 4
			unit.attributes.armor_bypass = false
		elif unit.kind == "marcher" and unit.attributes.get("suit") == "Wright":
			unit.attributes.attack = 1


static func distance(a: Dictionary, b: Dictionary) -> int:
	var dx: int = int(a.x_fp) - int(b.x_fp)
	var dy: int = int(a.y_fp) - int(b.y_fp)
	return dx * dx + dy * dy


static func nearest(unit: Dictionary, rows: Array) -> Dictionary:
	var preferred: Dictionary = preload("res://Scripts/Sim/U13MonsterEffects.gd").preferred(unit, rows)
	if not preferred.is_empty() and distance(unit.attributes, preferred.attributes) <= RANGE_FP * RANGE_FP: return preferred
	var best: Dictionary = {}
	var best_distance: int = RANGE_FP * RANGE_FP + 1
	for other in rows:
		if other.owner == unit.owner or other.attributes.lane != unit.attributes.lane or Wishmaster.ignored(unit, other):
			continue
		var separation: int = Fort.gap(unit, other)
		if separation < best_distance or (separation == best_distance and (best.is_empty() or other.id < best.id)):
			best = other
			best_distance = separation
	return best


static func ready(unit: Dictionary, clock: int) -> bool:
	return unit.attributes.suit != "Vulture" or int(unit.attributes.get("ranged_next_tick", 0)) <= clock


static func melee_ready(unit: Dictionary, clock: int) -> bool:
	# Old saves used the ranged field for the shared eight-tick attack recovery.
	return unit.attributes.suit != "Vulture" or int(unit.attributes.get("melee_next_tick", unit.attributes.get("ranged_next_tick", 0))) <= clock


static func volley(world: Dictionary, entities, context: Dictionary, duels: Dictionary, tick: int, fleeing: Dictionary, reaction: Callable) -> Dictionary:
	var rows: Array = entities.marchers() + Fort.rows(world).duplicate(true)
	var clock: int = int(context.round) * 200 + tick
	var busy: Dictionary = {}
	for duel in duels.values():
		for unit in duel.units:
			busy[unit.id] = true
	var shots: Array = []
	# One tick snapshot selects every shot; reciprocal fire is simultaneous.
	for unit in rows:
		var tower: bool = unit.kind == "fortification" and unit.attributes.structure == "Tower"
		if tower:
			if int(unit.attributes.ranged_next_tick) > clock: continue
		elif unit.kind != "marcher" or unit.attributes.suit != "Vulture" or busy.has(unit.id) or fleeing.has(unit.id) or Rout.retreating(unit.attributes, context.round) or not ready(unit, clock):
			continue
		var target: Dictionary = nearest(unit, rows)
		if tower:
			target = {}
			var best: int = Fort.TOWER_RANGE * Fort.TOWER_RANGE + 1
			for other in rows:
				if other.owner == unit.owner or other.attributes.lane != unit.attributes.lane or (other.kind == "marcher" and Wishmaster.ignored(unit, other)): continue
				var d: int = Fort.gap(unit, other)
				if d < best or (d == best and not target.is_empty() and other.id < target.id): target = other; best = d
		if target.is_empty() or (not tower and Fort.in_melee(unit, target)):
			continue
		var amount: int = 1
		if tower:
			Fort.find(Fort.rows(world), unit.owner, unit.attributes.lane, 2).attributes.ranged_next_tick = clock + RANGED_INTERVAL_TICKS
		else:
			var attacker: Dictionary = entities.get_entity(unit.id)
			amount = Wishmaster.attack_amount(attacker.attributes)
			attacker.attributes["ranged_next_tick"] = clock + RANGED_INTERVAL_TICKS
			attacker.attributes["melee_next_tick"] = clock + EXCHANGE_TICKS
			entities.update(attacker.id, attacker.owner, attacker.attributes)
		shots.append({"attacker": unit, "target": target, "amount": amount})
	if shots.is_empty():
		return {"action": "resolved", "world": world, "events": []}
	var events: Array = []
	var deaths: Array = []
	for shot in shots:
		var target: Dictionary = entities.get_entity(shot.target.id)
		# A shot already in the volley still exists after reciprocal lethal fire;
		# an overkilled target does not generate a second death or refund the shot.
		var dealt: int = 0
		var blocked: bool = false
		var hp_after: int = 0
		if shot.target.kind == "fortification":
			var hit: Dictionary = Fort.damage(world, shot.target.id, shot.attacker, shot.amount, false, context.round, tick)
			dealt = hit.damage_dealt; hp_after = hit.hp_after
			events.append_array(hit.events)
		elif not target.is_empty():
			blocked = Defense.blocks(target, shot.attacker.id, context.seed, context.round, tick, "Tower" if shot.attacker.kind == "fortification" else "Vulture")
			var amount: int = 0 if blocked else int(shot.amount)
			var absorbed: int = mini(int(target.attributes.armor), amount)
			target.attributes.armor -= absorbed
			dealt = amount - absorbed
			target.attributes.hp = maxi(0, int(target.attributes.hp) - dealt)
			hp_after = target.attributes.hp
			if target.attributes.hp == 0:
				entities.retire(target.id)
				deaths.append({"attacker": shot.attacker, "victim": target.duplicate(true), "damage_dealt": dealt, "hp_after": 0})
			else:
				# Birth-round holding ends when the unit is attacked, even through Armor.
				target.attributes.movement_ready_round = mini(int(target.attributes.movement_ready_round), int(context.round))
				entities.update(target.id, target.owner, target.attributes)
		var details: Dictionary = {"round": context.round, "tick": tick, "lane": shot.attacker.attributes.lane, "attacker": shot.attacker, "target": shot.target, "blocked": blocked, "damage_dealt": dealt, "hp_after": hp_after}
		events.append(event("MARCHER_RANGED_ATTACK", details))
	world.entities = entities.snapshot()
	for death in deaths:
		death.merge({"event_id": Data.instance_id("ranged_kill", str(clock), death.victim.id), "round": context.round, "tick": tick, "hook": context.hook, "cause": "combat"})
		var fact: Dictionary = {"type": "MARCHER_DEFEATED", "text": "", "data": death}
		events.append({"event": fact, "views": [fact, fact]})
		var reacted = reaction.call(world, fact, context.seed, context.player_order)
		if typeof(reacted) != TYPE_DICTIONARY or reacted.get("action") != "resolved":
			return Data.invalid("ranged_reaction_invalid")
		world = reacted.world
		events.append_array(reacted.events)
	if entities.restore(world.entities).action == "invalid":
		return Data.invalid("ranged_entities_invalid")
	return {"action": "resolved", "world": world, "events": events}


static func event(kind: String, details: Dictionary) -> Dictionary:
	var fact: Dictionary = {"type": kind, "text": "", "data": details}
	return {"event": fact, "views": [fact, fact]}
