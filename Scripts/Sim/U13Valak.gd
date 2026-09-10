extends "res://Scripts/Sim/U13Kroni.gd"

const Essence = preload("res://Scripts/Sim/U13ValakState.gd")
const Orbs = preload("res://Scripts/Sim/U13GravityOrbs.gd")
const PROJECTION: String = "Projection"
const ORB: String = "GravityOrb"
const VALAK_POWERS: Array = [PROJECTION, ORB]


func create_combat_match():
	var validators: Dictionary = {}
	var resolvers: Dictionary = {}
	for power in rules():
		validators[power] = Callable(self, "validate")
		resolvers[power] = Callable(self, "resolve")
	return MatchOwner.new(Essence.VERSION + ":" + KRONI_POLICY + ":" + ODRADEK_POLICY + ":" + POLICY, rules(), validators, resolvers, Callable(self, "project"), Callable(), Callable(self, "on_hook"), self, Callable(self, "valid_world"), Callable(self, "accept_order"), Callable(), Callable(Guards, "legal_orders"))


static func rules() -> Dictionary:
	var result: Dictionary = preload("res://Scripts/Sim/U13Kroni.gd").rules()
	result[PROJECTION] = {"lord_id": "Valak", "fire_hook": Timeline.POST_RESOLUTION_DIRECT, "cooldown_on": "activation", "cooldown_rounds": 0, "delay_rounds": 0, "cost": {}, "stages": [], "target_kind": "", "target_relation": "any", "visibility": "public"}
	result[ORB] = {"lord_id": "Valak", "fire_hook": Timeline.POST_RESOLUTION_HAZARDS, "cooldown_on": "expiration", "cooldown_rounds": 2, "delay_rounds": 0, "cost": {}, "stages": [{"name": "active"}, {"name": "active"}], "target_kind": "", "target_relation": "any", "visibility": "public"}
	return result


func valid_world(world: Dictionary) -> bool:
	return super.valid_world(world) and Essence.valid(world) and Orbs.valid(world.data.get("valak_orbs"))


static func projection_shape(source: Dictionary) -> bool:
	var target: Dictionary = source.target
	return target.size() == 3 and target.get("kind") == "guard_zone" and target.get("zone") in ["Lord", "Castle"] and Data.is_integer(target.get("player_id")) and target.player_id == 1 - int(source.player_id) and source.parameters.size() == 1 and Data.is_integer(source.parameters.get("spend")) and source.parameters.spend >= 1 and source.parameters.spend <= Essence.CAP


func validate(source: Dictionary, world: Dictionary, phase: String) -> Dictionary:
	if source.power_id == ORB:
		return {"legal": Fields.target_valid(source.target) and source.parameters.is_empty(), "reason": "gravity_orb_target_invalid"}
	if source.power_id != PROJECTION:
		return super.validate(source, world, phase)
	var legal: bool = projection_shape(source)
	if legal and phase == "declaration":
		legal = source.parameters.spend <= world.players[source.player_id].resources[Essence.RESOURCE]
	return {"legal": legal, "reason": "projection_zone_or_essence_invalid"}


func resolve(record: Dictionary, context: Dictionary) -> Dictionary:
	var source: Dictionary = record.declaration
	if source.power_id not in VALAK_POWERS:
		return super.resolve(record, context)
	if record.fire_hook != rules()[source.power_id].fire_hook:
		return Data.invalid("valak_hook_invalid")
	var world: Dictionary = Data.copy_data(context.world)
	var pid: int = source.player_id
	if source.power_id == ORB:
		var orb: Dictionary = Orbs.create(source, context.round)
		world.data.valak_orbs.append(orb)
		return {"action": "resolved", "world": world, "events": [Essence.event("GRAVITY_ORB_STARTED", orb)], "persistent_payload": {"gravity_orb": true}}
	var spend: int = source.parameters.spend
	if world.data.valak_reserved[pid] != spend:
		return Data.invalid("projection_reservation_missing")
	var before: int = world.players[pid].resources[Essence.RESOURCE] + spend
	world.data.valak_reserved[pid] = 0
	var guards: Array = []
	for row in world.entities.entities:
		if row.kind == "card" and row.owner == source.target.player_id and row.attributes.get("role") == "guard" and row.attributes.get("lane") == source.target.zone and row.attributes.value <= spend:
			guards.append(row)
	guards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.attributes.value > b.attributes.value if a.attributes.value != b.attributes.value else (a.attributes.slot < b.attributes.slot if a.attributes.slot != b.attributes.slot else a.id < b.id))
	var events: Array = []
	var victim: Dictionary = {} if guards.is_empty() else guards[0]
	if not victim.is_empty():
		var hit: Dictionary = Battle.apply(world, {"command_id": Data.instance_id("projection", source.declaration_id, victim.id), "kind": "defeat_guard", "target_id": victim.id}, context.round, record.fire_hook)
		if hit.action == "invalid":
			return hit
		var reacted: Dictionary = react(hit.world, hit.event, context.seed, context.player_order)
		if reacted.action == "invalid":
			return reacted
		world = reacted.world
		events.append({"event": hit.event, "views": [hit.event, hit.event]})
		events.append_array(reacted.events)
	events.append(Essence.event("VALAK_PROJECTION_RESOLVED", {"player_id": pid, "target": source.target, "spend": spend, "before": before, "after": world.players[pid].resources[Essence.RESOURCE], "victim": victim, "whiff": victim.is_empty(), "round": context.round}))
	return {"action": "resolved", "world": world, "events": events}


