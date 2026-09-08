extends "res://Scripts/Sim/U13KalliganTestRunner.gd"

const Bot = preload("res://Scripts/Sim/U13RandomLegal.gd")


func _run() -> void:
	var owner = _owner()
	if owner != null and _to_submission(owner):
		var before: Dictionary = owner.snapshot()
		# Keep this gate bounded: exercise actual power selection/legality with
		# empty combat vocabulary; larger roster batches use the full provider.
		var provider: Callable = func(match_owner, pid: int) -> Dictionary:
			var vocabulary: Dictionary = Candidates.enumerate(match_owner, pid)
			return {"powers": vocabulary.powers, "orders": []}
		var first: Dictionary = Bot.plan(owner, 0, provider)
		_check(first == Bot.plan(owner, 0, provider), "kalligan_keyed_choice_replays")
		_check(
			(
				first.action != "invalid"
				and first.powers.size() == 1
				and first.powers[0].power_id == Content.INFERNO
			),
			"kalligan_random_path_selects_inferno"
		)
		if first.action != "invalid":
			_check(
				owner.preview_submission(0, first.powers, first.order).action != "invalid",
				"kalligan_random_submission_valid"
			)
		_check(owner.snapshot() == before, "kalligan_random_planning_is_pure")
		owner.submit(0, first.powers, {})
		owner.submit(1, [], {})
		while not owner.next_hook().is_empty():
			if owner.run_next_hook().action == "invalid":
				_check(false, "kalligan_random_round_failed")
				break
		owner.begin_next_round([0, 1])
		if _to_submission(owner):
			var pyro_provider: Callable = func(match_owner, pid: int) -> Dictionary:
				var vocabulary: Dictionary = Candidates.enumerate(match_owner, pid)
				return {"powers": [vocabulary.powers[0]], "orders": []}
			var pyro: Dictionary = Bot.plan(owner, 0, pyro_provider)
			_check(
				(
					pyro.action != "invalid"
					and pyro.powers.size() == 1
					and pyro.powers[0].power_id == Content.PYROCLASM
				),
				"kalligan_random_path_selects_pyroclasm"
			)
	print("U13 Kalligan random failures: %d" % failures)
	quit(0 if failures == 0 else 1)
