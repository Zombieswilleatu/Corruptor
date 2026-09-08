extends SceneTree

const Scene = preload("res://Prototype/U13/U13Board.tscn")
const Session = preload("res://Scripts/Sim/U13LoadoutBoardSession.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const Deimos = preload("res://Scripts/Sim/U13Deimos.gd")
const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
var failures: int = 0


func _init() -> void:
	if DisplayServer.get_name() == "headless":
		Engine.max_fps = 60
	call_deferred("_run")


func _run() -> void:
	var board = Scene.instantiate()
	root.add_child(board)
	await process_frame
	await process_frame
	_check(board.setup_open and not board.match_started, "loadout_picker_precedes_match")
	_check(not board.phase_prompt.visible, "loadout_picker_hides_round_prompt")
	var picker = board.setup_picker
	picker.castle_choices[0][2].select(4)
	picker._validate()
	_check(picker.start_button.disabled, "loadout_picker_rejects_third_copy")
	picker.castle_choices[0][2].select(0)
	picker._validate()
	_check(not picker.start_button.disabled, "loadout_picker_accepts_two_copies")
	picker.start_button.pressed.emit()
	if not _check(board.match_started and not board.setup_open, "loadout_picker_starts_board"):
		board.queue_free()
		await process_frame
		_finish()
		return
	await process_frame
	await process_frame
	_check(board.session is Session, "loadout_board_uses_core_owner_session")
	_check(board.header.scores[0].text.contains("DEIMOS"), "loadout_header_shows_chosen_lord")
	_check(board.sides[1].lord_card.caption.text == "DEIMOS", "loadout_lord_card_shows_deimos")
	var first = board.sides[1].castle_row.get_child(0)
	var second = board.sides[1].castle_row.get_child(1)
	_check(
		first.get_meta("castle_id") != second.get_meta("castle_id"),
		"loadout_board_copy_ids_distinct"
	)
	_check(
		first.caption.text.contains("12/21") and second.caption.text.contains("7/21"),
		"loadout_board_copy_integrity_visible"
	)
	_check(
		second.caption.text.contains("PROTECTED"), "loadout_board_construction_protection_visible"
	)
	_check(
		board.sides[1].castle_guard_box.get_child_count() == 3, "loadout_board_one_shared_guard_row"
	)
	_check(
		board.target_choice.item_count == 1 and board.ruin_target.item_count == 1,
		"loadout_protected_enemy_copies_not_attack_targets"
	)
	var before: Dictionary = board.session.checkpoint()
	board.open_setup()
	board.setup_picker.lord_choices[0].select(1)
	board.close_setup()
	_check(board.session.checkpoint() == before, "loadout_cancel_preserves_running_match")
	_check(board._human_lord() == "Deimos", "loadout_cancel_does_not_change_lord")

	# Payments are physical cards, shared across Castle/combat/power reservations.
	var cards: Array = board.session.board_view().world.hand
	board.castle_target.select(2)
	board.castle_action_choice.select(0)
	board.hand_view.select_card_id(cards[0])
	board.stage_castle_action()
	_check(board.castle_plan.get("card_ids") == [cards[0]], "loadout_construct_reserves_exact_card")
	_check(
		board.hand_view.card_buttons.size() == 3, "loadout_castle_payment_removed_from_hand_choices"
	)
	board.action_zone.action_buttons["Ward"].pressed.emit()
	board.hand_view.select_card_id(cards[1])
	board.enter_powers()
	_check(board.session.checkpoint() == before, "loadout_staging_advances_no_state")
	_check(
		board.staged_order.get("castle_action", {}).get("target_id") == Slots.castle_id(0, 2),
		"loadout_castle_order_survives_power_transition"
	)
	_check(
		board.hand_view.card_buttons.size() == 2, "loadout_combat_and_castle_reservations_disjoint"
	)
	_check(
		board.deimos_box.visible and not board.gremory_box.visible,
		"loadout_deimos_has_separate_power_choices"
	)
	_check(not board.castle_box.visible, "loadout_powers_hide_castle_controls")
	board.queue_war_machine()
	board.queue_rout()
	var once: Array = board.queued.duplicate(true)
	board.queue_rout()
	board.queue_war_machine()
	_check(
		once.size() == 2 and board.queued == once, "loadout_power_repeat_clicks_do_not_duplicate"
	)
	_check(not board.confirm.disabled, "loadout_castle_combat_and_both_powers_legal")
	board.back_to_combat()
	_check(
		(
			board.castle_plan.card_ids == [cards[0]]
			and board.hand_view.selected_card_ids() == [cards[1]]
		),
		"loadout_back_preserves_castle_and_combat_cards"
	)
	board.clear_castle_action()
	_check(
		board.hand_view.selected_card_ids() == [cards[1]],
		"loadout_clear_castle_keeps_combat_selection"
	)
	_check(
		board.castle_plan.is_empty() and board.hand_view.card_buttons.size() == 4,
		"loadout_clear_returns_castle_payment"
	)

	# Commission slot 2, then resolve both Deimos powers through the real worker.
	board.action_choice.select(0)
	board.castle_target.select(1)
	board.castle_action_choice.select(1)
	board.stage_castle_action()
	_check(
		board.castle_plan.get("action") == "Activate" and board.castle_plan.get("card_ids") == [],
		"loadout_commission_maps_to_free_activation"
	)
	board.pass_round()
	_check(
		board.powers_step and board.staged_order.has("castle_action"),
		"loadout_skip_combat_keeps_commission"
	)
	board.queue_war_machine()
	board.queue_rout()
	var chosen: Dictionary = board._order()
	board.resolve_round()
	_check(board._job != null and not board.playing, "loadout_resolution_uses_worker")
	_check(board.session.checkpoint() == before, "loadout_worker_does_not_publish_partial_owner")
	if await _wait_job(board):
		_check(
			board.playing and board.session.plans().order == chosen,
			"loadout_worker_installs_castle_and_powers"
		)
		_check(
			board.session.setup_lords == ["Deimos", "Gremory"] and board.session.quick_start,
			"loadout_worker_preserves_setup"
		)
		var exposed: Dictionary = _castle(board.session, Slots.castle_id(0, 1))
		_check(
			exposed.attributes.construction_state == "active", "loadout_commission_fires_from_board"
		)
		_check(
			board.session.power_status(Deimos.ROUT).awaiting_expiration,
			"loadout_rout_not_ready_during_lifetime"
		)
		board.finish_playback()
		await _wait_job(board)
		var restored = Session.new()
		var checkpoint: Dictionary = board.session.checkpoint()
		_check(
			restored.restore_checkpoint(checkpoint).action != "invalid",
			"loadout_board_checkpoint_restores"
		)
		_check(restored.checkpoint() == checkpoint, "loadout_board_checkpoint_matches")
	board.restart()
	_check(board.session.checkpoint() == before, "loadout_restart_repeats_chosen_opening")

	# Repair has an explicit card/token reservation and a target instance.
	board.castle_target.select(0)
	board.castle_action_choice.select(2)
	board.castle_token.button_pressed = true
	board.hand_view.select_card_id(cards[0])
	board.stage_castle_action()
	_check(
		(
			board.castle_plan.get("action") == "Repair"
			and board.castle_plan.get("use_repair_token") == true
		),
		"loadout_repair_token_and_card_stage"
	)
	board.enter_powers()
	board.pass_round()
	if await _wait_job(board):
		_check(
			(
				board.session.plans().powers.is_empty()
				and board.session.plans().order.has("castle_action")
			),
			"loadout_no_powers_preserves_repair"
		)
		_check(
			board.session.board_view().world.repair_tokens == 1,
			"loadout_repair_token_consumed_once"
		)
		board.finish_playback()
		await _wait_job(board)

	# Both selectors work; all-unbuilt is a distinct, explicitly selected opening.
	board.open_setup()
	var selected: Array = board.session.setup_castles.duplicate(true)
	board.start_loadout(["Gremory", "Deimos"], selected, false)
	_check(board.target_choice.item_count == 0, "loadout_unbuilt_opening_has_no_siege_targets")
	_check(not board.pass_button.disabled, "loadout_unbuilt_opening_can_proceed")
	board.castle_action_choice.select(0)
	board.castle_target.select(0)
	board.stage_castle_action()
	_check(board.castle_plan.get("card_ids") == [], "loadout_free_construction_available")
	board.enter_powers()
	_check(
		board.gremory_box.visible and not board.deimos_box.visible, "loadout_gremory_panel_restored"
	)
	board.queue_predator()
	_check(
		board.queued.size() == 1 and board.queued[0].lord_id == "Gremory",
		"loadout_gremory_declaration_uses_selected_lord"
	)
	board.back_to_combat()
	board.open_setup()
	board.start_loadout(["Gremory", "Deimos"], selected, true)
	var gremory_cards: Array = board.session.board_view().world.hand
	board.castle_target.select(2)
	board.castle_action_choice.select(0)
	board.hand_view.select_card_id(gremory_cards[0])
	board.hand_view.select_card_id(gremory_cards[1])
	board.stage_castle_action()
	board.pass_round()
	board.hand_view.select_card_id(gremory_cards[2])
	board.hand_view.select_card_id(gremory_cards[3])
	board.queue_ruin()
	_check(
		board.hand_view.card_buttons.is_empty() and board.payment.size() == 2,
		"loadout_castle_and_ruin_can_use_entire_hand"
	)
	_check(
		not board.confirm.disabled and not board.pass_button.disabled,
		"loadout_empty_hand_keeps_resolve_and_skip_powers"
	)
	_check(
		board.queued.size() == 1 and board.queued[0].target.entity_id == Slots.castle_id(1, 0),
		"loadout_ruin_targets_specific_enemy_copy"
	)
	board.queue_free()
	await process_frame
	_finish()


func _castle(session, id: String) -> Dictionary:
	for entity in session.board_view().world.entities:
		if entity.id == id:
			return entity
	return {}


func _wait_job(board) -> bool:
	var deadline: int = Time.get_ticks_msec() + 15000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	return _check(board._job == null, "loadout_board_job_completes")


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok


func _finish() -> void:
	print("U13 loadout board failures: %d" % failures)
	quit(0 if failures == 0 else 1)
