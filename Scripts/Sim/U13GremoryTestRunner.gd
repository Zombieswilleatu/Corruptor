extends SceneTree

const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const MatchOwner = preload("res://Scripts/Sim/U13Match.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
var failures: int = 0


func _init() -> void:
	for test in [
		Callable(self, "_predator"),
		Callable(self, "_ruin"),
		Callable(self, "_bones"),
		Callable(self, "_sifting_and_gem"),
		Callable(self, "_replay")
	]:
		test.call()
		if failures > 0:
			break
	print("U13 Gremory failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _new_match():
	# Match must retain this local RefCounted content object after this returns.
	var policy = Gremory.new(Callable(self, "_driver"))
	return policy.create_match("gremory_test_adapter_v1")


func _world() -> Dictionary:
	var entities = Ids.new()
	var players: Array = []
	var hands: Array = [[], []]
	var deck: Array = []
	for player_id in [0, 1]:
		var lord: Dictionary = entities.create(
			"lord", "lord:" + str(player_id), 0, player_id, {"lord_id": "Gremory", "alive": true}
		)
		players.append({"lord_id": "Gremory", "lord_entity_id": lord.entity.id, "resources": {}})
		entities.create(
			"castle",
			"castle:" + str(player_id),
			0,
			player_id,
			{"status": "standing", "integrity": 3, "max_integrity": 6}
		)
		entities.create(
			"card",
			"guard:" + str(player_id),
			0,
			player_id,
			{"role": "guard", "suit": "Wright", "value": 1}
		)
		for index in range(4):
			var card: Dictionary = entities.create(
				"card", "hand:" + str(player_id), index, player_id, {"suit": "Vulture", "value": 1}
			)
			hands[player_id].append(card.entity.id)
	for index in range(8):
		deck.append(
			entities.create("card", "deck", index, -1, {"suit": "Butcher", "value": 1}).entity.id
		)
	return {
		"players": players,
		"entities": entities.snapshot(),
		"data":
		{
			"card_zones": {"hands": hands, "deck": deck, "discard": [], "hand_limit": 10},
			"neutral_tears": 0,
			"breach_lord": "",
			"fixture_commands": []
		}
	}


func _driver(context: Dictionary) -> Array:
	var result: Array = []
	for row in context.world.data.fixture_commands:
		if row.round == context.round and row.hook == context.hook:
			result.append(row.command.duplicate(true))
	return result


func _fixture(world: Dictionary = {}):
	var owner = _new_match()
	var started: Dictionary = owner.start(
		"gremory_seed", _world() if world.is_empty() else world, [0, 1]
	)
	_check(started.action != "invalid", "gremory_start")
	if started.action == "invalid":
		print("GREMORY START ERROR: ", started)
		return null
	if not _drive(owner, Timeline.SUBMISSION_LOCK):
		return null
	return owner


func _source(
	power: String,
	target: Dictionary,
	round_number: int = 1,
	index: int = 0,
	selected: Array = [],
	player_id: int = 0
) -> Dictionary:
	var rule: Dictionary = Gremory.rules()[power]
	var cost: Dictionary = {"discard_ids": selected} if power == Gremory.RUIN else {}
	return Decl.create(
		MatchOwner.declaration_id(player_id, round_number, index),
		player_id,
		"Gremory",
		power,
		round_number,
		rule.fire_hook,
		round_number + int(rule.delay_rounds),
		index,
		"public",
		target,
		cost,
		{}
	)


func _command(world: Dictionary, round_number: int, hook: String, command: Dictionary) -> void:
	world.data.fixture_commands.append({"round": round_number, "hook": hook, "command": command})


func _predator() -> void:
	var owner = _fixture()
	if owner == null:
		return
	_check(
		(
			owner.preview_submission(0, [_source(Gremory.PREDATOR, {"lane": "bad"})]).action
			== "invalid"
		),
		"predator_rejects_invalid_lane"
	)
	var source: Dictionary = _source(Gremory.PREDATOR, {"lane": "Castle"})
	_check(owner.submit(0, [source]).action != "invalid", "predator_declared")
	owner.submit(1, [])
	if not _drive(owner, Timeline.POST_RESOLUTION_SPAWNS):
		return
	_check(_marchers(owner.snapshot().world).is_empty(), "no_predator_spawn_before_step_10a")
	_check(owner.run_next_hook().action != "invalid", "predator_fires_step_10a")
	var marchers: Array = _marchers(owner.snapshot().world)
	_check(marchers.size() == 3, "predator_spawns_exactly_three")
	for row in marchers:
		_check(
			(
				row.owner == 0
				and row.attributes.suit == "Vulture"
				and row.attributes.lane == "Castle"
				and row.attributes.hp == 5
				and row.attributes.armor_bypass
			),
			"predator_standard_vulture_profile"
		)
	var resumed = _new_match()
	_check(
		resumed.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))).action != "invalid",
		"predator_spawn_ids_restore"
	)
	_check(resumed.snapshot() == owner.snapshot(), "predator_exact_snapshot")
	if not _drive(owner):
		return
	for round_number in [2, 3]:
		owner.begin_next_round([0, 1])
		if not _drive(owner, Timeline.SUBMISSION_LOCK):
			return
		var result: Dictionary = owner.preview_submission(
			0, [_source(Gremory.PREDATOR, {"lane": "Lord"}, round_number)]
		)
		_check(
			(result.action == "legal") == (round_number == 3),
			"predator_cooldown_round_" + str(round_number)
		)
		owner.submit(0, [])
		owner.submit(1, [])
		if not _drive(owner):
			return


