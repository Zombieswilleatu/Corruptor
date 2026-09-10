extends "res://Prototype/U13/U13OdradekBoard.gd"

const Kroni = preload("res://Scripts/Sim/U13Kroni.gd")
const KroniVisual = preload("res://Prototype/U13/U13KroniVisual.gd")
var kroni_box: VBoxContainer
var consume_button: Button
var ravenous_button: Button
var kroni_note: Label
var kroni_queue: VBoxContainer
var consume_targeting
var ravenous_placement
var guard_chomp
var kroni_visual


func _build() -> void:
	super._build()
	if not _direct():
		return
	kroni_box = VBoxContainer.new()
	kroni_box.add_theme_constant_override("separation", 10)
	powers_box.add_child(kroni_box)
	powers_box.move_child(kroni_box, 0)
	kroni_note = _label(kroni_box, "", 14)
	kroni_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consume_button = _button(kroni_box, "CONSUME · NEXT ROUND", _begin_consume)
	var consume_note: Label = _label(kroni_box, "Choose an enemy Guard. At next round's start, devour that exact Guard and gain 1 Hunger. No retargeting.", 13)
	consume_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ravenous_button = _button(kroni_box, "RAVENOUS", _begin_ravenous)
	var ravenous_note: Label = _label(kroni_box, "Place his start along your bottom edge. A random angle sends him toward the enemy, bouncing off the outer walls. Nearby Marchers on both sides start fleeing when he approaches, moving directly away at 30% normal speed for 1.1 seconds. Eat 6+ for 1 Soul, 1 Hunger and 1 Neutral Tear, once per activation. Two-round cooldown.", 13)
	ravenous_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kroni_queue = VBoxContainer.new()
	kroni_box.add_child(kroni_queue)
	consume_targeting = preload("res://Prototype/U13/U13GuardTargeting.gd").new()
	add_child(consume_targeting)
	consume_targeting.cancelled.connect(_cancel_consume)
	ravenous_placement = preload("res://Prototype/U13/U13KroniPlacement.gd").new()
	add_child(ravenous_placement)
	ravenous_placement.battlefield = lanes
	ravenous_placement.confirmed.connect(_confirm_ravenous)
	ravenous_placement.cancelled.connect(_cancel_ravenous)
	kroni_visual = KroniVisual.new()
	add_child(kroni_visual)
	kroni_visual.battlefield = lanes
	guard_chomp = preload("res://Prototype/U13/U13KroniGuardChomp.gd").new()
	add_child(guard_chomp)


func _update_direct_ui() -> void:
	super._update_direct_ui()
	if kroni_box == null:
		return
	kroni_box.visible = _human_lord() == "Kroni"
	_sync_consume()
	if ravenous_placement != null and ravenous_placement.visible:
		confirm.disabled = true
		pass_button.disabled = true
		phase_prompt.set_presenting(false)
	if not kroni_box.visible:
		return
	var hunger: int = int(_visible_world.get("hunger", [0, 0])[0])
	kroni_note.text = "HUNGER %d · DEFENSE %d\nIf Consume does not feed him, Kroni eats your lowest Guard—or loses 1 Hunger if none exists. Ward / Pass also loses 1 Hunger." % [hunger, 8 if hunger >= 3 else (6 if hunger >= 1 else 4)]
	var combat: Dictionary = Kroni.Guards.strip_order(_order())
	if _planning() and (combat.is_empty() or combat.get("action") == "Ward"):
		kroni_note.text += "\nTHIS TURN: %s will remove 1 Hunger. Powers alone still count as Pass." % ("PASS" if combat.is_empty() else "WARD")
	for event in session.board_view().events:
		if event.type == "KRONI_HUNGER_CHANGED" and event.data.player_id == 0 and event.data.before != event.data.after:
			kroni_note.tooltip_text = "Last Hunger change: %s · %d → %d" % [event.data.cause, event.data.before, event.data.after]
	for power in Kroni.KRONI_POWERS:
		var button: Button = consume_button if power == Kroni.CONSUME else ravenous_button
		var status: Dictionary = session.power_status(power)
		button.disabled = not _planning() or not powers_step or not _human_alive() or _queued_power(power) or int(status.remaining) > 0 or int(status.fire_round) > 0
		button.text = ("CONSUME · NEXT ROUND" if power == Kroni.CONSUME else "RAVENOUS") + (" · QUEUED" if _queued_power(power) else (" · READY ROUND %d" % status.ready_round if int(status.remaining) > 0 else ""))
	for child in kroni_queue.get_children():
		kroni_queue.remove_child(child)
		child.queue_free()
	for index in range(queued.size()):
		var source: Dictionary = queued[index]
		if source.power_id not in Kroni.KRONI_POWERS:
			continue
		var row := HBoxContainer.new()
		kroni_queue.add_child(row)
		var label: Label = _label(row, source.power_id + " queued", 13)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(row, "REMOVE", _remove_kroni.bind(index))


func _begin_ravenous() -> void:
	if ravenous_button.disabled:
		return
	_intent = Kroni.RAVENOUS
	ravenous_placement.radius_fp = Kroni.Actors.radius(int(_visible_world.get("hunger", [0, 0])[0]))
	ravenous_placement.open()
	_refresh()
	phase_prompt.set_presenting(false)


func _confirm_ravenous(target: Dictionary) -> void:
	_queue_kroni(Kroni.RAVENOUS, target)
	if _intent != Kroni.RAVENOUS:
		ravenous_placement.close()
		_refresh()
		reopen_decision()


