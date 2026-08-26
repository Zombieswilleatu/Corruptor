# UI2_CARD_INTERACTION_STAGING_V2
# UI2_SUBJECT_CARD_ART_V1
class_name UI2GuardPip
extends PanelContainer


const SubjectCardArtCatalogData = preload(
	"res://Prototype/UI2/SubjectCardArtCatalog.gd"
)
const SubjectCardHoldPreviewData = preload(
	"res://Prototype/UI2/SubjectCardHoldPreview.gd"
)




const SubjectSuitStyleData = preload(
	"res://Prototype/UI2/SubjectSuitStyle.gd"
)


var suit_label: Label = null
var value_label: Label = null
var art_rect: TextureRect = null
var art_preview = null


func _ready() -> void:
	set_meta("subject_click_inspect", true)
	custom_minimum_size = Vector2(
		70,
		95
	)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# UI2_SUBJECT_CARD_ART_GUARD_READY
	art_rect = TextureRect.new()
	art_rect.name = "SubjectCardArt"
	art_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art_rect)

	art_preview = SubjectCardHoldPreviewData.new()
	add_child(art_preview)
	art_preview.configure(
		self,
		null
	)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(
		"separation",
		0
	)
	add_child(box)

	suit_label = Label.new()
	suit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	suit_label.add_theme_font_size_override(
		"font_size",
		10
	)
	box.add_child(suit_label)

	value_label = Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	value_label.add_theme_font_size_override(
		"font_size",
		22
	)
	box.add_child(value_label)

	_apply_style(
		Color(0.07, 0.07, 0.075, 1.0),
		Color(0.33, 0.34, 0.37, 1.0)
	)


func bind_guard(
	card,
	revealed: bool
) -> void:
	if suit_label == null or value_label == null:
		return

	if art_rect != null:
		art_rect.texture = null
	if art_preview != null:
		art_preview.set_texture(null)

	if card == null:
		suit_label.text = ""
		value_label.text = ""
		tooltip_text = "Empty Guard slot"
		_apply_style(
			Color(0.055, 0.055, 0.06, 0.55),
			Color(0.28, 0.29, 0.32, 1.0)
		)
		return

	var suit_name: String = String(card.suit)
	var card_value: int = int(card.value)
	var card_art: Texture2D = (
		SubjectCardArtCatalogData.texture_for(
			suit_name,
			card_value,
			not revealed
		)
	)

	if art_rect != null:
		art_rect.texture = card_art
	if art_preview != null:
		art_preview.set_texture(card_art)

	if card_art != null:
		# Keep the Label controls alive because staged-Guard decoration writes
		# into suit_label after bind_guard(). Ordinary art cards need no text.
		suit_label.text = ""
		value_label.text = ""

		if revealed:
			tooltip_text = (
				"%s\nClick to inspect card art."
				% String(card.card_id())
			)
			_apply_style(
				Color(0.025, 0.025, 0.03, 1.0),
				SubjectSuitStyleData.accent(suit_name)
			)
		else:
			tooltip_text = "Hidden Guard\nClick to inspect card back."
			_apply_style(
				Color(0.035, 0.035, 0.04, 1.0),
				Color(0.43, 0.44, 0.49, 1.0)
			)
		return

	# Text fallback if an image ever goes missing.
	if not revealed:
		suit_label.text = "GUARD"
		value_label.text = "?"
		tooltip_text = "Hidden Guard"
		_apply_style(
			Color(0.10, 0.10, 0.115, 1.0),
			Color(0.43, 0.44, 0.49, 1.0)
		)
		return

	suit_label.text = (
		suit_name.left(1).to_upper()
		if not suit_name.is_empty()
		else "?"
	)
	value_label.text = str(card_value)
	tooltip_text = String(card.card_id())

	var accent: Color = SubjectSuitStyleData.accent(suit_name)

	suit_label.add_theme_color_override(
		"font_color",
		accent
	)

	_apply_style(
		Color(0.085, 0.085, 0.095, 1.0),
		accent
	)

func _apply_style(
	background: Color,
	border: Color,
	border_width: int = 1
) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	add_theme_stylebox_override(
		"panel",
		style
	)
