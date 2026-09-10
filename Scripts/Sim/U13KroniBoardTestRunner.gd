extends "res://Scripts/Sim/U13DirectBoardTestRunner.gd"

const Kroni = preload("res://Scripts/Sim/U13Kroni.gd")
const Visual = preload("res://Prototype/U13/U13KroniVisual.gd")

func _run() -> void:
	var board = Scene.instantiate()
	root.add_child(board)
	await _settle()
	board.start_loadout(["Kroni", "Odradek"], [Slots.TYPES, Slots.TYPES], true)
	await _settle()
	_check(board.match_started and board._visible_world.lord_ids[0] == "Kroni", "Kroni main runner starts")
	board.enter_powers()
	await _settle()
	_check(board.kroni_box.visible and not board.consume_button.disabled and not board.ravenous_button.disabled, "both active powers available")
	var checkpoint: Dictionary = board.session.checkpoint()
	board.consume_button.pressed.emit()
	await _settle()
	_check(board.consume_targeting.visible and not board.phase_prompt.visible, "Consume opens clean board targeting")
	var enemy: Dictionary = {}
	for row in board._visible_world.entities:
		if row.kind == "card" and row.owner == 1 and row.attributes.get("role") == "guard":
			enemy = row
			break
	board._guard_selected({"kind": "zone", "owner": 1, "lane": enemy.attributes.lane, "slot": enemy.attributes.slot})
	await _settle()
	_check(board.queued.size() == 1 and board.queued[0].target.entity_id == enemy.id, "single Guard click queues exact Consume target")
	_check(not board.consume_targeting.visible and board.phase_prompt.visible, "target dialogue dismisses automatically")
	board.ravenous_button.pressed.emit()
	await _settle()
	_check(board.queued.size() == 2 and board.ravenous_button.disabled, "Ravenous queues alongside Consume")
	_check(board.session.checkpoint() == checkpoint, "UI planning leaves authoritative state unchanged")
	board._remove_kroni(0)
	await _settle()
	_check(board.queued.size() == 1 and board.queued[0].power_id == Kroni.RAVENOUS, "queue removal retains Ravenous with valid index")
	# Put real Marchers on the activation path through the debug edit boundary.
	board.session.debug_action("hunger", 0, "Lord")
	board.session.debug_action("hunger", 0, "Lord")
	board.session.debug_action("hunger", 0, "Lord")
	_check(board.session.board_view().world.hunger[0] == 3 and board.session.board_view().world.personal_tears[0] == 1, "debug Hunger follows milestone rules")
	board._refresh()
	board.queued = []
	board._queue_kroni(Kroni.RAVENOUS, {})
	board.session._opponent = {"powers": [], "order": {}}
	board.resolve_round()
	var deadline: int = Time.get_ticks_msec() + 15000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(board._job == null and board.playing, "Kroni worker resolves")
	_check(not board.kroni_visual.frames.is_empty(), "authoritative actor tape reaches board playback")
	board.finish_playback()
	_check(board.kroni_visual.frames.is_empty() and not board.kroni_visual.busy(), "skip clears actor and chomp state")
	deadline = Time.get_ticks_msec() + 15000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	board.next_round()
	deadline = Time.get_ticks_msec() + 15000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(board.session.round_number() == 2, "runner continues after Ravenous")
	var banished: Dictionary = board.session.debug_action("banish", 0, "Lord")
	_check(banished.action != "invalid", "Kroni banishes into Breach")
	board.session.choose([], {})
	board.session._opponent = {"powers": [], "order": {}}
	var breach_round: Dictionary = board.session.run_to_marching()
	_check(breach_round.action != "invalid" and board.session.marching_events().any(func(e: Dictionary) -> bool: return e.type == "KRONI_ACTORS_STARTED" and e.data.actors.any(func(a: Dictionary) -> bool: return a.breach)), "Breach manifestation wired into actual match")
	var card = board.sides[1].lord_card
	card.preview._show_preview()
	card.preview.showing_back = true
	card.preview._render()
	await _settle()
	_check(card.preview.back_art.texture != null and card.preview.back_art.visible and not card.preview.preview_art.visible, "Lord flip displays back artwork")
	_check(card.art.stretch_mode == TextureRect.STRETCH_SCALE and card.lord_stats_overlay.artwork_rect().size == card.art.size, "card art fills container and stats track its geometry")
	card.preview._hide_preview()
	board.queue_free()
	await process_frame
	var preview = load("res://Prototype/U13/U13KroniPreview.tscn").instantiate()
	root.add_child(preview)
	await _settle()
	_check(not preview.visual.bites.is_empty() and preview.visual.sheet != null, "standalone preview has real consumption events and sprite")
	preview.set_process(false)
	var visual = preview.visual
	var at: float = visual.bites[0].at
	visual.show_time(at)
	_check(visual.busy(), "consumption starts presentation pause")
	visual.advance_bite(visual.chomp_seconds * 0.5)
	_check(visual.busy() and visual.clock == at, "chomp animates without advancing field clock")
	_check(Visual.facing(Vector2(1, 0)) == 2 and Visual.facing(Vector2(-1, 0)) == 1 and Visual.facing(Vector2(0, 1)) == 0 and Visual.facing(Vector2(0, -1)) == 3, "all four supplied directions supported")
	preview.breach = true
	preview._restart()
	_check(preview.visual.frames[0].actors[0].breach, "preview switches to real Breach actor")
	preview.queue_free()
	await process_frame
	print("U13 Kroni board failures: %d" % failures)
	quit(0 if failures == 0 else 1)
