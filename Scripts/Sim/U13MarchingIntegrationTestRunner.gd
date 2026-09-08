extends SceneTree

const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const MatchOwner = preload("res://Scripts/Sim/U13Match.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
var failures: int = 0


func _init() -> void:
	for test in [
		Callable(self, "_movement_and_waiting"),
		Callable(self, "_duels"),
		Callable(self, "_sealed_siege"),
		Callable(self, "_defense_boundaries"),
		Callable(self, "_predator_and_replay"),
		Callable(self, "_atomic_validation"),
		Callable(self, "_fractional_positions"),
		Callable(self, "_real_ruin_fizzle")
	]:
		test.call()
		if failures > 0:
			break
	print("U13 Marching integration failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _new_match():
	var content = Gremory.new()
	return content.create_combat_match()


func _world() -> Dictionary:
	var entities = Ids.new()
	var players: Array = []
	var hands: Array = [[], []]
	var deck: Array = []
	for player_id in [0, 1]:
		var lord: Dictionary = entities.create(
			"lord", "lord:" + str(player_id), 0, player_id, {"lord_id": "Gremory", "alive": true}
		)
		players.append(
			{"lord_id": "Gremory", "lord_entity_id": lord.entity.id, "resources": {"souls": 0}}
		)
		entities.create(
			"castle",
			"castle:" + str(player_id),
			0,
			player_id,
			{
				"status": "standing",
				"integrity": 3,
				"max_integrity": 6,
				"combat_profile": "plain_integrity"
			}
		)
		for index in range(4):
			var card: Dictionary = entities.create(
				"card", "hand:" + str(player_id), index, player_id, {"suit": "Butcher", "value": 3}
			)
			hands[player_id].append(card.entity.id)
	for index in range(12):
		var card: Dictionary = entities.create(
			"card", "deck", index, -1, {"suit": "Wright", "value": 1}
		)
		deck.append(card.entity.id)
	return {
		"players": players,
		"entities": entities.snapshot(),
		"data":
		{
			"combat_profile": Combat.VERSION,
			"card_zones": {"hands": hands, "deck": deck, "discard": [], "hand_limit": 10},
			"neutral_tears": 0,
			"breach_lord": "Gremory",
			"sigils": [{"Lord": "", "Castle": ""}, {"Lord": "", "Castle": ""}]
		}
	}


func _spawn(
	world: Dictionary,
	origin: String,
	player_id: int,
	suit: String,
	x_fp: int,
	ready: int = 1,
	lane: String = "Castle"
) -> String:
	var entities = Ids.new()
	entities.restore(world.entities)
	var a: Dictionary = Marching.profile(suit, lane, player_id, 0, ready)
	a.x_fp = x_fp
	var created: Dictionary = entities.create("marcher", origin, 0, player_id, a)
	world.entities = entities.snapshot()
	return created.entity.id


func _guard(world: Dictionary, origin: String, value: int, slot: int) -> String:
	var entities = Ids.new()
	entities.restore(world.entities)
	var created: Dictionary = entities.create(
		"card",
		origin,
		0,
		1,
		{"role": "guard", "suit": "Wright", "value": value, "lane": "Castle", "slot": slot}
	)
	world.entities = entities.snapshot()
	return created.entity.id


func _edit(world: Dictionary, entity_id: String, changes: Dictionary) -> void:
	var entities = Ids.new()
	entities.restore(world.entities)
	var entity: Dictionary = entities.get_entity(entity_id)
	for key in changes:
		entity.attributes[key] = changes[key]
	var updated: Dictionary = entities.update(entity_id, entity.owner, entity.attributes)
	if updated.action == "invalid":
		print("MARCHING FIXTURE UPDATE ERROR: ", updated)
		_check(false, "fixture_entity_update_rejected")
		return
	world.entities = entities.snapshot()


func _entity(world: Dictionary, entity_id: String) -> Dictionary:
	for entity in world.entities.entities:
		if entity.id == entity_id:
			return entity
	return {}


func _context(
	world: Dictionary, hook: String = Timeline.MARCHING, round_number: int = 1
) -> Dictionary:
	return {
		"world": world,
		"hook": hook,
		"round": round_number,
		"seed": "marching_integration_seed",
		"player_order": [0, 1],
		"combat_orders": [{}, {}]
	}


func _run_marching(world: Dictionary, round_number: int = 1) -> Dictionary:
	var content = Gremory.new()
	return Marching.resolve(
		_context(world, Timeline.MARCHING, round_number), Callable(content, "react")
	)


func _movement_and_waiting() -> void:
	var world: Dictionary = _world()
	var ids: Array = []
	for suit in Marching.SUITS:
		ids.append(_spawn(world, suit, 0, suit, 0))
		_edit(world, ids.back(), {"y_fp": 50 + 150 * (ids.size() - 1)})
	var fresh: String = _spawn(world, "fresh", 0, "Vulture", 0, 2, "Lord")
	var before: Dictionary = world.duplicate(true)
	var result: Dictionary = _run_marching(world)
	if not _check(result.action == "resolved", "marching_phase_resolves"):
		return
	_check(world == before, "marching_transform_preserves_input")
	for index in range(ids.size()):
		var expected: Array = [800, 600, 1200, 800]
		_check(
			_entity(result.world, ids[index]).attributes.x_fp == expected[index],
			"audited_200_tick_distance_" + Marching.SUITS[index]
		)
	_check(_entity(result.world, fresh).attributes.x_fp == 0, "commitment_birth_round_hold")
	_check(_run_marching(result.world).action == "invalid", "duplicate_marching_rejected")
	var second: Dictionary = _run_marching(result.world, 2)
	_check(_entity(second.world, ids[2]).attributes.waiting, "vulture_arrives_after_two_phases")
	_check(second.world.data.neutral_tears == 0, "arrival_creates_no_tear")
	_edit(second.world, ids[2], {"hp": 2, "armor": 0})
	var regen: Dictionary = Marching.regenerate(
		_context(second.world, Timeline.ROUND_START_AUTOMATIC, 3)
	)
	_check(_entity(regen.world, ids[2]).attributes.hp == 2, "waiter_does_not_regenerate")
	_check(_entity(regen.world, ids[2]).attributes.armor == 0, "armor_is_not_regenerated")
	_edit(second.world, ids[0], {"hp": 2, "armor": 0})
	regen = Marching.regenerate(_context(second.world, Timeline.ROUND_START_AUTOMATIC, 3))
	_check(
		_entity(regen.world, ids[0]).attributes.hp == 3, "moving_marcher_regenerates_at_step_three"
	)


func _duels() -> void:
	var world: Dictionary = _world()
	var vulture: String = _spawn(world, "vulture", 0, "Vulture", 1200)
	var butcher: String = _spawn(world, "butcher", 1, "Butcher", 1200)
	var result: Dictionary = _run_marching(world)
	if not _check(result.action == "resolved", "asymmetric_duel_resolves"):
		return
	_check(_entity(result.world, vulture).is_empty(), "butcher_kills_vulture_from_real_exchanges")
	_check(
		_entity(result.world, butcher).attributes.hp == 1,
		"vulture_bypass_preserves_audited_duel_hp"
	)
	_check(
		_entity(result.world, butcher).attributes.armor == 1,
		"vulture_bypass_does_not_consume_armor"
	)
	_check(
		_events(result.events, "PICKING_THE_BONES").is_empty(),
		"non_vulture_kill_has_no_bones_reward"
	)
	world = _world()
	_spawn(world, "left", 0, "Vulture", 1194)
	_spawn(world, "right", 1, "Vulture", 1206)
	result = _run_marching(world)
	_check(
		_events(result.events, "MARCHER_DEFEATED").size() == 2,
		"simultaneous_lethal_exchange_records_both_kills"
	)
	_check(
		(
			_events(result.events, "PICKING_THE_BONES").size() == 2
			and result.world.data.neutral_tears == 2
		),
		"mutual_vulture_kills_reward_both_gremories"
	)
	var clashes: Array = _events(result.events, "MARCHER_CLASH")
	_check(
		clashes[0].data.tick == 0 and clashes[0].data.x_fp == 1200,
		"contact_is_at_crossing_midpoint"
	)
	_check(clashes[0].data.exchanges.size() == 3, "duel_uses_all_simultaneous_exchanges")
	world = _world()
	_spawn(world, "vulture", 0, "Vulture", 1200)
	_spawn(world, "wright", 1, "Wright", 1200)
	result = _run_marching(world)
	clashes = _events(result.events, "MARCHER_CLASH")
	_check(
		clashes[0].data.exchanges[0] == {"hp": [4, 3], "armor": [0, 2]}, "armor_depletes_as_buffer"
	)
	_check(clashes[0].data.exchanges[2].hp == [0, 0], "armor_is_not_reapplied_each_exchange")
	# Same tied fronts inserted in reverse order must resolve identically.
	world = _world()
	for index in range(3):
		_spawn(world, "tie:left:" + str(index), 0, "Vulture", 1200)
		_spawn(world, "tie:right:" + str(index), 1, "Vulture", 1200)
	var reversed: Dictionary = world.duplicate(true)
	reversed.entities.entities.reverse()
	var first: Dictionary = _run_marching(world)
	var replay: Dictionary = _run_marching(reversed)
	_check(first == replay, "keyed_front_ties_ignore_registry_insertion_order")
	_check(
		first.world.data.neutral_tears == 2, "multiple_real_kills_cap_bones_once_per_owner_round"
	)
	# A waiter intercepts a fresh defender even though that defender cannot move.
	world = _world()
	var waiter: String = _spawn(world, "waiting", 0, "Vulture", 2400)
	_edit(world, waiter, {"waiting": true, "waiting_since_round": 1})
	_spawn(world, "fresh_defender", 1, "Vulture", 2400, 2)
	result = _run_marching(world)
	_check(
		_events(result.events, "MARCHER_DEFEATED").size() == 2, "waiter_fights_birth_held_defender"
	)


func _fixture(world: Dictionary):
	var owner = _new_match()
	var started: Dictionary = owner.start("marching_match_seed", world, [0, 1])
	if not _check(started.action != "invalid", "combat_match_starts"):
		print(started)
		return null
	if not _drive(owner, Timeline.SUBMISSION_LOCK):
		return null
	return owner


func _order(world: Dictionary, player_id: int, count: int = 2) -> Dictionary:
	return {
		"action": "Siege",
		"lane": "Castle",
		"target_id": Ids.identity("castle", "castle:" + str(1 - player_id)),
		"card_ids": world.data.card_zones.hands[player_id].slice(0, count)
	}


func _sealed_siege() -> void:
	var world: Dictionary = _world()
	var first_guard: String = _guard(world, "guard:high", 2, 0)
	var last_guard: String = _guard(world, "guard:low", 1, 1)
	var owner = _fixture(world)
	if owner == null:
		return
	var order: Dictionary = _order(world, 0)
	var before: Dictionary = owner.snapshot()
	_check(owner.preview_submission(0, [], order).action == "legal", "siege_uses_shared_preview")
	_check(owner.snapshot() == before, "combat_preview_is_atomic")
	var opposing_view: Dictionary = owner.player_view(1)
	_check(owner.submit(0, [], order).action != "invalid", "sealed_siege_submitted")
	_check(owner.player_view(1) == opposing_view, "submission_hides_opponent_order")
	owner.submit(1, [])
	if not _drive(owner, Timeline.COMMITMENT_REVEAL):
		return
	var view: Dictionary = owner.player_view(1)
	_check(view.world.opponent_hand_count == 4, "sealed_commitment_count_hidden_until_reveal")
	_check(
		not JSON.stringify(view).contains(order.card_ids[0]),
		"sealed_card_identity_not_in_opponent_view"
	)
	_check(Cards.valid(owner.snapshot().world), "committed_cards_have_authoritative_zone")
	if not _drive(owner, Timeline.COMBAT_RESOLUTION):
		return
	view = owner.player_view(1)
	_check(JSON.stringify(view).contains(order.card_ids[0]), "reveal_publishes_physical_commitment")
	_check(owner.run_next_hook().action != "invalid", "real_siege_resolves")
	var after: Dictionary = owner.snapshot()
	var facts: Array = _events(after.events.rows, "GUARD_DEFEATED")
	_check(
		(
			facts.size() == 2
			and facts[0].data.guard.id == first_guard
			and facts[1].data.guard.id == last_guard
		),
		"real_attack_defeats_guards_in_value_order"
	)
	_check(
		_events(after.events.rows, "GEM_DAGGER").size() == 2,
		"real_guard_defeat_draws_for_both_once"
	)
	_check(
		_events(after.events.rows, "CASTLE_DESTROYED").size() == 1,
		"remaining_siege_strength_destroys_castle"
	)
	_check(
		(
			last_guard in after.world.data.card_zones.hands[0]
			and first_guard in after.world.data.card_zones.hands[1]
		),
		"sifting_uses_actual_guard_discard_order"
	)
	_check(
		after.world.players[0].resources.souls == 3 and after.world.data.neutral_tears == 1,
		"ordinary_siege_rewards_preserved"
	)
	_check(_entity(after.world, order.target_id).is_empty(), "destroyed_castle_identity_retired")
	if not _drive(owner):
		return
	_check(
		owner.snapshot().world.data.card_zones.committed == [[], []], "aftermath_clears_commitments"
	)
	for card_id in order.card_ids:
		_check(
			card_id in owner.snapshot().world.data.card_zones.discard,
			"committed_card_reaches_discard_after_combat"
		)


func _defense_boundaries() -> void:
	# Printed Butcher 3 against Guard 3: equality stops, no defeat/no Gem.
	var world: Dictionary = _world()
	var guard_id: String = _guard(world, "equal_guard", 3, 0)
	var owner = _fixture(world)
	if owner == null:
		return
	owner.submit(0, [], _order(world, 0, 1))
	owner.submit(1, [])
	if not _drive(owner, Timeline.POST_RESOLUTION_SPAWNS):
		return
	_check(
		_entity(owner.snapshot().world, guard_id).attributes.role == "guard",
		"equal_attack_does_not_defeat_guard"
	)
	_check(
		_events(owner.snapshot().events.rows, "GEM_DAGGER").is_empty(),
		"blocked_siege_does_not_emit_fake_defeat"
	)
	# Full Ward consumes a matching waiter even when it stops the whole attack.
	world = _world()
	var waiter: String = _spawn(world, "support", 0, "Butcher", 2400)
	_edit(world, waiter, {"waiting": true, "waiting_since_round": 1})
	for card_id in world.data.card_zones.hands[1].slice(0, 2):
		_edit(world, card_id, {"suit": "Penitent", "value": 3})
	owner = _fixture(world)
	if owner == null:
		return
	owner.submit(0, [], _order(world, 0, 1))
	owner.submit(
		1,
		[],
		{"action": "Ward", "lane": "Castle", "card_ids": world.data.card_zones.hands[1].slice(0, 2)}
	)
	if not _drive(owner, Timeline.POST_RESOLUTION_SPAWNS):
		return
	var siege: Dictionary = _events(owner.snapshot().events.rows, "SIEGE_RESOLVED")[0]
	_check(
		siege.data.strength == 4 and siege.data.ward_screen == 7 and siege.data.damage == 0,
		"ward_precedes_guard_and_structure_damage"
	)
	_check(
		_entity(owner.snapshot().world, waiter).is_empty(),
		"valid_blocked_siege_consumes_waiter_support"
	)
	# A Fresh Sigil requires strict excess, while Integrity breaks at equality.
	world = _world()
	_edit(world, world.data.card_zones.hands[0][0], {"value": 2})
	world.data.sigils[1].Castle = "fresh"
	owner = _fixture(world)
	if owner == null:
		return
	owner.submit(0, [], _order(world, 0, 1))
	owner.submit(1, [])
	if not _drive(owner, Timeline.POST_RESOLUTION_SPAWNS):
		return
	_check(owner.snapshot().world.data.sigils[1].Castle == "fresh", "equal_attack_preserves_sigil")
	world = _world()
	owner = _fixture(world)
	if owner == null:
		return
	owner.submit(0, [], _order(world, 0, 1))
	owner.submit(1, [])
	if not _drive(owner, Timeline.POST_RESOLUTION_SPAWNS):
		return
	_check(
		_events(owner.snapshot().events.rows, "CASTLE_DESTROYED").size() == 1,
		"equal_structure_hit_destroys_positive_integrity"
	)


func _predator(player_id: int, round_number: int = 1) -> Dictionary:
	return Decl.create(
		MatchOwner.declaration_id(player_id, round_number, 0),
		player_id,
		"Gremory",
		Gremory.PREDATOR,
		round_number,
		Timeline.POST_RESOLUTION_SPAWNS,
		round_number,
		0,
		"public",
		{"lane": "Castle"},
		{},
		{}
	)


func _predator_and_replay() -> void:
	var world: Dictionary = _world()
	var owner = _fixture(world)
	if owner == null:
		return
	owner.submit(0, [_predator(0)])
	owner.submit(1, [_predator(1)])
	if not _drive(owner, Timeline.POST_RESOLUTION_SPAWNS):
		return
	_check(
		_events(owner.snapshot().events.rows, "MARCHER_SPAWNED").is_empty(),
		"predator_waits_until_step_10a_in_real_path"
	)
	if not _drive(owner, Timeline.MARCHING):
		return
	_check(
		_events(owner.snapshot().events.rows, "MARCHER_SPAWNED").size() == 6,
		"both_predator_queues_spawn_before_marching"
	)
	var resumed = _new_match()
	_check(
		resumed.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))).action != "invalid",
		"restore_before_real_marching"
	)
	if not _drive(owner) or not _drive(resumed):
		return
	_check(owner.snapshot() == resumed.snapshot(), "real_marching_replays_exact_world_and_events")
	var rows: Array = owner.snapshot().events.rows
	var kills: Array = _events(rows, "MARCHER_DEFEATED")
	var finished: Array = _events(rows, "MARCHING_FINISHED")
	_check(kills.size() + finished[0].data.units.size() == 6, "all_six_predators_accounted_for")
	var contacts: Array = _events(rows, "MARCHER_CONTACT")
	_check(not contacts.is_empty(), "lord_spawns_reach_real_contact_in_current_phase")
	_check(
		_events(rows, "MARCHING_TICK").size() == 200, "all_authoritative_movement_ticks_recorded"
	)
	var rewarded: Array = []
	for kill in kills:
		if kill.data.attacker.owner not in rewarded:
			rewarded.append(kill.data.attacker.owner)
	_check(
		owner.snapshot().world.data.neutral_tears == rewarded.size(),
		"actual_predator_kills_trigger_bones_once_each"
	)
	# Replay from every boundary, including a one-sided sealed combat order.
	world = _world()
	_guard(world, "replay_guard", 1, 0)
	owner = _fixture(world)
	if owner == null:
		return
	owner.submit(0, [_predator(0)], _order(world, 0))
	resumed = _new_match()
	_check(
		resumed.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))).action != "invalid",
		"sealed_order_restores_before_opponent_submit"
	)
	owner.submit(1, [_predator(1)])
	resumed.submit(1, [_predator(1)])
	for index in range(21):
		if owner.next_hook().is_empty():
			break
		var left: Dictionary = owner.run_next_hook()
		var right: Dictionary = resumed.run_next_hook()
		if not _check(
			left.action != "invalid" and right.action != "invalid",
			"combat_replay_hook_" + str(index)
		):
			print(left, right)
			return
		_check(owner.snapshot() == resumed.snapshot(), "combat_replay_state_" + str(index))
		var restored = _new_match()
		if not _check(
			(
				restored.restore(JSON.parse_string(JSON.stringify(resumed.snapshot()))).action
				!= "invalid"
			),
			"combat_json_restore_" + str(index)
		):
			return
		resumed = restored