func _cancel_ravenous() -> void:
	ravenous_placement.close()
	_intent = ""
	_refresh()
	reopen_decision()


func _reset_direct() -> void:
	if guard_chomp != null:
		guard_chomp.clear()
	if ravenous_placement != null:
		ravenous_placement.close()
	super._reset_direct()


func _begin_consume() -> void:
	if not _planning() or not powers_step or not _human_alive():
		return
	_intent = Kroni.CONSUME
	_refresh()
	_reveal_targets()
	phase_prompt.set_presenting(false)
	_sync_consume()


func _target_allowed(target: Dictionary, intent: String) -> bool:
	if intent != Kroni.CONSUME:
		return super._target_allowed(target, intent)
	return _planning() and powers_step and target.get("owner") == 1 and not _cell_guard(target).is_empty()


func _guard_selected(target: Dictionary) -> void:
	if _intent != Kroni.CONSUME:
		super._guard_selected(target)
		return
	if _target_allowed(target, _intent):
		_queue_kroni(Kroni.CONSUME, {"entity_id": _cell_guard(target).id})


func _queue_kroni(power: String, target: Dictionary) -> void:
	if not _planning() or not powers_step:
		return
	var draft: Array = queued.duplicate(true)
	draft.append(session.declaration(power, draft.size(), target))
	if _error(session.choose(draft, _order())):
		return
	queued = draft
	_intent = ""
	_refresh()
	reopen_decision()


func _remove_kroni(index: int) -> void:
	var draft: Array = queued.duplicate(true)
	draft.remove_at(index)
	for i in range(draft.size()):
		draft[i] = session.declaration(draft[i].power_id, i, draft[i].target)
	if not _error(session.choose(draft, _order())):
		queued = draft
		_refresh()
		reopen_decision()


func _cancel_consume() -> void:
	_intent = ""
	_refresh()
	reopen_decision()


func _sync_consume() -> void:
	if consume_targeting == null:
		return
	if _intent != Kroni.CONSUME or not _planning():
		consume_targeting.hide()
		return
	var markers: Array = []
	for box in [sides[0].lord_guard_box, sides[0].castle_guard_box]:
		for slot in box.get_children():
			var cell: Dictionary = {"kind": "zone", "owner": 1, "lane": "Lord" if box == sides[0].lord_guard_box else "Castle", "slot": slot.get_index()}
			if _target_allowed(cell, Kroni.CONSUME):
				markers.append({"control": slot, "selected": false})
	consume_targeting.heading.text = "CONSUME"
	consume_targeting.display("Click an enemy Guard to mark Kroni's next meal.\nIt is devoured at the start of next round if it remains an enemy Guard." if not markers.is_empty() else "No enemy Guards are available. Cancel to return to powers.", false, [], markers)
	consume_targeting.confirm_button.hide()
	_fit_consume()


func _fit_consume() -> void:
	if consume_targeting == null or not consume_targeting.visible:
		return
	phase_prompt.set_presenting(false)
	var rect: Rect2 = get_global_transform_with_canvas().affine_inverse() * phase_prompt.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, phase_prompt.size)
	consume_targeting.frame.position = rect.position
	consume_targeting.frame.custom_minimum_size.x = rect.size.x
	consume_targeting.frame.size = Vector2(rect.size.x, 0)


func _complete_job() -> void:
	var previous_session = session
	var operation: String = _job_operation
	super._complete_job()
	if kroni_visual != null and session != previous_session and playing:
		kroni_visual.load_tape(session.marching_events())
	if session != previous_session and operation == "next_round":
		_play_guard_chomps()


func _process(delta: float) -> void:
	if _job == null and guard_chomp != null and guard_chomp.active():
		guard_chomp.advance(delta)
		phase_prompt.set_presenting(false)
		if not guard_chomp.active():
			_refresh()
			reopen_decision()
		return
	_fit_consume()
	if _job == null and kroni_visual != null and kroni_visual.busy():
		kroni_visual.advance_bite(delta)
		return
	var adjusted: float = delta
	if playing and kroni_visual != null:
		adjusted = kroni_visual.limit_delta(clock, delta)
	super._process(adjusted)
	if playing and kroni_visual != null:
		kroni_visual.visible = not artillery_view.active() and not gem_dagger_view.active() and not odradek_effects.active()
		kroni_visual.show_time(clock)
	_fit_consume()


func finish_playback(skip: bool = true) -> void:
	var was_guard: bool = guard_chomp != null and guard_chomp.active()
	if guard_chomp != null:
		guard_chomp.clear()
	if kroni_visual != null:
		kroni_visual.clear()
	super.finish_playback(skip)
	if was_guard and _job == null:
		_refresh()
		reopen_decision()


func start_loadout(lords: Array, castles: Array, quick: bool) -> void:
	var previous_session = session
	if setup_open and _job == null and kroni_visual != null:
		kroni_visual.clear()
	super.start_loadout(lords, castles, quick)
	if session != previous_session:
		_play_guard_chomps()


func _play_guard_chomps() -> void:
	if guard_chomp == null:
		return
	guard_chomp.play(session.kroni_guard_events, sides)
	if guard_chomp.active():
		phase_prompt.set_presenting(false)
		# Disable decisions without rebinding the Guard controls being animated.
		for control in controls:
			control.disabled = true


func _planning() -> bool:
	return (guard_chomp == null or not guard_chomp.active()) and super._planning()
