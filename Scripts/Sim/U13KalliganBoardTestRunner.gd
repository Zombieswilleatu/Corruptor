extends "res://Scripts/Sim/U13DirectBoardTestRunner.gd"

const Kalligan = preload("res://Scripts/Sim/U13Kalligan.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")


func _run() -> void:
	var board = Scene.instantiate()
	root.add_child(board)
	await _settle()
	var picker = board.setup_picker
	picker.lord_choices[0].select(picker.LORDS.find("Kalligan"))
	picker.start_button.pressed.emit()
	await _settle()
	if not _check(
		board.match_started and board._human_lord() == "Kalligan", "kalligan_picker_starts_board"
	):
		board.queue_free()
		await process_frame
		_finish()
		return
	_check(board.sides[1].lord_card.art.texture != null, "kalligan_original_lord_art")
	var initial: Dictionary = board.session.checkpoint()
	# Both prompts stage orders; neither advances the authoritative cursor.
	var hand: Array = board.session.board_view().world.hand
	board.action_zone.action_buttons.Ward.pressed.emit()
	board._choose_target({"id": "", "kind": "zone", "owner": 0, "lane": "Castle"})
	board.hand_view.select_card_id(hand[0])
	await _settle()
	board.enter_powers()
	await _settle()
	board._return_card("combat", hand[0])
	_check(board.staged_order.card_ids == [hand[0]], "kalligan_power_phase_locks_combat_cards")
	_check(
		(
			board.kalligan_box.visible
			and not board.humbaba_box.visible
			and not board.gremory_box.visible
			and not board.deimos_box.visible
		),
		"kalligan_own_power_modal"
	)
	_check(board.kalligan_buttons[Kalligan.PYROCLASM].disabled, "pyroclasm_disabled_without_scorch")
	board.kalligan_buttons[Kalligan.INFERNO].pressed.emit()
	await _settle()
	_check(
		(
			board._intent == Kalligan.INFERNO
			and board.lanes.target_lane_enabled
			and board.lanes._lane_pulses.size() == 2
		),
		"inferno_highlights_lanes_and_guard_regions"
	)
	_check(
		(
			board.sides[0].lord_guard_box.has_meta("u13_target_flash")
			and board.sides[0].castle_guard_box.has_meta("u13_target_flash")
		),
		"inferno_enemy_guard_regions_flash"
	)
	_check(
		not board.phase_prompt.board_view_collapsed and not board.inferno_target.visible,
		"inferno_keeps_modal_without_dropdown"
	)
	board._guard_selected({"id": "", "kind": "zone", "owner": 0, "lane": "Castle"})
	_check(board.queued.is_empty(), "inferno_rejects_own_guard_zone")
	board.sides[0].castle_guard_box.get_child(0).input_surface.pressed.emit()
	await _settle()
	_check(
		(
			board.queued.size() == 1
			and board.queued[0].target == {"kind": "guard", "lane": "Castle", "player_id": 1}
		),
		"guard_card_click_selects_shared_enemy_zone"
	)
	board.kalligan_buttons[Kalligan.INFERNO].pressed.emit()
	_check(
		board.queued.size() == 1 and board.kalligan_buttons[Kalligan.INFERNO].disabled,
		"inferno_repeat_click_cannot_double_queue"
	)
	_check(board.session.checkpoint() == initial, "kalligan_targeting_never_advances_state")
	# Keep the worker exercise empty: this gate tests presentation and policy,
	# while dense Marching remains in its own existing runner.
	board.back_to_combat()
	board._select_direct_action("Powers Only")
	board.enter_powers()
	board.kalligan_buttons[Kalligan.INFERNO].pressed.emit()
	await _settle()
	board.lanes.lane_selected.emit("Lord")
	await _settle()
	_check(
		board.queued[0].target == {"kind": "lane", "lane": "Lord"},
		"inferno_lane_target_is_side_neutral"
	)
	board.session._opponent = {"powers": [], "order": {}}
	board.resolve_round()
	_check(
		board._job != null and board.session.checkpoint() == initial,
		"kalligan_worker_keeps_live_state_unchanged"
	)
	if await _wait_job(board):
		_check(
			(
				board.playing
				and board.lanes.active_scorches.size() == 1
				and board.lanes.active_scorches[0].fire_round == 2
			),
			"prepared_inferno_telegraphed_during_playback"
		)
		board.finish_playback()
		if await _wait_job(board):
			board.next_round()
			if await _wait_job(board):
				await _active_controls(board)
	board.queue_free()
	await process_frame
	_finish()


func _active_controls(board) -> void:
	board.enter_powers()
	await _settle()
	var active: Dictionary = board.ScorchView.active_for(board._scorch_rows, 0)
	_check(
		active.intensity == 1 and active.remaining == 3 and active.target.lane == "Lord",
		"active_lane_scorch_intensity_and_duration"
	)
	_check(
		(
			not board.kalligan_buttons[Kalligan.INFERNO].disabled
			and board.kalligan_states[Kalligan.INFERNO].text.contains("Relocation ready")
		),
		"inferno_relocation_not_mistaken_for_cooldown"
	)
	var before: Dictionary = board.session.checkpoint()
	board.kalligan_buttons[Kalligan.INFERNO].pressed.emit()
	await _settle()
	board.sides[0].lord_guard_box.get_child(0).input_surface.pressed.emit()
	await _settle()
	_check(
		(
			board.queued.size() == 1
			and board.queued[0].target == {"kind": "guard", "lane": "Lord", "player_id": 1}
		),
		"inferno_relocation_uses_enemy_lord_guard_click"
	)
	board.kalligan_buttons[Kalligan.PYROCLASM].pressed.emit()
	await _settle()
	_check(
		(
			board.queued.size() == 2
			and board.queued[1].target.is_empty()
			and not board.confirm.disabled
		),
		"pyroclasm_queues_without_retargeting"
	)
	_check(
		board.lanes._lane_pulses.size() == 1,
		"pyroclasm_flashes_current_scorch_not_future_relocation"
	)
	board.kalligan_buttons[Kalligan.PYROCLASM].pressed.emit()
	_check(
		board.queued.size() == 2 and board.kalligan_buttons[Kalligan.PYROCLASM].disabled,
		"pyroclasm_repeat_click_locked"
	)
	_check(board.session.checkpoint() == before, "active_scorch_choices_do_not_reset_lifetime")
	# Presentation cleanup without simulating several redundant empty rounds.
	board.sides[0].bind_scorch(
		[
			{
				"target": {"kind": "guard", "player_id": 1, "lane": "Castle"},
				"fire_round": 0,
				"intensity": 2,
				"remaining": 2
			}
		],
		1
	)
	_check(
		board.sides[0].scorch_titles.Castle.text.contains("SCORCH 2"), "guard_scorch_badge_visible"
	)
	board.sides[0].bind_scorch([], 1)
	board.lanes.bind_scorch([])
	_check(
		(
			board.sides[0].scorch_titles.Castle.text == "CASTLE GUARDS"
			and board.lanes.active_scorches.is_empty()
		),
		"expired_scorch_presentation_clears"
	)


func _wait_job(board) -> bool:
	var deadline: int = Time.get_ticks_msec() + 12000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	return _check(board._job == null, "kalligan_board_worker_completes")


func _finish() -> void:
	print("U13 Kalligan board failures: %d" % failures)
	quit(0 if failures == 0 else 1)
