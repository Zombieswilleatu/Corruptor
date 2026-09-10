extends "res://Scripts/Sim/U13OdradekTestRunner.gd"


func _run() -> void:
	var observed: Dictionary = {}
	var banked: bool = false
	var mixed: bool = false
	for seed_index in range(4):
		var world: Dictionary = OdradekScenario.world()
		world.players[0].resources.reconfiguration = 3
		var owner = Odradek.new().create_combat_match()
		owner.start("odradek-bot-check-%d" % seed_index, world, [0, 1])
		if not _advance(owner, Timeline.SUBMISSION_LOCK):
			break
		var before: Dictionary = owner.snapshot()
		var planned: Dictionary = OdradekScenario.plan(owner, 0)
		if not _check(planned.action == "bot_plan", "bot_cart_legal_seed_%d" % seed_index):
			print(planned)
			break
		banked = banked or planned.powers.is_empty()
		mixed = mixed or planned.powers.size() > 1
		for source in planned.powers:
			observed[source.power_id] = true
		_check(owner.snapshot() == before, "bot_planning_read_only_seed_%d" % seed_index)
		if seed_index == 0:
			var groups: Array = preload("res://Scripts/Sim/U13Legality.gd").legal_power_groups(
				owner, 0, OdradekScenario.enumerate(owner, 0).powers
			)
			var names: Array = []
			for group in groups:
				names.append(group.power)
			for power in Odradek.POWERS:
				_check(power in names, "bot_has_legal_candidate_" + power)
			_check(planned == OdradekScenario.plan(owner, 0), "bot_cart_seed_replay_exact")
	_check(banked, "bot_can_bank_for_expensive_powers")
	_check(mixed, "bot_can_build_multi_effect_cart")
	_check(
		observed.has(Odradek.INVERSION) and observed.has(Odradek.FALSE_ORDERS),
		"bot_spends_saved_points_on_guard_powers"
	)
	var owner = Odradek.new().create_combat_match()
	owner.start("odradek-mirror-bot", OdradekScenario.world("Odradek"), [0, 1])
	for round_number in range(1, 3):
		if not _advance(owner, Timeline.SUBMISSION_LOCK):
			break
		for pid in [0, 1]:
			var planned: Dictionary = OdradekScenario.plan(owner, pid)
			if not _check(
				(
					planned.action == "bot_plan"
					and owner.submit(pid, planned.powers, planned.order).action != "invalid"
				),
				"mirror_bot_round_%d_player_%d" % [round_number, pid]
			):
				break
		owner.run_next_hook()
		if not _advance(owner, Timeline.AFTERMATH):
			break
		_check(
			owner.run_next_hook().action != "invalid", "mirror_aftermath_round_%d" % round_number
		)
		var restored = Odradek.new().create_combat_match()
		_check(
			(
				restored.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))).action
				!= "invalid"
			),
			"mirror_snapshot_round_%d" % round_number
		)
		if round_number < 2:
			owner.begin_next_round([0, 1])
	print("U13 Odradek bot failures: %d" % failures)
	quit(0 if failures == 0 else 1)
