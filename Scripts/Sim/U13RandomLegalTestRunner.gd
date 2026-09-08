extends SceneTree

const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const Opening = preload("res://Scripts/Sim/U13SmokeSession.gd")
const Candidates = preload("res://Scripts/Sim/U13GremoryCandidates.gd")
const Bot = preload("res://Scripts/Sim/U13RandomLegal.gd")
const Legality = preload("res://Scripts/Sim/U13Legality.gd")
const Telemetry = preload("res://Scripts/Sim/U13FrequencyTelemetry.gd")
const Batch = preload("res://Scripts/Sim/U13RandomBatch.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_candidates_and_plans()
	_telemetry()
	_batch_replay()
	print("U13 random-legal failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _owner():
	var content = Gremory.new()
	var owner = content.create_combat_match()
	if not _check(
		owner.start("random-legal-test", Opening._initial_world(), [0, 1]).action != "invalid",
		"random_match_starts"
	):
		return null
	for _index in range(5):
		if owner.next_hook() == Timeline.SUBMISSION_LOCK:
			return owner
		if not _check(owner.run_next_hook().action != "invalid", "random_planning_progress"):
			return null
	return owner


func _candidates_and_plans() -> void:
	var owner = _owner()
	if owner == null:
		return
	var before: Dictionary = owner.snapshot()
	var plans: Array = []
	for player_id in [0, 1]:
		var raw: Dictionary = Candidates.enumerate(owner, player_id)
		var groups: Array = Legality.legal_power_groups(owner, player_id, raw.powers)
		_check(groups.size() == 2, "random_both_gremory_powers_available")
		for group in groups:
			_check(
				group.candidates.size() == (2 if group.power == Gremory.PREDATOR else 6),
				"random_power_weight_independent_of_payload_count"
			)
			for source in group.candidates:
				_check(source.player_id == player_id, "random_declaration_owner")
				if source.power_id == Gremory.RUIN:
					_check(
						source.target.entity_id == Opening._castle_id(1 - player_id),
						"random_ruin_only_enemy_castle"
					)
		var duplicated: Array = raw.powers.duplicate(true)
		duplicated.append_array(raw.powers.duplicate(true))
		duplicated.reverse()
		for source in duplicated:
			if source.cost.has("discard_ids"):
				source.cost.discard_ids.reverse()
		_check(
			Legality.legal_power_groups(owner, player_id, duplicated) == groups,
			"random_duplicate_and_reordered_payloads_same_domain"
		)
		var chosen: Dictionary = Bot.plan(owner, player_id, Callable(Candidates, "enumerate"))
		_check(
			chosen.action == "bot_plan" and chosen.powers.size() == 1,
			"random_fires_when_power_legal"
		)
		Rng.draw("other-seed", "other-match", "BOT_POWER_CHOICE", 0, 7)
		_check(
			Bot.plan(owner, player_id, Callable(Candidates, "enumerate")) == chosen,
			"random_unrelated_draws_do_not_shift_plan"
		)
		_check(
			owner.preview_submission(player_id, chosen.powers, chosen.order).action != "invalid",
			"random_complete_plan_legal"
		)
		var paid: Array = chosen.powers[0].cost.get("discard_ids", [])
		for card_id in chosen.order.get("card_ids", []):
			_check(card_id not in paid, "random_combat_cannot_reuse_power_payment")
		plans.append(chosen)
	_check(owner.snapshot() == before, "random_enumeration_and_choice_are_pure")
	var pass_plan: Dictionary = Bot.plan(owner, 0, Callable(), Callable(self, "_real_pass"))
	_check(
		(
			pass_plan.action == "bot_plan"
			and pass_plan.powers.is_empty()
			and pass_plan.order.is_empty()
		),
		"random_does_not_override_real_doctrine_pass"
	)
	_check(
		(
			(
				Bot
				. plan(owner, 0, Callable(Candidates, "enumerate"), Callable(self, "_bad_doctrine"))
				. action
			)
			== "invalid"
		),
		"random_does_not_hide_real_doctrine_error"
	)
	for player_id in [0, 1]:
		_check(
			(
				owner.submit(player_id, plans[player_id].powers, plans[player_id].order).action
				!= "invalid"
			),
			"random_both_submissions_accepted"
		)
	_check(owner.run_next_hook().action != "invalid", "random_joint_lock_resolves")
	_check(
		Legality.legal_power_groups(owner, 0, Candidates.enumerate(owner, 0).powers).is_empty(),
		"random_cannot_declare_after_lock"
	)


func _real_pass(_view: Dictionary) -> Dictionary:
	return {"powers": [], "order": {}}


func _bad_doctrine(_view: Dictionary) -> Dictionary:
	return {"powers": [], "order": {"action": "unsupported"}}


func _telemetry() -> void:
	var telemetry = Telemetry.new()
	var view: Dictionary = {"world": {"entities": [], "souls": [0, 0], "neutral_tears": 0}}
	telemetry.begin(1, view)
	var units: Array = []
	for index in range(6):
		var attributes: Dictionary = Marching.profile(
			"Vulture", "Castle", 0 if index < 5 else 1, 0, 1
		)
		attributes.waiting = index < 5
		units.append(
			{
				"id": "unit_" + str(index),
				"kind": "marcher",
				"owner": 0 if index < 5 else 1,
				"attributes": attributes
			}
		)
	telemetry.consume([_event("MARCHING_STARTED", {"units": units})])
	var deltas: Array = []
	for unit in units:
		deltas.append({"id": unit.id, "owner": unit.owner, "attributes": {"hp": 4}})
	telemetry.consume(
		[_event("MARCHING_TICK", {"unit_format": "attribute_delta_v1", "units": deltas})]
	)
	telemetry.consume([_event("MARCHER_WAITING", {"entity_id": "unit_0", "lane": "Castle"})])
	units.remove_at(0)
	telemetry.consume(
		[
			_event("MARCHING_FINISHED", {"units": units}),
			_event("POWER_DECLARED", {"power_id": "Example", "player_id": 0}),
			_event(
				"FIZZLE_INVALID_TARGET",
				{"power_id": "Example", "player_id": 0, "result": {"reason": "target_missing"}}
			),
			_event("NEUTRAL_TEAR_CREATED", {"source": "PickingTheBones", "amount": 1}),
			_event("CASTLE_DESTROYED", {})
		]
	)
	view.world.souls = [2, 0]
	view.world.neutral_tears = 1
	telemetry.observe_hook(view, "combat_resolution")
	var row: Dictionary = telemetry.finish(false)
	_check(
		row.marching_start.total == 6 and row.marching_end.total == 5 and row.peak_marchers == 6,
		"frequency_start_end_peak_are_distinct"
	)
	_check(
		row.waiters["0:Castle"].ticks_at_least_five == 1, "frequency_delta_restores_waiting_flags"
	)
	_check(
		row.waiters["0:Castle"].peak == 5 and row.arrivals["0:Castle"] == 1,
		"frequency_waiter_peak_and_arrivals"
	)
	_check(
		(
			row.powers["0:Example"].declared == 1
			and row.powers["0:Example"].fizzled == 1
			and row.fizzle_causes["0:Example:target_missing"] == 1
		),
		"frequency_fizzle_count_and_nested_cause"
	)
	_check(
		(
			row.souls_gained_by_hook.combat_resolution == [2, 0]
			and row.castles_destroyed == 1
			and row.tears_by_source.PickingTheBones == 1
		),
		"frequency_economy_attribution"
	)
	var distribution: Dictionary = Telemetry.distribution([0, 0, 3, 9])
	_check(
		(
			distribution.n == 4
			and distribution.mean == 3.0
			and distribution.histogram == {"0": 2, "3": 1, "9": 1}
		),
		"frequency_histogram_preserves_zero_and_variance"
	)
	_check(Telemetry.distribution([]).mean == null, "frequency_empty_sample_not_zero")
	_check(
		Telemetry.summarize([row]).threshold_power_ratios == null and row.personal_tears == null,
		"frequency_absent_mechanics_not_reported_as_zero"
	)


func _batch_replay() -> void:
	var first: Dictionary = Batch.trial("random-batch-regression", 2)
	if not _check(first.action == "batch_trial_complete", "batch_two_rounds_complete"):
		return
	var second: Dictionary = Batch.trial("random-batch-regression", 2)
	_check(first == second, "batch_seed_replays_state_events_decisions_and_metrics")
	_check(
		first.rounds.size() == 2 and first.summary.round_samples == 2,
		"batch_replay_not_double_counted"
	)
	_check(
		first.rounds[0].ticks_observed == 200 and first.rounds[1].ticks_observed == 200,
		"batch_complete_tick_observations"
	)
	var report: Dictionary = Batch.report([first], 2)
	_check(
		(
			report.seeds == ["random-batch-regression"]
			and report.absent_systems.has("normal round draws")
		),
		"batch_pins_seed_and_missing_systems"
	)
	_check(
		Batch.trial("", 2).action == "invalid" and Batch.trial("seed", 0).action == "invalid",
		"batch_invalid_limits_rejected"
	)


func _event(type: String, data: Dictionary) -> Dictionary:
	return {"type": type, "text": "", "data": data}


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok
