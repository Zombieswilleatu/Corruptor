extends SceneTree

const Content = preload("res://Scripts/Sim/U13Valak.gd")
const Scenario = preload("res://Scripts/Sim/U13ValakScenario.gd")
const Session = preload("res://Scripts/Sim/U13LoadoutBoardSession.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Buffer = preload("res://Scripts/Sim/U13MarchingBuffer.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, title: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + title)
	return ok

func _run() -> void:
	var content = Content.new()
	var world: Dictionary = Scenario.world()
	check(content.valid_world(world), "Valak initial world valid")
	for lord in ["Gremory", "Deimos", "Humbaba", "Kalligan", "Orias", "Odradek", "Kroni", "Valak"]:
		var session = Session.new()
		var result: Dictionary = session.configure(["Valak", lord], world.data.castle_loadouts, true)
		if check(result.action != "invalid", "configure Valak / " + lord + str(result)):
			check(Session.new().restore_checkpoint(session.checkpoint()).action != "invalid", "restore " + lord)
	_essence()
	_projection()
	_combat()
	_orbs()
	_collapse()
	_gravity_match()
	_match()
	print("U13 Valak checks: %d/%d; failures: %d" % [checks - failures, checks, failures])
	print("U13 Valak failures: %d" % failures)
	quit(0 if failures == 0 else 1)

func _essence() -> void:
	var world: Dictionary = Scenario.world()
	world.players[0].resources.life_essence = 4
	Content.Essence.gain(world, 0, {}, 1)
	check(world.players[0].resources.life_essence == 5, "Essence caps at five")
	var result: Dictionary = Content.Essence.reinforce(world, 0, 2, 1)
	check(result.spent == 2 and world.players[0].resources.life_essence == 3, "Hunt reinforcement consumes only incoming strength")
	world.data.valak_reserved[0] = 2
	Content.Essence.gain(world, 0, {}, 1)
	check(world.players[0].resources.life_essence == 3, "reserved shot still occupies capacity")
	result = Content.Essence.reinforce(world, 0, 9, 1)
	check(result.spent == 3 and world.data.valak_reserved[0] == 2, "Hunt cannot consume reserved Projection")

func _projection() -> void:
	var content = Content.new()
	for zone in ["Lord", "Castle"]:
		var world: Dictionary = Scenario.world()
		world.players[0].resources.life_essence = 5
		var source: Dictionary = Scenario.source(0, 1, {"kind": "guard_zone", "player_id": 1, "zone": zone}, 0, Content.PROJECTION, 3)
		check(content.validate(source, world, "declaration").legal, "Projection accepts enemy " + zone + " zone")
		var bad: Dictionary = source.duplicate(true)
		bad.target = {"lane": zone}
		check(not content.validate(bad, world, "declaration").legal, "Projection rejects marching lane")
		bad = source.duplicate(true)
		bad.target.player_id = 0
		check(not content.validate(bad, world, "declaration").legal, "Projection rejects own zone")
		world.players[0].resources.life_essence = 2
		check(not content.validate(source, world, "declaration").legal, "cannot declare unowned Essence")
		world.data.valak_reserved[0] = 3
		for row in world.entities.entities:
			if row.kind == "card" and row.owner == 1 and row.attributes.get("role") == "guard":
				row.attributes.lane = zone
		var guards: Array = world.entities.entities.filter(func(row: Dictionary) -> bool: return row.kind == "card" and row.owner == 1 and row.attributes.get("role") == "guard" and row.attributes.lane == zone)
		if not check(not guards.is_empty(), "guard fixture " + zone):
			continue
		guards[0].attributes.value = 3
		var target_id: String = guards[0].id
		for i in range(1, guards.size()):
			guards[i].attributes.value = 5
		var record: Dictionary = {"declaration": source, "fire_hook": Timeline.POST_RESOLUTION_DIRECT}
		var ctx: Dictionary = {"world": world, "round": 1, "seed": "valak-test", "player_order": [0, 1]}
		var result: Dictionary = content.resolve(record, ctx)
		if check(result.action == "resolved", "Projection resolves " + zone + str(result.get("reason", ""))):
			var event: Dictionary = result.events.back().event
			check(event.data.victim.id == target_id, "equality defeats highest qualifying Guard")
			check(result.world.players[0].resources.life_essence == 2 and result.world.data.valak_reserved[0] == 0, "Projection spends reserved amount without refund")
			check(content.valid_world(result.world), "Projection preserves world invariants")
		for guard in guards:
			guard.attributes.value = 5
		result = content.resolve(record, ctx)
		check(result.action == "resolved" and result.events.back().event.data.whiff and result.world.data.valak_reserved[0] == 0, "whiff still spends Essence")
		for guard in guards:
			guard.attributes.lane = "Castle" if zone == "Lord" else "Lord"
		for row in world.entities.entities:
			if row.kind == "lord" and row.owner == 0:
				row.attributes.alive = false
		result = content.resolve(record, ctx)
		check(result.action == "resolved" and result.events.back().event.data.whiff and result.world.data.valak_reserved[0] == 0, "armed Projection survives banishment, empty zone never retargets")

func _orbs() -> void:
	var world: Dictionary = Scenario.world()
	var ids = Content.Ids.new()
	ids.restore(world.entities)
	for index in range(6):
		var a: Dictionary = Marching.profile("Butcher", "Lord" if index < 5 else "Castle", index % 2, 0, 1)
		a.x_fp = 1200
		a.y_fp = 300
		ids.create("marcher", "valak-test", index, index % 2, a)
	var buffer = Buffer.new()
	buffer.restore(ids.snapshot())
	var source: Dictionary = Scenario.source(0, 1, {"lane": "Lord", "field_position": {"x_fp": 1200, "y_fp": 300}})
	var orbs: Array = [Content.Orbs.create(source, 1)]
	var events: Array = Content.Orbs.step(orbs, buffer, buffer.marchers(), 1, 0)
	check(events.size() == 5 and buffer.marchers().size() == 1, "Orb destroys both sides, stays in its lane")
	var tears: int = 0
	for event in events:
		tears += event.event.data.neutral_tears
	check(tears == 1 and orbs[0].rewarded, "four kills pay exactly one neutral Tear")
	check(Content.Orbs.valid(orbs), "Orb kill ledger valid")
	check(Content.Orbs._touches({"x_fp": 1000, "y_fp": 300}, {"x_fp": 1400, "y_fp": 300}, source.target.field_position), "swept collision prevents tunneling")
	check(not Content.Orbs._touches({"x_fp": 1000, "y_fp": 500}, {"x_fp": 1400, "y_fp": 500}, source.target.field_position), "off-axis passage does not touch Orb")
	var spare: Dictionary = buffer.marchers()[0]
	spare.attributes.lane = "Lord"
	spare.attributes.x_fp = 1400
	buffer.update(spare.id, spare.owner, spare.attributes)
	var after: Array = Content.Orbs.step(orbs, buffer, buffer.marchers(), 1, 1)
	check(after.is_empty() and buffer.get_entity(spare.id).attributes.x_fp < 1400, "Orb attracts a later entrant without capture-at-cast")
	spare.attributes.x_fp = 1200
	buffer.update(spare.id, spare.owner, spare.attributes)
	after = Content.Orbs.step(orbs, buffer, buffer.marchers(), 2, 0)
	check(after.size() == 1 and after[0].event.data.neutral_tears == 0, "Orb reward cannot repeat next round")

func _combat() -> void:
	var content = Content.new()
	for action in ["Hunt", "Siege"]:
		var world: Dictionary = Scenario.world()
		var target: String = world.players[1].lord_entity_id
		for row in world.entities.entities:
			if row.kind == "card" and row.owner == 1 and row.attributes.get("role") == "guard":
				row.attributes.lane = "Lord" if action == "Hunt" else "Castle"
				row.attributes.value = 1
			if row.kind == "castle" and row.owner == 1:
				row.attributes.status = "standing"
				row.attributes.integrity = 12
				row.attributes.construction_state = "active"
				if action == "Siege":
					target = row.id
		var order: Dictionary = {"action": action, "lane": "Lord" if action == "Hunt" else "Castle", "target_id": target, "card_ids": world.data.card_zones.hands[0].duplicate()}
		var ctx: Dictionary = {"world": world, "round": 1, "hook": Timeline.COMBAT_RESOLUTION, "seed": "valak-combat", "player_order": [0, 1], "combat_orders": [order, {}]}
		var result: Dictionary = preload("res://Scripts/Sim/U13Combat.gd")._resolve(ctx, Callable(content, "react"))
		if check(result.action != "invalid", action + " resolves credited combat"):
			var gains: Array = result.events.filter(func(row: Dictionary) -> bool: return row.event.type == "VALAK_ESSENCE_GAINED")
			check(not gains.is_empty() and result.world.players[0].resources.life_essence == mini(5, gains.size() * 2), action + " guard defeats supply capped Essence")
			check(content.valid_world(result.world), action + " result stays valid")
	# A full Ward screens the attack before Essence is consulted.
	var world: Dictionary = Scenario.world()
	world.players[0].resources.life_essence = 5
	var ids = Content.Ids.new()
	ids.restore(world.entities)
	var attack_id: String = world.data.card_zones.hands[1][0]
	var attack_card: Dictionary = ids.get_entity(attack_id)
	attack_card.attributes.value = 1
	ids.update(attack_id, 1, attack_card.attributes)
	world.entities = ids.snapshot()
	var ward: Dictionary = {"action": "Ward", "lane": "Lord", "card_ids": world.data.card_zones.hands[0].duplicate()}
	var hunt: Dictionary = {"action": "Hunt", "lane": "Lord", "target_id": world.players[0].lord_entity_id, "card_ids": [attack_id]}
	var ctx: Dictionary = {"world": world, "round": 1, "hook": Timeline.COMBAT_RESOLUTION, "seed": "valak-ward", "player_order": [0, 1], "combat_orders": [ward, hunt]}
	var result: Dictionary = preload("res://Scripts/Sim/U13Combat.gd")._resolve(ctx, Callable(content, "react"))
	check(result.action != "invalid" and result.world.players[0].resources.life_essence == 5, "normal Ward protects Essence from unnecessary spending")
	ctx.combat_orders[0] = {}
	result = preload("res://Scripts/Sim/U13Combat.gd")._resolve(ctx, Callable(content, "react"))
	check(result.action != "invalid" and result.world.players[0].resources.life_essence < 5 and result.events.any(func(row: Dictionary) -> bool: return row.event.type == "VALAK_ESSENCE_REINFORCED"), "unwarded Hunt consumes Essence in actual combat")

func _collapse() -> void:
	var content = Content.new()
	var world: Dictionary = Scenario.world()
	var ids = Content.Ids.new()
	ids.restore(world.entities)
	var identity: String = ids.create("marcher", "collapse-test", 0, 0, Marching.profile("Butcher", "Lord", 0, 0, 1)).entity.id
	world.entities = ids.snapshot()
	var ctx: Dictionary = {"world": world, "round": 1, "hook": Timeline.MARCHING, "seed": "valak-collapse", "player_order": [0, 1], "combat_orders": [{}, {}], "persistent_effects": []}
	var normal: Dictionary = Marching.resolve(ctx, Callable(content, "react"))
	ctx.world.data.breach_lord = "Valak"
	var slowed: Dictionary = Marching.resolve(ctx, Callable(content, "react"))
	if check(normal.action != "invalid" and slowed.action != "invalid", "Breach movement resolves"):
		var a = Content.Ids.new()
		var b = Content.Ids.new()
		a.restore(normal.world.entities)
		b.restore(slowed.world.entities)
		check(a.get_entity(identity).attributes.x_fp == 2 * b.get_entity(identity).attributes.x_fp, "Gravitational Collapse halves actual lane travel")
	check(preload("res://Scripts/Sim/U13LaneAuras.gd").speed(4, 0, false, 0, true, true) == 1, "Web and Collapse compose to quarter speed")

func _match() -> void:
	var owner = Content.new().create_combat_match()
	var world: Dictionary = Scenario.world()
	world.players[0].resources.life_essence = 5
	if not check(owner.start("valak-lifetime", world, [0, 1]).action != "invalid", "match starts"):
		return
	for round_number in range(1, 6):
		while owner.next_hook() != Timeline.SUBMISSION_LOCK:
			var result: Dictionary = owner.run_next_hook()
			if not check(result.action != "invalid", "round %d opening %s" % [round_number, str(result)]):
				return
		var powers: Array = []
		var orb_source: Dictionary = Scenario.source(0, round_number, {"lane": "Lord", "field_position": {"x_fp": 1200, "y_fp": 300}})
		check((owner.preview_submission(0, [orb_source]).action != "invalid") == (round_number in [1, 5]), "Orb unavailable while active and during two cooldown rounds")
		if round_number == 1:
			powers = [Scenario.source(0, 1, {"lane": "Lord", "field_position": {"x_fp": 1200, "y_fp": 300}}), Scenario.source(0, 1, {"kind": "guard_zone", "player_id": 1, "zone": "Lord"}, 1, Content.PROJECTION, 2)]
		check(owner.submit(0, powers).action != "invalid", "submit Valak round %d" % round_number)
		check(owner.submit(1, []).action != "invalid", "submit opponent")
		while not owner.next_hook().is_empty():
			var hook: String = owner.next_hook()
			var result: Dictionary = owner.run_next_hook()
			if not check(result.action != "invalid", "round %d %s %s" % [round_number, hook, str(result)]):
				return
			if round_number == 1 or hook == Timeline.AFTERMATH:
				var restored = Content.new().create_combat_match()
				if not check(restored.restore(owner.snapshot()).action != "invalid", "restore after " + hook):
					return
		check(owner.snapshot().world.data.valak_orbs.size() == (1 if round_number < 3 else 0), "Orb two-round lifetime %d" % round_number)
		if round_number < 5:
			check(owner.begin_next_round([0, 1]).action != "invalid", "next round")

func _gravity_match() -> void:
	var world: Dictionary = Scenario.world()
	var ids = Content.Ids.new()
	ids.restore(world.entities)
	for index in range(6):
		var a: Dictionary = Marching.profile("Butcher", "Lord", index % 2, 0, 1)
		a.x_fp = 1200
		a.y_fp = 300
		ids.create("marcher", "gravity-match", index, index % 2, a)
	world.entities = ids.snapshot()
	var owner = Content.new().create_combat_match()
	if not check(owner.start("gravity-replay", world, [0, 1]).action != "invalid", "populated Orb match starts"):
		return
	while owner.next_hook() != Timeline.SUBMISSION_LOCK:
		if owner.run_next_hook().action == "invalid":
			check(false, "populated Orb opening")
			return
	owner.submit(0, [Scenario.source(0, 1, {"lane": "Lord", "field_position": {"x_fp": 1200, "y_fp": 300}})])
	owner.submit(1, [])
	while owner.next_hook() != Timeline.MARCHING:
		if owner.run_next_hook().action == "invalid":
			check(false, "populated Orb activation")
			return
	var snapshot: Dictionary = owner.snapshot()
	var restored = Content.new().create_combat_match()
	check(restored.restore(snapshot).action != "invalid", "restore populated active Orb")
	check(owner.run_next_hook().action != "invalid" and restored.run_next_hook().action != "invalid", "populated Orb Marching resolves on both copies")
	check(owner.snapshot() == restored.snapshot(), "Orb kill events and results replay identically")
	check(owner.snapshot().world.data.valak_orbs[0].consumed == 6 and owner.snapshot().world.data.neutral_tears == snapshot.world.data.neutral_tears + 1, "six actual Marching kills produce one Tear")
	var forged: Dictionary = snapshot.duplicate(true)
	forged.world.data.valak_orbs[0].consumed = 4
	check(Content.new().create_combat_match().restore(forged).action == "invalid", "reject forged reward ledger")
	forged = snapshot.duplicate(true)
	forged.world.data.valak_reserved[0] = 1
	check(Content.new().create_combat_match().restore(forged).action == "invalid", "reject unbacked Projection reservation")
