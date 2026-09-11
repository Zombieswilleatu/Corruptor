extends "res://Scripts/Sim/U13Valak.gd"

const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Lamp = preload("res://Scripts/Sim/U13Wishmaster.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Wishes: Array = ["WishPower", "WishLongevity", "WishResurrection", "WishDeath", "WishWealth"]
const PRICE_WEIGHTS: Dictionary = {"Cards": 30, "Blood": 30, "Guards": 15, "Stone": 15, "Soul": 5, "Ruin": 4, "Wishmaster": 1}

func create_combat_match():
	var validators: Dictionary = {}
	var resolvers: Dictionary = {}
	for power in rules():
		validators[power] = Callable(self, "validate")
		resolvers[power] = Callable(self, "resolve")
	return MatchOwner.new(Lamp.VERSION + ":" + Essence.VERSION + ":" + KRONI_POLICY + ":" + ODRADEK_POLICY + ":" + POLICY, rules(), validators, resolvers, Callable(self, "project"), Callable(), Callable(self, "on_hook"), self, Callable(self, "valid_world"), Callable(self, "accept_order"), Callable(), Callable(Guards, "legal_orders"))

static func rules() -> Dictionary:
	var result: Dictionary = preload("res://Scripts/Sim/U13Valak.gd").rules()
	for power in Wishes:
		result[power] = {"lord_id": "Kanifous", "fire_hook": Timeline.POST_RESOLUTION_SPAWNS if power == "WishPower" else Timeline.POST_RESOLUTION_DIRECT, "cooldown_on": "activation", "cooldown_rounds": 0, "delay_rounds": 0, "cost": {}, "stages": [], "target_kind": "", "target_relation": "any", "visibility": "public"}
	return result

func valid_world(world: Dictionary) -> bool:
	return super.valid_world(world) and Lamp.valid(world)

func validate(source: Dictionary, world: Dictionary, phase: String) -> Dictionary:
	if source.power_id not in Wishes:
		return super.validate(source, world, phase)
	var t: Dictionary = source.target
	var legal: bool = source.parameters.is_empty()
	match source.power_id:
		"WishPower":
			legal = legal and t.size() == 1 and t.get("lane") in ["Lord", "Castle"]
		"WishLongevity":
			var castle: Dictionary = _entity(world, t.get("entity_id", ""))
			legal = legal and t.size() == 1 and longevity_target(castle, source.player_id)
		"WishResurrection":
			legal = legal and t.size() == 2 and t.get("kind") == "guard_zone" and t.get("zone") in ["Lord", "Castle"]
		"WishDeath":
			legal = legal and Fields.target_valid(t)
		"WishWealth":
			legal = legal and t.is_empty()
	return {"legal": legal, "reason": "wish_target_invalid"}

static func longevity_target(castle: Dictionary, player_id: int) -> bool:
	return (
		preload("res://Scripts/Sim/U13Structures.gd").targetable(castle)
		and castle.owner == player_id
		and castle.attributes.integrity < castle.attributes.max_integrity
	)

static func _entity(world: Dictionary, id: String) -> Dictionary:
	for row in world.entities.entities:
		if row.id == id:
			return row
	return {}

func resolve(record: Dictionary, context: Dictionary) -> Dictionary:
	var source: Dictionary = record.declaration
	if source.power_id not in Wishes:
		return super.resolve(record, context)
	var world: Dictionary = context.world.duplicate(true)
	var ids = Ids.new()
	ids.restore(world.entities)
	var events: Array = []
	var count: int = 0
	var death_victims: Array = []
	var pid: int = source.player_id
	match source.power_id:
		"WishPower":
			for index in range(Lamp.power_count(context.seed, source.declaration_id)):
				var suit: String = Marching.SUITS[Lamp.draw(context.seed, source.declaration_id, "WISH_SUIT", 4, index)]
				var unit: Dictionary = ids.create("marcher", source.declaration_id, index, pid, Marching.profile(suit, source.target.lane, pid, context.round, context.round)).entity
				Marching.place_spawn(ids, unit.id, context.seed)
				count += 1
		"WishLongevity":
			var castle: Dictionary = ids.get_entity(source.target.entity_id)
			if longevity_target(castle, pid):
				castle.attributes.integrity = castle.attributes.max_integrity
				castle.attributes.status = "standing"
				castle.attributes.construction_state = "active"
				ids.update(castle.id, pid, castle.attributes)
				if world.data.construction_targets[pid] == castle.id:
					world.data.construction_targets[pid] = ""
				count = 1
		"WishResurrection":
			var occupied: Array = []
			for row in world.entities.entities:
				if row.kind == "card" and row.owner == pid and row.attributes.get("role") == "guard" and row.attributes.lane == source.target.zone:
					occupied.append(row.attributes.slot)
			for lost in world.data.kanifous_losses:
				if lost.owner != pid or lost.attributes.lane != source.target.zone or lost.id not in world.data.card_zones.discard or lost.attributes.slot in occupied:
					continue
				ids.update(lost.id, pid, lost.attributes)
				world.data.card_zones.discard.erase(lost.id)
				occupied.append(lost.attributes.slot)
				count += 1
		"WishDeath":
			for row in world.entities.entities:
				if row.kind == "marcher" and row.attributes.lane == source.target.lane and Lamp.distance(row.attributes, source.target.field_position) <= Lamp.DEATH_RADIUS * Lamp.DEATH_RADIUS:
					death_victims.append(row.duplicate(true))
					ids.retire(row.id)
					count += 1
		"WishWealth":
			for index in range(2):
				var drawn: Dictionary = Cards.draw(world, pid, context.seed, source.declaration_id + ":" + str(index))
				if drawn.action == "invalid":
					return drawn
				count += int(drawn.drawn)
			ids.restore(world.entities)
	world.entities = ids.snapshot()
	var success: bool = count > 0
	if success:
		var price: Dictionary = {"id": Data.instance_id("price", source.declaration_id, "main"), "owner": pid, "created_round": context.round, "due_round": int(context.round) + 1 + Lamp.draw(context.seed, source.declaration_id, "PRICE_DELAY", 3)}
		world.data.kanifous_prices.append(price)
		events.append(Lamp.event("KANIFOUS_PRICE_SCHEDULED", price))
	events.append(Lamp.event("KANIFOUS_WISH_RESOLVED", {"player_id": pid, "power": source.power_id, "target": source.target, "count": count, "success": success, "round": context.round, "victims": death_victims}))
	return {"action": "resolved", "world": world, "events": events}

func react(world: Dictionary, fact: Dictionary, seed_value: String, order: Array) -> Dictionary:
	var result: Dictionary = super.react(world, fact, seed_value, order)
	if result.action != "invalid" and fact.type == "GUARD_DEFEATED":
		if not result.world.data.kanifous_losses.any(func(row: Dictionary) -> bool: return row.id == fact.data.guard.id):
			result.world.data.kanifous_losses.append(fact.data.guard.duplicate(true))
	return result

func on_hook(context: Dictionary) -> Dictionary:
	var result: Dictionary = super.on_hook(context)
	if result.action == "invalid":
		return result
	result.events.append_array(Lamp.advance(result.world, context.hook, context.round, context.seed))
	if context.hook == Timeline.ROUND_START_AUTOMATIC:
		var due: Array = result.world.data.kanifous_prices.duplicate(true)
		for price in due:
			if price.due_round > context.round:
				continue
			var paid: Dictionary = _price(result.world, price, context)
			if paid.action == "invalid":
				return paid
			result.world = paid.world
			result.events.append_array(paid.events)
			if not paid.get("deferred", false):
				result.world.data.kanifous_prices = result.world.data.kanifous_prices.filter(func(row: Dictionary) -> bool: return row.id != price.id)
	return result

func _price(raw: Dictionary, price: Dictionary, context: Dictionary) -> Dictionary:
	var world: Dictionary = raw.duplicate(true)
	var pid: int = price.owner
	var groups: Dictionary = {"Cards": world.data.card_zones.hands[pid].duplicate(), "Blood": [], "Guards": [], "Stone": [], "Soul": [], "Ruin": [], "Wishmaster": []}
	for row in world.entities.entities:
		if row.owner != pid:
			continue
		if row.kind == "marcher":
			groups.Blood.append(row.id)
		elif row.kind == "card" and row.attributes.get("role") == "guard":
			groups.Guards.append(row.id)
		elif row.kind == "castle" and row.attributes.status == "standing" and row.attributes.construction_state == "active":
			groups.Stone.append(row.id)
			groups.Ruin.append(row.id)
		elif row.kind == "lord" and row.attributes.alive and row.attributes.lord_id == "Kanifous":
			groups.Wishmaster.append(row.id)
	if world.players[pid].resources.souls > 0:
		groups.Soul.append(pid)
	var pool: Array = []
	for outcome in PRICE_WEIGHTS:
		if not groups[outcome].is_empty():
			for index in range(PRICE_WEIGHTS[outcome]):
				pool.append(outcome)
	var events: Array = []
	if pool.is_empty():
		# Keep the original due date: overdue Prices remain in the saved ledger.
		return {"action": "resolved", "world": world, "deferred": true, "events": [Lamp.event("KANIFOUS_PRICE_DEFERRED", {"id": price.id, "outcome": "Deferred", "player_id": pid, "round": context.round, "due_round": int(context.round) + 1})]}
	var outcome: String = pool[Lamp.draw(context.seed, price.id, "PRICE_OUTCOME", pool.size())]
	var targets: Array = groups[outcome]
	targets.sort()
	var chosen: Array = []
	for index in range(mini(targets.size(), 2 if outcome in ["Cards", "Blood"] else 1)):
		var pick: int = Lamp.draw(context.seed, price.id, "PRICE_TARGET", targets.size(), index)
		chosen.append(targets.pop_at(pick))
	var taken: Array = []
	for target in chosen:
		if typeof(target) != TYPE_STRING:
			continue
		for entity in raw.entities.entities:
			if entity.id != target:
				continue
			var a: Dictionary = entity.attributes
			if entity.kind == "castle":
				taken.append("%s (slot %d)" % [a.get("castle_type", "Castle"), int(a.get("castle_slot", 0)) + 1])
			elif entity.kind == "lord":
				taken.append(a.get("lord_id", "Lord"))
			else:
				taken.append("%s %s · %s%s" % [str(a.get("value", "")), a.get("suit", "Card"), "Marcher" if entity.kind == "marcher" else a.get("role", "card"), " · " + str(a.get("lane", a.get("guard_zone", "")))])
	var ids = Ids.new()
	ids.restore(world.entities)
	match outcome:
		"Cards":
			Cards.discard(world, pid, chosen)
			ids.restore(world.entities)
		"Blood":
			for id in chosen:
				ids.retire(id)
		"Soul":
			world.players[pid].resources.souls -= 1
		"Stone", "Ruin":
			var castle: Dictionary = ids.get_entity(chosen[0])
			castle.attributes.integrity = maxi(0, int(castle.attributes.integrity) - 5) if outcome == "Stone" else 0
			castle.attributes.status = "standing" if castle.attributes.integrity > 0 else "defunct"
			if castle.attributes.status == "defunct":
				castle.attributes.artillery_target = ""
			ids.update(castle.id, pid, castle.attributes)
		"Guards", "Wishmaster":
			var hit: Dictionary = Battle.apply(world, {"command_id": price.id, "kind": "defeat_guard" if outcome == "Guards" else "banish_lord", "target_id": chosen[0]}, context.round, context.hook)
			if hit.action == "invalid":
				return hit
			var reacted: Dictionary = react(hit.world, hit.event, context.seed, context.player_order)
			if reacted.action == "invalid":
				return reacted
			world = reacted.world
			if outcome == "Wishmaster":
				var breach: Dictionary = Battle.apply(world, {"command_id": price.id + ":breach", "kind": "set_breach", "lord_id": "Kanifous", "source_id": chosen[0]}, context.round, context.hook)
				if breach.action == "invalid":
					return breach
				world = breach.world
				events.append({"event": breach.event, "views": [breach.event, breach.event]})
			events.append({"event": hit.event, "views": [hit.event, hit.event]})
			events.append_array(reacted.events)
			ids.restore(world.entities)
	world.entities = ids.snapshot()
	if outcome in ["Stone", "Soul", "Ruin", "Wishmaster"]:
		world.data.neutral_tears += 1
	events.append(Lamp.event("KANIFOUS_PRICE_RESOLVED", {"id": price.id, "outcome": outcome, "targets": chosen, "taken": taken, "player_id": pid, "round": context.round}))
	return {"action": "resolved", "world": world, "events": events}

func project(world: Dictionary, player_id: int) -> Dictionary:
	var result: Dictionary = super.project(world, player_id)
	result["wishmaster_objects"] = world.data.kanifous_objects.duplicate(true)
	result["wish_prices"] = world.data.kanifous_prices.duplicate(true)
	result["void_active"] = world.data.breach_lord == "Kanifous"
	return result

func accept_order(context: Dictionary) -> Dictionary:
	var result: Dictionary = super.accept_order(context)
	if result.action == "invalid":
		return result
	var count: int = 0
	for source in context.declarations:
		if source.power_id in Wishes:
			count += 1
	if count > 1:
		return Data.invalid("one_wish_per_round")
	if context.phase == "snapshot":
		for pending in context.pending_effects:
			if pending.declaration.power_id in Wishes and (not pending.payload.is_empty() or pending.effect_key != "main"):
				return Data.invalid("wish_pending_invalid")
		for row in context.world.data.kanifous_objects:
			if row.id != Data.instance_id("wishmaster", str(row.owner), str(row.created_round)) or row.created_round > context.round or row.due_round < context.round:
				return Data.invalid("wishmaster_clock_invalid")
		for price in context.world.data.kanifous_prices:
			if price.created_round > context.round:
				return Data.invalid("price_clock_invalid")
	return result
