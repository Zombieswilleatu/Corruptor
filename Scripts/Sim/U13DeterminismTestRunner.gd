extends SceneTree

const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Log = preload("res://Scripts/Sim/U13EventLog.gd")
var failures: int = 0


func _init() -> void:
	_test_rng()
	_test_ids()
	_test_events()
	print("U13 determinism and identity failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _test_rng() -> void:
	# Independent Python hashlib vectors, including UTF-8 and rejection sampling.
	var vectors: Array = [
		["seed", "effect", "PRICE_DELAY", 0, 6, 5],
		["seed", "effect", "PRICE_TYPE", 0, 17, 6],
		["s:é", "龍", "target", 42, 4294967296, 3876510453],
		["seed", "effect", "PRICE_TARGET", 3, 2147483649, 169728365]
	]
	for row in vectors:
		var result: Dictionary = Rng.draw(row[0], row[1], row[2], row[3], row[4])
		_check(result.get("value") == row[5], "rng_golden_" + row[2])
	var before: Dictionary = Rng.draw("seed", "effect", "PRICE_DELAY", 0, 6)
	for index in range(30):
		Rng.draw("seed", "unrelated", "OTHER", index, 100)
	_check(
		Rng.draw("seed", "effect", "PRICE_DELAY", 0, 6) == before,
		"unrelated_rolls_do_not_shift_outcome"
	)
	_check(
		Rng.draw("seed", "effect", "purpose", -1, 6).action == "invalid",
		"rng_negative_index_rejected"
	)
	_check(
		Rng.draw("seed", "effect", "purpose", 0, 0).action == "invalid", "rng_empty_range_rejected"
	)
	_check(Rng.draw("seed", "effect", "purpose", 0, 1).value == 0, "rng_single_choice")
	_check(
		Rng.draw("a:b", "c", "p", 0, 4294967296) != Rng.draw("a", "b:c", "p", 0, 4294967296),
		"rng_key_boundaries_unambiguous"
	)


func _test_ids() -> void:
	var ids = Ids.new()
	var first: Dictionary = ids.create(
		"card", "deck:Butcher:1", 0, 0, {"suit": "Butcher", "value": 1, "role": "guard"}
	)
	var second: Dictionary = ids.create(
		"card", "deck:Butcher:1", 1, 0, {"suit": "Butcher", "value": 1}
	)
	_check(first.entity.id != second.entity.id, "duplicate_face_cards_have_distinct_identity")
	var stable: String = first.entity.id
	ids.update(
		stable, 1, {"suit": "Butcher", "value": 1, "role": "guard", "lane": "Castle", "x_fp": 700}
	)
	_check(
		ids.get_entity(stable).owner == 1 and ids.get_entity(stable).id == stable,
		"guard_move_and_allegiance_preserve_identity"
	)
	var castle: Dictionary = ids.create("castle", "setup:p0:Keep", 0, 0)
	ids.retire(castle.entity.id)
	_check(
		ids.create("castle", "setup:p0:Keep", 0, 0).action == "invalid",
		"destroyed_castle_identity_cannot_be_reused"
	)
	var rebuilt: Dictionary = ids.create("castle", "rebuild_effect_17", 0, 0)
	_check(
		rebuilt.entity.id != castle.entity.id and ids.get_entity(castle.entity.id).is_empty(),
		"rebuilt_castle_does_not_inherit_delayed_target"
	)
	_check(
		(
			Ids.identity("marcher", "spawn_effect_a", 0)
			!= Ids.identity("marcher", "spawn_effect_b", 0)
		),
		"separate_spawn_batches_do_not_collide"
	)
	var resumed = Ids.new()
	_check(
		(
			resumed.restore(JSON.parse_string(JSON.stringify(ids.snapshot()))).action != "invalid"
			and resumed.snapshot() == ids.snapshot()
		),
		"identity_json_replay"
	)
	_check(
		resumed.create("castle", "setup:p0:Keep", 0, 0).action == "invalid",
		"retired_ledger_survives_restore"
	)
	var before: Dictionary = ids.snapshot()
	var corrupt: Dictionary = before.duplicate(true)
	corrupt.entities[0].id = "forged"
	_check(
		ids.restore(corrupt).action == "invalid" and ids.snapshot() == before,
		"forged_identity_restore_atomic"
	)


func _test_events() -> void:
	var log = Log.new()
	var secret: Dictionary = {
		"type": "PRICE_ARMED",
		"text": "secret outcome",
		"data": {"outcome": "HIDDEN", "due_round": 4}
	}
	var visible: Dictionary = {"type": "PRICE_ARMED", "text": "", "data": {"due_round": 4}}
	log.append(secret, [visible, visible])
	log.append({"type": "INTERNAL", "text": "", "data": {"secret": 7}}, [null, null])
	for player_id in [0, 1]:
		_check(
			log.for_player(player_id) == [visible],
			"hidden_outcome_redacted_even_for_owner_%d" % player_id
		)
	_check(JSON.stringify(log.snapshot()).contains("HIDDEN"), "authoritative_log_retains_secret")
	var resumed = Log.new()
	_check(
		(
			resumed.restore(JSON.parse_string(JSON.stringify(log.snapshot()))).action != "invalid"
			and resumed.snapshot() == log.snapshot()
		),
		"event_log_json_roundtrip"
	)
	var view: Array = log.for_player(0)
	view[0].data.due_round = 99
	_check(log.for_player(0)[0].data.due_round == 4, "viewer_cannot_mutate_log")
	var before: Dictionary = log.snapshot()
	_check(
		log.append(secret, [{"data": {}}, null]).action == "invalid" and log.snapshot() == before,
		"malformed_event_projection_atomic"
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		failures += 1
		print("FAIL  " + label)
