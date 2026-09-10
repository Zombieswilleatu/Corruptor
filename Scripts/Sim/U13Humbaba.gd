extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const MatchOwner = preload("res://Scripts/Sim/U13Match.gd")
const Deimos = preload("res://Scripts/Sim/U13Deimos.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Construction = preload("res://Scripts/Sim/U13Construction.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const Rout = preload("res://Scripts/Sim/U13Rout.gd")
const Stats = preload("res://Scripts/Sim/U13LordStats.gd")
const LaneAuras = preload("res://Scripts/Sim/U13LaneAuras.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const MUSTER: String = "MusterTheFaithful"
const BREATH: String = "BreathOfLife"
const POLICY: String = Stats.HUMBABA_PROFILE
var _deimos = Deimos.new(true, true, true)


func create_combat_match():
	var validators: Dictionary = {}
	var resolvers: Dictionary = {}
	for power in rules():
		validators[power] = Callable(self, "validate")
		resolvers[power] = Callable(self, "resolve")
	return MatchOwner.new(
		(
			POLICY
			+ ":"
			+ Deimos.POLICY
			+ ":"
			+ Structures.PROFILE
			+ ":"
			+ Marching.VERSION
			+ ":"
			+ Construction.VERSION
			+ ":"
			+ Slots.VERSION
			+ ":"
			+ Rout.VERSION
			+ ":"
			+ Combat.HUNT_VERSION
			+ ":"
			+ LaneAuras.VERSION
		),
		rules(),
		validators,
		resolvers,
		Callable(self, "project"),
		Callable(),
		Callable(self, "on_hook"),
		self,
		Callable(self, "valid_world"),
		Callable(self, "accept_order"),
		Callable(Construction, "screen_orders"),
		Callable(Construction, "legal_orders")
	)


static func rules() -> Dictionary:
	var result: Dictionary = Deimos.rules()
	result[MUSTER] = {
		"lord_id": "Humbaba",
		"fire_hook": Timeline.POST_RESOLUTION_SPAWNS,
		"cooldown_on": "activation",
		"cooldown_rounds": 1,
		"delay_rounds": 0,
		"cost": {},
		"stages": [],
		"target_kind": "",
		"target_relation": "own",
		"visibility": "public"
	}
	result[BREATH] = {
		"lord_id": "Humbaba",
		"fire_hook": Timeline.POST_RESOLUTION_MOVEMENT_STATE,
		"cooldown_on": "expiration",
		"cooldown_rounds": 2,
		"delay_rounds": 0,
		"cost": {},
		"stages": [{"active": true}, {"active": true}],
		"target_kind": "",
		"target_relation": "own",
		"visibility": "public",
		"lane_aura": {"regen_bonus": 1, "speed_percent": 25}
	}
	return result


func valid_world(world: Dictionary, allow_kalligan: bool = false) -> bool:
	if world.data.has("kalligan_profile") and not allow_kalligan:
		return false
	if (
		world.data.get("humbaba_profile") != POLICY
		or not LaneAuras.enabled(world)
		or not _deimos.valid_world(world, true)
	):
		return false
	var checked = world.data.get("humbaba_end_round")
	var entries = world.data.get("humbaba_breach_entries")
	if not Data.is_integer(checked) or checked < 0 or typeof(entries) != TYPE_DICTIONARY:
		return false
	for key in entries:
		if (
			key.is_empty()
			or not Data.is_integer(entries[key])
			or entries[key] < 1
			or not world.data.get("battle_commands", {}).has(key)
		):
			return false
	for lord in world.entities.entities:
		if lord.kind == "lord" and lord.attributes.get("lord_id") == "Humbaba":
			if lord.attributes.has("threat"):
				return false
	return true


func accept_order(context: Dictionary) -> Dictionary:
	if context.phase == "snapshot":
		if not LaneAuras.snapshot_valid(context, rules()):
			return Data.invalid("lane_aura_snapshot_invalid")
		var completed: int = (
			context.round
			if context.next_hook_index > Timeline.hook_rank(Timeline.END_MARCHING_CHECKS)
			else context.round - 1
		)
		if context.world.data.humbaba_end_round != completed:
			return Data.invalid("humbaba_end_ledger_wrong_phase")
		for entry_id in context.world.data.humbaba_breach_entries:
			var round_number: int = context.world.data.humbaba_breach_entries[entry_id]
			var debug_entries = context.world.data.get("debug_breach_entries", {})
			var debug_entry: bool = typeof(debug_entries) == TYPE_DICTIONARY and debug_entries.get(entry_id) == round_number and round_number <= context.round
			if round_number > context.world.data.get("combat_resolved_round", 0) and not debug_entry:
				return Data.invalid("humbaba_breach_ledger_ahead")
	return _deimos.accept_order(context)


func validate(source: Dictionary, world: Dictionary, phase: String) -> Dictionary:
	if source.power_id not in [MUSTER, BREATH]:
		return _deimos.validate(source, world, phase)
	return {
		"legal":
		(
			source.target.size() == 1
			and source.target.get("lane") in Marching.LANES
			and source.parameters.is_empty()
		),
		"reason": "humbaba_lane_invalid"
	}


func resolve(record: Dictionary, context: Dictionary) -> Dictionary:
	if record.declaration.power_id == BREATH:
		return LaneAuras.activate(record, context, rules()[BREATH].lane_aura)
	if record.declaration.power_id != MUSTER:
		return _deimos.resolve(record, context)
	var world: Dictionary = context.world.duplicate(true)
	var entities = Ids.new()
	entities.restore(world.entities)
	var source: Dictionary = record.declaration
	var events: Array = []
	for ordinal in range(3):
		var attributes: Dictionary = Marching.profile(
			"Penitent", source.target.lane, source.player_id, context.round, context.round
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
	world.entities = entities.snapshot()
	return {"action": "resolved", "world": world, "events": events}


func on_hook(context: Dictionary, reaction: Callable = Callable()) -> Dictionary:
	var handler: Callable = reaction if reaction.is_valid() else Callable(self, "react")
	if context.hook == Timeline.PERSISTENT_ADVANCEMENT:
		return Rout.advance(context)
	if context.hook == Timeline.DEVELOPMENT:
		return Construction.resolve(context)
	if context.hook == Timeline.POST_REPAIR_ARTILLERY:
		return Structures.normal_fire(context, handler)
	if context.hook == Timeline.END_MARCHING_CHECKS:
		return endurance(context)
	var ordinary: Dictionary = context.duplicate(true)
	ordinary.combat_orders = [
		Construction.combat_order(context.combat_orders[0]),
		Construction.combat_order(context.combat_orders[1])
	]
	var result: Dictionary = Combat.on_hook(ordinary, handler)
	if result.action != "invalid" and context.hook == Timeline.AFTERMATH:
		result.world.data.castle_orders = [null, null]
	return result


static func endurance(context: Dictionary) -> Dictionary:
	if context.hook != Timeline.END_MARCHING_CHECKS:
		return Data.invalid("endurance_wrong_hook")
	var world: Dictionary = context.world.duplicate(true)
	if world.data.humbaba_end_round >= context.round:
		return Data.invalid("endurance_already_checked")
	var entities = Ids.new()
	entities.restore(world.entities)
	var events: Array = []
	for player_id in context.player_order:
		var player: Dictionary = world.players[player_id]
		if player.lord_id != "Humbaba":
			continue
		var lord: Dictionary = entities.get_entity(player.lord_entity_id)
		var qualifying: Array = []
		for unit in entities.snapshot().entities:
			if (
				unit.kind == "marcher"
				and unit.owner == player_id
				and unit.attributes.suit == "Penitent"
				and unit.attributes.hp == 1
			):
				qualifying.append(unit.id)
		var met: bool = lord.attributes.alive and not qualifying.is_empty()
		events.append(
			Structures.public_event(
				"ENDURANCE_CHECKED",
				{
					"player_id": player_id,
					"round": context.round,
					"threshold_met": met,
					"lord_alive": lord.attributes.alive,
					"qualifying_ids": qualifying
				}
			)
		)
		if met:
			world.data.neutral_tears += 1
			events.append(
				Structures.public_event(
					"NEUTRAL_TEAR_CREATED",
					{
						"player_id": player_id,
						"round": context.round,
						"amount": 1,
						"source": "EnduranceOfTheFaithful"
					}
				)
			)
	world.data.humbaba_end_round = context.round
	return {"action": "resolved", "world": world, "events": events}


func react(
	raw: Dictionary, fact: Dictionary, seed_value: String, player_order: Array
) -> Dictionary:
	var changed: Dictionary = _deimos.react(raw, fact, seed_value, player_order)
	if (
		changed.action == "invalid"
		or fact.type != "BREACH_CHANGED"
		or fact.data.lord_id != "Humbaba"
	):
		return changed
	var world: Dictionary = changed.world
	var events: Array = changed.events
	var entry_id: String = fact.data.event_id
	if world.data.humbaba_breach_entries.has(entry_id):
		return changed
	if not world.data.get("battle_commands", {}).has(entry_id):
		return Data.invalid("stones_forget_requires_breach_fact")
	var entities = Ids.new()
	entities.restore(world.entities)
	var source: Dictionary = entities.get_entity(String(fact.data.get("source_id", "")))
	if (
		source.is_empty()
		or source.kind != "lord"
		or source.attributes.get("lord_id") != "Humbaba"
		or source.attributes.get("alive", true)
	):
		return Data.invalid("stones_forget_source_missing")
	world.data.humbaba_breach_entries[entry_id] = fact.data.round
	var targets: Array = []
	for castle in entities.snapshot().entities:
		if Structures.targetable(castle) and castle.attributes.integrity > 0:
			targets.append(castle.id)
	targets.sort()
	for castle_id in targets:
		var damaged: Dictionary = Structures.breach_damage(
			world,
			castle_id,
			source.id,
			4,
			entry_id,
			{
				"round": fact.data.round,
				"hook": fact.data.hook,
				"seed": seed_value,
				"player_order": player_order
			},
			Callable(self, "react")
		)
		if damaged.action == "invalid":
			return damaged
		world = damaged.world
		events.append_array(damaged.events)
	events.append(
		Structures.public_event(
			"THE_STONES_FORGET",
			{
				"source_id": source.id,
				"entry_id": entry_id,
				"round": fact.data.round,
				"castle_ids": targets,
				"damage_per_castle": 4
			}
		)
	)
	return {"action": "resolved", "world": world, "events": events}


func project(world: Dictionary, player_id: int) -> Dictionary:
	var view: Dictionary = _deimos.project(world, player_id)
	view["humbaba_profile"] = POLICY
	var stats: Array = [{}, {}]
	for lord in world.entities.entities:
		if lord.kind == "lord" and lord.owner in [0, 1]:
			stats[lord.owner] = {
				"threat": Stats.threat_value(lord),
				"defense": Stats.defense(world, lord),
				"standing_castles": Stats.standing_castles(world, lord.owner)
			}
	view["lord_stats"] = stats
	return view
