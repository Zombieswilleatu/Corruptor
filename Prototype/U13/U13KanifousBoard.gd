extends "res://Prototype/U13/U13ValakBoard.gd"
const Kanifous = preload("res://Scripts/Sim/U13Kanifous.gd")
var void_overlay: ColorRect
var wish_box: VBoxContainer
var wish_choice: OptionButton
var wish_target: OptionButton
var wish_button: Button
var wish_remove: Button
var wish_note: Label
var price_note: Label
var wish_placement
var wish_visual
var price_visual

func _build() -> void:
	super._build()
	if not _direct():
		return
	wish_box = VBoxContainer.new()
	powers_box.add_child(wish_box)
	_label(wish_box, "WISH · ONE PER ROUND", 18)
	wish_choice = _option(wish_box, ["Power", "Longevity", "Resurrection", "Death", "Wealth"])
	wish_choice.item_selected.connect(func(_index): _wish_targets())
	wish_target = _option(wish_box, [])
	wish_note = _label(wish_box, "", 13)
	wish_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wish_button = _button(wish_box, "QUEUE WISH", _queue_wish)
	wish_remove = _button(wish_box, "REMOVE WISH", _remove_wish)
	price_note = _label(wish_box, "", 13)
	price_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wish_placement = preload("res://Prototype/U13/U13WishDeathPlacement.gd").new()
	add_child(wish_placement)
	wish_placement.battlefield = lanes
	wish_placement.confirmed.connect(_confirm_wish_death)
	wish_placement.cancelled.connect(func(): wish_placement.close(); _refresh(); reopen_decision())
	wish_visual = preload("res://Prototype/U13/U13WishmasterVisual.gd").new()
	add_child(wish_visual)
	wish_visual.battlefield = lanes
	price_visual = preload("res://Prototype/U13/U13WishPriceVisual.gd").new()
	add_child(price_visual)
	void_overlay = ColorRect.new()
	void_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	void_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	void_overlay.z_index = 95
	var material := ShaderMaterial.new()
	material.shader = preload("res://Prototype/U13/U13Void.gdshader")
	void_overlay.material = material
	add_child(void_overlay)
	void_overlay.hide()
	_wish_targets()

func _wish_targets() -> void:
	wish_target.clear()
	var power: String = Kanifous.Wishes[wish_choice.selected]
	if power in ["WishPower", "WishResurrection"]:
		wish_target.add_item("Lord lane" if power == "WishPower" else "Lord guards")
		wish_target.add_item("Castle lane" if power == "WishPower" else "Castle guards")
	elif power == "WishLongevity":
		for row in _visible_world.get("entities", []):
			if row.kind == "castle" and row.owner == 0 and row.attributes.status in ["standing", "defunct"]:
				wish_target.add_item("%s · slot %d" % [row.attributes.get("castle_type", "Castle"), int(row.attributes.get("castle_slot", 0)) + 1])
				wish_target.set_item_metadata(wish_target.item_count - 1, row.id)
	wish_target.visible = power not in ["WishDeath", "WishWealth"]
	wish_note.text = ["Spawn 1–3 random-suit Marchers: 70% one, 25% two, 5% three.", "Restore your Castle to full Integrity. Ruined/Profaned targets fail.", "Restore your Guards defeated this round in the selected zone.", "Choose a small circle on the field. Destroy every Marcher inside, friend or enemy.", "Draw 2 cards."][wish_choice.selected] + "\nSuccess creates a hidden Price due in 1–3 rounds."

func _update_direct_ui() -> void:
	super._update_direct_ui()
	if wish_box == null:
		return
	wish_box.visible = _human_lord() == "Kanifous"
	lanes.void_active = _visible_world.get("void_active", false)
	void_overlay.visible = _visible_world.get("void_active", false)
	wish_visual.bind_world(_visible_world)
	var has_wish: bool = queued.any(func(row: Dictionary) -> bool: return row.power_id in Kanifous.Wishes)
	wish_button.disabled = not _planning() or not powers_step or not _human_alive() or has_wish
	wish_remove.visible = has_wish
	price_note.text = ""
	for price in _visible_world.get("wish_prices", []):
		price_note.text += "%s Price: %s\n" % ["Your" if price.owner == 0 else "Enemy", "Overdue · still owed" if price.due_round < session.round_number() else "Round %d" % price.due_round]
	if wish_placement.visible:
		confirm.disabled = true
		pass_button.disabled = true
		phase_prompt.set_presenting(false)

func _queue_wish() -> void:
	if wish_button.disabled:
		return
	var power: String = Kanifous.Wishes[wish_choice.selected]
	var target: Dictionary = {}
	if power == "WishDeath":
		wish_placement.open()
		_refresh()
		return
	if power == "WishPower":
		target = {"lane": "Lord" if wish_target.selected == 0 else "Castle"}
	elif power == "WishResurrection":
		target = {"kind": "guard_zone", "zone": "Lord" if wish_target.selected == 0 else "Castle"}
	elif power == "WishLongevity":
		if wish_target.selected < 0:
			return
		target = {"entity_id": wish_target.get_item_metadata(wish_target.selected)}
	_queue_valak(session.declaration(power, queued.size(), target))

func _confirm_wish_death(target: Dictionary) -> void:
	if _queue_valak(session.declaration("WishDeath", queued.size(), target)):
		wish_placement.close()
		_refresh()
		reopen_decision()

func _remove_wish() -> void:
	for index in range(queued.size()):
		if queued[index].power_id in Kanifous.Wishes:
			_remove_valak(index)
			return

func _planning() -> bool:
	return (wish_placement == null or not wish_placement.visible) and super._planning()


func _complete_job() -> void:
	var previous = session
	var operation: String = _job_operation
	super._complete_job()
	if session != previous and price_visual != null:
		price_visual.present(session.kanifous_events, sides)
	if session != previous and operation == "marching" and wish_visual != null:
		wish_visual.play_events(session.kanifous_events)

func _process(delta: float) -> void:
	super._process(delta)
	if wish_visual != null and playing:
		wish_visual.show_time(clock)

func finish_playback(skip: bool = true) -> void:
	super.finish_playback(skip)
	if wish_visual != null:
		wish_visual.playback_time = -1.0
		wish_visual.bind_world(session.board_view().world)

func _reset_direct() -> void:
	if wish_placement != null:
		wish_placement.close()
	super._reset_direct()
