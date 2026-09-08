extends "res://Scripts/Sim/U13HumbabaIntegrationTestRunner.gd"

const Bot = preload("res://Scripts/Sim/U13RandomLegal.gd")


func _run() -> void:
	_admission_and_bot()
	print("BREATH STAGE lifetime_replay")
	_lifetime_replay()
	print("BREATH STAGE canonical_regeneration")
	_regeneration_owner()
	print("BREATH STAGE armed_after_banishment")
	_armed_after_banishment()
	print("U13 Breath of Life failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _admission_and_bot() -> void:
	var owner = _owner()
	if owner == null or not _to_submission(owner):
		return
	var before: Dictionary = owner.snapshot()
	var source: Dictionary = Candidates.source(0, 1, "Lord", Content.BREATH)
	_check(owner.preview_submission(0, [source], {}).action != "invalid", "breath_shared_admission")
	for condition in ["lane", "extra_target", "parameters", "duplicate"]:
		var bad: Dictionary = source.duplicate(true)
		match condition:
			"lane":
				bad.target.lane = "Elsewhere"
			"extra_target":
				bad.target["entity_id"] = _lord(before.world, 0).id
			"parameters":
				bad.parameters["speed_percent"] = 99
		var powers: Array = [bad, bad] if condition == "duplicate" else [bad]
		_check(
			owner.preview_submission(0, powers, {}).action == "invalid",
			"breath_rejects_" + condition
		)
	var provider: Callable = func(match_owner, pid: int) -> Dictionary:
		var vocabulary: Dictionary = Candidates.enumerate(match_owner, pid)
		var breath: Array = []
		for candidate in vocabulary.powers:
			if candidate.power_id == Content.BREATH:
				breath.append(candidate)
		return {"action": "candidate_vocabulary", "powers": breath, "orders": []}
	var chosen: Dictionary = Bot.plan(owner, 0, provider)
	_check(
		chosen == Bot.plan(owner, 0, provider) and chosen.action != "invalid",
		"breath_keyed_choice_replays"
	)
	if chosen.action != "invalid":
		_check(
			chosen.powers.size() == 1 and chosen.powers[0].power_id == Content.BREATH,
			"breath_random_path_produces_declaration"
		)
		_check(
			owner.preview_submission(0, chosen.powers, chosen.order).action != "invalid",
			"breath_random_submission_uses_legality"
		)
	_check(owner.snapshot() == before, "breath_previews_and_chooser_are_pure")


# Empty field keeps the five-round timing/replay gate cheap. Actual moving
# bodies, healing, lane changes and Rout composition live in U13LaneAuras.
func _lifetime_replay() -> void:
	var owner = _owner()
	var replay = _owner()
	if owner == null or replay == null:
		return
	for round_number in range(1, 6):
		print("BREATH ROUND ", round_number, "/5")
		while not owner.next_hook().is_empty():
			var hook: String = owner.next_hook()
			if hook == Timeline.SUBMISSION_LOCK:
				var source: Dictionary = Candidates.source(0, round_number, "Lord", Content.BREATH)
				# Exercise the shared immediate-fire sentinel as well as explicit
				# firing rounds used by the bot and the armed-Banishment fixture.
				source.fire_round = -1
				var ready: bool = owner.preview_submission(0, [source], {}).action != "invalid"
				_check(
					ready == (round_number in [1, 5]), "breath_readiness_round_" + str(round_number)
				)
				for match_owner in [owner, replay]:
					if not _check(
						(
							match_owner.submit(0, [source] if round_number == 1 else [], {}).action
							!= "invalid"
						),
						"breath_submission"
					):
						return
					match_owner.submit(1, [], {})
			if not _check(
				(
					owner.run_next_hook().action != "invalid"
					and replay.run_next_hook().action != "invalid"
				),
				"breath_hook_" + hook
			):
				return
			var snapshot: Dictionary = owner.snapshot()
			_check(snapshot == replay.snapshot(), "breath_replay_" + hook)
			if (
				hook
				in [
					Timeline.PERSISTENT_ADVANCEMENT,
					Timeline.POST_RESOLUTION_MOVEMENT_STATE,
					Timeline.AFTERMATH
				]
			):
				var restored = Content.new().create_combat_match()
				_check(
					(
						(
							restored.restore(JSON.parse_string(JSON.stringify(snapshot))).action
							!= "invalid"
						)
						and restored.snapshot() == snapshot
					),
					"breath_json_" + hook
				)
			if hook == Timeline.POST_RESOLUTION_MOVEMENT_STATE:
				_check(
					snapshot.persistent.active.size() == (1 if round_number <= 2 else 0),
					"breath_two_active_rounds_" + str(round_number)
				)
				if round_number == 1:
					_check(
						(
							snapshot.persistent.active[0].payload
							== {"lane_aura": {"regen_bonus": 1, "speed_percent": 25}}
						),
						"breath_registry_owns_modifiers"
					)
					_corrupt_snapshots(owner)
			if hook == Timeline.PERSISTENT_ADVANCEMENT and round_number == 3:
				_check(
					(
						snapshot.cooldowns.locks.size() == 1
						and snapshot.cooldowns.locks[0].first_blocked_round == 3
						and snapshot.cooldowns.locks[0].ready_round == 5
					),
					"breath_expiration_starts_two_round_cooldown"
				)
		if round_number < 5:
			owner.begin_next_round([0, 1])
			replay.begin_next_round([0, 1])
			var boundary: Dictionary = owner.snapshot()
			var restored = Content.new().create_combat_match()
			_check(
				(
					(
						restored.restore(JSON.parse_string(JSON.stringify(boundary))).action
						!= "invalid"
					)
					and restored.snapshot() == boundary
				),
				"breath_before_step_two_json"
			)


func _corrupt_snapshots(owner) -> void:
	var before: Dictionary = owner.snapshot()
	for condition in [
		"magnitude", "payload", "stage", "lane", "clock", "profile", "old_policy", "parameters"
	]:
		var bad: Dictionary = before.duplicate(true)
		var active: Dictionary = bad.persistent.active[0]
		match condition:
			"magnitude":
				active.payload.lane_aura.speed_percent = 99
			"payload":
				active.payload.erase("lane_aura")
			"stage":
				active.stages.append({"active": true})
			"lane":
				active.target.lane = "Castle"
			"clock":
				bad.cooldowns.locks.clear()
			"profile":
				bad.world.data.erase("lane_aura_profile")
			"old_policy":
				bad.world.data.humbaba_profile = "U13_HUMBABA_STONES_V1"
			"parameters":
				active.declaration.parameters["healing"] = 999
		_check(
			owner.restore(bad).action == "invalid" and owner.snapshot() == before,
			"breath_corrupt_restore_atomic_" + condition
		)


func _regeneration_owner() -> void:
	var world: Dictionary = Scenario.world()
	var id: String = _add_unit(world, 0, "Butcher", 1)
	var owner = Content.new().create_combat_match()
	if not _check(
		owner.start("breath-regeneration", world, [0, 1]).action != "invalid",
		"breath_wounded_owner_starts"
	):
		return
	while not owner.next_hook().is_empty():
		var hook: String = owner.next_hook()
		if hook == Timeline.SUBMISSION_LOCK:
			owner.submit(0, [Candidates.source(0, 1, "Lord", Content.BREATH)], {})
			owner.submit(1, [], {})
		if not _check(owner.run_next_hook().action != "invalid", "breath_regen_round_one_" + hook):
			return
		if hook in [Timeline.ROUND_START_AUTOMATIC, Timeline.POST_RESOLUTION_MOVEMENT_STATE]:
			_check(
				_entity(owner.snapshot().world, id).attributes.hp == 2,
				"breath_no_retroactive_cast_regeneration"
			)
	owner.begin_next_round([0, 1])
	while owner.next_hook() != Timeline.PRESENT_PUBLIC_STATE:
		if not _check(owner.run_next_hook().action != "invalid", "breath_regen_round_two_opening"):
			return
	var snapshot: Dictionary = owner.snapshot()
	_check(_entity(snapshot.world, id).attributes.hp == 4, "owner_passes_active_aura_to_step_three")
	var restored = Content.new().create_combat_match()
	_check(
		(
			restored.restore(JSON.parse_string(JSON.stringify(snapshot))).action != "invalid"
			and restored.snapshot() == snapshot
		),
		"breath_post_regeneration_json"
	)


func _armed_after_banishment() -> void:
	var owner = _owner()
	if owner == null or not _to_submission(owner):
		return
	var world: Dictionary = owner.snapshot().world
	var powers: Array = [
		Candidates.source(0, 1, "Lord"), Candidates.source(0, 1, "Lord", Content.BREATH, 1)
	]
	if not _check(
		owner.submit(0, powers, {}).action != "invalid", "muster_and_breath_share_submission"
	):
		return
	var order: Dictionary = {
		"action": "Hunt",
		"lane": "Lord",
		"target_id": _lord(world, 0).id,
		"card_ids": world.data.card_zones.hands[1].slice(0, 2)
	}
	if not _check(owner.submit(1, [], order).action != "invalid", "breath_enemy_hunt_legal"):
		return
	while not owner.next_hook().is_empty():
		var hook: String = owner.next_hook()
		if not _check(owner.run_next_hook().action != "invalid", "armed_breath_hook_" + hook):
			return
		if hook == Timeline.POST_RESOLUTION_MOVEMENT_STATE:
			var snapshot: Dictionary = owner.snapshot()
			_check(
				(
					not _lord(snapshot.world, 0).attributes.alive
					and snapshot.persistent.active.size() == 1
				),
				"armed_breath_survives_banishment"
			)
			var count: int = 0
			for unit in snapshot.world.entities.entities:
				if unit.kind == "marcher" and unit.owner == 0:
					count += 1
			_check(count == 3, "muster_spawns_before_breath")
			var restored = Content.new().create_combat_match()
			_check(
				restored.restore(JSON.parse_string(JSON.stringify(snapshot))).action != "invalid",
				"armed_breath_banishment_json"
			)
			# This fixture proves ordering and armed lifetime; movement was tested
			# separately, so avoid another full three-body phase in this process.
			return
