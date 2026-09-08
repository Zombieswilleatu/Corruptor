extends "res://Scripts/Sim/U13HumbabaTestRunner.gd"

const Candidates = preload("res://Scripts/Sim/U13HumbabaCandidates.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")


func _run() -> void:
	print("HUMBABA STAGE admission")
	_admission()
	print("HUMBABA STAGE cooldown_replay")
	_cooldown_replay()
	print("HUMBABA STAGE hunt_and_armed_muster")
	_hunt_and_armed_muster()
	print("U13 Humbaba integration failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _owner():
	var owner = Content.new().create_combat_match()
	var started: Dictionary = owner.start("humbaba-integration", Scenario.world(), [0, 1])
	if not _check(started.action != "invalid", "humbaba_owner_starts"):
		return null
	return owner


func _to_submission(owner) -> bool:
	while owner.next_hook() != Timeline.SUBMISSION_LOCK:
		if not _check(owner.run_next_hook().action != "invalid", "humbaba_opening_hook"):
			return false
	return true


func _admission() -> void:
	var owner = _owner()
	if owner == null or not _to_submission(owner):
		return
	var before: Dictionary = owner.snapshot()
	var source: Dictionary = Candidates.source(0, 1, "Castle")
	_check(owner.preview_submission(0, [source], {}).action != "invalid", "muster_shared_admission")
	_check(
		owner.preview_submission(0, [source, source], {}).action == "invalid",
		"muster_duplicate_rejected"
	)
	var wrong: Dictionary = source.duplicate(true)
	wrong.target.lane = "Elsewhere"
	_check(
		owner.preview_submission(0, [wrong], {}).action == "invalid", "muster_invalid_lane_rejected"
	)
	wrong = source.duplicate(true)
	wrong.target["entity_id"] = _lord(before.world, 1).id
	_check(
		owner.preview_submission(0, [wrong], {}).action == "invalid",
		"muster_extraneous_target_rejected"
	)
	wrong = source.duplicate(true)
	wrong.parameters["count"] = 99
	_check(
		owner.preview_submission(0, [wrong], {}).action == "invalid", "muster_caller_count_rejected"
	)
	_check(owner.snapshot() == before, "muster_previews_and_rejections_atomic")
	_check(owner.player_view(0, 0).world.lord_stats[0].threat == null, "humbaba_view_threat_absent")
	for kind in ["threat", "end_round", "breach_entry", "fractional"]:
		var bad: Dictionary = before.duplicate(true)
		match kind:
			"threat":
				_lord(bad.world, 0).attributes["threat"] = 0
			"end_round":
				bad.world.data.humbaba_end_round = 1
			"breach_entry":
				bad.world.data.humbaba_breach_entries["forged"] = 1
			"fractional":
				bad.world.data.humbaba_end_round = 0.5
		_check(
			owner.restore(bad).action == "invalid" and owner.snapshot() == before,
			"humbaba_corrupt_restore_atomic_" + kind
		)
	_check(not Content.rules().has("BreathOfLife"), "breath_waits_for_lane_aura_foundation")


func _cooldown_replay() -> void:
	var a = _owner()
	var b = _owner()
	if a == null or b == null:
		return
	for round_number in range(1, 4):
		print("HUMBABA ROUND ", round_number, "/3")
		while not a.next_hook().is_empty():
			var hook: String = a.next_hook()
			if hook == Timeline.SUBMISSION_LOCK:
				var source: Dictionary = Candidates.source(0, round_number, "Lord")
				var ready: bool = a.preview_submission(0, [source], {}).action != "invalid"
				_check(ready == (round_number != 2), "muster_cooldown_round_" + str(round_number))
				for owner in [a, b]:
					if not _check(
						owner.submit(0, [source] if ready else [], {}).action != "invalid",
						"muster_round_submission"
					):
						return
					owner.submit(1, [], {})
			var left: Dictionary = a.run_next_hook()
			var right: Dictionary = b.run_next_hook()
			if not _check(
				left.action != "invalid" and right.action != "invalid", "humbaba_hook_" + hook
			):
				return
			_check(a.snapshot() == b.snapshot(), "humbaba_replay_" + hook)
			if hook in [Timeline.POST_RESOLUTION_SPAWNS, Timeline.END_MARCHING_CHECKS]:
				var checkpoint: Dictionary = a.snapshot()
				var restored = Content.new().create_combat_match()
				_check(
					(
						(
							restored.restore(JSON.parse_string(JSON.stringify(checkpoint))).action
							!= "invalid"
						)
						and restored.snapshot() == checkpoint
					),
					"humbaba_json_restore_" + hook
				)
			if hook == Timeline.POST_RESOLUTION_SPAWNS and round_number == 1:
				var units: Array = []
				for entity in a.snapshot().world.entities.entities:
					if entity.kind == "marcher":
						units.append(entity)
				_check(units.size() == 3, "muster_exactly_three_penitents")
				var positions: Dictionary = {}
				for unit in units:
					_check(
						(
							unit.owner == 0
							and unit.attributes.suit == "Penitent"
							and unit.attributes.lane == "Lord"
							and unit.attributes.movement_ready_round == 1
						),
						"muster_owner_lane_stats_and_immediate_readiness"
					)
					positions[Vector2i(unit.attributes.x_fp, unit.attributes.y_fp)] = true
				_check(positions.size() == 3, "muster_real_spawn_positions_spread")
		if round_number < 3:
			_check(
				(
					a.begin_next_round([0, 1]).action != "invalid"
					and b.begin_next_round([0, 1]).action != "invalid"
				),
				"humbaba_next_round"
			)


func _hunt_and_armed_muster() -> void:
	var owner = _owner()
	if owner == null or not _to_submission(owner):
		return
	var world: Dictionary = owner.snapshot().world
	var cards: Array = world.data.card_zones.hands[1].slice(0, 2)
	var order: Dictionary = {
		"action": "Hunt", "lane": "Lord", "target_id": _lord(world, 0).id, "card_ids": cards
	}
	var equal_order: Dictionary = order.duplicate(true)
	equal_order.card_ids = cards.slice(0, 1)
	# A single value-4 Butcher exactly matches the two-Castle defense of 4.
	# This detached fixture does not change the owner's actual value-3 hand.
	_entity(world, cards[0]).attributes.value = 4
	var context: Dictionary = _context(world, Timeline.COMBAT_RESOLUTION)
	context.combat_orders = [{}, equal_order]
	var content = Content.new()
	var equal: Dictionary = Combat._resolve(context, Callable(content, "react"))
	if _check(equal.action == "resolved", "woven_hunt_equality_resolves"):
		var fact: Dictionary = equal.events.back().event.data
		_check(
			fact.strength == 4 and fact.lord_defense == 4 and not fact.banished,
			"woven_hunt_requires_strictly_more_than_defense"
		)
	_check(
		owner.submit(0, [Candidates.source(0, 1, "Castle")], {}).action != "invalid",
		"muster_armed_before_hunt"
	)
	_check(owner.submit(1, [], order).action != "invalid", "humbaba_enemy_hunt_legal")
	var saw_entry: bool = false
	var saw_muster: bool = false
	while not owner.next_hook().is_empty():
		var hook: String = owner.next_hook()
		var cursor: int = owner._event_cursor()
		if not _check(owner.run_next_hook().action != "invalid", "armed_muster_hook_" + hook):
			return
		var snapshot: Dictionary = owner.snapshot()
		if hook == Timeline.COMBAT_RESOLUTION:
			_check(
				(
					not _lord(snapshot.world, 0).attributes.alive
					and snapshot.world.data.breach_lord == "Humbaba"
				),
				"hunt_banishes_humbaba_into_breach"
			)
			for event in owner._player_events_since(0, cursor):
				if event.type == "THE_STONES_FORGET":
					saw_entry = true
			_check(
				snapshot.world.data.neutral_tears == 2,
				"hunt_and_castle_destruction_tears_independent"
			)
			var restored = Content.new().create_combat_match()
			_check(
				restored.restore(JSON.parse_string(JSON.stringify(snapshot))).action != "invalid",
				"stones_entry_json_restores"
			)
			var before: Dictionary = restored.snapshot()
			var entries: Dictionary = snapshot.world.data.humbaba_breach_entries
			var id: String = entries.keys()[0]
			var replayed: Dictionary = content.react(
				snapshot.world,
				{
					"type": "BREACH_CHANGED",
					"text": "",
					"data":
					{
						"event_id": id,
						"round": 1,
						"hook": hook,
						"lord_id": "Humbaba",
						"source_id": _lord(snapshot.world, 0).id
					}
				},
				"humbaba-integration",
				[0, 1]
			)
			_check(
				replayed.world == before.world and replayed.events.is_empty(),
				"stones_restored_entry_does_not_refire"
			)
		if hook == Timeline.POST_RESOLUTION_SPAWNS:
			var count: int = 0
			for unit in snapshot.world.entities.entities:
				if (
					unit.kind == "marcher"
					and unit.owner == 0
					and unit.attributes.suit == "Penitent"
				):
					count += 1
			saw_muster = count == 3
	_check(saw_entry and saw_muster, "armed_muster_survives_banishment_after_stones_forget")
