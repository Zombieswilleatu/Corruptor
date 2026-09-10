extends PanelContainer

const Preview = preload("res://Prototype/UI2/SubjectCardHoldPreview.gd")
const SuitStyle = preload("res://Prototype/UI2/SubjectSuitStyle.gd")
const CastleArtwork = preload("res://Prototype/U13/U13CastleArtwork.gd")
const LordCardStats = preload("res://Prototype/U13/U13LordCardStats.gd")
const LordPreview = preload("res://Prototype/U13/U13LordCardPreview.gd")
var lord_inspection: bool = false
var lord_stats_overlay
var lord_preview_stats
var art: TextureRect
var caption: Label
var input_surface: Button
var preview
var castle_artwork


func _ready() -> void:
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0.025, 0.024, 0.022, 0.8)
	border.border_color = Color("625234")
	border.set_border_width_all(1)
	border.set_content_margin_all(0)
	add_theme_stylebox_override("panel", border)
	art = TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	caption = Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -44
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("efdeb8"))
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_outline_size", 3)
	overlay.add_child(caption)
	input_surface = Button.new()
	input_surface.flat = true
	input_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(input_surface)
	preview = Preview.new()
	input_surface.add_child(preview)
	preview.configure(input_surface, null)


func bind_art(texture: Texture2D, label: String, help: String, enabled: bool = true) -> void:
	art.texture = texture
	art.modulate = Color.WHITE if enabled else Color(0.24, 0.24, 0.24)
	caption.text = label
	input_surface.tooltip_text = help
	preview.set_texture(texture)


func bind_suit(suit: String) -> void:
	add_theme_stylebox_override("panel", SuitStyle.card_style(suit, Color("111113"), 3))


func bind_castle_art(attributes: Dictionary, previous: Dictionary) -> void:
	if castle_artwork == null:
		castle_artwork = CastleArtwork.new()
		art.add_child(castle_artwork)
		castle_artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Keep the source available for inspection; only replace its board drawing.
	art.self_modulate.a = 0.0
	art.modulate = Color.WHITE
	castle_artwork.bind_castle(art.texture, attributes, previous)
	if attributes.construction_state == "active":
		input_surface.tooltip_text += (
			"\n"
			+ ["Undamaged", "Damaged", "Heavily damaged"][CastleArtwork.damage_band(
				attributes.integrity, attributes.max_integrity
			)]
		)
	else:
		input_surface.tooltip_text += "\nArtwork fills upward with construction progress."


func bind_lord_stats(values: Dictionary) -> void:
	if lord_stats_overlay == null:
		lord_stats_overlay = LordCardStats.new()
		art.add_child(lord_stats_overlay)
		lord_preview_stats = LordCardStats.new()
		preview.preview_art.add_child(lord_preview_stats)
	lord_stats_overlay.bind_stats(values)
	lord_preview_stats.bind_stats(values, true)


func bind_lord(name_value: String, alive: bool, in_breach: bool) -> void:
	if not lord_inspection:
		input_surface.gui_input.disconnect(preview._on_source_gui_input)
		preview.queue_free()
		preview = LordPreview.new()
		input_surface.add_child(preview)
		preview.configure(input_surface, art.texture)
		lord_inspection = true
	preview.bind_lord(name_value, alive, in_breach)
