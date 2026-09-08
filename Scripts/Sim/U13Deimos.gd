extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const MatchOwner = preload("res://Scripts/Sim/U13Match.gd")
const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const WAR_MACHINE: String = "WarMachine"
const POLICY: String = "U13_DEIMOS_ARTILLERY_SLICE_V1"
var _gremory = Gremory.new()


func create_combat_match():
	var validators: Dictionary = {}
	var resolvers: Dictionary = {}
	for power in rules():
		validators[power] = Callable(self, "validate")
		resolvers[power] = Callable(self, "resolve")
	return MatchOwner.new(
		POLICY + ":" + Structures.PROFILE + ":" + Marching.VERSION,
		rules(),
		validators,
		resolvers,
		Callable(self, "project"),
		Callable(),
		Callable(self, "on_hook"),
		self,
		Callable(self, "valid_world"),
		Callable(self, "accept_order")
	)


static func rules() -> Dictionary:
	var result: Dictionary = Gremory.rules()
	result[WAR_MACHINE] = {
		"lord_id": "Deimos",
		"fire_hook": Timeline.POST_REPAIR_ARTILLERY,
		"cooldown_on": "activation",
		"cooldown_rounds": 0,
		"delay_rounds": 0,
		"cost": {},
		"stages": [],
		"target_kind": "castle",
		"target_relation": "own",
		"visibility": "public"
	}
	return result


func valid_world(world: Dictionary) -> bool:
	if (
		not Combat.valid(world)
		or world.data.combat_profile != Structures.PROFILE
		or not _gremory.valid_world(world)
	):
		return false
	var counters = world.data.get("deimos_spoils")
	var seen = world.data.get("deimos_spoils_events")
	var fear = world.data.get("deimos_fear_round")
	if typeof(fear) != TYPE_ARRAY or fear.size() != 2:
		return false
	for value in fear:
		if not Data.is_integer(value) or value < 0:
			return false
	if typeof(counters) != TYPE_ARRAY or counters.size() != 2 or typeof(seen) != TYPE_DICTIONARY:
		return false
	for count in counters:
		if not Data.is_integer(count) or count < 0:
			return false
	var counted: Array = [0, 0]
	for key in seen:
		if (
			key.is_empty()
			or not Data.is_integer(seen[key])
			or seen[key] not in [0, 1]
			or not world.data.get("battle_commands", {}).has(key)
		):
			return false
		counted[int(seen[key])] += 1
	if counted != counters:
		return false
	var entities = Ids.new()
	entities.restore(world.entities)
	for player_id in [0, 1]:
		var player: Dictionary = world.players[player_id]
		if (
			not Data.is_integer(player.resources.get("personal_tears"))
			or player.resources.personal_tears < 0
		):
			return false
		if player.lord_id == "Deimos":
			var lord: Dictionary = entities.get_entity(player.lord_entity_id)
			if (
				not Data.is_integer(lord.attributes.get("threat"))
				or lord.attributes.threat < 0
				or lord.attributes.threat > 1000000
			):
				return false
	return true


func validate(source: Dictionary, world: Dictionary, phase: String) -> Dictionary:
	if source.power_id != WAR_MACHINE:
		return _gremory.validate(source, world, phase)
	var entities = Ids.new()
	entities.restore(world.entities)
	var engine: Dictionary = entities.get_entity(String(source.target.get("entity_id", "")))
	var legal: bool = (
		not engine.is_empty()
		and engine.kind == "castle"
		and engine.owner == source.player_id
		and engine.attributes.combat_profile == "siege_engine"
		and Structures.operational(engine)
	)
	return {"legal": legal, "reason": "siege_engine_not_operational"}


func resolve(record: Dictionary, context: Dictionary) -> Dictionary:
	if record.declaration.power_id != WAR_MACHINE:
		return _gremory.resolve(record, context)
	# The match's established same-hook contract resolves pending powers before
	# the ordinary hook. Extra shot first, then the normal artillery sweep.
	var changed: Dictionary = Structures.fire(
		context.world,
		record.declaration.target.entity_id,
		context.seed,
		context.round,
		record.effect_id,
		Callable(self, "react"),
		context.player_order
	)
	if changed.action == "invalid":
		return changed
	var events: Array = []
	for envelope in changed.events:
		# Artillery's current reactions (including public discard reclamation)
		# are public. Reject a future private reaction rather than exposing it.
		if envelope.views != [envelope.event, envelope.event]:
			return Data.invalid("artillery_private_reaction_requires_adapter")
		events.append(envelope.event)
	return {"action": "resolved", "world": changed.world, "events": events}


