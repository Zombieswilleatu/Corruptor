extends "res://Prototype/U13/U13OriasBoard.gd"

const Odradek = preload("res://Scripts/Sim/U13Odradek.gd")
const RedirectPlacement = preload("res://Prototype/U13/U13RedirectPlacement.gd")
var odradek_box: VBoxContainer
var odradek_note: Label
var redirect_button: Button
var redirect_queue: VBoxContainer
var redirect_placement


func _build() -> void:
	super._build()
	if not _direct():
		return
	odradek_box = VBoxContainer.new()
	powers_box.add_child(odradek_box)
	powers_box.move_child(odradek_box, 0)
	_label(odradek_box, "ODRADEK · THE PARADOX", 18)
	odradek_note = _label(odradek_box, "", 14)
	odradek_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	redirect_button = _button(odradek_box, "REDIRECT · 1 RECONFIGURATION", _begin_redirect)
	redirect_queue = VBoxContainer.new()
	odradek_box.add_child(redirect_queue)
	var scope: Label = _label(
		odradek_box, "Redirect is available. The remaining powers and passives are coming next.", 12
	)
	scope.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	redirect_placement = RedirectPlacement.new()
	add_child(redirect_placement)
	redirect_placement.confirmed.connect(_confirm_redirect)
	redirect_placement.cancelled.connect(_cancel_redirect)


func _update_direct_ui() -> void:
	super._update_direct_ui()
	if odradek_box == null:
		return
	odradek_box.visible = _human_lord() == "Odradek"
	if not odradek_box.visible:
		return
	var bank: int = _visible_world.get("reconfiguration", [0, 0])[0]
	var reserved: int = 0
	for source in queued:
		reserved += int(source.cost.get(Odradek.RESOURCE, 0))
	odradek_note.text = (
		"Reconfiguration %d/4 · %d queued · %d available\nGain 1 each round while active. Banishment resets the bank. Redirect moves both sides; queued order matters."
		% [bank, reserved, bank - reserved]
	)
	redirect_button.disabled = (
		not _planning() or not powers_step or not _human_alive() or bank <= reserved
	)
	for child in redirect_queue.get_children():
		redirect_queue.remove_child(child)
		child.queue_free()
	for index in range(queued.size()):
		var source: Dictionary = queued[index]
		if source.power_id != Odradek.REDIRECT:
			continue
		var row := HBoxContainer.new()
		redirect_queue.add_child(row)
		var label: Label = _label(
			row,
			(
				"%d · %s → %s · %d%%"
				% [
					index + 1,
					source.target.lane,
					"Castle" if source.target.lane == "Lord" else "Lord",
					int(float(source.target.field_position.x_fp) * 100.0 / 2400.0)
				]
			),
			13
		)
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
	redirect_placement.marchers = preview
	redirect_placement.open()
	phase_prompt.set_presenting(false)


func _confirm_redirect(target: Dictionary) -> void:
	if not _planning() or not powers_step:
		return
	var draft: Array = queued.duplicate(true)
	draft.append(session.declaration(Odradek.REDIRECT, draft.size(), target))
	if _error(session.choose(draft, _order())):
		return
	queued = draft
	_cancel_redirect()


func _cancel_redirect() -> void:
	redirect_placement.close()
	_refresh()
	reopen_decision()


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
	if redirect_placement != null:
		redirect_placement.close()
	super._reset_direct()
