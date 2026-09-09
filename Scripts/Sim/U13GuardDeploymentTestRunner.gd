extends SceneTree

const Content = preload("res://Scripts/Sim/U13Orias.gd")
const Scenario = preload("res://Scripts/Sim/U13OriasScenario.gd")
const Candidates = preload("res://Scripts/Sim/U13OriasCandidates.gd")
const GremoryCandidates = preload("res://Scripts/Sim/U13GremoryCandidates.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const Timeline = Content.Timeline
const Guards = Content.Guards
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_deployment()
	_admission()
	_finish("Guard deployment")


func _finish(label: String) -> void:
	print("U13 %s failures: %d" % [label, failures])
	quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok


func _ok(result: Dictionary, label: String) -> bool:
	var success: bool = result.get("action", "invalid") != "invalid"
	if not success:
		print("DETAIL ", result)
	return _check(success, label)


# Six hand cards and empty Guard zones, one damaged operational Keep per side.
# This is a small rules fixture, not a production opening.
func _world(opponent: String = "Gremory") -> Dictionary:
	var world: Dictionary = Scenario.world(opponent)
	var ids = Content.Ids.new()
	ids.restore(world.entities)
	for card in ids.snapshot().entities:
		if card.kind == "card" and card.attributes.get("role") == "guard":
			card.attributes.erase("role")
			card.attributes.erase("lane")
			card.attributes.erase("slot")
			ids.update(card.id, card.owner, card.attributes)
			world.data.card_zones.hands[card.owner].append(card.id)
	for pid in [0, 1]:
		var castle: Dictionary = ids.get_entity(Slots.castle_id(pid, 0))
		castle.attributes.integrity = 12
		castle.attributes.status = "standing"
		castle.attributes.construction_state = "active"
		ids.update(castle.id, pid, castle.attributes)
	world.entities = ids.snapshot()
	return world


func _patch(world: Dictionary, id: String, values: Dictionary) -> void:
	var ids = Content.Ids.new()
	ids.restore(world.entities)
	var row: Dictionary = ids.get_entity(id)
	row.attributes.merge(values, true)
	ids.update(id, row.owner, row.attributes)
	world.entities = ids.snapshot()


func _entity(world: Dictionary, id: String) -> Dictionary:
	for row in world.entities.entities:
		if row.id == id:
			return row
	return {}


func _owner(world: Dictionary):
	var owner = Content.new().create_combat_match()
	if not _ok(owner.start("snare-guard-v1", world, [0, 1]), "guard_owner_starts"):
		return null
	return owner


func _drive(owner, stop: String) -> bool:
	while owner.next_hook() != stop:
		if owner.next_hook().is_empty():
			return _check(false, "guard_requested_hook_missing_" + stop)
		var hook: String = owner.next_hook()
		var result: Dictionary = owner.run_next_hook()
		if result.get("action", "invalid") == "invalid":
			return _ok(result, "guard_hook_" + hook)
	return true


func _ready(world: Dictionary):
	var owner = _owner(world)
	if owner == null or not _drive(owner, Timeline.SUBMISSION_LOCK):
		return null
	return owner


func _move(id: String, lane: String = "Lord", slot: int = 0) -> Dictionary:
	return {"card_id": id, "lane": lane, "slot": slot}


func _json(owner, label: String) -> bool:
	var restored = Content.new().create_combat_match()
	var snapshot: Dictionary = owner.snapshot()
	return _check(
		(
			(
				restored.restore(JSON.parse_string(JSON.stringify(snapshot))).get("action")
				== "u13_match_restored"
			)
			and restored.snapshot() == snapshot
		),
		label
	)


func _deployment() -> void:
	var owner = _ready(_world())
	if owner == null:
		return
	var cards: Array = owner.player_view(0).world.hand
	var order: Dictionary = {"guard_moves": [_move(cards[0]), _move(cards[1], "Castle", 2)]}
	var before: Dictionary = owner.snapshot()
	_check(
		owner.preview_submission(0, [], order).action != "invalid" and owner.snapshot() == before,
		"guard_preview_is_pure"
	)
	if not _ok(owner.submit(0, [], order), "guard_order_sealed"):
		return
	_check(
		owner.player_view(1).world.guard_commitments.is_empty(),
		"guard_selection_hidden_before_lock"
	)
	if (
		not _ok(owner.submit(1, [], {}), "guard_opponent_pass")
		or not _ok(owner.run_next_hook(), "guard_joint_lock")
	):
		return
	_check(
		cards[0] in owner.snapshot().world.data.card_zones.hands[0],
		"guard_stays_in_hand_until_development"
	)
	_check(
		(
			owner.player_view(0).world.guard_commitments == order.guard_moves
			and owner.player_view(1).world.guard_commitments.is_empty()
		),
		"guard_reservation_owner_only"
	)
	_check(
		not JSON.stringify(owner.player_view(1).events).contains("GUARDS_SEALED"),
		"guard_sealed_event_not_leaked"
	)
	_json(owner, "guard_locked_json_restore")
	if not _ok(owner.run_next_hook(), "guard_development_resolves"):
		return
	for move in order.guard_moves:
		var row: Dictionary = _entity(owner.snapshot().world, move.card_id)
		_check(
			(
				row.attributes.get("role") == "guard"
				and row.attributes.get("lane") == move.lane
				and row.attributes.get("slot") == move.slot
				and move.card_id not in owner.player_view(0).world.hand
			),
			"guard_physically_moves_" + move.lane
		)
	_check(Guards.Cards.valid(owner.snapshot().world), "guard_card_conservation")
	_json(owner, "guard_developed_json_restore")
	var snapshot: Dictionary = owner.snapshot()
	for mutation in ["card", "slot", "cap", "clock"]:
		var bad: Dictionary = snapshot.duplicate(true)
		if mutation == "card":
			bad.world.data.guard_orders[0].moves[0].card_id = "unknown"
		elif mutation == "slot":
			bad.world.data.guard_orders[0].moves[0].slot = 0.5
		elif mutation == "cap":
			bad.world.data.guard_public_limits[0] = 2
		else:
			bad.world.data.guard_deployment_round += 1
		_check(
			owner.restore(bad).action == "invalid" and owner.snapshot() == snapshot,
			"guard_corrupt_restore_atomic_" + mutation
		)


func _admission() -> void:
	var world: Dictionary = _world()
	var owner = _ready(world)
	if owner == null:
		return
	var cards: Array = owner.player_view(0).world.hand
	var orders: Array = [
		{"guard_moves": [_move(cards[0]), _move(cards[0], "Castle")]},
		{"guard_moves": [_move(cards[0]), _move(cards[1])]},
		{"guard_moves": [_move(world.data.card_zones.hands[1][0])]},
		{"guard_moves": [{"card_id": cards[0], "lane": "Lord", "slot": 0.5}]},
		{"guard_moves": [_move(cards[0], "Castle", 3)]},
		{"guard_moves": "bad"},
		{"action": "Ward", "lane": "Lord", "card_ids": "bad", "guard_moves": []},
		{
			"action": "Ward",
			"lane": "Lord",
			"card_ids": [cards[0]],
			"guard_moves": [_move(cards[0])]
		},
		{
			"castle_action":
			{
				"action": "Construct",
				"target_id": Slots.castle_id(0, 1),
				"card_ids": [cards[0]],
				"use_repair_token": false
			},
			"guard_moves": [_move(cards[0])]
		}
	]
	var before: Dictionary = owner.snapshot()
	for index in range(orders.size()):
		_check(
			owner.submit(0, [], orders[index]).action == "invalid" and owner.snapshot() == before,
			"guard_invalid_order_atomic_" + str(index)
		)
	var enemy_cards: Array = owner.player_view(1).world.hand
	var ruin: Dictionary = GremoryCandidates._source(
		1,
		1,
		"InevitableRuin",
		{"entity_id": Slots.castle_id(0, 0)},
		{"discard_ids": enemy_cards.slice(0, 2)}
	)
	_check(
		(
			(
				owner.preview_submission(1, [ruin], {"guard_moves": [_move(enemy_cards[0])]}).action
				== "invalid"
			)
			and owner.snapshot() == before
		),
		"guard_cannot_double_spend_power_cost"
	)
	var full: Array = []
	for index in range(6):
		full.append(_move(cards[index], "Lord" if index < 3 else "Castle", index % 3))
	_check(
		owner.preview_submission(0, [], {"guard_moves": full}).action != "invalid",
		"guard_normal_limit_six_across_two_zones"
	)
	var repair: Dictionary = {
		"castle_action":
		{
			"action": "Repair",
			"target_id": Slots.castle_id(0, 0),
			"card_ids": [cards[4]],
			"use_repair_token": false
		},
		"guard_moves": [_move(cards[0])]
	}
	_check(
		owner.preview_submission(0, [], repair).action != "invalid",
		"guard_repair_allows_distinct_hand_card"
	)
	var occupied: Dictionary = _world()
	var occupied_id: String = occupied.data.card_zones.hands[0].pop_back()
	_patch(occupied, occupied_id, {"role": "guard", "lane": "Lord", "slot": 0})
	var blocked = _ready(occupied)
	if blocked != null:
		_check(
			(
				blocked.preview_submission(0, [], {"guard_moves": [_move(cards[0])]}).action
				== "invalid"
			),
			"guard_existing_slot_cannot_be_overwritten"
		)
