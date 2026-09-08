extends "res://Scripts/Sim/U13DirectBoardTestRunner.gd"

const Humbaba = preload("res://Scripts/Sim/U13Humbaba.gd")
const CastleArtwork = preload("res://Prototype/U13/U13CastleArtwork.gd")


func _run() -> void:
	var board = Scene.instantiate()
	root.add_child(board)
	await _settle()
	var picker = board.setup_picker
	picker.lord_choices[0].select(picker.LORDS.find("Humbaba"))
	picker.start_button.pressed.emit()
	await _settle()
	if not _check(
		board.match_started and board._human_lord() == "Humbaba",
		"humbaba_picker_starts_playable_board"
	):
		board.queue_free()
		await process_frame
		_finish()
		return
	_check(board.sides[1].lord_card.art.texture != null, "humbaba_reuses_original_lord_art")
	_check(
		(
			board.sides[1].lord_card.caption.text.contains("DEFENSE 3")
			and board.sides[1].lord_card.caption.text.contains("NO THREAT")
		),
		"humbaba_live_defense_and_absent_threat_visible"
	)
	_artwork(board)
	var before: Dictionary = board.session.checkpoint()
	var hand: Array = board.session.board_view().world.hand
	board.action_zone.action_buttons.Ward.pressed.emit()
	var own_lord: Dictionary = {}
	for entity in board._visible_world.entities:
		if entity.kind == "lord" and entity.owner == 0:
			own_lord = board._entity_target(entity.id)
	board._choose_target(own_lord)
	board.hand_view.select_card_id(hand[0])
	await _settle()
	board.enter_powers()
	await _settle()
	_check(
		(
			board.humbaba_box.visible
			and not board.gremory_box.visible
			and not board.deimos_box.visible
		),
		"humbaba_only_own_powers_visible"
	)
	_check(board.session.checkpoint() == before, "humbaba_modal_transition_does_not_advance_state")
	board._return_card("combat", hand[0])
	_check(board.staged_order.card_ids == [hand[0]], "humbaba_power_phase_locks_combat_cards")
	for power in [Humbaba.MUSTER, Humbaba.BREATH]:
		board.humbaba_buttons[power].pressed.emit()
		await _settle()
		_check(
			(
				board._intent == power
				and board.lanes.target_lane_enabled
				and board.lanes._lane_pulses.size() == 2
			),
			"humbaba_power_then_lane_pulse_" + power
		)
		_check(
			not board.phase_prompt.board_view_collapsed and not board.humbaba_lanes[power].visible,
			"humbaba_targeting_keeps_modal_and_hides_dropdown"
		)
		board.lanes.lane_selected.emit("Lord")
		await _settle()
		var queued: Array = board.queued.duplicate(true)
		board.humbaba_buttons[power].pressed.emit()
		_check(
			board.queued == queued and board.humbaba_buttons[power].disabled,
			"humbaba_repeat_click_cannot_double_queue_" + power
		)
	_check(
		board.queued.size() == 2 and not board.confirm.disabled,
		"humbaba_both_powers_and_combat_ready"
	)
	_check(board.session.checkpoint() == before, "humbaba_target_choices_still_uncommitted")
	# Exercise both powers through the worker with a sparse field. Combat
	# commitment locking was checked above; skip it here to keep this gate bounded.
	board.back_to_combat()
	board._select_direct_action("Powers Only")
	board.enter_powers()
	for power in [Humbaba.MUSTER, Humbaba.BREATH]:
		board.humbaba_buttons[power].pressed.emit()
		await _settle()
		board.lanes.lane_selected.emit("Lord")
		await _settle()
	board.session._opponent = {"powers": [], "order": {}}
	board.resolve_round()
	_check(
		board._job != null and board.session.checkpoint() == before,
		"humbaba_worker_preserves_live_state_while_running"
	)
	if await _wait_humbaba_job(board):
		_check(
			board.playing and board.session.setup_lords[0] == "Humbaba",
			"humbaba_worker_publishes_playback"
		)
		_check(
			board.lanes.active_auras == [{"owner": 0, "lane": "Lord", "remaining": 2}],
			"humbaba_breath_visible_during_playback"
		)
		var count: int = 0
		for unit in board.lanes._units:
			if unit.owner == 0 and unit.attributes.suit == "Penitent":
				count += 1
		_check(count == 3, "humbaba_muster_chits_enter_playback")
		board.finish_playback()
		if await _wait_humbaba_job(board):
			board.next_round()
			if await _wait_humbaba_job(board):
				board.enter_powers()
				await _settle()
				_check(
					board.humbaba_states[Humbaba.MUSTER].text.contains("Cooldown 1"),
					"humbaba_muster_cooldown_visible"
				)
				_check(
					(
						board.humbaba_states[Humbaba.BREATH].text.contains("Breath active")
						and board.humbaba_buttons[Humbaba.BREATH].disabled
					),
					"humbaba_active_breath_not_reusable"
				)
				_check(
					board.lanes.active_auras[0].remaining == 1,
					"humbaba_breath_remaining_round_visible"
				)
	board.queue_free()
	await process_frame
	_finish()


func _wait_humbaba_job(board) -> bool:
	var deadline: int = Time.get_ticks_msec() + 15000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	return _check(board._job == null, "humbaba_board_worker_completes")


func _artwork(board) -> void:
	var active = board.sides[1].castle_row.get_child(0)
	var building = board.sides[1].castle_row.get_child(1)
	_check(
		active.castle_artwork != null and not active.castle_artwork.construction,
		"castle_active_uses_fracture_art"
	)
	_check(
		(
			building.castle_artwork.construction
			and is_equal_approx(building.castle_artwork.display_ratio, 1.0 / 3.0)
		),
		"castle_construction_art_matches_seven_of_twentyone"
	)
	_check(
		building.input_surface.get_meta("commission_eligible", false),
		"castle_art_preserves_commission_target"
	)
	for maximum in [21, 30]:
		var third: int = 7 if maximum == 21 else 10
		_check(
			(
				CastleArtwork.damage_band(maximum, maximum) == 0
				and CastleArtwork.damage_band(third * 2, maximum) == 1
				and CastleArtwork.damage_band(third, maximum) == 2
			),
			"castle_damage_bands_scale_with_maximum_" + str(maximum)
		)
	# Visual transitions own only a ratio; source artwork/inspection and game
	# attributes remain intact, including a low-Integrity Commission transition.
	var attributes: Dictionary = {
		"integrity": 7, "max_integrity": 21, "construction_state": "active"
	}
	var copy: Dictionary = attributes.duplicate(true)
	building.bind_castle_art(attributes, {"ratio": 1.0 / 3.0, "construction": true})
	_check(
		(
			not building.castle_artwork.construction
			and attributes == copy
			and building.art.texture != null
		),
		"castle_commission_switches_from_progress_to_true_damage"
	)
	board._refresh()


func _finish() -> void:
	print("U13 Humbaba board failures: %d" % failures)
	quit(0 if failures == 0 else 1)
