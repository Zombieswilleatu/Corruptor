extends "res://Scripts/Sim/U13GuardDeploymentTestRunner.gd"

const Combat = preload("res://Scripts/Sim/U13Combat.gd")


func _run() -> void:
	_thresholds()
	_combat_and_replay()
	_finish("Orias pursuit")


func _thresholds() -> void:
	for opponent in ["Gremory", "Humbaba"]:
		for threat in [0, 1, 2, 3]:
			var world: Dictionary = _world(opponent)
			if opponent != "Humbaba":
				_patch(world, world.players[1].lord_entity_id, {"threat": threat})
			var owner = _ready(world)
			if owner == null:
				return
			var before: Dictionary = owner.snapshot()
			var view: Dictionary = owner.player_view(0).world
			var expected: int = 2 if opponent != "Humbaba" and threat >= 2 else 1
			_check(view.relentless_pursuit[0].strength_bonus == expected, "public_pursuit_%s_%d" % [opponent, threat])
			_check(view.relentless_pursuit[1].strength_bonus == 0, "opponent_has_no_pursuit")
			_check(owner.snapshot() == before, "pursuit_projection_read_only")
			_json(owner, "pursuit_public_checkpoint")


func _combat_and_replay() -> void:
	var world: Dictionary = _world()
	_patch(world, world.players[1].lord_entity_id, {"threat": 1})
	var attack_card: String = world.data.card_zones.hands[0][0]
	_patch(world, attack_card, {"suit": "Butcher", "value": 3})
	for slot in [0, 1]:
		var id: String = world.data.card_zones.hands[1].pop_back()
		_patch(world, id, {"role": "guard", "lane": "Lord", "slot": slot, "value": 1})
	world.data.sigils[1].Lord = ""
	var owner = _ready(world)
	if owner == null:
		return
	var order: Dictionary = {"action": "Hunt", "lane": "Lord", "target_id": world.players[1].lord_entity_id, "card_ids": [attack_card]}
	if not _ok(owner.submit(0, [], order), "pursuit_hunt_sealed") or not _ok(owner.submit(1, [], {}), "pursuit_opponent_pass"):
		return
	var clone = Content.new().create_combat_match()
	var saved = JSON.parse_string(JSON.stringify(owner.snapshot()))
	if not _ok(clone.restore(saved), "pursuit_sealed_restore"):
		return
	while owner.next_hook() != Timeline.COMBAT_RESOLUTION:
		if owner.next_hook().is_empty():
			_check(false, "pursuit_reaches_combat")
			return
		if not _ok(owner.run_next_hook(), "pursuit_precombat_hook") or not _ok(clone.run_next_hook(), "pursuit_replay_precombat_hook"):
			return
		_check(owner.snapshot() == clone.snapshot(), "pursuit_precombat_replay_equal")
	if not _ok(owner.run_next_hook(), "pursuit_combat_resolves") or not _ok(clone.run_next_hook(), "pursuit_replay_combat_resolves"):
		return
	_check(owner.snapshot() == clone.snapshot(), "pursuit_combat_replay_equal")
	var result: Dictionary = owner.snapshot().world
	var target: Dictionary = _entity(result, world.players[1].lord_entity_id)
	_check(target.attributes.alive, "pursuit_does_not_recalculate_after_accelerate")
	_check(target.attributes.threat == 2, "accelerate_once_for_two_guards")
	_check(result.data.orias_accelerate[0].round == 1, "accelerate_records_round")
	_check(result.data.orias_accelerate[1] == null, "accelerate_only_credited_attacker")
	_json(owner, "accelerate_postcombat_checkpoint")
	var before: Dictionary = owner.snapshot()
	var bad: Dictionary = before.duplicate(true)
	bad.world.data.orias_accelerate[0].round = 2
	_check(owner.restore(bad).action == "invalid" and owner.snapshot() == before, "accelerate_future_ledger_rejected_atomically")
