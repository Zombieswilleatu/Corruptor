extends "res://Scripts/Sim/U13KalliganTestRunner.gd"

const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")


func _run() -> void:
	_admission()
	_reaction_privacy()
	_lifecycle_replay()
	_armed_banishment()
	print("U13 Kalligan integration failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _reaction_privacy() -> void:
	var owner = _owner()
	if owner == null:
		return
	var event: Dictionary = {
		"type": "GEM_DAGGER", "text": "", "data": {"player_id": 1, "drawn_ids": ["private-card"]}
	}
	var public_event: Dictionary = {
		"type": "GEM_DAGGER", "text": "", "data": {"player_id": 1, "count": 1}
	}
	var before: int = owner._event_cursor()
	var applied: Dictionary = owner._apply_transform(
		{
			"action": "resolved",
			"world": owner.snapshot().world,
			"events": [{"event": event, "views": [public_event, event]}]
		},
		Candidates.source(0, 1, Content.PYROCLASM)
	)
	_check(applied.action != "invalid", "public_power_accepts_reaction_event_views")
	_check(
		(
			owner._player_events_since(0, before) == [public_event]
			and owner._player_events_since(1, before) == [event]
		),
		"public_power_does_not_reveal_opponent_draw"
	)


func _admission() -> void:
	var owner = _owner()
	if owner == null or not _to_submission(owner):
		return
	var before: Dictionary = owner.snapshot()
	var source: Dictionary = Candidates.source(
		0, 1, Content.INFERNO, {"kind": "lane", "lane": "Lord"}
	)
	_check(
		owner.preview_submission(0, [source], {}).action != "invalid",
		"inferno_shared_declaration_legal"
	)
	_check(
		(
			owner.preview_submission(0, [Candidates.source(0, 1, Content.PYROCLASM)], {}).action
			== "invalid"
		),
		"pyroclasm_requires_existing_scorch"
	)
	for condition in ["parameters", "own_guard", "lane_owner", "duplicate"]:
		var bad: Dictionary = source.duplicate(true)
		match condition:
			"parameters":
				bad.parameters["intensity"] = 99
			"own_guard":
				bad.target = {"kind": "guard", "lane": "Lord", "player_id": 0}
			"lane_owner":
				bad.target["player_id"] = 1
		var submitted: Array = [bad]
		if condition == "duplicate":
			submitted.append(Candidates.source(0, 1, Content.INFERNO, source.target, 1))
		_check(
			owner.preview_submission(0, submitted, {}).action == "invalid",
			"inferno_rejects_" + condition
		)
	_check(owner.snapshot() == before, "kalligan_previews_are_atomic")
	_check(
		(
			(
				Content
				. Humbaba
				. new()
				. create_combat_match()
				. start("wrong-adapter", Scenario.world(), [0, 1])
				. action
			)
			== "invalid"
		),
		"old_content_rejects_kalligan_profile"
	)


func _lifecycle_replay() -> void:
	var owner = _owner()
	var replay = _owner()
	if owner == null or replay == null:
		return
	var first_id: String = ""
	var original: Dictionary = {}
	for round_number in range(1, 7):
		print("KALLIGAN REPLAY round=", round_number, "/6")
		while not owner.next_hook().is_empty():
			var hook: String = owner.next_hook()
			if hook == Timeline.SUBMISSION_LOCK:
				var target: Dictionary = {"kind": "guard", "lane": "Castle", "player_id": 1}
				if round_number == 2:
					target = {"kind": "lane", "lane": "Lord"}
				elif round_number == 3:
					target = {"kind": "guard", "lane": "Lord", "player_id": 1}
				var inferno: Dictionary = Candidates.source(
					0, round_number, Content.INFERNO, target
				)
				var can_inferno: bool = (
					owner.preview_submission(0, [inferno], {}).action != "invalid"
				)
				_check(
					can_inferno == (round_number in [1, 2, 3, 6]),
					"inferno_create_relocate_expiration_readiness_" + str(round_number)
				)
				var pyro: Dictionary = Candidates.source(0, round_number, Content.PYROCLASM)
				_check(
					(
						(owner.preview_submission(0, [pyro], {}).action != "invalid")
						== (round_number in [2, 3, 4])
					),
					"pyroclasm_active_only_" + str(round_number)
				)
				var powers: Array = [inferno] if round_number <= 3 else []
				if round_number in [2, 3]:
					powers.append(Candidates.source(0, round_number, Content.PYROCLASM, {}, 1))
				elif round_number == 4:
					powers.append(pyro)
				for match_owner in [owner, replay]:
					if not _check(
						match_owner.submit(0, powers, {}).action != "invalid",
						"kalligan_queue_accepted"
					):
						return
					match_owner.submit(1, [], {})
			var left: Dictionary = owner.run_next_hook()
			var right: Dictionary = replay.run_next_hook()
			if not _check(
				left.action != "invalid" and right.action != "invalid",
				"kalligan_hook_" + hook + "_" + str(left.get("reason", "ok"))
			):
				return
			_check(owner.snapshot() == replay.snapshot(), "kalligan_exact_replay_" + hook)
			if (
				hook
				in [
					Timeline.PERSISTENT_ADVANCEMENT,
					Timeline.SUBMISSION_LOCK,
					Timeline.POST_RESOLUTION_DIRECT,
					Timeline.AFTERMATH
				]
			):
				var saved: Dictionary = owner.snapshot()
				var restored = Content.new().create_combat_match()
				var loaded: Dictionary = restored.restore(JSON.parse_string(JSON.stringify(saved)))
				_check(
					loaded.action != "invalid" and restored.snapshot() == saved,
					"kalligan_json_restore_" + hook + "_" + str(loaded.get("reason", "ok"))
				)
			if hook == Timeline.PERSISTENT_ADVANCEMENT:
				var active: Array = owner.snapshot().persistent.active
				if round_number in [2, 3, 4]:
					if not _check(active.size() == 1, "scorch_single_instance"):
						return
					if round_number == 2:
						first_id = active[0].effect_id
						original = active[0].declaration.duplicate(true)
					_check(
						(
							active[0].effect_id == first_id
							and active[0].declaration == original
							and active[0].activated_round == 2
						),
						"relocation_preserves_identity_and_original_declaration"
					)
					_check(
						(
							active[0].stages[active[0].stage_index].intensity
							== (2 if round_number == 3 else 1)
						),
						"scorch_one_two_one"
					)
					var expected: Dictionary = (
						{"kind": "guard", "lane": "Castle", "player_id": 1}
						if round_number == 2
						else (
							{"kind": "lane", "lane": "Lord"}
							if round_number == 3
							else {"kind": "guard", "lane": "Lord", "player_id": 1}
						)
					)
					_check(
						active[0].target == expected, "prepared_relocation_applies_before_pulses"
					)
					if round_number == 3:
						_forged_snapshots(owner)
				else:
					_check(active.is_empty(), "no_early_or_expired_scorch")
		if round_number < 6:
			owner.begin_next_round([0, 1])
			replay.begin_next_round([0, 1])


func _forged_snapshots(owner) -> void:
	var pristine: Dictionary = owner.snapshot()
	for field in ["intensity", "lifetime", "target", "relocation", "ledger", "cooldown"]:
		var bad: Dictionary = pristine.duplicate(true)
		match field:
			"intensity":
				bad.persistent.active[0].stages[1].intensity = 200
			"lifetime":
				bad.persistent.active[0].activated_round = 3
			"target":
				bad.persistent.active[0].target = {
					"kind": "guard", "lane": "Castle", "player_id": 0
				}
			"relocation":
				bad.persistent.active[0].payload.last_relocation.fire_round = 7
			"ledger":
				bad.world.data.scorch_lane_round = 3
			"cooldown":
				bad.cooldowns.locks[0].cooldown_rounds = 99
		_check(
			owner.restore(bad).action == "invalid" and owner.snapshot() == pristine,
			"scorch_restore_rejects_" + field + "_atomically"
		)


func _armed_banishment() -> void:
	var owner = _owner()
	if owner == null or not _to_submission(owner):
		return
	owner.submit(
		0, [Candidates.source(0, 1, Content.INFERNO, {"kind": "lane", "lane": "Lord"})], {}
	)
	owner.submit(1, [], {})
	if not _check(owner.run_next_hook().action != "invalid", "prepared_inferno_locked"):
		return
	# Install a post-lock Banishment fixture using the authoritative battle
	# transition. Admission already happened; firing must not recheck alive.
	var saved: Dictionary = owner.snapshot()
	var battle: Dictionary = Battle.apply(
		saved.world,
		{
			"command_id": "armed-banishment",
			"kind": "banish_lord",
			"target_id": saved.world.players[0].lord_entity_id
		},
		1,
		Timeline.COMBAT_RESOLUTION
	)
	saved.world = battle.world
	if not _check(owner.restore(saved).action != "invalid", "armed_banishment_fixture_restores"):
		return
	while not owner.next_hook().is_empty():
		if owner.run_next_hook().action == "invalid":
			_check(false, "armed_banishment_round_failed")
			return
	owner.begin_next_round([0, 1])
	if not _to_submission(owner):
		return
	_check(owner.snapshot().persistent.active.size() == 1, "prepared_inferno_survives_banishment")
	_check(
		(
			owner.preview_submission(0, [Candidates.source(0, 2, Content.PYROCLASM)], {}).action
			== "invalid"
		),
		"banished_source_cannot_make_new_declarations"
	)