func _ruin() -> void:
	var world: Dictionary = _world()
	var castle_id: String = Ids.identity("castle", "castle:1")
	var own_source: Dictionary = _source(
		Gremory.RUIN, {"entity_id": Ids.identity("castle", "castle:0")}
	)
	for phase in ["declaration", "firing"]:
		var rejected: Dictionary = Gremory.new().validate(own_source, world, phase)
		_check(
			not rejected.legal and rejected.reason == "castle_not_enemy",
			"ruin_rejects_friendly_castle_" + phase
		)
	var hand: Array = world.data.card_zones.hands[0].duplicate()
	_command(
		world,
		1,
		Timeline.AFTERMATH,
		{"command_id": "repair", "kind": "repair_castle", "target_id": castle_id}
	)
	_command(
		world,
		1,
		Timeline.COMBAT_RESOLUTION,
		{
			"command_id": "banish",
			"kind": "banish_lord",
			"target_id": world.players[0].lord_entity_id
		}
	)
	var owner = _fixture(world)
	if owner == null:
		return
	var before_friendly: Dictionary = owner.snapshot()
	var friendly: Dictionary = _source(
		Gremory.RUIN, {"entity_id": Ids.identity("castle", "castle:0")}, 1, 0, [hand[0], hand[1]]
	)
	_check(owner.submit(0, [friendly]).action == "invalid", "ruin_friendly_submission_rejected")
	_check(owner.snapshot() == before_friendly, "ruin_friendly_rejection_preserves_state")
	for selected in [
		[], [hand[0]], [hand[0], hand[0]], [hand[0], "missing"], [hand[0], hand[1], hand[2]]
	]:
		_check(
			(
				(
					owner
					. submit(0, [_source(Gremory.RUIN, {"entity_id": castle_id}, 1, 0, selected)])
					. action
				)
				== "invalid"
			),
			"ruin_requires_exactly_two_owned_distinct_cards"
		)
	var source: Dictionary = _source(
		Gremory.RUIN, {"entity_id": castle_id}, 1, 0, [hand[0], hand[1]]
	)
	_check(owner.submit(0, [source]).action != "invalid", "ruin_legal_declaration")
	_check(
		owner.snapshot().world.data.card_zones.hands[0].size() == 4,
		"ruin_payment_waits_for_joint_lock"
	)
	owner.submit(1, [])
	_check(owner.run_next_hook().action != "invalid", "ruin_joint_lock")
	_check(
		(
			owner.snapshot().world.data.card_zones.discard == [hand[0], hand[1]]
			and owner.snapshot().world.data.card_zones.hands[0].size() == 2
		),
		"ruin_discards_selected_cards_in_submitted_order"
	)
	if not _drive(owner):
		return
	_check(
		_entity(owner.snapshot().world, castle_id).attributes.integrity == 6,
		"target_repaired_after_declaration"
	)
	owner.begin_next_round([0, 1])
	_check(owner.run_next_hook().action != "invalid", "ruin_fires_before_step_two")
	_check(
		_entity(owner.snapshot().world, castle_id).attributes.status == "defunct",
		"repair_and_banishment_do_not_cancel_doom"
	)
	_check(
		owner.snapshot().world.data.neutral_tears == 0, "defunct_is_not_destruction_or_tear_reward"
	)
	world = _world()
	_command(
		world,
		1,
		Timeline.AFTERMATH,
		{"command_id": "destroy", "kind": "destroy_castle", "target_id": castle_id}
	)
	owner = _fixture(world)
	if owner == null:
		return
	owner.submit(0, [source])
	owner.submit(1, [])
	if not _drive(owner):
		return
	var spent_state: Dictionary = owner.snapshot().world.data.card_zones.duplicate(true)
	owner.begin_next_round([0, 1])
	_check(owner.run_next_hook().action != "invalid", "missing_doom_target_resolves_as_fizzle")
	_check(
		(
			owner.snapshot().pending.pending.is_empty()
			and owner.snapshot().world.data.card_zones == spent_state
		),
		"fizzle_consumes_doom_without_refund_or_retarget"
	)
	_check(
		_count(owner.player_view(0).events, "FIZZLE_INVALID_TARGET") == 1, "ruin_fizzle_event_once"
	)
	world = _world()
	var entities = Ids.new()
	entities.restore(world.entities)
	var castle: Dictionary = entities.get_entity(castle_id)
	castle.attributes.integrity = 6
	entities.update(castle_id, 1, castle.attributes)
	world.entities = entities.snapshot()
	owner = _fixture(world)
	if owner == null:
		return
	_check(owner.submit(0, [source]).action == "invalid", "undamaged_target_illegal_at_declaration")


