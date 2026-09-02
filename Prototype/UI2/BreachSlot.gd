# UI2_DIALOGUE_BREACH_OVERHAUL_V1
class_name UI2BreachSlot
extends PanelContainer

# UI2_BREACH_ART_V1
const UI2_BREACH_ART: Texture2D = preload(
    "res://ConceptImages/Menus/TheBreach.png"
)


const LordCardData = preload(
    "res://Prototype/UI2/LordCard.gd"
)


var title_label: Label = null
var owner_label: Label = null
var empty_label: Label = null
var lord_card = null


func _ready() -> void:
    _install_breach_art_v1()
    custom_minimum_size = Vector2(104, 118)

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.035, 0.026, 0.045, 1.0)
    style.border_color = Color(0.34, 0.27, 0.44, 0.95)
    style.set_border_width_all(1)
    style.set_corner_radius_all(7)
    style.content_margin_left = 5.0
    style.content_margin_right = 5.0
    style.content_margin_top = 4.0
    style.content_margin_bottom = 4.0
    add_theme_stylebox_override("panel", style)

    var outer := VBoxContainer.new()
    outer.alignment = BoxContainer.ALIGNMENT_CENTER
    outer.add_theme_constant_override("separation", 2)
    add_child(outer)

    title_label = Label.new()
    title_label.text = "THE BREACH"
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 11)
    title_label.add_theme_color_override(
        "font_color",
        Color(0.82, 0.74, 0.92, 1.0)
    )
    outer.add_child(title_label)

    var card_host := CenterContainer.new()
    card_host.custom_minimum_size = Vector2(72, 88)
    outer.add_child(card_host)

    lord_card = LordCardData.new()
    lord_card.set_compact_size(Vector2(56, 84))
    lord_card.set_breach_context(true)
    lord_card.visible = false
    card_host.add_child(lord_card)

    empty_label = Label.new()
    empty_label.text = "EMPTY"
    empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    empty_label.add_theme_font_size_override("font_size", 10)
    empty_label.add_theme_color_override(
        "font_color",
        Color(0.43, 0.42, 0.48, 1.0)
    )
    card_host.add_child(empty_label)

    owner_label = Label.new()
    owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    owner_label.add_theme_font_size_override("font_size", 9)
    outer.add_child(owner_label)


func bind_state(
    game,
    human_player_id: int = 0
) -> void:
    if game == null:
        return

    var breach_lord: String = String(game.breach)
    var breach_owner: int = int(game.breach_owner)

    if breach_lord.is_empty() or breach_owner < 0:
        lord_card.visible = false
        empty_label.visible = true
        owner_label.text = ""
        tooltip_text = "The Breach is empty."
        return

    var owner = game.get_player(breach_owner)
    if owner == null:
        lord_card.visible = false
        empty_label.visible = true
        empty_label.text = breach_lord.to_upper()
        owner_label.text = ""
        return

    empty_label.visible = false
    lord_card.visible = true
    lord_card.set_breach_context(true)
    lord_card.set_compact_size(Vector2(56, 84))
    # UI2_THEATER_PROMPT_VESSEL_TRUTH_V1
    lord_card.bind_breach_lord(breach_lord)

    owner_label.text = (
        "YOUR LORD"
        if breach_owner == human_player_id
        else "ENEMY LORD"
    )
    owner_label.add_theme_color_override(
        "font_color",
        Color(0.62, 0.74, 0.94, 1.0)
        if breach_owner == human_player_id
        else Color(0.94, 0.60, 0.60, 1.0)
    )
    tooltip_text = "%s occupies the Breach. Hold the card to inspect its Breach power." % breach_lord


# UI2_BREACH_ART_V1
func _install_breach_art_v1() -> void:
    if UI2_BREACH_ART == null:
        return

    # Keep the Breach vaguely poker-card shaped rather than a skinny status box.
    # The top HUD owns the overall height, so this is deliberately restrained.
    custom_minimum_size = Vector2(92.0, 118.0)

    # The artwork itself supplies the border/frame.
    var transparent_panel := StyleBoxFlat.new()
    transparent_panel.bg_color = Color(0.0, 0.0, 0.0, 0.0)
    transparent_panel.border_color = Color(0.0, 0.0, 0.0, 0.0)
    transparent_panel.set_border_width_all(0)
    transparent_panel.content_margin_left = 5.0
    transparent_panel.content_margin_right = 5.0
    transparent_panel.content_margin_top = 5.0
    transparent_panel.content_margin_bottom = 5.0
    add_theme_stylebox_override(
        "panel",
        transparent_panel
    )

    var art := get_node_or_null("BreachArtV1") as TextureRect
    if art == null:
        art = TextureRect.new()
        art.name = "BreachArtV1"
        # UI2_BREACH_ART_CROP_V1_3_1
        var source_size := UI2_BREACH_ART.get_size()
        var cropped := AtlasTexture.new()
        cropped.atlas = UI2_BREACH_ART
        cropped.region = Rect2(
            # UI2_BREACH_ART_CORNER_CROP_V1_4
            source_size.x * 0.2360,
            source_size.y * 0.0340,
            source_size.x * 0.5280,
            source_size.y * 0.9310
        )
        art.texture = cropped
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_SCALE
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        # UI2_BREACH_ART_VISIBILITY_FIX_V1_2
        art.show_behind_parent = false
        add_child(art)
        move_child(art, 0)

    art.set_anchors_and_offsets_preset(
        Control.PRESET_FULL_RECT
    )
    art.offset_left = 0.0
    art.offset_top = 0.0
    art.offset_right = 0.0
    art.offset_bottom = 0.0

    call_deferred("_finish_breach_art_layout_v1")


func _finish_breach_art_layout_v1() -> void:
    # Legacy _ready() applies its opaque panel after the art installer.
    # Clear it here, after _ready() has finished, so TheBreach stays visible.
    var transparent_panel_v1_2 := StyleBoxFlat.new()
    transparent_panel_v1_2.bg_color = Color(0.0, 0.0, 0.0, 0.0)
    transparent_panel_v1_2.border_color = Color(0.0, 0.0, 0.0, 0.0)
    transparent_panel_v1_2.set_border_width_all(0)
    transparent_panel_v1_2.content_margin_left = 5.0
    transparent_panel_v1_2.content_margin_right = 5.0
    transparent_panel_v1_2.content_margin_top = 5.0
    transparent_panel_v1_2.content_margin_bottom = 5.0
    add_theme_stylebox_override("panel", transparent_panel_v1_2)

    var art := get_node_or_null("BreachArtV1") as TextureRect
    if art != null:
        art.set_anchors_and_offsets_preset(
            Control.PRESET_FULL_RECT
        )

    if title_label != null:
        title_label.add_theme_font_size_override(
            "font_size",
            10
        )
        title_label.add_theme_color_override(
            "font_color",
            Color(0.91, 0.86, 0.72, 1.0)
        )

    if empty_label != null:
        empty_label.add_theme_font_size_override(
            "font_size",
            9
        )
        empty_label.add_theme_color_override(
            "font_color",
            Color(0.60, 0.56, 0.55, 0.88)
        )

    if owner_label != null:
        owner_label.add_theme_font_size_override(
            "font_size",
            8
        )
