extends Control

signal start_requested(lords: Array, castles: Array, quick: bool)
signal cancelled
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const LORDS: Array = ["Deimos", "Gremory"]
var lord_choices: Array = []
var castle_choices: Array = [[], []]
var opening: OptionButton
var start_button: Button
var cancel_button: Button
var message: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 660)
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("171511")
	skin.border_color = Color("93713d")
	skin.set_border_width_all(2)
	skin.content_margin_left = 24
	skin.content_margin_right = 24
	skin.content_margin_top = 20
	skin.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", skin)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	_label(column, "CHOOSE YOUR LORD & CASTLES", 24)
	_label(
		column, "Five Castle slots · maximum two of each type · one shared Castle Guard zone", 16
	)
	var players := HBoxContainer.new()
	players.add_theme_constant_override("separation", 36)
	column.add_child(players)
	for pid in [0, 1]:
		var side := VBoxContainer.new()
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side.add_theme_constant_override("separation", 8)
		players.add_child(side)
		_label(side, "YOU" if pid == 0 else "RANDOM-LEGAL OPPONENT", 18)
		var lord := _option(side, LORDS)
		lord.select(pid)
		lord_choices.append(lord)
		for slot in range(Slots.SLOT_COUNT):
			var row := HBoxContainer.new()
			side.add_child(row)
			_label(row, "Slot %d" % (slot + 1), 16)
			var choice := _option(row, Slots.TYPES)
			choice.select([4, 4, 0, 1, 3][slot])
			castle_choices[pid].append(choice)
	_label(column, "TEST OPENING", 16)
	opening = _option(
		column,
		[
			"Quick start: slot 1 active at 12, slot 2 protected at 7, others unbuilt",
			"Construction start: all five Castles unbuilt"
		]
	)
	_label(
		column,
		"Both openings use four hand cards and two Repair tokens per side. These are exercise resources, not the final starting economy.",
		14
	)
	_label(
		column,
		"Siege Engine artillery is implemented. Other Castle types have construction and repair, but their printed powers are not connected yet. Normal draws, resummoning, Fracture and victory are also pending.",
		14
	)
	message = _label(column, "", 15)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	start_button = Button.new()
	start_button.text = "START BOARD"
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.custom_minimum_size.y = 42
	buttons.add_child(start_button)
	start_button.pressed.connect(_start)
	cancel_button = Button.new()
	cancel_button.text = "RETURN TO CURRENT BOARD"
	buttons.add_child(cancel_button)
	cancel_button.pressed.connect(func(): cancelled.emit())
	_validate()


func present(lords: Array, castles: Array, quick: bool, can_cancel: bool) -> void:
	for pid in [0, 1]:
		lord_choices[pid].select(LORDS.find(lords[pid]))
		for slot in range(Slots.SLOT_COUNT):
			castle_choices[pid][slot].select(Slots.TYPES.find(castles[pid][slot]))
	opening.select(0 if quick else 1)
	cancel_button.visible = can_cancel
	_validate()
	show()


func selection() -> Dictionary:
	var lords: Array = []
	var castles: Array = [[], []]
	for pid in [0, 1]:
		lords.append(LORDS[lord_choices[pid].selected])
		for choice in castle_choices[pid]:
			castles[pid].append(Slots.TYPES[choice.selected])
	return {"lords": lords, "castles": castles, "quick": opening.selected == 0}


func _validate() -> void:
	if start_button == null:
		return
	var draft: Dictionary = selection()
	var valid: bool = (
		Slots.selection_valid(draft.castles[0]) and Slots.selection_valid(draft.castles[1])
	)
	start_button.disabled = not valid
	message.text = (
		"Start creates a new match. Your Castle types stay fixed for that match."
		if valid
		else "Choose no more than two Castles of the same type on either side."
	)


func _start() -> void:
	_validate()
	if start_button.disabled:
		return
	var draft: Dictionary = selection()
	start_requested.emit(draft.lords, draft.castles, draft.quick)


func _option(parent: Node, entries: Array) -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in entries:
		option.add_item(
			String(entry).replace("SiegeEngine", "Siege Engine").replace(
				"SummoningCircle", "Summoning Circle"
			)
		)
	parent.add_child(option)
	option.item_selected.connect(func(_index): _validate())
	return option


func _label(parent: Node, value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label
