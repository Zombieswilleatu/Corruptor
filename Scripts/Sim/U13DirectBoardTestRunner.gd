extends SceneTree

const Scene = preload("res://Prototype/U13/U13Board.tscn")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const Deimos = preload("res://Scripts/Sim/U13Deimos.gd")
const Tutorials = preload("res://Prototype/U13/U13TutorialPreferences.gd")
var failures: int = 0


func _init() -> void:
	if DisplayServer.get_name() == "headless":
		Engine.max_fps = 60
	call_deferred("_run")


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _payload(id: String) -> Dictionary:
	return {"ui2_type": "commitment_hand_card", "source": "Hand", "card": id}


func _run() -> void:
	var board = Scene.instantiate()
	root.add_child(board)
	await _settle()
	_check(
		board.setup_picker.selection().castles == [Slots.TYPES, Slots.TYPES],
		"direct_beginner_picker_keep_first_one_each"
	)
	_test_tutorial_picker(board.setup_picker)
	# Keep the accepted double-Engine fixture explicit; UI defaults are beginner-facing.
	var exercise: Array = ["SiegeEngine", "SiegeEngine", "Keep", "Bastion", "Stockpile"]
	board.setup_picker.present(["Deimos", "Gremory"], [exercise, exercise], true, false)
	board.setup_picker.start_button.pressed.emit()
	await _settle()
	if not _check(
		board.match_started and board.session.hunt_enabled, "direct_board_starts_hunt_owner"
	):
		board.queue_free()
		await process_frame
		_finish()
		return
	var initial: Dictionary = board.session.checkpoint()
	var hand: Array = board.session.board_view().world.hand
	var enemy_castle: Dictionary = board._entity_target(Slots.castle_id(1, 0))
	var own_castle: Dictionary = board._entity_target(Slots.castle_id(0, 2))
	var own_lord: Dictionary = {}
	var enemy_lord: Dictionary = {}
	for entity in board._visible_world.entities:
		if entity.kind == "lord":
			if entity.owner == 0:
				own_lord = board._entity_target(entity.id)
			else:
				enemy_lord = board._entity_target(entity.id)
	_check(
		not board.target_choice.visible and not board.castle_action_choice.visible,
		"direct_board_hides_target_dropdowns"
	)
	_check(
		board.sides[1].commission_buttons.has(Slots.castle_id(0, 1)),
		"direct_commission_on_eligible_card"
	)
	_check(
		not board.sides[1].commission_buttons.has(Slots.castle_id(0, 0)),
		"direct_active_castle_has_no_commission"
	)
	board.action_zone.action_buttons.Siege.pressed.emit()
	board.hand_view.select_card_id(hand[0])
	await _settle()
	_check(board._draft_combat.is_empty(), "direct_click_requires_target_before_cards")
	board._choose_target(enemy_castle)
	await _settle()
	board.hand_view.select_card_id(hand[0])
	await _settle()
	_check(
		(
			board._draft_combat.get("target_id") == enemy_castle.id
			and board._draft_combat.card_ids == [hand[0]]
		),
		"direct_click_action_target_card"
	)
	_check(
		board.hand_view.card_buttons.size() == 3 and board._order_preview._stacks.size() == 1,
		"direct_card_moves_from_hand_to_target_stack"
	)
	for child in board._order_preview.get_children():
		if child is Button:
			var skin: StyleBoxFlat = child.get_theme_stylebox("normal") as StyleBoxFlat
			_check(
				skin.border_width_left == 3 and skin.border_color == Color(0.86, 0.24, 0.22, 1.0),
				"direct_committed_card_keeps_suit_outline"
			)
	_check(board.hand_view.all_in_enabled, "direct_first_staged_card_enables_all_in")
	board.hand_view.all_in_requested.emit()
	await _settle()
	_check(
		board._draft_combat.card_ids.size() == 4 and board.hand_view.card_buttons.is_empty(),
		"direct_all_in_moves_remaining_hand"
	)
	board._return_card("combat", hand[0])
	await _settle()
	_check(
		board.hand_view.card_buttons.size() == 1 and board._draft_combat.card_ids.size() == 3,
		"direct_staged_card_returns_to_hand"
	)
	_check(
		not board._can_drop(Vector2.ZERO, _payload(hand[1]), enemy_castle),
		"direct_reserved_card_cannot_be_dropped_again"
	)
	_check(
		not board._can_drop(Vector2.ZERO, _payload("forged"), enemy_castle),
		"direct_unknown_drag_id_rejected"
	)
	var protected: Dictionary = board._entity_target(Slots.castle_id(1, 1))
	_check(
		not board._can_drop(Vector2.ZERO, _payload(hand[0]), protected),
		"direct_protected_castle_rejects_siege_drop"
	)
	board._drop(Vector2.ZERO, _payload(hand[0]), own_lord)
	await _settle()
	_check(
		(
			board._draft_combat.action == "Ward"
			and board._draft_combat.lane == "Lord"
			and board._draft_combat.card_ids.size() == 4
		),
		"direct_drop_own_lord_infers_ward_and_retargets_stack"
	)
	board._return_card("combat", hand[0])
	await _settle()
	board._drop(Vector2.ZERO, _payload(hand[0]), enemy_lord)
	await _settle()
	_check(
		board._draft_combat.action == "Hunt" and board._draft_combat.target_id == enemy_lord.id,
		"direct_enemy_lord_drop_is_real_hunt"
	)
	_check(board.session.preview().action != "invalid", "direct_hunt_submission_valid")
	_check(board.session.checkpoint() == initial, "direct_gestures_do_not_advance_match")
	board.restart()
	await _settle()
	board._drop(Vector2.ZERO, _payload(hand[0]), own_castle)
	await _settle()
	_check(
		board._draft_combat.action == "Ward" and board._draft_combat.lane == "Castle",
		"direct_own_castle_drop_uses_shared_ward_lane"
	)
	board.restart()
	await _settle()
	board._select_direct_action("Construct")
	board._choose_target(own_castle)
	await _settle()
	_check(
		board.castle_plan.get("action") == "Construct" and board.castle_plan.card_ids.is_empty(),
		"direct_construct_target_stages_free_progress"
	)
	board.hand_view.select_card_id(hand[0])
	await _settle()
	board.hand_view.select_card_id(hand[1])
	await _settle()
	_check(board.castle_plan.card_ids == hand.slice(0, 2), "direct_construct_cards_move_to_castle")
	board._select_direct_action("Siege")
	board._choose_target(enemy_castle)
	await _settle()
	board.hand_view.select_card_id(hand[2])
	await _settle()
	board.hand_view.all_in_requested.emit()
	await _settle()
	_check(
		board._draft_combat.card_ids == hand.slice(2, 4) and board.castle_plan.card_ids.size() == 2,
		"direct_all_in_excludes_reserved_castle_payment"
	)
	board.enter_powers()
	await _settle()
	var locked_order: Dictionary = board._order().duplicate(true)
	board._return_card("combat", hand[2])
	board._return_card("castle", hand[0])
	_check(
		board._order() == locked_order and board._available_ids().is_empty(),
		"direct_powers_lock_combat_and_castle_payments"
	)
	for child in board._order_preview.get_children():
		if child is Button:
			_check(
				(
					child.mouse_filter == Control.MOUSE_FILTER_IGNORE
					and child.focus_mode == Control.FOCUS_NONE
				),
				"direct_locked_stack_passes_clicks_to_board_target"
			)
	board.back_to_combat()
	await _settle()
	_check(board._order() == locked_order, "direct_back_to_combat_preserves_locked_draft")
	board.sides[1].commission_buttons[Slots.castle_id(0, 1)].pressed.emit()
	await _settle()
	_check(
		board.castle_plan.action == "Activate" and board.hand_view.card_buttons.size() == 2,
		"direct_commission_replaces_castle_action_and_returns_payment"
	)
	_check(board.session.checkpoint() == initial, "direct_commission_click_does_not_advance_state")
	board.sides[1].commission_buttons[Slots.castle_id(0, 1)].pressed.emit()
	await _settle()
	_check(board.castle_plan.is_empty(), "direct_commission_can_be_unstaged")
	board.enter_powers()
	await _settle()
	board.war_button.pressed.emit()
	await _settle()
	_check(board.queued.is_empty(), "direct_war_machine_waits_for_engine_click")
	board._choose_target(board._entity_target(Slots.castle_id(0, 0)))
	await _settle()
	_check(
		board.queued.size() == 1 and board.queued[0].power_id == Deimos.WAR_MACHINE,
		"direct_war_machine_clicks_specific_engine"
	)
	_check(
		board.war_state.text.contains("Only eligible enemy Castle now"),
		"direct_war_machine_explains_automatic_target"
	)
	var engine: Dictionary = board._entity(Slots.castle_id(0, 0)).duplicate(true)
	engine.attributes.artillery_target = Slots.castle_id(1, 0)
	_check(
		board._artillery_target_note(engine).contains("Retained enemy target"),
		"direct_war_machine_shows_retained_target"
	)
	board.rout_button.pressed.emit()
	await _settle()
	board.lanes.lane_selected.emit("Castle")
	await _settle()
	_check(
		board.queued.size() == 2 and board.queued[1].target.lane == "Castle",
		"direct_rout_clicks_lane"
	)

	board.open_setup()
	var selections: Array = board.session.setup_castles.duplicate(true)
	board.start_loadout(["Gremory", "Deimos"], selections, true)
	await _settle()
	board.pass_round()
	await _settle()
	board.predator_button.pressed.emit()
	await _settle()
	_check(
		board.queued.is_empty() and board.lanes.target_lane_enabled,
		"direct_predator_waits_for_lane"
	)
	board.lanes.lane_selected.emit("Lord")
	await _settle()
	_check(
		board.queued.size() == 1 and board.queued[0].target.lane == "Lord",
		"direct_predator_lane_queues_declaration"
	)
	board.ruin_button.pressed.emit()
	await _settle()
	board.hand_view.select_card_id(hand[0])
	await _settle()
	board.hand_view.select_card_id(hand[1])
	await _settle()
	_check(
		board._power_cost.size() == 2 and board.hand_view.card_buttons.size() == 2,
		"direct_ruin_cost_cards_stage_before_target"
	)
	_check(
		not board.hand_view.all_in_enabled, "direct_fixed_power_cost_does_not_all_in_extra_cards"
	)
	board._choose_target(board._entity_target(Slots.castle_id(0, 0)))
	_check(board.queued.size() == 1, "direct_ruin_rejects_own_castle")
	board._choose_target(board._entity_target(Slots.castle_id(1, 0)))
	await _settle()
	_check(
		board.queued.size() == 2 and board.payment.size() == 2 and board._power_cost.is_empty(),
		"direct_ruin_payment_then_enemy_target"
	)
	board._return_card("ruin", hand[0])
	await _settle()
	_check(
		(
			board.queued.size() == 1
			and board.queued[0].queue_index == 0
			and board.hand_view.card_buttons.size() == 4
		),
		"direct_return_ruin_payment_preserves_other_power"
	)
	board.back_to_combat()
	board._select_direct_action("Construct")
	board._choose_target(board._entity_target(Slots.castle_id(0, 2)))
	await _settle()
	board.enter_powers()
	board.predator_button.pressed.emit()
	await _settle()
	board.lanes.lane_selected.emit("Castle")
	await _settle()
	board.session._opponent = {"powers": [], "order": {}}
	board.resolve_round()
	_check(board._job != null, "direct_submit_uses_background_worker")
	var deadline: int = Time.get_ticks_msec() + 15000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	if _check(board._job == null and board.playing, "direct_worker_resolves_staged_orders"):
		var castle: Dictionary = board._entity(Slots.castle_id(0, 2))
		# The installed presentation is before Marching and includes Development.
		_check(castle.attributes.integrity == 3, "direct_free_construction_resolves")
		_check(board.session.plans().powers.size() == 1, "direct_selected_lane_power_submitted")
	board.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("U13 direct board failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _test_tutorial_picker(picker) -> void:
	var original = picker.tutorials
	var path: String = "user://u13_tutorial_test_%d.cfg" % Time.get_ticks_usec()
	picker.tutorials = Tutorials.new(path)
	var choice: OptionButton = picker.castle_choices[0][0]
	choice.select(4)
	choice.item_selected.emit(4)
	_check(
		picker.tutorial_popup.visible and picker.selection().castles[0][0] == "Keep",
		"tutorial_keep_change_waits_for_choice"
	)
	picker.tutorial_popup.cancel_button.pressed.emit()
	_check(
		not picker.tutorial_popup.visible and choice.selected == 0, "tutorial_cancel_preserves_keep"
	)
	choice.select(4)
	choice.item_selected.emit(4)
	picker.tutorial_popup.dont_show.set_pressed_no_signal(true)
	picker.tutorial_popup.continue_button.pressed.emit()
	_check(
		choice.selected == 4 and not picker.tutorial_popup.visible,
		"tutorial_accept_allows_specialized_loadout"
	)
	var restored = Tutorials.new(path)
	_check(not restored.should_show(Tutorials.KEEP_LOADOUT), "tutorial_dont_show_persists")
	picker._apply_castle_choice(0, 0, 0)
	choice.select(4)
	choice.item_selected.emit(4)
	_check(
		not picker.tutorial_popup.visible and choice.selected == 4,
		"tutorial_dismissed_hint_does_not_block_choice"
	)
	picker.tutorials.dismiss("future_tutorial_test")
	picker.show_tutorials.pressed.emit()
	_check(
		(
			restored.should_show(Tutorials.KEEP_LOADOUT)
			and restored.should_show("future_tutorial_test")
		),
		"tutorial_reset_restores_all_popup_flags"
	)
	picker._apply_castle_choice(0, 0, 0)
	picker.tutorials.enabled = false
	choice.select(4)
	choice.item_selected.emit(4)
	_check(
		not picker.tutorial_popup.visible and choice.selected == 4,
		"tutorial_gate_can_be_disabled_without_changing_rules"
	)
	picker.tutorials = original
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