func _atomic_validation() -> void:
	var world: Dictionary = _world()
	var owner = _fixture(world)
	if owner == null:
		return
	var before: Dictionary = owner.snapshot()
	var bad: Dictionary = _order(world, 0)
	bad.card_ids = [bad.card_ids[0], bad.card_ids[0]]
	_check(
		owner.submit(0, [], bad).action == "invalid" and owner.snapshot() == before,
		"duplicate_committed_card_rejected_atomically"
	)
	bad = _order(world, 0)
	bad["damage"] = 100
	_check(owner.submit(0, [], bad).action == "invalid", "caller_cannot_submit_resolved_damage")
	bad = _order(world, 0)
	bad.action = "Hunt"
	_check(owner.submit(0, [], bad).action == "invalid", "unsupported_combat_action_rejected")
	var castle_id: String = Ids.identity("castle", "castle:1")
	var selected: Array = world.data.card_zones.hands[0].slice(0, 2)
	var ruin: Dictionary = Decl.create(
		MatchOwner.declaration_id(0, 1, 0),
		0,
		"Gremory",
		Gremory.RUIN,
		1,
		Timeline.ROUND_START_SCHEDULED,
		2,
		0,
		"public",
		{"entity_id": castle_id},
		{"discard_ids": selected},
		{}
	)
	_check(
		(
			owner.submit(0, [ruin], _order(world, 0)).action == "invalid"
			and owner.snapshot() == before
		),
		"power_payment_and_commitment_cannot_spend_same_cards"
	)
	owner.submit(0, [], _order(world, 0))
	var malformed: Dictionary = owner.snapshot()
	malformed.combat_orders[0].card_ids = ["invented"]
	var restored = _new_match()
	_check(
		restored.restore(malformed).action == "invalid",
		"restore_rejects_unknown_committed_identity"
	)
	owner.submit(1, [])
	if not _drive(owner, Timeline.COMMITMENT_REVEAL):
		return
	malformed = owner.snapshot()
	malformed.combat_orders[0].card_ids[0] = world.data.card_zones.hands[0][3]
	_check(
		restored.restore(malformed).action == "invalid",
		"restore_rejects_existing_but_uncommitted_card"
	)
	malformed = owner.snapshot()
	malformed.world.data["marching_round"] = 1
	_check(
		restored.restore(malformed).action == "invalid",
		"restore_rejects_phase_ledger_ahead_of_cursor"
	)


