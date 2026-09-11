class_name U13Gremory
extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
const MatchOwner = preload("res://Scripts/Sim/U13Match.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const POLICY: String = "U13_GREMORY_SLICE_V1"
const PREDATOR: String = "PredatorOfRuin"
const RUIN: String = "InevitableRuin"
var _driver: Callable
var _combat_enabled: bool = false


# Driver is a versioned, pure authoritative phase adapter returning a command
# array. It supplies combat/development results, never a post-lock player prompt.
func _init(driver: Callable = Callable(), combat_enabled: bool = false) -> void:
	_driver = driver
	_combat_enabled = combat_enabled


# Built-in path takes sealed orders, never injected kill/defeat commands.
func create_combat_match():
	var content = get_script().new(Callable(), true)
	return content.create_match(Combat.VERSION + ":" + Marching.VERSION)


func create_match(adapter_version: String):
	if adapter_version.is_empty():
		return null
	var validators: Dictionary = {
		PREDATOR: Callable(self, "validate"), RUIN: Callable(self, "validate")
	}
	var resolvers: Dictionary = {
		PREDATOR: Callable(self, "resolve"), RUIN: Callable(self, "resolve")
	}
	return MatchOwner.new(
		POLICY + (":combat:" if _combat_enabled else ":") + adapter_version,
		rules(),
		validators,
		resolvers,
		Callable(self, "project"),
		Callable(),
		Callable(self, "on_hook"),
		self,
		Callable(self, "valid_world"),
		Callable(self, "accept_order"),
		Callable(),
		Callable(Combat, "legal_orders") if _combat_enabled else Callable()
	)


func valid_world(world: Dictionary) -> bool:
	if (
		_combat_enabled
		and (world.data.get("combat_profile") != Combat.VERSION or not Combat.valid(world))
	):
		return false
	if (
		not Cards.valid(world)
		or not Data.is_integer(world.data.get("neutral_tears"))
		or world.data.neutral_tears < 0
		or typeof(world.data.get("breach_lord")) != TYPE_STRING
	):
		return false
	var ledger = world.data.get("gremory_triggers", {})
	if typeof(ledger) != TYPE_DICTIONARY:
		return false
	for value in ledger.values():
		if not Data.is_integer(value) or value < 0:
			return false
	for entity in world.entities.entities:
		var attributes: Dictionary = entity.attributes
		if entity.kind == "castle":
			if (
				attributes.get("status") not in ["standing", "defunct", "ruined", "profaned"]
				or not Data.is_integer(attributes.get("integrity"))
				or not Data.is_integer(attributes.get("max_integrity"))
			):
				return false
			if (
				attributes.integrity < 0
				or attributes.max_integrity < 1
				or attributes.integrity > attributes.max_integrity
			):
				return false
		if entity.kind == "marcher":
			if (
				not Data.is_integer(attributes.get("hp"))
				or attributes.hp < 1
				or attributes.get("lane") not in ["Lord", "Castle"]
				or attributes.get("suit") not in ["Butcher", "Vulture", "Wright", "Penitent"]
			):
				return false
	return true


static func rules() -> Dictionary:
	var base: Dictionary = {
		"lord_id": "Gremory",
		"fire_hook": Timeline.POST_RESOLUTION_SPAWNS,
		"cooldown_on": "activation",
		"cooldown_rounds": 1,
		"delay_rounds": 0,
		"cost": {},
		"stages": [],
		"target_kind": "",
		"target_relation": "any",
		"visibility": "public"
	}
	var prepared: Dictionary = base.duplicate(true)
	prepared.fire_hook = Timeline.ROUND_START_SCHEDULED
	prepared.delay_rounds = 1
	prepared.cooldown_rounds = 0
	prepared.target_kind = "castle"
	prepared["discard_count"] = 2
	return {PREDATOR: base, RUIN: prepared}


func validate(source: Dictionary, world: Dictionary, phase: String) -> Dictionary:
	if not Cards.valid(world):
		return {"legal": false, "reason": "card_zones_invalid"}
	if source.power_id == PREDATOR:
		return {"legal": source.target.get("lane") in ["Lord", "Castle"], "reason": "lane_invalid"}
	var entities = Ids.new()
	entities.restore(world.entities)
	var castle: Dictionary = entities.get_entity(String(source.target.get("entity_id", "")))
	if (
		castle.is_empty()
		or castle.kind != "castle"
		or castle.attributes.get("status") not in ["standing", "defunct"]
	):
		return {"legal": false, "reason": "castle_not_standing"}
	if castle.owner != 1 - int(source.player_id):
		return {"legal": false, "reason": "castle_not_enemy"}
	if phase == "declaration":
		var attributes: Dictionary = castle.attributes
		if (
			not Data.is_integer(attributes.get("integrity"))
			or not Data.is_integer(attributes.get("max_integrity"))
		):
			return {"legal": false, "reason": "castle_integrity_invalid"}
		return {
			"legal": attributes.integrity < attributes.max_integrity, "reason": "castle_not_damaged"
		}
	# Repair between declaration and firing does not cancel the original doom.
	return {"legal": true, "reason": ""}


func resolve(record: Dictionary, context: Dictionary) -> Dictionary:
	var world: Dictionary = context.world
	var entities = Ids.new()
	entities.restore(world.entities)
	var source: Dictionary = record.declaration
	var events: Array = []
	if source.power_id == PREDATOR:
		for ordinal in range(3):
			# Lord spawns move in this round's upcoming Step 12. Commitments
			# separately retain the audited birth-round movement hold.
			var attributes: Dictionary = Marching.profile(
				"Vulture", source.target.lane, source.player_id, context.round, context.round
			)
			attributes["source_effect_id"] = record.effect_id
			var created: Dictionary = entities.create(
				"marcher", record.effect_id, ordinal, source.player_id, attributes
			)
			if created.action == "invalid":
				return created
			var placed: Dictionary = Marching.place_spawn(entities, created.entity.id, context.seed)
			if placed.action == "invalid":
				return placed
			events.append({"type": "MARCHER_SPAWNED", "text": "", "data": placed.entity})
	else:
		var castle: Dictionary = entities.get_entity(source.target.entity_id)
		castle.attributes["integrity"] = 0
		castle.attributes["status"] = "defunct"
		entities.update(castle.id, castle.owner, castle.attributes)
		events.append(
			{
				"type": "CASTLE_DEFUNCT",
				"text": "",
				"data": {"castle_id": castle.id, "declaration_id": source.declaration_id}
			}
		)
	world.entities = entities.snapshot()
	return {"action": "resolved", "world": world, "events": events}


func accept_order(context: Dictionary) -> Dictionary:
	if _combat_enabled:
		return Combat.accept(context)
	if not context.order.is_empty():
		return Data.invalid("combat_orders_not_supported")
	if context.phase == "snapshot":
		return {"action": "legal"}
	return {"action": "resolved", "world": context.world, "events": []}


func on_hook(context: Dictionary) -> Dictionary:
	if _combat_enabled:
		return Combat.on_hook(context, Callable(self, "react"))
	var world: Dictionary = context.world
	var commands = [] if not _driver.is_valid() else _driver.call(context.duplicate(true))
	if typeof(commands) != TYPE_ARRAY or not Data.is_data(commands):
		return Data.invalid("battle_adapter_invalid")
	var events: Array = []
	for command in commands:
		if typeof(command) != TYPE_DICTIONARY:
			return Data.invalid("battle_command_invalid")
		var changed: Dictionary = Battle.apply(world, command, context.round, context.hook)
		if changed.action == "invalid":
			return changed
		world = changed.world
		var fact: Dictionary = changed.event
		events.append({"event": fact, "views": [fact, fact]})
		var reaction: Dictionary = react(world, fact, context.seed, context.player_order)
		if reaction.action == "invalid":
			return reaction
		world = reaction.world
		events.append_array(reaction.events)
	return {"action": "resolved", "world": world, "events": events}


static func react(
	raw: Dictionary, fact: Dictionary, seed_value: String, player_order: Array
) -> Dictionary:
	var world: Dictionary = raw.duplicate(true)
	var events: Array = []
	var details: Dictionary = fact.data
	var round_number: int = int(details.round)
	var ledger: Dictionary = world.data.get("gremory_triggers", {}).duplicate(true)
	var entities = Ids.new()
	entities.restore(world.entities)
	if fact.type == "GUARD_DEFEATED" and world.data.get("breach_lord", "") == "Gremory":
		if _take_trigger(ledger, "GemDagger", round_number):
			for player_id in player_order:
				var drawn: Dictionary = Cards.draw(
					world, player_id, seed_value, details.event_id + ":gem:" + str(player_id)
				)
				if drawn.action == "invalid":
					return drawn
				events.append(_draw_event("GEM_DAGGER", drawn))
	for player_id in player_order:
		var player: Dictionary = world.players[player_id]
		var lord: Dictionary = entities.get_entity(player.lord_entity_id)
		if player.lord_id != "Gremory" or not lord.attributes.get("alive", false):
			continue
		if (
			fact.type == "CASTLE_DESTROYED"
			and _take_trigger(ledger, "Sifting:" + str(player_id), round_number)
		):
			var drawn: Dictionary = Cards.draw(
				world, player_id, seed_value, details.event_id + ":sift:" + str(player_id), true
			)
			if drawn.action == "invalid":
				return drawn
			events.append(_draw_event("SIFTING_THE_RUINS", drawn))
		if (
			fact.type == "MARCHER_DEFEATED"
			and details.cause == "combat"
			and details.get("hook") == Timeline.MARCHING
		):
			var attacker: Dictionary = details.attacker
			if (
				attacker.get("owner") == player_id
				and attacker.attributes.get("suit") == "Vulture"
				and details.victim.owner == 1 - player_id
				and _take_trigger(ledger, "Bones:" + str(player_id), round_number)
			):
				var drawn: Dictionary = Cards.draw(
					world, player_id, seed_value, details.event_id + ":bones:" + str(player_id)
				)
				if drawn.action == "invalid":
					return drawn
				world.data.neutral_tears += 1
				events.append(_draw_event("PICKING_THE_BONES", drawn))
				var tear: Dictionary = {
					"type": "NEUTRAL_TEAR_CREATED",
					"text": "",
					"data": {"player_id": player_id, "amount": 1, "source": "PickingTheBones"}
				}
				events.append({"event": tear, "views": [tear, tear]})
	world.data["gremory_triggers"] = ledger
	return {"action": "resolved", "world": world, "events": events}


static func _take_trigger(ledger: Dictionary, key: String, round_number: int) -> bool:
	if ledger.get(key, 0) >= round_number:
		return false
	ledger[key] = round_number
	return true


static func _draw_event(event_type: String, drawn: Dictionary) -> Dictionary:
	var event: Dictionary = {"type": event_type, "text": "", "data": drawn.duplicate(true)}
	var public_event: Dictionary = event.duplicate(true)
	public_event.data.erase("card_id")
	var views: Array = [public_event, public_event]
	# Reclaimed discard identities were already public; ordinary draws are private.
	if event_type == "SIFTING_THE_RUINS":
		views = [event, event]
	else:
		views[int(drawn.player_id)] = event
	return {"event": event, "views": views}


func project(world: Dictionary, player_id: int) -> Dictionary:
	var zones: Dictionary = world.data.card_zones
	var visible: Array = []
	var committed: Array = zones.get("committed", [[], []])
	var revealed: bool = (
		int(world.data.get("combat_reveal_round", 0))
		> int(world.data.get("combat_cleanup_round", 0))
	)
	for entity in world.entities.entities:
		if (
			entity.kind != "card"
			or entity.attributes.get("role") == "guard"
			or entity.id in zones.hands[player_id]
			or entity.id in zones.discard
			or entity.id in zones.get("market", [])
			or entity.id in committed[player_id]
			or (revealed and entity.id in committed[1 - player_id])
		):
			visible.append(entity.duplicate(true))
	return {
		"entities": visible,
		"hand": zones.hands[player_id].duplicate(),
		"committed": committed[player_id].duplicate(),
		"sigils": world.data.get("sigils", []).duplicate(true),
		"opponent_hand_count":
		zones.hands[1 - player_id].size() + (0 if revealed else committed[1 - player_id].size()),
		"deck_count": zones.deck.size(),
		"discard": zones.discard.duplicate(),
		"neutral_tears": world.data.neutral_tears,
		"souls":
		[world.players[0].resources.get("souls", 0), world.players[1].resources.get("souls", 0)],
		"breach_lord": world.data.get("breach_lord", "")
	}
