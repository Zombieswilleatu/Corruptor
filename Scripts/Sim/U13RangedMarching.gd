extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Wishmaster = preload("res://Scripts/Sim/U13Wishmaster.gd")
const Rout = preload("res://Scripts/Sim/U13Rout.gd")
const VERSION: String = "U13_VULTURE_RANGED_V1"
const RANGE_FP: int = 800 # Four units at 200 fixed-point units per unit.
const CONTACT_FP: int = 180
const EXCHANGE_TICKS: int = 8


static func enabled(world: Dictionary) -> bool:
	return world.get("data", {}).get("ranged_profile") == VERSION


static func configure(world: Dictionary) -> void:
	world.data["ranged_profile"] = VERSION
	for unit in world.entities.entities:
		if unit.kind == "marcher" and unit.attributes.suit == "Vulture":
			unit.attributes.step_fp = 4
			unit.attributes.armor_bypass = false


static func distance(a: Dictionary, b: Dictionary) -> int:
	var dx: int = int(a.x_fp) - int(b.x_fp)
	var dy: int = int(a.y_fp) - int(b.y_fp)
	return dx * dx + dy * dy


static func nearest(unit: Dictionary, rows: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: int = RANGE_FP * RANGE_FP + 1
	for other in rows:
		if other.owner == unit.owner or other.attributes.lane != unit.attributes.lane or Wishmaster.ignored(unit, other):
			continue
		var separation: int = distance(unit.attributes, other.attributes)
		if separation < best_distance or (separation == best_distance and (best.is_empty() or other.id < best.id)):
			best = other
			best_distance = separation
	return best


static func ready(unit: Dictionary, clock: int) -> bool:
	return unit.attributes.suit != "Vulture" or int(unit.attributes.get("ranged_next_tick", 0)) <= clock


static func volley(world: Dictionary, entities, context: Dictionary, duels: Dictionary, tick: int, fleeing: Dictionary, reaction: Callable) -> Dictionary:
	var rows: Array = entities.marchers()
	var clock: int = int(context.round) * 200 + tick
	var busy: Dictionary = {}
	for duel in duels.values():
		for unit in duel.units:
			busy[unit.id] = true
	var shots: Array = []
	# One tick snapshot selects every shot; reciprocal fire is simultaneous.
	for unit in rows:
		if unit.attributes.suit != "Vulture" or busy.has(unit.id) or fleeing.has(unit.id) or Rout.retreating(unit.attributes, context.round) or not ready(unit, clock):
			continue
		var target: Dictionary = nearest(unit, rows)
		if target.is_empty() or distance(unit.attributes, target.attributes) <= CONTACT_FP * CONTACT_FP:
			continue
		var attacker: Dictionary = entities.get_entity(unit.id)
		var amount: int = Wishmaster.attack_amount(attacker.attributes)
		attacker.attributes["ranged_next_tick"] = clock + EXCHANGE_TICKS
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
		if not target.is_empty():
			var absorbed: int = mini(int(target.attributes.armor), int(shot.amount))
			target.attributes.armor -= absorbed
			dealt = int(shot.amount) - absorbed
			target.attributes.hp = maxi(0, int(target.attributes.hp) - dealt)
			if target.attributes.hp == 0:
				entities.retire(target.id)
				deaths.append({"attacker": shot.attacker, "victim": target.duplicate(true), "damage_dealt": dealt, "hp_after": 0})
			else:
				entities.update(target.id, target.owner, target.attributes)
		var details: Dictionary = {"round": context.round, "tick": tick, "lane": shot.attacker.attributes.lane, "attacker": shot.attacker, "target": shot.target, "damage_dealt": dealt, "hp_after": 0 if target.is_empty() else target.attributes.hp}
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
