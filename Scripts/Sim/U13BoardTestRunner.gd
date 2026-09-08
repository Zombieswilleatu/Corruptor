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
		"res://ConceptImages/Menus/Domain1.png", "res://ConceptImages/Menus/BottomBanner.png"
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
	for unit in playback.sample(3.0).units:
		_check(unit.attributes.visual_x == 0.0, "board_committed_butchers_hold_birth_round")
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
			is_equal_approx(unit.attributes.visual_x, 400.0),
			"board_butcher_midpoint_is_interpolated"
		)
	for unit in playback.sample(playback.duration).units:
		_check(unit.attributes.x_fp == 800, "board_butcher_recorded_endpoint")
	for fps in [30, 60, 144]:
		for frame in range(fps * 6):
			playback.sample(float(frame) / float(fps))
	_check(session.checkpoint() == before, "board_animation_never_changes_simulation")


func _board_controls() -> void:
	var board = Scene.instantiate()
	root.add_child(board)
	await process_frame
	_check(board.hand_view.card_buttons.size() == 4, "board_actual_hand_is_visible")
	var ids: Array = board.session.view().world.hand
	board.hand_view.select_card_id(ids[0])
	board.hand_view.select_card_id(ids[1])
	board.queue_ruin()
	_check(
		board.payment.size() == 2 and board.hand_view.card_buttons.size() == 2,
		"board_ruin_reserves_selected_physical_cards"
	)
	board.clear_powers()
	_check(
		board.payment.is_empty() and board.hand_view.card_buttons.size() == 4,
		"board_clear_returns_reserved_cards"
	)
	board.action_choice.select(2)
	board.hand_view.select_card_id(ids[0])
	board.hand_view.select_card_id(ids[1])
	board.resolve_round()
	_check(board.playing, "board_commit_starts_playback")
	var before: Dictionary = board.session.checkpoint()
	board.resolve_round()
	board._process(0.5)
	_check(
		board.session.checkpoint() == before, "board_double_click_and_playback_do_not_resolve_again"
	)
	board.finish_playback()
	_check(board.session.next_hook().is_empty(), "board_skip_completes_aftermath")
	board.next_round()
	_check(board.session.round_number() == 2, "board_next_round_control")
	board.restart()
	_check(board.session.round_number() == 1 and not board.playing, "board_restart_isolated")
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
