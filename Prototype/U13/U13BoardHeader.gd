extends HBoxContainer

const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
var round_label: Label
var veil_label: Label
var scores: Dictionary = {}
var tools_box: VBoxContainer
var history_box: VBoxContainer
var breach_art: TextureRect
var scope: Label


func _ready() -> void:
	custom_minimum_size.y = 120
	add_theme_constant_override("separation", 8)
	_score(1)
	tools_box = VBoxContainer.new()
	tools_box.custom_minimum_size.x = 105
	add_child(tools_box)
	var banner: Control = _art_panel("res://ConceptImages/Menus/TopBanner.png", Vector2(500, 120))
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var text := VBoxContainer.new()
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_top = 20
	text.offset_bottom = -16
	banner.add_child(text)
	round_label = _label(text, "", 18)
	veil_label = _label(text, "", 18)
	scope = _label(text, "U13 · Gremory combat", 12)
	scope.tooltip_text = "Siege, Ward and Lord powers are playable. Development, Hunt, normal draws, named Castle powers and victory are not connected yet."
	var breach := VBoxContainer.new()
	breach.custom_minimum_size.x = 94
	add_child(breach)
	_label(breach, "BREACH", 11)
	breach_art = TextureRect.new()
	breach_art.custom_minimum_size = Vector2(70, 95)
	breach_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	breach_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	breach.add_child(breach_art)
	_score(0)
	history_box = VBoxContainer.new()
	add_child(history_box)


func _art_panel(path: String, minimum: Vector2) -> Control:
	var panel := Control.new()
	panel.custom_minimum_size = minimum
	add_child(panel)
	var art := TextureRect.new()
	art.texture = Art.texture(path)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(art)
	return panel


func _score(pid: int) -> void:
	var panel: Control = _art_panel("res://ConceptImages/Menus/LordPanel.png", Vector2(205, 120))
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 16
	column.offset_bottom = -12
	panel.add_child(column)
	scores[pid] = _label(column, "", 16)
	scores[pid].add_theme_color_override(
		"font_color", Color("efada5") if pid == 1 else Color("a3cee9")
	)


func _label(parent: Node, value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("ebdab4"))
	parent.add_child(label)
	return label


func bind_world(world: Dictionary, round_number: int) -> void:
	round_label.text = "ROUND %d" % round_number
	# The current owner publishes Neutral Tears only; do not fabricate a total Veil.
	veil_label.text = "NEUTRAL TEARS  %d" % world.neutral_tears
	for pid in [0, 1]:
		scores[pid].text = (
			"%s · %s\nSouls  %d\nHand  %d"
			% [
				"YOU" if pid == 0 else "OPPONENT",
				String(world.get("lord_ids", ["Gremory", "Gremory"])[pid]).to_upper(),
				world.souls[pid],
				world.hand.size() if pid == 0 else world.opponent_hand_count
			]
		)
	if world.has("castle_loadouts"):
		scope.text = "U13 · Castle / Lord exercise"
		scope.tooltip_text = "Construct, Commission, Repair, Siege, Ward and Gremory/Deimos powers. Only Siege Engine printed Castle power is connected. Hunt, normal draws and victory are pending."
		veil_label.text += (
			" · PERSONAL %d : %d" % [world.personal_tears[0], world.personal_tears[1]]
		)
	breach_art.texture = (
		null if String(world.breach_lord).is_empty() else Art.lord_texture(world.breach_lord)
	)
	breach_art.tooltip_text = world.breach_lord
