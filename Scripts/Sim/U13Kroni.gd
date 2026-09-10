extends "res://Scripts/Sim/U13Odradek.gd"

const Hunger = preload("res://Scripts/Sim/U13KroniState.gd")
const Actors = preload("res://Scripts/Sim/U13KroniActors.gd")
const KRONI_POLICY: String = Hunger.VERSION
const CONSUME: String = "Consume"
const RAVENOUS: String = "Ravenous"
const KRONI_POWERS: Array = [CONSUME, RAVENOUS]


func create_combat_match():
	var validators: Dictionary = {}
	var resolvers: Dictionary = {}
	for power in rules():
		validators[power] = Callable(self, "validate")
		resolvers[power] = Callable(self, "resolve")
	return MatchOwner.new(KRONI_POLICY + ":" + ODRADEK_POLICY + ":" + POLICY, rules(), validators, resolvers, Callable(self, "project"), Callable(), Callable(self, "on_hook"), self, Callable(self, "valid_world"), Callable(self, "accept_order"), Callable(), Callable(Guards, "legal_orders"))


static func rules() -> Dictionary:
	var result: Dictionary = preload("res://Scripts/Sim/U13Odradek.gd").rules()
	for power in KRONI_POWERS:
		result[power] = {"lord_id": "Kroni", "fire_hook": Timeline.ROUND_START_SCHEDULED if power == CONSUME else Timeline.POST_RESOLUTION_SPECIAL_ACTORS, "cooldown_on": "activation", "cooldown_rounds": 0 if power == CONSUME else 2, "delay_rounds": 1 if power == CONSUME else 0, "cost": {}, "stages": [], "target_kind": "", "target_relation": "any", "visibility": "public"}
	return result


func valid_world(world: Dictionary) -> bool:
	return super.valid_world(world) and Hunger.valid(world) and Actors.valid(world.data.get("kroni_actors"))


static func kroni_target(power: String, target: Dictionary, pid: int = 0) -> bool:
	if power == RAVENOUS:
		return target.size() == 2 and target.get("lane") in ["Lord", "Castle"] and not preload("res://Scripts/Sim/U13SpatialSpace.gd").position(target.get("field_position")).is_empty() and int(target.field_position.x_fp) == (0 if pid == 0 else 2400)
	return target.size() == 1 and typeof(target.get("entity_id")) == TYPE_STRING and not target.entity_id.is_empty()


func validate(source: Dictionary, world: Dictionary, phase: String) -> Dictionary:
	if source.power_id not in KRONI_POWERS:
		return super.validate(source, world, phase)
	var legal: bool = source.parameters.is_empty() and kroni_target(source.power_id, source.target, int(source.player_id))
	if legal and source.power_id == CONSUME:
		var victim: Dictionary = Hunger.guard(world, source.target.entity_id)
		legal = not victim.is_empty() and victim.owner == 1 - int(source.player_id)
	return {"legal": legal, "reason": "kroni_target_unavailable"}


func resolve(record: Dictionary, context: Dictionary) -> Dictionary:
	var source: Dictionary = record.declaration
	if source.power_id not in KRONI_POWERS:
		return super.resolve(record, context)
	if record.fire_hook != rules()[source.power_id].fire_hook or context.get("hook", record.fire_hook) != record.fire_hook:
		return Data.invalid("kroni_hook_invalid")
	if not validate(source, context.world, "firing").legal:
		return Data.invalid("kroni_target_unavailable")
	var world: Dictionary = Data.copy_data(context.world)
	var events: Array = []
	var pid: int = source.player_id
	if source.power_id == CONSUME:
		var victim: Dictionary = Hunger.guard(world, source.target.entity_id)
		events.append(Hunger.devour_guard(world, victim, pid, context.round, CONSUME))
		events.append_array(Hunger.feed(world, pid, 1, context.round, CONSUME))
		world.data.kroni_fed[pid] = context.round
	else:
		var actor: Dictionary = Actors.create(source.declaration_id, pid, context.round, Hunger.hunger(world, pid), false, context.seed, source.target)
		world.data.kroni_actors.append(actor)
		events.append(Hunger.event("RAVENOUS_ARMED", {"actor": actor, "round": context.round, "hook": record.fire_hook}, "Ravenous: Kroni will cross the field during Marching."))
	return {"action": "resolved", "world": world, "events": events}