func react(raw: Dictionary, fact: Dictionary, seed_value: String, player_order: Array) -> Dictionary:
	var result: Dictionary = super.react(raw, fact, seed_value, player_order)
	if result.action == "invalid" or fact.type != "GUARD_DEFEATED" or fact.data.get("hook") != Timeline.COMBAT_RESOLUTION or fact.data.get("attack_kind") not in ["Hunt", "Siege"] or not fact.data.has("attacker"):
		return result
	var pid: int = fact.data.attacker.owner
	if Essence.active(result.world, pid) and fact.data.guard.owner == 1 - pid:
		result.events.append(Essence.gain(result.world, pid, fact.data.guard, fact.data.round))
	return result


func on_hook(context: Dictionary) -> Dictionary:
	var result: Dictionary = super.on_hook(context)
	if result.action == "invalid":
		return result
	if context.hook == Timeline.PERSISTENT_ADVANCEMENT:
		var active_ids: Array = []
		for active in context.persistent_effects:
			if active.declaration.power_id == ORB:
				active_ids.append(active.effect_id)
		result.world.data.valak_orbs = result.world.data.valak_orbs.filter(func(orb: Dictionary) -> bool: return orb.id in active_ids)
	return result


func project(world: Dictionary, player_id: int) -> Dictionary:
	var result: Dictionary = super.project(world, player_id)
	result["life_essence"] = [world.players[0].resources[Essence.RESOURCE] + world.data.valak_reserved[0], world.players[1].resources[Essence.RESOURCE] + world.data.valak_reserved[1]]
	result["valak_orbs"] = world.data.valak_orbs.duplicate(true)
	return result


func accept_order(context: Dictionary) -> Dictionary:
	var result: Dictionary = super.accept_order(context)
	if result.action == "invalid":
		return result
	if context.phase != "snapshot":
		for source in context.declarations:
			if source.power_id != PROJECTION:
				continue
			var spend: int = source.parameters.spend
			var pid: int = source.player_id
			if result.world.players[pid].resources[Essence.RESOURCE] < spend or result.world.data.valak_reserved[pid] != 0:
				return Data.invalid("projection_essence_unavailable")
			result.world.players[pid].resources[Essence.RESOURCE] -= spend
			result.world.data.valak_reserved[pid] = spend
		return result
	var expected: Array = [0, 0]
	for pending in context.pending_effects:
		var source: Dictionary = pending.declaration
		if source.power_id not in VALAK_POWERS:
			continue
		if not pending.payload.is_empty() or pending.effect_key != "main" or not validate(source, context.world, "firing").legal:
			return Data.invalid("valak_pending_invalid")
		if source.power_id == PROJECTION:
			expected[source.player_id] += int(source.parameters.spend)
	if context.world.data.valak_reserved != expected:
		return Data.invalid("projection_reservation_invalid")
	var ids: Array = []
	for active in context.persistent_effects:
		if active.declaration.power_id != ORB:
			continue
		if active.effect_key != ORB or active.activated_round != active.declaration.declared_round or not active.declaration.parameters.is_empty() or active.stages != rules()[ORB].stages or active.payload != {"gravity_orb": true} or active.target != active.declaration.target or not Fields.target_valid(active.target):
			return Data.invalid("gravity_orb_lifetime_invalid")
		var bound: bool = false
		for clock in context.cooldown_locks:
			if clock.persistent_effect_id == active.effect_id:
				bound = clock.phase == "awaiting_expiration" and clock.declaration == active.declaration and clock.cooldown_rounds == 2
		if not bound:
			return Data.invalid("gravity_orb_cooldown_invalid")
		var matched: bool = false
		for orb in context.world.data.valak_orbs:
			if orb.id == active.effect_id and orb.owner == active.declaration.player_id and orb.target == active.target and orb.round == active.activated_round:
				matched = true
		if not matched:
			return Data.invalid("gravity_orb_ledger_missing")
		ids.append(active.effect_id)
	for orb in context.world.data.valak_orbs:
		if orb.id not in ids:
			return Data.invalid("gravity_orb_registry_missing")
	return result
