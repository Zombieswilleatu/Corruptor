extends "res://Scripts/Sim/U13GuardDeploymentTestRunner.gd"


func _run() -> void:
	for threat in [2, 3]:
		_banish(threat)
	_finish("Orias Mark")


func _mark_world(threat: int) -> Dictionary:
	var world: Dictionary = _world()
	_patch(world, world.players[1].lord_entity_id, {"threat": threat})
	for id in world.data.card_zones.hands[0].slice(0, 2):
		_patch(world, id, {"suit": "Butcher", "value": 5})
	world.data.sigils[1].Lord = ""
	return world


func _banish(threat: int):
	var world: Dictionary = _mark_world(threat)
	var owner = _ready(world)
	if owner == null:
		return null
	var souls: int = world.players[0].resources.souls
	var tears: int = world.data.neutral_tears
	var order: Dictionary = {
		"action": "Hunt",
		"lane": "Lord",
		"target_id": world.players[1].lord_entity_id,
		"card_ids": owner.player_view(0).world.hand.slice(0, 2)
	}
	if (
		not _ok(owner.submit(0, [], order), "mark_hunt_sealed")
		or not _ok(owner.submit(1, [], {}), "mark_opponent_sealed")
	):
		return null
	var replay = Content.new().create_combat_match()
	if not _ok(
		replay.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))), "mark_sealed_json"
	):
		return null
	while owner.next_hook() != Timeline.POST_RESOLUTION_SPAWNS:
		if owner.next_hook().is_empty():
			_check(false, "mark_reaches_combat")
			return null
		if (
			not _ok(owner.run_next_hook(), "mark_owner_hook")
			or not _ok(replay.run_next_hook(), "mark_replay_hook")
		):
			return null
		_check(owner.snapshot() == replay.snapshot(), "mark_replay_exact")
	var result: Dictionary = owner.snapshot().world
	_check(not _entity(result, order.target_id).attributes.alive, "mark_real_banishment")
	_check(
		result.players[0].resources.souls - souls == (4 if threat == 3 else 2),
		"mark_bonus_souls_threshold"
	)
	_check(
		result.data.neutral_tears - tears == (2 if threat == 3 else 1), "mark_bonus_tear_threshold"
	)
	_check((result.data.orias_marks[1] != null) == (threat == 3), "mark_only_at_threat_three")
	_check(
		_entity(result, order.target_id).attributes.threat == 0,
		"mark_reads_threat_before_banish_reset"
	)
	_json(owner, "mark_postcombat_json")
	if threat == 3:
		var saved: Dictionary = owner.snapshot()
		for key in ["lord_id", "marked_by", "round", "event_id"]:
			var bad: Dictionary = saved.duplicate(true)
			bad.world.data.orias_marks[1][key] = 99 if key == "round" else "forged"
			_check(
				owner.restore(bad).action == "invalid" and owner.snapshot() == saved,
				"mark_forged_ledger_" + key
			)
	return owner