func _fractional_positions() -> void:
	var world: Dictionary = _world()
	var unit: String = _spawn(world, "fractional", 0, "Vulture", 0)
	var entities = Ids.new()
	entities.restore(world.entities)
	var before_entities: Dictionary = entities.snapshot()
	var attributes: Dictionary = entities.get_entity(unit).attributes
	attributes["x_fp"] = 0.5
	_check(
		(
			entities.update(unit, 0, attributes).action == "invalid"
			and entities.snapshot() == before_entities
		),
		"fractional_registry_update_rejected_atomically"
	)
	var valid_owner = _new_match()
	if not _check(
		valid_owner.start("seed", world, [0, 1]).action != "invalid",
		"integer_position_control_starts"
	):
		return
	# Intentionally corrupt raw external data. The normal _edit helper uses
	# Ids.update, which rejects *_fp fractions before they can enter the world.
	var malformed_world: Dictionary = world.duplicate(true)
	_entity(malformed_world, unit).attributes["x_fp"] = 0.5
	if not _check(
		_entity(malformed_world, unit).attributes.x_fp == 0.5,
		"fractional_fixture_contains_fraction"
	):
		return
	_check(not Marching.valid(malformed_world), "marching_validator_rejects_fractional_position")
	var invalid_owner = _new_match()
	var before_start: Dictionary = invalid_owner.snapshot()
	_check(
		(
			invalid_owner.start("seed", malformed_world, [0, 1]).action == "invalid"
			and invalid_owner.snapshot() == before_start
		),
		"fractional_marching_position_rejected"
	)
	var before_restore: Dictionary = valid_owner.snapshot()
	var malformed_snapshot: Dictionary = before_restore.duplicate(true)
	_entity(malformed_snapshot.world, unit).attributes["x_fp"] = 0.5
	_check(
		(
			valid_owner.restore(malformed_snapshot).action == "invalid"
			and valid_owner.snapshot() == before_restore
		),
		"fractional_marching_restore_rejected_atomically"
	)