func _bones() -> void:
	var world: Dictionary = _world()
	var entities = Ids.new()
	entities.restore(world.entities)
	var killer: String = (
		entities
		. create("marcher", "killer", 0, 0, {"suit": "Vulture", "hp": 5, "lane": "Lord"})
		. entity
		. id
	)
	var victims: Array = []
	for index in range(3):
		victims.append(
			(
				entities
				. create("marcher", "victim", index, 1, {"suit": "Wright", "hp": 1, "lane": "Lord"})
				. entity
				. id
			)
		)
	world.entities = entities.snapshot()
	_command(
		world,
		1,
		Timeline.POST_RESOLUTION_HAZARDS,
		{
			"command_id": "hazard",
			"kind": "marcher_damage",
			"target_id": victims[0],
			"attacker_id": killer,
			"damage": 1,
			"cause": "hazard"
		}
	)
	for index in [1, 2]:
		_command(
			world,
			1,
			Timeline.MARCHING,
			{
				"command_id": "kill" + str(index),
				"kind": "marcher_damage",
				"target_id": victims[index],
				"attacker_id": killer,
				"damage": 1,
				"cause": "combat"
			}
		)
	var owner = _fixture(world)
	if owner == null:
		return
	owner.submit(0, [])
	owner.submit(1, [])
	if not _drive(owner, Timeline.MARCHING):
		return
	_check(owner.snapshot().world.data.neutral_tears == 0, "noncombat_kill_does_not_trigger_bones")
	if not _drive(owner):
		return
	_check(
		(
			owner.snapshot().world.data.neutral_tears == 1
			and owner.snapshot().world.data.card_zones.hands[0].size() == 5
		),
		"bones_one_draw_one_neutral_tear_per_round"
	)
	_check(
		_count(owner.player_view(0).events, "PICKING_THE_BONES") == 1,
		"bones_once_for_multiple_combat_kills"
	)
	var own: Array = owner.player_view(0).events
	var other: Array = owner.player_view(1).events
	for event in other:
		if event.type == "PICKING_THE_BONES":
			_check(not event.data.has("card_id"), "bones_draw_identity_hidden_from_opponent")
	_check(_count(own, "NEUTRAL_TEAR_CREATED") == 1, "bones_tear_event")

	world = _world()
	world.data.card_zones.hand_limit = 4
	entities = Ids.new()
	entities.restore(world.entities)
	killer = (
		entities
		. create("marcher", "full_hand_killer", 0, 0, {"suit": "Vulture", "hp": 5, "lane": "Lord"})
		. entity
		. id
	)
	var victim: String = (
		entities
		. create("marcher", "full_hand_victim", 0, 1, {"suit": "Wright", "hp": 1, "lane": "Lord"})
		. entity
		. id
	)
	world.entities = entities.snapshot()
	var killed: Dictionary = _combat(
		world,
		{
			"command_id": "full_hand_kill",
			"kind": "marcher_damage",
			"target_id": victim,
			"attacker_id": killer,
			"damage": 1,
			"cause": "combat"
		},
		1
	)
	var reaction: Dictionary = Gremory.react(killed.world, killed.event, "seed", [0, 1])
	_check(
		(
			reaction.world.data.neutral_tears == 1
			and reaction.world.data.card_zones.hands[0].size() == 4
		),
		"bones_tear_not_conditional_on_successful_draw"
	)
	entities.restore(reaction.world.entities)
	victim = (
		entities
		. create("marcher", "next_round_victim", 0, 1, {"suit": "Wright", "hp": 1, "lane": "Lord"})
		. entity
		. id
	)
	reaction.world.entities = entities.snapshot()
	killed = _combat(
		reaction.world,
		{
			"command_id": "next_round_kill",
			"kind": "marcher_damage",
			"target_id": victim,
			"attacker_id": killer,
			"damage": 1,
			"cause": "combat"
		},
		2
	)
	reaction = Gremory.react(killed.world, killed.event, "seed", [0, 1])
	_check(reaction.world.data.neutral_tears == 2, "bones_resets_next_round")
	world = _world()
	entities.restore(world.entities)
	killer = (
		entities
		. create("marcher", "wrong_suit", 0, 0, {"suit": "Wright", "hp": 5, "lane": "Lord"})
		. entity
		. id
	)
	victim = (
		entities
		. create("marcher", "wrong_suit_victim", 0, 1, {"suit": "Wright", "hp": 1, "lane": "Lord"})
		. entity
		. id
	)
	world.entities = entities.snapshot()
	killed = _combat(
		world,
		{
			"command_id": "wrong_suit_kill",
			"kind": "marcher_damage",
			"target_id": victim,
			"attacker_id": killer,
			"damage": 1,
			"cause": "combat"
		},
		1
	)
	reaction = Gremory.react(killed.world, killed.event, "seed", [0, 1])
	_check(
		reaction.world.data.neutral_tears == 0 and reaction.events.is_empty(),
		"non_vulture_kill_does_not_trigger_bones"
	)


