extends "res://Scripts/Sim/U13ConstructionTestRunner.gd"

const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")


func _run() -> void:
	_continuing_project()
	print("U13 automatic construction failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _continuing_project() -> void:
	var selection: Array = ["Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine"]
	var world: Dictionary = Core.loadout_world(["Deimos", "Gremory"], [selection, selection])
	var first: String = Slots.castle_id(0, 3)
	var second: String = Slots.castle_id(0, 4)
	var begun: Dictionary = _develop(world, [_choice("Construct", first), {}])
	if not _resolved(begun, "auto_project_selected_once"):
		return
	var continued: Dictionary = _develop(begun.world, [{}, {}])
	if not _resolved(continued, "auto_project_continues_without_resubmission"):
		return
	_check(
		_entity(continued.world, first).attributes.integrity == 6, "auto_project_three_per_round"
	)
	_check(
		continued.world.data.card_zones.hands == world.data.card_zones.hands,
		"auto_project_does_not_spend_hand"
	)
	var switched: Dictionary = _develop(continued.world, [_choice("Construct", second), {}])
	if not _resolved(switched, "auto_project_switches"):
		return
	_check(
		(
			_entity(switched.world, first).attributes.integrity == 6
			and _entity(switched.world, second).attributes.integrity == 3
		),
		"old_project_pauses_when_target_changes"
	)
	var card_id: String = switched.world.data.card_zones.hands[0][0]
	_patch_attributes(switched.world, card_id, {"value": 6})
	var accelerated: Dictionary = _develop(
		switched.world, [_choice("Construct", second, [card_id]), {}]
	)
	if not _resolved(accelerated, "auto_project_accepts_optional_payment"):
		return
	_check(
		_entity(accelerated.world, second).attributes.integrity == 8,
		"selected_project_gets_passive_only_once_with_payment"
	)
	var next: Dictionary = _develop(accelerated.world, [{}, {}])
	if not _resolved(next, "paid_project_continues_free_next_round"):
		return
	_check(
		(
			_entity(next.world, second).attributes.integrity == 11
			and next.world.data.card_zones.hands == accelerated.world.data.card_zones.hands
		),
		"prior_payment_is_not_repeated"
	)
	# Repairing another Castle does not silently turn construction off.
	var repair_id: String = Slots.castle_id(0, 0)
	_patch_attributes(
		next.world,
		repair_id,
		{"integrity": 10, "status": "standing", "construction_state": "active"}
	)
	var repaired: Dictionary = _develop(next.world, [_choice("Repair", repair_id, [], true), {}])
	if not _resolved(repaired, "repair_alongside_selected_project"):
		return
	_check(
		(
			_entity(repaired.world, second).attributes.integrity == 14
			and _entity(repaired.world, repair_id).attributes.integrity == 13
		),
		"repair_keeps_project_running"
	)
	_patch_attributes(repaired.world, second, {"integrity": 20})
	var finished: Dictionary = _develop(repaired.world, [{}, {}])
	if not _resolved(finished, "automatic_project_completes"):
		return
	_check(
		(
			Structures.operational(_entity(finished.world, second))
			and finished.world.data.construction_targets[0] == ""
		),
		"full_project_activates_and_clears_selection"
	)
	var automatic: int = 0
	for event in finished.events:
		if event.event.type == "CASTLE_ACTIVATED" and event.event.data.get("automatic", false):
			automatic += 1
	_check(automatic == 1, "completion_emits_one_activation_fact")
	var idle: Dictionary = _develop(finished.world, [{}, {}])
	if _resolved(idle, "automatic_project_waits_after_completion"):
		_check(
			(
				_entity(idle.world, first).attributes.integrity == 6
				and idle.world.data.construction_targets[0] == ""
			),
			"completion_does_not_resume_an_old_or_new_project"
		)