func accept_order(context: Dictionary) -> Dictionary:
	if context.phase == "snapshot":
		for delivered_round in context.world.data.deimos_fear_round:
			if delivered_round > context.world.data.get("combat_resolved_round", 0):
				return Data.invalid("fear_ledger_ahead_of_combat")
	return Combat.accept(context)


func on_hook(context: Dictionary) -> Dictionary:
	if context.hook == Timeline.POST_REPAIR_ARTILLERY:
		return Structures.normal_fire(context, Callable(self, "react"))
	return Combat.on_hook(context, Callable(self, "react"))


func react(
	raw: Dictionary, fact: Dictionary, seed_value: String, player_order: Array
) -> Dictionary:
	var changed: Dictionary = Gremory.react(raw, fact, seed_value, player_order)
	if changed.action == "invalid":
		return changed
	var world: Dictionary = changed.world
	var events: Array = changed.events
	if fact.type == "BREACH_CHANGED":
		var ceiling: Dictionary = Structures.sync_breach(world)
		world = ceiling.world
		events.append_array(ceiling.events)
	var player_id: int = int(fact.data.get("player_id", -1))
	if player_id not in [0, 1]:
		return {"action": "resolved", "world": world, "events": events}
	var player: Dictionary = world.players[player_id]
	var entities = Ids.new()
	entities.restore(world.entities)
	var lord: Dictionary = entities.get_entity(player.lord_entity_id)
	if player.lord_id != "Deimos" or not lord.attributes.alive:
		return {"action": "resolved", "world": world, "events": events}
	if fact.type == "SIEGE_STARTED":
		if world.data.deimos_fear_round[player_id] >= fact.data.round:
			return {"action": "resolved", "world": world, "events": events}
		world.data.deimos_fear_round[player_id] = fact.data.round
		var guards: Array = []
		for entity in entities.snapshot().entities:
			if (
				entity.kind == "card"
				and entity.owner == 1 - player_id
				and entity.attributes.get("role") == "guard"
				and entity.attributes.get("lane") == "Castle"
			):
				guards.append(entity)
		guards.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				if a.attributes.value != b.attributes.value:
					return a.attributes.value < b.attributes.value
				return a.id < b.id
		)
		var returned: Array = []
		for guard in guards.slice(0, mini(guards.size(), 1 + int(lord.attributes.threat))):
			guard.attributes.role = "card"
			guard.attributes.erase("slot")
			guard.attributes.erase("lane")
			entities.update(guard.id, guard.owner, guard.attributes)
			world.data.card_zones.hands[guard.owner].append(guard.id)
			returned.append(guard.id)
		world.entities = entities.snapshot()
		events.append(
			Structures.public_event(
				"FEAR_AURA",
				{
					"player_id": player_id,
					"round": fact.data.round,
					"returned_ids": returned,
					"threat": lord.attributes.threat
				}
			)
		)
	if fact.type == "CASTLE_DESTROYED" and fact.data.castle.owner == 1 - player_id:
		var key: String = fact.data.event_id
		if not world.data.deimos_spoils_events.has(key):
			var first: bool = world.data.deimos_spoils[player_id] == 0
			world.data.deimos_spoils_events[key] = player_id
			world.data.deimos_spoils[player_id] += 1
			if first:
				player.resources.personal_tears += 1
			else:
				world.data.neutral_tears += 1
			events.append(
				Structures.public_event(
					"PERSONAL_TEAR_CREATED" if first else "NEUTRAL_TEAR_CREATED",
					{
						"player_id": player_id,
						"round": fact.data.round,
						"amount": 1,
						"source": "SpoilsOfWar"
					}
				)
			)
	return {"action": "resolved", "world": world, "events": events}


func project(world: Dictionary, player_id: int) -> Dictionary:
	var view: Dictionary = _gremory.project(world, player_id)
	view["personal_tears"] = [
		world.players[0].resources.personal_tears, world.players[1].resources.personal_tears
	]
	view["lord_ids"] = [world.players[0].lord_id, world.players[1].lord_id]
	return view