func _sifting_and_gem() -> void:
	var world: Dictionary = _world()
	var paid: Array = world.data.card_zones.hands[0].slice(0, 2)
	Cards.discard(world, 0, paid)
	var first: Dictionary = Battle.apply(
		world,
		{
			"command_id": "castle1",
			"kind": "destroy_castle",
			"target_id": Ids.identity("castle", "castle:0")
		},
		1
	)
	var reaction: Dictionary = Gremory.react(first.world, first.event, "seed", [1, 0])
	_check(
		(
			reaction.world.data.card_zones.hands[1].back() == paid[1]
			and reaction.world.data.card_zones.hands[0].back() == paid[0]
		),
		"sifting_actual_discard_top_in_reflex_order"
	)
	var repeated: Dictionary = Gremory.react(reaction.world, first.event, "seed", [1, 0])
	_check(
		repeated.world == reaction.world and repeated.events.is_empty(),
		"sifting_once_survives_repeat_event"
	)
	world = _world()
	world.data.breach_lord = "Gremory"
	var guard: Dictionary = Battle.apply(
		world,
		{
			"command_id": "guard0",
			"kind": "defeat_guard",
			"target_id": Ids.identity("card", "guard:0")
		},
		1
	)
	reaction = Gremory.react(guard.world, guard.event, "seed", [0, 1])
	_check(
		(
			reaction.world.data.card_zones.hands[0].size() == 5
			and reaction.world.data.card_zones.hands[1].size() == 5
		),
		"gem_dagger_each_player_draws"
	)
	guard = Battle.apply(
		reaction.world,
		{
			"command_id": "guard1",
			"kind": "defeat_guard",
			"target_id": Ids.identity("card", "guard:1")
		},
		1
	)
	reaction = Gremory.react(guard.world, guard.event, "seed", [0, 1])
	_check(reaction.events.is_empty(), "gem_dagger_once_per_round_global")
	world = _world()
	world.data.card_zones.hand_limit = 4
	world.data.breach_lord = "Gremory"
	guard = Battle.apply(
		world,
		{
			"command_id": "full_guard",
			"kind": "defeat_guard",
			"target_id": Ids.identity("card", "guard:0")
		},
		1
	)
	reaction = Gremory.react(guard.world, guard.event, "seed", [0, 1])
	_check(
		(
			reaction.world.data.card_zones.hands[0].size() == 4
			and reaction.world.data.card_zones.hands[1].size() == 4
		),
		"gem_respects_hand_limit"
	)
	world = _world()
	guard = Battle.apply(
		world,
		{
			"command_id": "no_breach",
			"kind": "defeat_guard",
			"target_id": Ids.identity("card", "guard:0")
		},
		1
	)
	reaction = Gremory.react(guard.world, guard.event, "seed", [0, 1])
	_check(reaction.events.is_empty(), "gem_inactive_outside_gremory_breach")
	world = _world()
	first = Battle.apply(
		world,
		{
			"command_id": "empty_discard",
			"kind": "destroy_castle",
			"target_id": Ids.identity("castle", "castle:0")
		},
		1
	)
	reaction = Gremory.react(first.world, first.event, "seed", [0, 1])
	_check(
		reaction.world.data.card_zones.hands[0].size() == 4,
		"sifting_empty_discard_does_not_draw_from_deck"
	)
	Cards.discard(reaction.world, 0, [reaction.world.data.card_zones.hands[0][0]])
	first = Battle.apply(
		reaction.world,
		{
			"command_id": "second_castle",
			"kind": "destroy_castle",
			"target_id": Ids.identity("castle", "castle:1")
		},
		1
	)
	reaction = Gremory.react(first.world, first.event, "seed", [0, 1])
	_check(reaction.events.is_empty(), "sifting_first_event_consumes_attempt_even_when_empty")
	world = _world()
	world.data.breach_lord = "Gremory"
	guard = Battle.apply(
		world,
		{
			"command_id": "first_round_guard",
			"kind": "defeat_guard",
			"target_id": Ids.identity("card", "guard:0")
		},
		1
	)
	reaction = Gremory.react(guard.world, guard.event, "seed", [0, 1])
	guard = Battle.apply(
		reaction.world,
		{
			"command_id": "next_round_guard",
			"kind": "defeat_guard",
			"target_id": Ids.identity("card", "guard:1")
		},
		2
	)
	reaction = Gremory.react(guard.world, guard.event, "seed", [0, 1])
	_check(
		(
			reaction.world.data.card_zones.hands[0].size() == 6
			and reaction.world.data.card_zones.hands[1].size() == 6
		),
		"gem_trigger_resets_next_round"
	)
	var empty: Dictionary = _world()
	empty.data.card_zones.discard.append_array(empty.data.card_zones.deck)
	empty.data.card_zones.deck.clear()
	var resumed: Dictionary = JSON.parse_string(JSON.stringify(empty))
	resumed = Data.copy_data(resumed)
	_check(
		(
			Cards.draw(empty, 0, "seed", "recycle") == Cards.draw(resumed, 0, "seed", "recycle")
			and empty == resumed
		),
		"keyed_discard_recycle_replays"
	)


