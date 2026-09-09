extends "res://Scripts/Sim/U13GuardDeploymentTestRunner.gd"

const Bot = preload("res://Scripts/Sim/U13RandomLegal.gd")


func _run() -> void:
	_candidates()
	_bulk_equivalence()
	_finish("Guard random")


func _candidates() -> void:
	var owner = _ready(_world())
	if owner == null:
		return
	var before: Dictionary = owner.snapshot()
	var vocabulary: Dictionary = Scenario.enumerate(owner, 0)
	var guard_count: int = 0
	var snare_count: int = 0
	for source in vocabulary.powers:
		if source.power_id == Content.SNARE:
			snare_count += 1
	for order in vocabulary.orders:
		if order.has("guard_moves"):
			guard_count += 1
	_check(
		guard_count > 0 and snare_count == 1,
		"guard_random_vocabulary_includes_snare_and_deployment"
	)
	_check(vocabulary == Scenario.enumerate(owner, 0), "guard_candidate_replay")
	var bases: Dictionary = {
		"action": "candidate_vocabulary",
		"powers": [],
		"orders": [{}, {"action": "Ward", "lane": "Lord", "card_ids": []}]
	}
	var reversed: Dictionary = bases.duplicate(true)
	reversed.orders.reverse()
	var a: Dictionary = Guards.add_candidates(bases, owner.player_view(0, 0), owner.rng_seed())
	var b: Dictionary = Guards.add_candidates(reversed, owner.player_view(0, 0), owner.rng_seed())
	for order in a.orders:
		_check(order in b.orders, "guard_key_independent_of_candidate_order")
	var plan: Dictionary = Bot.plan(owner, 0, Callable(self, "_guard_only_candidates"))
	if not _ok(plan, "guard_random_plan"):
		return
	_check(
		(
			plan.powers.size() == 1
			and plan.powers[0].power_id == Content.SNARE
			and not plan.order.get("guard_moves", []).is_empty()
		),
		"random_plan_exercises_snare_and_guard"
	)
	_check(
		(
			plan == Bot.plan(owner, 0, Callable(self, "_guard_only_candidates"))
			and owner.snapshot() == before
		),
		"guard_random_plan_pure_and_repeatable"
	)
	var replay = Content.new().create_combat_match()
	if not _ok(
		replay.restore(JSON.parse_string(JSON.stringify(before))), "guard_random_restored_owner"
	):
		return
	_check(
		Bot.plan(replay, 0, Callable(self, "_guard_only_candidates")) == plan,
		"guard_random_plan_json_replays"
	)
	for current in [owner, replay]:
		if (
			not _ok(current.submit(0, plan.powers, plan.order), "guard_random_submit")
			or not _ok(current.submit(1, [], {}), "guard_random_other_pass")
		):
			return
		if (
			not _ok(current.run_next_hook(), "guard_random_lock")
			or not _ok(current.run_next_hook(), "guard_random_develop")
		):
			return
	_check(owner.snapshot() == replay.snapshot(), "guard_random_execution_replays")
	for move in plan.order.guard_moves:
		_check(
			_entity(owner.snapshot().world, move.card_id).attributes.get("role") == "guard",
			"guard_random_card_deployed"
		)


func _guard_only_candidates(owner, pid: int) -> Dictionary:
	var view: Dictionary = owner.player_view(pid, 0)
	return Guards.add_candidates(
		{
			"action": "candidate_vocabulary",
			"powers": [Candidates.snare_source(pid, owner.round_number())],
			"orders": []
		},
		view,
		owner.rng_seed()
	)


func _bulk_equivalence() -> void:
	var owner = _ready(_world())
	if owner == null:
		return
	var cards: Array = owner.player_view(0).world.hand
	var moves: Array = [_move(cards[0])]
	var orders: Array = [
		{},
		{"guard_moves": moves},
		{"guard_moves": [_move("unknown")]},
		{"guard_moves": [_move(cards[0]), _move(cards[1])]},
		{"action": "Ward", "lane": "Lord", "card_ids": [cards[0]], "guard_moves": moves},
		{"action": "Ward", "lane": "Lord", "card_ids": [cards[1]], "guard_moves": moves},
		{"action": "Ward", "lane": "Lord", "card_ids": "bad", "guard_moves": moves},
		{"guard_moves": [{"card_id": cards[0], "lane": "Lord", "slot": 0.5}]},
		{
			"castle_action":
			{
				"action": "Construct",
				"target_id": Slots.castle_id(0, 1),
				"card_ids": [cards[0]],
				"use_repair_token": false
			},
			"guard_moves": moves
		},
		{
			"castle_action":
			{
				"action": "Construct",
				"target_id": Slots.castle_id(0, 1),
				"card_ids": [cards[1]],
				"use_repair_token": false
			},
			"guard_moves": moves
		}
	]
	var powers: Array = [Candidates.snare_source(0, 1)]
	var fast: Array = owner.legal_order_candidates(0, powers, orders)
	var full: Array = []
	for order in orders:
		if owner.preview_submission(0, powers, order).action != "invalid":
			full.append(order)
	_check(fast == full and fast.size() == 4, "guard_bulk_equals_full_submission_validation")
