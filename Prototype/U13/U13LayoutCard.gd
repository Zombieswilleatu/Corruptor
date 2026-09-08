extends PanelContainer

const Preview = preload("res://Prototype/UI2/SubjectCardHoldPreview.gd")
const SuitStyle = preload("res://Prototype/UI2/SubjectSuitStyle.gd")
var art: TextureRect
var caption: Label
var input_surface: Button
var preview


func _ready() -> void:
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0.025, 0.024, 0.022, 0.8)
	border.border_color = Color("625234")
	border.set_border_width_all(1)
	add_theme_stylebox_override("panel", border)
	art = TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
