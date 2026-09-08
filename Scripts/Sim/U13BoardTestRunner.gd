extends SceneTree

const Textures = preload("res://Prototype/U13/U13BoardTextures.gd")
const Session = preload("res://Scripts/Sim/U13BoardSession.gd")
const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")
const Scene = preload("res://Prototype/U13/U13Board.tscn")
const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_source_textures()
	_manual_and_payment()
	_random_and_replay()
	_butcher_movement()
	if failures == 0:
		await _board_controls()
	print("U13 board failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _source_textures() -> void:
	for path in [
		"res://ConceptImages/Menus/Domain1.png",
		"res://ConceptImages/Sprites/Chits.png",
		"res://ConceptImages/Menus/BottomBanner.png",
		"res://ConceptImages/Menus/DecisionPanel.png",
		"res://ConceptImages/Menus/TopBanner.png",
		"res://ConceptImages/Menus/LordPanel.png",
		"res://ConceptImages/Menus/Battlefield.png",
		"res://ConceptImages/CastleCards/Keep.png",
		"res://ConceptImages/CastleCards/Bastion.png",
		"res://ConceptImages/CastleCards/SummoningCircle.png",
		"res://ConceptImages/CastleCards/Stockpile.png",
		"res://ConceptImages/CastleCards/SiegeEngine.png"
	]:
		var texture: Texture2D = Textures.texture(path)
		_check(
			texture != null and texture.get_width() > 0, "board_source_texture_" + path.get_file()
		)
		_check(texture == Textures.texture(path), "board_source_texture_cached")
	_check(Textures.lord_texture("Gremory") != null, "board_source_lord_art")
	for suit in ["Butcher", "Penitent", "Vulture", "Wright"]:
		for value in range(1, 6):
			_check(
				Textures.texture_for(suit, value) != null, "board_source_card_%s_%d" % [suit, value]
			)
	_check(Textures.texture_for("", 0, true) != null, "board_source_card_back")


func _manual_and_payment() -> void:
	var session = Session.new()
	if not _check(session.reset().action != "invalid", "board_starts"):
		return
	var before: Dictionary = session.checkpoint()
	var hand: Array = session.view().world.hand
	var ruin: Dictionary = session.declaration(
		Gremory.RUIN, 0, {"entity_id": Session._castle_id(1)}, {"discard_ids": hand.slice(0, 2)}
	)
	var ward: Dictionary = {"action": "Ward", "lane": "Lord", "card_ids": hand.slice(0, 2)}
	_check(session.choose([ruin], ward).action == "invalid", "board_payment_cannot_double_spend")
	_check(session.checkpoint() == before, "board_invalid_preview_preserves_owner")
	ward.card_ids = hand.slice(2, 4)
	_check(session.choose([ruin], ward).action != "invalid", "board_distinct_payment_accepted")
	_check(session.checkpoint() == before, "board_valid_preview_preserves_owner")
	_check(session.run_to_marching().action != "invalid", "board_manual_plan_resolves")
	_check(session.view().pending.size() >= 1, "board_ruin_is_scheduled")


func _random_and_replay() -> void:
	var first = Session.new()
	var second = Session.new()
	first.reset()
	second.reset()
	for round_index in range(3):
		var before: Dictionary = first.checkpoint()
		var choice: Dictionary = first.random_opponent_plan()
		Rng.draw("unrelated", "unrelated", "UNRELATED", 0, 100)
		_check(choice == first.random_opponent_plan(), "board_keyed_choice_stable_%d" % round_index)
		_check(first.checkpoint() == before, "board_bot_does_not_mutate_owner_%d" % round_index)
		_check(
			first._owner.preview_submission(1, choice.powers, choice.order).action != "invalid",
			"board_random_plan_is_legal_%d" % round_index
		)
		_check(round_index > 0 or not choice.powers.is_empty(), "board_bot_exercises_opening_power")
		for session in [first, second]:
			if not _check(
				session.run_to_marching().action != "invalid", "board_random_round_resolves"
			):
				return
			if not _finish(session):
				return
		_check(
			first.checkpoint() == second.checkpoint(), "board_same_seed_replays_%d" % round_index
		)
		first.next_round()
		second.next_round()


func _butcher_movement() -> void:
	var session = Session.new()
	session.reset()
	var hand: Array = session.view().world.hand
	session.choose([], {"action": "Ward", "lane": "Lord", "card_ids": hand.slice(0, 2)})
	# Focus this fixture on movement with no contact; bot coverage is above.
	session._opponent = {"powers": [], "order": {}}
	if not _check(session.run_to_marching().action != "invalid", "board_birth_round_resolves"):
		return
	var playback = Playback.new()
	_check(playback.build(session.marching_events()), "board_birth_tape_exists")
	_check(playback.sample(3.0).units.size() == 2, "board_two_butchers_in_tape")
	var starts: Dictionary = {}
	for unit in playback.sample(0.0).units:
		starts[unit.id] = unit.attributes.duplicate(true)
	for unit in playback.sample(3.0).units:
		_check(
			(
				unit.attributes.visual_x == starts[unit.id].x_fp
				and unit.attributes.visual_y == starts[unit.id].y_fp
			),
			"board_committed_butchers_hold_birth_round"
		)
	if not _finish(session):
		return
	if not _check(session.next_round().action != "invalid", "board_butcher_next_round"):
		return
	session._opponent = {"powers": [], "order": {}}
	if not _check(session.run_to_marching().action != "invalid", "board_butcher_movement_resolves"):
		return
	_check(playback.build(session.marching_events()), "board_no_clash_movement_tape_exists")
	var before: Dictionary = session.checkpoint()
	_check(playback.sample(0).units.size() == 2, "board_two_butchers_present")
	for unit in playback.sample(3.0).units:
		_check(
			(
				unit.attributes.visual_x > float(starts[unit.id].x_fp)
				and unit.attributes.visual_x <= float(starts[unit.id].x_fp) + 400.0
			),
			"board_butcher_moves_during_playback"
		)
	for unit in playback.sample(playback.duration).units:
		_check(
			(
				unit.attributes.x_fp > starts[unit.id].x_fp
				and unit.attributes.x_fp <= starts[unit.id].x_fp + 800
			),
			"board_butcher_endpoint_respects_speed_budget"
		)
	for fps in [30, 60, 144]:
		for frame in range(fps * 6):
			playback.sample(float(frame) / float(fps))
	_check(session.checkpoint() == before, "board_animation_never_changes_simulation")


func _board_controls() -> void:
	var board = Scene.instantiate()
	root.add_child(board)
	await process_frame
	await process_frame
	# Container layout and deferred overlay placement must settle before geometry checks.
	await process_frame
	await process_frame
	_check(board.ruin_target.item_count == 1, "board_ruin_only_enemy_target")
	var ruin_id: String = board.ruin_target.get_item_metadata(0)
	for entity in board.session.view().world.entities:
		if entity.id == ruin_id:
			_check(entity.owner == 1, "board_ruin_target_is_enemy")
	var enemy = board.sides[0]
	var human = board.sides[1]
	_check(
		enemy.castle_row.get_child_count() == 5 and human.castle_row.get_child_count() == 5,
		"board_old_layout_has_five_castle_positions"
	)
	_check(
		(
			enemy.lord_guard_box.get_child_count() == 3
			and human.castle_guard_box.get_child_count() == 3
		),
		"board_old_layout_has_guard_slots"
	)
	_check(
		(
			enemy.castle_row.get_global_rect().position.y
			< enemy.castle_guard_box.get_global_rect().position.y
		),
		"board_enemy_castles_above_guards"
	)
	_check(
		(
			human.castle_row.get_global_rect().position.y
			> human.castle_guard_box.get_global_rect().position.y
		),
		"board_human_guards_above_castles"
	)
	_check(
		board.lanes.get_global_rect().position.x >= human.get_global_rect().end.x,
		"board_battlefield_is_right_sidebar"
	)
	_check(
		board.hand_view.get_global_rect().position.y >= human.get_global_rect().end.y,
		"board_hand_below_domains"
	)
	_check(
		not board.phase_prompt.get_global_rect().intersects(board.hand_view.get_global_rect()),
		"board_modal_does_not_cover_hand"
	)
	_check(
		board.phase_prompt.size.is_equal_approx(Vector2(400, 530)), "board_modal_fixed_footprint"
	)
	_check(board.hand_view.get_global_rect().end.y <= board.size.y + 1, "board_hand_fits_viewport")
	_check(not board.history_panel.visible, "board_history_is_collapsed_overlay")
	var preview = human.lord_card.preview
	var preview_children: int = preview.get_child_count()
	board.restart()
	_check(preview.get_child_count() == preview_children, "board_refresh_reuses_lord_preview")
	var ids_for_target: Array = board.session.view().world.hand
	board.hand_view.select_card_id(ids_for_target[0])
	human.lord_card.input_surface.pressed.emit()
	_check(
		board.action_choice.selected == 2 and board.lane_choice.selected == 1,
		"board_lord_click_selects_ward"
	)
	_check(
		board.hand_view.selected_card_ids() == [ids_for_target[0]],
		"board_target_click_keeps_selected_cards"
	)
	board.restart()
	_check(
		board.phase_prompt.visible and board.pass_button.is_visible_in_tree(),
		"board_existing_prompt_has_visible_pass"
	)
	board.action_zone.action_buttons["Siege"].pressed.emit()
	_check(board.action_choice.selected == 1, "board_actionzone_button_selects_siege")
	var untouched: Dictionary = board.session.checkpoint()
	board.target_choice.clear()
	board._preview()
	_check(
		board.confirm.disabled and not board.pass_button.disabled,
		"board_missing_target_keeps_pass_available"
	)
	_check(board.status.text.contains("No enemy Castle"), "board_missing_target_explained")
	_check(board.session.checkpoint() == untouched, "board_modal_preview_is_pure")
	board.restart()
	_check(not board.powers_box.visible, "board_combat_modal_hides_powers")
	var ids: Array = board.session.view().world.hand
	board.action_zone.action_buttons["Ward"].pressed.emit()
	board.hand_view.select_card_id(ids[0])
	board.hand_view.select_card_id(ids[1])
	var before_modal: Dictionary = board.session.checkpoint()
	board.confirm.pressed.emit()
	_check(board.powers_step and not board.playing, "board_combat_confirm_opens_powers")
	_check(board.session.checkpoint() == before_modal, "board_no_state_advance_between_modals")
	_check(
		board.powers_box.visible and not board.action_zone.action_box.visible,
		"board_power_modal_hides_combat"
	)
	_check(
		board.hand_view.card_buttons.size() == 2,
		"board_combat_cards_not_available_as_power_payment"
	)
	_check(board.staged_order.card_ids == [ids[0], ids[1]], "board_staged_combat_preserved")
	board.hand_view.select_card_id(ids[2])
	board.hand_view.select_card_id(ids[3])
	board.queue_ruin()
	_check(
		board.payment.size() == 2 and board.hand_view.card_buttons.is_empty(),
		"board_ruin_uses_only_remaining_cards"
	)
	_check(not board.confirm.disabled, "board_combat_and_ruin_valid_together")
	var planned: Array = board.queued.duplicate(true)
	board.phase_prompt.view_board_button.pressed.emit()
	await process_frame
	_check(
		(
			board.phase_prompt.board_view_collapsed
			and board.phase_prompt.view_board_button.is_visible_in_tree()
		),
		"board_power_modal_collapses_to_return_tab"
	)
	board.phase_prompt.view_board_button.pressed.emit()
	await process_frame
	_check(
		board.queued == planned and board.payment.size() == 2,
		"board_return_preserves_power_payment"
	)
	_check(
		not board.phase_prompt.get_global_rect().intersects(board.hand_view.get_global_rect()),
		"board_power_modal_keeps_hand_accessible"
	)
	board.clear_powers()
	_check(
		board.hand_view.card_buttons.size() == 2 and board.payment.is_empty(),
		"board_clear_powers_keeps_combat_reservation"
	)
	board.queue_predator()
	var once: Array = board.queued.duplicate(true)
	board.queue_predator()
	_check(board.queued == once and once.size() == 1, "board_predator_second_click_is_noop")
	_check(
		board.predator_button.disabled and board.predator_state.text.contains("Queued"),
		"board_predator_shows_queued"
	)
	_check(not board.confirm.disabled, "board_duplicate_click_does_not_invalidate_plan")
	board.back_to_combat()
	_check(not board.powers_step and board.queued.is_empty(), "board_back_clears_powers")
	_check(
		board.hand_view.selected_card_ids() == [ids[0], ids[1]],
		"board_back_restores_combat_selection"
	)
	board.confirm.pressed.emit()
	board.queue_predator()
	board.pass_button.pressed.emit()
	_check(
		board.playing and board.session.plans().powers.is_empty(), "board_no_powers_clears_queue"
	)
	_check(board.session.plans().order.card_ids == [ids[0], ids[1]], "board_no_powers_keeps_combat")
	var before: Dictionary = board.session.checkpoint()
	board.resolve_round()
	board._process(0.5)
	_check(
		board.session.checkpoint() == before,
		"board_playback_and_repeat_confirm_do_not_resolve_again"
	)
	board.finish_playback()
	board.restart()
	var before_skip: Dictionary = board.session.checkpoint()
	board.pass_button.pressed.emit()
	_check(
		board.powers_step and board.staged_order.is_empty() and not board.playing,
		"board_skip_combat_still_offers_powers"
	)
	_check(board.session.checkpoint() == before_skip, "board_skip_combat_does_not_advance_state")
	board.queue_predator()
	board.confirm.pressed.emit()
	_check(
		board.playing and board.session.plans().powers.size() == 1,
		"board_power_only_round_resolves"
	)
	await process_frame
	_check(not board.pass_button.is_visible_in_tree(), "board_playback_hides_modal_actions")
	board.finish_playback()
	board.confirm.pressed.emit()
	_check(
		board.session.round_number() == 2 and not board.powers_step,
		"board_next_round_starts_with_combat"
	)
	board.pass_button.pressed.emit()
	_check(
		board.predator_state.text.contains("Cooldown 1") and board.predator_button.disabled,
		"board_predator_current_cooldown_shown"
	)
	board.pass_button.pressed.emit()
	board.finish_playback()
	board.confirm.pressed.emit()
	board.pass_button.pressed.emit()
	_check(
		board.predator_state.text.contains("Ready") and not board.predator_button.disabled,
		"board_predator_ready_after_cooldown"
	)
	board.restart()
	board.pass_button.pressed.emit()
	var fired_target: String = board.ruin_target.get_item_metadata(0)
	var ruin_hand: Array = board.session.view().world.hand
	board.hand_view.select_card_id(ruin_hand[0])
	board.hand_view.select_card_id(ruin_hand[1])
	board.ruin_button.pressed.emit()
	_check(board.queued.size() == 1 and not board.confirm.disabled, "board_ruin_can_be_queued")
	board.confirm.pressed.emit()
	board.finish_playback()
	_check(
		board.session.power_status(Gremory.RUIN).fire_round == 2, "board_ruin_armed_for_next_round"
	)
	_check(
		board.phase_prompt.copy_label.text.contains("armed"), "board_aftermath_explains_armed_ruin"
	)
	board.confirm.pressed.emit()
	var defunct: bool = false
	for entity in board.session.view().world.entities:
		if entity.id == fired_target:
			defunct = entity.attributes.status == "defunct" and entity.attributes.integrity == 0
	_check(defunct, "board_ruin_fires_from_real_modal_flow")
	_check(
		board.session.power_status(Gremory.RUIN).fire_round == 0,
		"board_ruin_no_longer_pending_after_firing"
	)
	_check(board.ruin_target.item_count == 0, "board_already_defunct_castle_not_offered_for_ruin")
	board.queue_free()
	await process_frame


func _finish(session) -> bool:
	for index in range(3):
		if session.next_hook().is_empty():
			return true
		if not _check(session.step().action != "invalid", "board_aftermath_resolves"):
			return false
	return _check(session.next_hook().is_empty(), "board_round_finished")


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok
