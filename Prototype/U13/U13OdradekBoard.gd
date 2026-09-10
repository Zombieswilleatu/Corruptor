extends "res://Prototype/U13/U13OriasBoard.gd"

const Odradek = preload("res://Scripts/Sim/U13Odradek.gd")
const RedirectPlacement = preload("res://Prototype/U13/U13RedirectPlacement.gd")
var reconfiguration_menu: PanelContainer
var reconfiguration_entry: Button
var odradek_box: VBoxContainer
var odradek_note: Label
var redirect_button: Button
var redirect_queue: VBoxContainer
var redirect_placement
var shift_button: Button
var false_orders_button: Button
var inversion_button: Button
var area_power: String = Odradek.REDIRECT
var guard_source: Dictionary = {}
var guard_destination: Dictionary = {}
var guard_targeting
var debug_panel
var debug_button: Button
var odradek_effects


func _build() -> void:
	super._build()
	if not _direct():
		return
	guard_targeting = preload("res://Prototype/U13/U13GuardTargeting.gd").new()
	add_child(guard_targeting)
	guard_targeting.confirmed.connect(_confirm_guard_power)
	guard_targeting.cancelled.connect(_cancel_guard_power)
	guard_targeting.zone_selected.connect(func(pid: int, lane: String) -> void: _guard_selected({"kind": "zone", "owner": pid, "lane": lane}))
	odradek_effects = preload("res://Prototype/U13/U13OdradekEffects.gd").new()
	add_child(odradek_effects)
	debug_panel = preload("res://Prototype/U13/U13DebugPanel.gd").new()
	add_child(debug_panel)
	debug_panel.requested.connect(_debug_action)
	debug_panel.closed.connect(reopen_decision)
	debug_button = _button(header.tools_box, "DEBUG", _open_debug)
	reconfiguration_entry = _button(powers_box, "RECONFIGURATION", _open_reconfiguration)
	powers_box.move_child(reconfiguration_entry, 0)
	reconfiguration_menu = PanelContainer.new()
	reconfiguration_menu.z_index = 121
	preload("res://Prototype/U13/U13ReconfigurationStyle.gd").apply(reconfiguration_menu)
	add_child(reconfiguration_menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	reconfiguration_menu.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	odradek_box = VBoxContainer.new()
	odradek_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	odradek_box.add_theme_constant_override("separation", 10)
	scroll.add_child(odradek_box)
	_button(column, "BACK TO POWERS", _close_reconfiguration)
	reconfiguration_menu.hide()
	_label(odradek_box, "ODRADEK · THE PARADOX", 18)
	odradek_note = _label(odradek_box, "", 14)
	odradek_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	redirect_button = _button(odradek_box, "REDIRECT · 1 RECONFIGURATION", _begin_redirect)
	false_orders_button = _button(
		odradek_box, "FALSE ORDERS · 2 · NEXT ROUND", _begin_guard_power.bind(Odradek.FALSE_ORDERS)
	)
	shift_button = _button(odradek_box, "ALLEGIANCE SHIFT · 3", _begin_shift)
	inversion_button = _button(
		odradek_box, "INVERSION · 4 · NEXT ROUND", _begin_guard_power.bind(Odradek.INVERSION)
	)
	for pair in [
		[redirect_button, "Both sides inside the circle move to the other lane after combat."],
		[false_orders_button, "Move one Guard to its owner's other zone before next round's deployment."],
		[shift_button, "Enemy Marchers inside the smaller circle become yours after combat."],
		[inversion_button, "Flip legal Guards from either side to the opposite matching zone next round. Any success adds 1 Neutral Tear."]
	]:
		var note: Label = _label(odradek_box, pair[1], 13)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		odradek_box.move_child(note, pair[0].get_index() + 1)
	redirect_queue = VBoxContainer.new()
	odradek_box.add_child(redirect_queue)
	var scope: Label = _label(
		odradek_box,
		"Psychic Interlock reflects the first killing attack against your Marchers each round. In the Breach, Paradox Geometry rewrites a random allegiance group.",
		12
	)
	scope.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	redirect_placement = RedirectPlacement.new()
	add_child(redirect_placement)
	redirect_placement.battlefield = lanes
	redirect_placement.confirmed.connect(_confirm_redirect)
	redirect_placement.cancelled.connect(_cancel_redirect)


func _update_direct_ui() -> void:
	super._update_direct_ui()
	_sync_guard_targeting()
	if debug_button != null:
		debug_button.disabled = not _planning()
	if odradek_box == null:
		return
	odradek_box.visible = _human_lord() == "Odradek"
	reconfiguration_entry.visible = odradek_box.visible
	if not odradek_box.visible:
		return
	var bank: int = _visible_world.get("reconfiguration", [0, 0])[0]
	reconfiguration_entry.text = "RECONFIGURATION · %d / 4" % bank
	reconfiguration_entry.disabled = not _planning() or not powers_step or not _human_alive()
	var reserved: int = 0
	for source in queued:
		reserved += int(source.cost.get(Odradek.RESOURCE, 0))
	odradek_note.text = (
		"Reconfiguration %d/4 · %d queued · %d available\nGain 1 each round while active. Banishment resets the bank. Redirect moves both sides. Shift converts enemies. Guard orders fire next round."
		% [bank, reserved, bank - reserved]
	)
	redirect_button.disabled = (
		not _planning() or not powers_step or not _human_alive() or bank <= reserved
	)
	false_orders_button.disabled = redirect_button.disabled or bank - reserved < 2
	shift_button.disabled = redirect_button.disabled or bank - reserved < 3
	inversion_button.disabled = redirect_button.disabled or bank - reserved < 4
	for child in redirect_queue.get_children():
		redirect_queue.remove_child(child)
		child.queue_free()
	for index in range(queued.size()):
		var source: Dictionary = queued[index]
		if source.power_id not in Odradek.POWERS:
			continue
		var row := HBoxContainer.new()
		redirect_queue.add_child(row)
		var label: Label = _label(
			row,
			(
				"%d · %s · %s%s"
				% [
					index + 1,
					_odradek_name(source.power_id),
					source.target.lane,
					(
						" · next round"
						if source.power_id in [Odradek.FALSE_ORDERS, Odradek.INVERSION]
						else ""
					)
				]
			),
			13
		)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var up: Button = _button(row, "↑", _move_redirect.bind(index, -1))
		up.disabled = index == 0 or not _planning()
		var down: Button = _button(row, "↓", _move_redirect.bind(index, 1))
		down.disabled = index == queued.size() - 1 or not _planning()
		var remove: Button = _button(row, "×", _remove_redirect.bind(index))
		remove.disabled = not _planning()
	if redirect_placement != null and redirect_placement.visible:
		confirm.disabled = true
		pass_button.disabled = true


func _begin_redirect() -> void:
	if redirect_button.disabled:
		return
	area_power = Odradek.REDIRECT
	_open_odradek_area()


func _begin_shift() -> void:
	if shift_button.disabled:
		return
	area_power = Odradek.SHIFT
	_open_odradek_area()


func _open_odradek_area() -> void:
	reconfiguration_menu.hide()
	_intent = ""
	_target = {}
	var preview: Array = []
	for entity in _visible_world.entities:
		if entity.kind == "marcher":
			preview.append(entity.duplicate(true))
	for source in queued:
		if source.power_id != Odradek.REDIRECT:
			continue
		var area: Dictionary = Odradek.Space.circle_region(
			source.target.lane, source.target.field_position, Odradek.REDIRECT_RADIUS_FP
		)
		for unit in preview:
			var a: Dictionary = unit.attributes
			if Odradek.Space.contains(area, a.lane, {"x_fp": a.x_fp, "y_fp": a.y_fp}).inside:
				a.lane = "Castle" if a.lane == "Lord" else "Lord"
	# Every Redirect fires at 10B, before every Shift at 10C. Earlier Shifts
	# affect ownership in the preview after those position edits.
	if area_power == Odradek.SHIFT:
		for source in queued:
			if source.power_id != Odradek.SHIFT:
				continue
			var area: Dictionary = Odradek.Space.circle_region(
				source.target.lane, source.target.field_position, Odradek.SHIFT_RADIUS_FP
			)
			for unit in preview:
				var a: Dictionary = unit.attributes
				if (
					unit.owner == 1
					and (
						Odradek
						. Space
						. contains(area, a.lane, {"x_fp": a.x_fp, "y_fp": a.y_fp})
						. inside
					)
				):
					unit.owner = 0
	redirect_placement.allegiance_mode = area_power == Odradek.SHIFT
	redirect_placement.radius_fp = (
		Odradek.SHIFT_RADIUS_FP if area_power == Odradek.SHIFT else Odradek.REDIRECT_RADIUS_FP
	)
	redirect_placement.confirm_button.text = (
		"TURN THEIR LOYALTY" if area_power == Odradek.SHIFT else "REWRITE THE PATH"
	)
	redirect_placement.marchers = preview
	redirect_placement.open()
	phase_prompt.set_presenting(false)


func _confirm_redirect(target: Dictionary) -> void:
	if not _planning() or not powers_step:
		return
	var draft: Array = queued.duplicate(true)
	draft.append(session.declaration(area_power, draft.size(), target))
	if _error(session.choose(draft, _order())):
		return
	queued = draft
	redirect_placement.close()
	reconfiguration_menu.hide()
	_refresh()
	reopen_decision()


func _cancel_redirect() -> void:
	redirect_placement.close()
	_refresh()
	_open_reconfiguration()


func _move_redirect(index: int, direction: int) -> void:
	if not _planning() or index + direction < 0 or index + direction >= queued.size():
		return
	var draft: Array = queued.duplicate(true)
	var item = draft[index]
	draft[index] = draft[index + direction]
	draft[index + direction] = item
	_replace_redirect_queue(draft)


func _remove_redirect(index: int) -> void:
	if not _planning():
		return
	var draft: Array = queued.duplicate(true)
	draft.remove_at(index)
	_replace_redirect_queue(draft)


func _replace_redirect_queue(draft: Array) -> void:
	for index in range(draft.size()):
		var source: Dictionary = draft[index]
		draft[index] = session.declaration(source.power_id, index, source.target, source.cost)
	if _error(session.choose(draft, _order())):
		return
	queued = draft
	_refresh()


func _reset_direct() -> void:
	if reconfiguration_menu != null:
		reconfiguration_menu.hide()
	guard_destination = {}
	if guard_targeting != null:
		guard_targeting.hide()
	guard_source = {}
	area_power = Odradek.REDIRECT
	if odradek_effects != null:
		odradek_effects.clear()
	if redirect_placement != null:
		redirect_placement.close()
	super._reset_direct()


static func _odradek_name(power: String) -> String:
	return (
		{
			Odradek.REDIRECT: "Redirect",
			Odradek.FALSE_ORDERS: "False Orders",
			Odradek.SHIFT: "Allegiance Shift",
			Odradek.INVERSION: "Inversion"
		}
		. get(power, power)
	)


func _begin_guard_power(power: String) -> void:
	if not _planning() or not powers_step or not _human_alive():
		return
	if (
		(power == Odradek.FALSE_ORDERS and false_orders_button.disabled)
		or (power == Odradek.INVERSION and inversion_button.disabled)
	):
		return
	reconfiguration_menu.hide()
	_intent = power
	guard_destination = {}
	guard_source = {}
	_target = {}
	_refresh()
	_reveal_targets()
	phase_prompt.set_presenting(false)


func _guide() -> String:
	if _intent == Odradek.FALSE_ORDERS:
		return "FALSE ORDERS · click a Guard to queue its move to the same owner's other zone next round."
	if _intent == Odradek.INVERSION:
		return "INVERSION · select your or the enemy's Guard zone. Next round its Guards transfer to free slots in the opposite side's matching zone; success grants one Neutral Tear."
	return super._guide()


func _cell_guard(target: Dictionary) -> Dictionary:
	for entity in _visible_world.entities:
		if (
			entity.kind == "card"
			and entity.attributes.get("role") == "guard"
			and (
				(target.get("id", "") == entity.id)
				or (
					target.get("owner") == entity.owner
					and target.get("lane") == entity.attributes.lane
					and target.get("slot", -1) == entity.attributes.slot
				)
			)
		):
			return entity
	return {}


func _target_allowed(target: Dictionary, intent: String) -> bool:
	if intent not in [Odradek.FALSE_ORDERS, Odradek.INVERSION]:
		return super._target_allowed(target, intent)
	if not _planning() or not powers_step or target.get("lane") not in Odradek.Guards.LANES:
		return false
	if intent == Odradek.INVERSION:
		return target.get("owner") in [0, 1] and target.get("kind") in ["zone", "card"]
	if guard_source.is_empty():
		return not _cell_guard(target).is_empty()
	return (
		target.get("owner") == guard_source.owner
		and target.lane != guard_source.attributes.lane
		and target.get("kind") in ["zone", "card"]
	)


func _guard_selected(target: Dictionary) -> void:
	if _intent not in [Odradek.FALSE_ORDERS, Odradek.INVERSION]:
		super._guard_selected(target)
		return
	if not _target_allowed(target, _intent):
		return
	if _intent == Odradek.FALSE_ORDERS and guard_source.is_empty():
		guard_source = _cell_guard(target).duplicate(true)
		guard_destination = {"kind": "zone", "owner": guard_source.owner, "lane": "Castle" if guard_source.attributes.lane == "Lord" else "Lord"}
		_confirm_guard_power()
		return
	guard_destination = target.duplicate(true)
	_sync_guard_targeting()


func _confirm_guard_power() -> void:
	if guard_destination.is_empty() or not _target_allowed(guard_destination, _intent):
		return
	var target: Dictionary = guard_destination
	var payload: Dictionary = {"owner_id": int(target.owner), "lane": target.lane}
	if _intent == Odradek.FALSE_ORDERS:
		payload["entity_id"] = guard_source.id
	var draft: Array = queued.duplicate(true)
	draft.append(session.declaration(_intent, draft.size(), payload))
	var result: Dictionary = session.choose(draft, _order())
	if _error(result):
		if _intent == Odradek.FALSE_ORDERS:
			guard_source = {}
			guard_destination = {}
			_sync_guard_targeting()
		guard_targeting.note.text += "\nCould not queue: " + String(result.get("reason", "Target unavailable"))
		return
	queued = draft
	_intent = ""
	guard_destination = {}
	guard_source = {}
	_refresh()
	reconfiguration_menu.hide()
	reopen_decision()


func _guard_input(event: InputEvent, owner_id: int, lane: String, control: Control) -> void:
	if (
		_intent in [Odradek.FALSE_ORDERS, Odradek.INVERSION]
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		control.accept_event()
		_guard_selected({"id": "", "kind": "zone", "owner": owner_id, "lane": lane})
		return
	super._guard_input(event, owner_id, lane, control)


func _open_debug() -> void:
	if not _planning() or not session.has_method("debug_action"):
		return
	redirect_placement.close()
	debug_panel.show()
	phase_prompt.set_presenting(false)


func _debug_action(action: String, pid: int, lane: String) -> void:
	if not _planning():
		debug_panel.message.text = "Debug controls are available during planning."
		return
	var result: Dictionary = session.debug_action(action, pid, lane)
	if result.action == "invalid":
		debug_panel.message.text = String(result.get("reason", "Action unavailable")).replace("debug_", "").replace("_", " ").capitalize()
		return
	_reset_direct()
	queued = []
	payment = []
	castle_plan = {}
	staged_order = {}
	_refresh()
	debug_panel.message.text = result.message
	phase_prompt.set_presenting(false)


func _complete_job() -> void:
	var previous_session = session
	super._complete_job()
	if odradek_effects != null and session != previous_session and session.has_method("_capture_odradek_visuals"):
		odradek_effects.play(session.odradek_visuals, lanes, sides)
		if odradek_effects.active():
			if not playing:
				_refresh()
			odradek_effects._begin()


func _process(delta: float) -> void:
	_sync_reconfiguration_panels()
	if _job == null and odradek_effects != null and odradek_effects.active():
		if artillery_view.active():
			artillery_view.advance(delta)
			if not artillery_view.active():
				_restore_artillery_castles()
			return
		if gem_dagger_view.active():
			gem_dagger_view.advance(delta)
			if not gem_dagger_view.active():
				_finish_gem_presentation()
			return
		odradek_effects.advance(delta)
		if not odradek_effects.active() and not playing:
			_refresh()
			reopen_decision()
		_busy_label.text = "Odradek reconfigures the battlefield…"
		return
	super._process(delta)
	_sync_reconfiguration_panels()


func finish_playback(skip: bool = true) -> void:
	var was_effect: bool = odradek_effects != null and odradek_effects.active()
	if odradek_effects != null:
		odradek_effects.clear()
	super.finish_playback(skip)
	if was_effect and not playing and _job == null:
		_refresh()


func _planning() -> bool:
	return (odradek_effects == null or not odradek_effects.active()) and super._planning()


func _cancel_guard_power() -> void:
	_intent = ""
	guard_source = {}
	guard_destination = {}
	_refresh()
	_open_reconfiguration()


func _sync_guard_targeting() -> void:
	if guard_targeting == null:
		return
	if _intent not in [Odradek.FALSE_ORDERS, Odradek.INVERSION] or not _planning():
		guard_targeting.hide()
		return
	var zones: Array = []
	var markers: Array = []
	for pid in [0, 1]:
		var side = sides[1 - pid]
		for lane in ["Lord", "Castle"]:
			var box = side.lord_guard_box if lane == "Lord" else side.castle_guard_box
			var target: Dictionary = {"kind": "zone", "owner": pid, "lane": lane}
			if _intent == Odradek.FALSE_ORDERS and guard_source.is_empty():
				for slot in box.get_children():
					var cell: Dictionary = target.duplicate()
					cell.slot = slot.get_index()
					if _target_allowed(cell, _intent):
						markers.append({"control": slot, "selected": false})
			elif _target_allowed(target, _intent):
				zones.append(target)
				markers.append({"control": box, "selected": guard_destination.get("owner", -1) == pid and guard_destination.get("lane", "") == lane})
	if not guard_source.is_empty():
		var side = sides[1 - int(guard_source.owner)]
		var box = side.lord_guard_box if guard_source.attributes.lane == "Lord" else side.castle_guard_box
		markers.append({"control": box.get_child(int(guard_source.attributes.slot)), "selected": true})
	var message: String = "Choose a Guard zone on either side.\nGuards switch sides next round, filling free slots. A successful transfer adds 1 Neutral Tear."
	if _intent == Odradek.FALSE_ORDERS:
		message = "Click a Guard to queue its move to the same owner's other zone next round. The destination is automatic."
	if not guard_source.is_empty():
		message += "\nSelected: %s %s Guard, slot %d." % ["your" if guard_source.owner == 0 else "enemy", guard_source.attributes.lane, int(guard_source.attributes.slot) + 1]
	if not guard_destination.is_empty():
		message += "\nSelected zone: %s %s Guards.\nConfirm to queue; resolves NEXT ROUND." % ["your" if guard_destination.owner == 0 else "enemy", guard_destination.lane]
	if _intent == Odradek.INVERSION and not guard_destination.is_empty():
		message += "\nDestination: %s %s Guards." % ["ENEMY" if guard_destination.owner == 0 else "YOUR", guard_destination.lane]
	guard_targeting.heading.text = _odradek_name(_intent).to_upper()
	guard_targeting.display(message, not guard_destination.is_empty(), zones, markers)
	guard_targeting.confirm_button.visible = _intent != Odradek.FALSE_ORDERS


func _open_reconfiguration() -> void:
	if reconfiguration_menu == null or not _planning() or not powers_step:
		return
	reconfiguration_menu.show()
	phase_prompt.set_presenting(false)
	_sync_reconfiguration_panels()


func _close_reconfiguration() -> void:
	reconfiguration_menu.hide()
	reopen_decision()


func _sync_reconfiguration_panels() -> void:
	if reconfiguration_menu == null:
		return
	var targeting: bool = guard_targeting != null and guard_targeting.visible
	if not targeting and not reconfiguration_menu.visible:
		return
	if phase_prompt.visible:
		phase_prompt.set_presenting(false)
	var rect: Rect2 = get_global_transform_with_canvas().affine_inverse() * phase_prompt.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, phase_prompt.size)
	if targeting:
		reconfiguration_menu.hide()
		guard_targeting.frame.position = rect.position
		guard_targeting.frame.custom_minimum_size.x = rect.size.x
		guard_targeting.frame.size = Vector2(rect.size.x, 0)
	else:
		reconfiguration_menu.position = rect.position
		reconfiguration_menu.size = rect.size