func _replay() -> void:
	var owner = _fixture()
	if owner == null:
		return
	var hand: Array = owner.snapshot().world.data.card_zones.hands[0]
	owner.submit(
		0,
		[
			_source(Gremory.PREDATOR, {"lane": "Lord"}),
			_source(
				Gremory.RUIN,
				{"entity_id": Ids.identity("castle", "castle:1")},
				1,
				1,
				hand.slice(0, 2)
			)
		]
	)
	owner.submit(1, [])
	var resumed = _new_match()
	_check(
		resumed.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))).action != "invalid",
		"gremory_saved_both_declarations_before_lock"
	)
	for round_number in [1, 2, 3]:
		if round_number > 1:
			owner.begin_next_round([1, 0])
			resumed.begin_next_round([1, 0])
		for _index in range(21):
			if owner.next_hook().is_empty():
				break
			if round_number > 1 and owner.next_hook() == Timeline.SUBMISSION_LOCK:
				for match_owner in [owner, resumed]:
					match_owner.submit(0, [])
					match_owner.submit(1, [])
			var a: Dictionary = owner.run_next_hook()
			var b: Dictionary = resumed.run_next_hook()
			_check(a.action != "invalid" and a == b, "gremory_replay_hook")
			if a.action == "invalid" or b.action == "invalid":
				print("GREMORY REPLAY ERROR: ", a, b)
				return
			_check(
				owner.snapshot() == resumed.snapshot(), "gremory_exact_replay_state_events_and_ids"
			)
			var restored = _new_match()
			_check(
				(
					restored.restore(JSON.parse_string(JSON.stringify(resumed.snapshot()))).action
					!= "invalid"
				),
				"gremory_json_restore_every_hook"
			)
			resumed = restored


func _combat(world: Dictionary, command: Dictionary, round_number: int) -> Dictionary:
	return Battle.apply(world, command, round_number, Timeline.MARCHING)


func _entity(world: Dictionary, entity_id: String) -> Dictionary:
	for row in world.entities.entities:
		if row.id == entity_id:
			return row
	return {}


func _marchers(world: Dictionary) -> Array:
	var result: Array = []
	for row in world.entities.entities:
		if row.kind == "marcher":
			result.append(row)
	return result


func _count(events: Array, event_type: String) -> int:
	var count: int = 0
	for event in events:
		if event.type == event_type:
			count += 1
	return count


func _drive(owner, stop: String = "") -> bool:
	for _index in range(21):
		if owner.next_hook().is_empty() or owner.next_hook() == stop:
			return true
		var result: Dictionary = owner.run_next_hook()
		if result.action == "invalid":
			print("GREMORY HOOK ERROR: ", result)
			_check(false, "gremory_drive_" + owner.next_hook())
			return false
	_check(false, "gremory_hook_limit")
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		failures += 1
		print("FAIL  " + label)