func on_hook(context: Dictionary) -> Dictionary:
	# Ward/Pass changes Defense before either player's combat resolves.
	var prepared: Dictionary = context.duplicate(true)
	prepared.world = Data.copy_data(context.world)
	var before_events: Array = []
	if context.hook == Timeline.COMBAT_RESOLUTION:
		if prepared.world.data.kroni_action_round >= context.round:
			return Data.invalid("kroni_action_already_applied")
		prepared.world.data.kroni_action_round = context.round
		for pid in context.player_order:
			var order: Dictionary = Guards.strip_order(context.combat_orders[pid])
			if Hunger.active(prepared.world, pid) and (order.is_empty() or order.get("action") == "Ward"):
				before_events.append_array(Hunger.feed(prepared.world, pid, -1, context.round, "Ward" if not order.is_empty() else "Pass"))
	var result: Dictionary = super.on_hook(prepared)
	if result.action == "invalid":
		return result
	result.events = before_events + result.events
	var world: Dictionary = result.world
	if context.hook == Timeline.ROUND_START_SCHEDULED:
		if world.data.kroni_feed_round >= context.round:
			return Data.invalid("kroni_feed_already_applied")
		world.data.kroni_feed_round = context.round
		world.data.kroni_actors = []
		for pid in context.player_order:
			if not Hunger.active(world, pid) or world.data.kroni_fed[pid] == context.round:
				continue
			var candidates: Array = []
			for row in world.entities.entities:
				if row.kind == "card" and row.owner == pid and row.attributes.get("role") == "guard":
					candidates.append(row)
			candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.attributes.value < b.attributes.value if a.attributes.value != b.attributes.value else a.id < b.id)
			if candidates.is_empty():
				result.events.append_array(Hunger.feed(world, pid, -1, context.round, "Cannibal Hunger"))
			else:
				result.events.append(Hunger.devour_guard(world, candidates[0], pid, context.round, "Cannibal Hunger"))
	elif context.hook == Timeline.MARCHING_START:
		if world.data.kroni_breach_round >= context.round:
			return Data.invalid("kroni_breach_already_applied")
		world.data.kroni_breach_round = context.round
		if world.data.breach_lord == "Kroni":
			var identity: String = Data.instance_id("insatiable", str(context.round), "breach")
			var actor: Dictionary = Actors.create(identity, -1, context.round, 0, true, context.seed)
			world.data.kroni_actors.append(actor)
			result.events.append(Hunger.event("INSATIABLE_HUNGER_MANIFESTED", {"actor": actor, "round": context.round}, "Insatiable Hunger manifests in the field."))
	elif context.hook == Timeline.MARCHING:
		for actor in world.data.kroni_actors:
			if not actor.breach and actor.consumed >= 6 and not actor.rewarded:
				actor.rewarded = true
				world.players[actor.owner].resources.souls += 1
				world.data.neutral_tears += 1
				result.events.append_array(Hunger.feed(world, actor.owner, 1, context.round, RAVENOUS))
				result.events.append(Hunger.event("RAVENOUS_REWARDED", {"actor_id": actor.id, "player_id": actor.owner, "round": context.round, "consumed": actor.consumed, "souls": 1, "hunger": 1, "neutral_tears": 1}, "Ravenous: +1 Soul, +1 Hunger, +1 Neutral Tear."))
	return result


func project(world: Dictionary, player_id: int) -> Dictionary:
	var result: Dictionary = super.project(world, player_id)
	result["kroni_profile"] = KRONI_POLICY
	result["hunger"] = [Hunger.hunger(world, 0), Hunger.hunger(world, 1)]
	return result


func accept_order(context: Dictionary) -> Dictionary:
	var result: Dictionary = super.accept_order(context)
	if result.action == "invalid" or context.phase != "snapshot":
		return result
	for pair in [["kroni_feed_round", Timeline.ROUND_START_SCHEDULED], ["kroni_action_round", Timeline.COMBAT_RESOLUTION], ["kroni_breach_round", Timeline.MARCHING_START]]:
		var expected: int = context.round if context.next_hook_index > Timeline.hook_rank(pair[1]) else context.round - 1
		if context.world.data[pair[0]] != expected:
			return Data.invalid("kroni_clock_invalid")
	for pending in context.pending_effects:
		var source: Dictionary = pending.declaration
		if source.power_id in KRONI_POWERS and (pending.effect_key != "main" or not pending.payload.is_empty() or not source.parameters.is_empty() or not kroni_target(source.power_id, source.target, int(source.player_id))):
			return Data.invalid("kroni_pending_invalid")
	for stamp in context.world.data.kroni_fed:
		if stamp > context.world.data.kroni_feed_round:
			return Data.invalid("kroni_feeding_clock_invalid")
	for actor in context.world.data.kroni_actors:
		if actor.round != (context.round - 1 if context.next_hook_index == 0 else context.round):
			return Data.invalid("kroni_actor_round_invalid")
	return result