func _real_ruin_fizzle() -> void:
	var world: Dictionary = _world()
	var owner = _fixture(world)
	if owner == null:
		return
	var castle_id: String = Ids.identity("castle", "castle:1")
	var hand: Array = world.data.card_zones.hands[0]
	var ruin: Dictionary = Decl.create(
		MatchOwner.declaration_id(0, 1, 0),
		0,
		"Gremory",
		Gremory.RUIN,
		1,
		Timeline.ROUND_START_SCHEDULED,
		2,
		0,
		"public",
		{"entity_id": castle_id},
		{"discard_ids": hand.slice(0, 2)},
		{}
	)
	var siege: Dictionary = _order(world, 0, 0)
	siege.card_ids = hand.slice(2, 3)
	_check(
		owner.submit(0, [ruin], siege).action != "invalid", "ruin_and_siege_use_distinct_paid_cards"
	)
	owner.submit(1, [])
	if not _drive(owner):
		return
	_check(
		_entity(owner.snapshot().world, castle_id).is_empty(),
		"real_siege_removes_prepared_ruin_target"
	)
	var before: Dictionary = owner.snapshot().world.data.card_zones.duplicate(true)
	_check(owner.begin_next_round([1, 0]).action != "invalid", "combat_match_begins_second_round")
	_check(owner.run_next_hook().action != "invalid", "prepared_ruin_fizzles_at_next_round_start")
	_check(
		owner.snapshot().world.data.card_zones == before,
		"fizzled_ruin_does_not_refund_or_spend_again"
	)
	_check(
		_events(owner.snapshot().events.rows, "FIZZLE_INVALID_TARGET").size() == 1,
		"real_destroyed_identity_causes_one_ruin_fizzle"
	)
	if not _drive(owner, Timeline.SUBMISSION_LOCK):
		return
	owner.submit(0, [])
	owner.submit(1, [])
	if not _drive(owner):
		return
	_check(owner.snapshot().world.data.marching_round == 2, "phase_ledgers_advance_across_rounds")


func _events(rows: Array, kind: String) -> Array:
	var result: Array = []
	for row in rows:
		if row.event.type == kind:
			result.append(row.event)
	return result


func _drive(owner, stop: String = "") -> bool:
	for index in range(21):
		if owner.next_hook().is_empty() or owner.next_hook() == stop:
			return true
		var result: Dictionary = owner.run_next_hook()
		if result.action == "invalid":
			print("MARCHING INTEGRATION HOOK ERROR: ", owner.next_hook(), " ", result)
			_check(false, "combat_hook_failed")
			return false
	return _check(false, "combat_hook_limit")


func _check(condition: bool, label: String) -> bool:
	if condition:
		print("PASS  " + label)
	else:
		failures += 1
		print("FAIL  " + label)
	return condition
