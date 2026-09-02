class_name UI2PlayerPuck
extends PanelContainer


const GameSetupData = preload(
    "res://Scripts/Sim/GameSetup.gd"
)


var name_label: Label = null
var left_label: Label = null
var right_label: Label = null


func _ready() -> void:
    custom_minimum_size = Vector2(205, 92)

    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 4)
    add_child(outer)

    name_label = Label.new()
    name_label.add_theme_font_size_override("font_size", 18)
    outer.add_child(name_label)

    var columns := HBoxContainer.new()
    columns.add_theme_constant_override("separation", 12)
    outer.add_child(columns)

    left_label = Label.new()
    left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(left_label)

    right_label = Label.new()
    right_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(right_label)


func bind_player(
    player,
    rules,
    _is_human: bool
) -> void:
    # UI2_LORD_SCORE_TEXT_LAYOUT_V1
    call_deferred("_sync_lord_score_text_layout_v1")
    if player == null:
        return

    var lord_name: String = String(player.lord)
    name_label.text = lord_name.to_upper()

    var current_def: int = int(player.derived_lord_def)
    var content: Dictionary = GameSetupData.LORD_CONTENT.get(
        lord_name,
        {}
    )
    var printed_def: int = int(
        content.get(
            "base_defense",
            current_def
        )
    )

    var defense_text: String = "DEF —"

    if bool(player.alive):
        defense_text = (
            "DEF %d"
            % current_def
            if printed_def == current_def
            else "DEF %d→%d" % [
                printed_def,
                current_def,
            ]
        )

    left_label.text = "Souls %d/%d\nTears %d/%d\nThreat %d" % [
        int(player.souls),
        int(rules.win_souls),
        int(player.tears),
        int(rules.dominion_requirement),
        int(player.threat),
    ]

    right_label.text = "%s\nHand %d\nRetinue %d" % [
        defense_text,
        player.hand.size(),
        player.garrison.size(),
    ]


# UI2_LORD_SCORE_TEXT_LAYOUT_V1
func _sync_lord_score_text_layout_v1() -> void:
    var panel := get_parent() as PanelContainer
    if panel == null:
        return

    var source_text: String = _lord_score_source_text_v1(self)
    if source_text.strip_edges().is_empty():
        return

    var lord_name: String = _lord_score_title_v1(source_text)
    var souls: String = _lord_score_value_v1(source_text, "Souls")
    var defense: String = _lord_score_value_v1(source_text, "DEF")
    var tears: String = _lord_score_value_v1(source_text, "Tears")
    var hand: String = _lord_score_value_v1(source_text, "Hand")
    var threat: String = _lord_score_value_v1(source_text, "Threat")
    var retinue: String = _lord_score_value_v1(source_text, "Retinue")

    var overlay := panel.get_node_or_null(
        "LordScoreTextOverlayV1"
    ) as Control

    if overlay == null:
        overlay = Control.new()
        overlay.name = "LordScoreTextOverlayV1"
        overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
        overlay.z_index = 5
        panel.add_child(overlay)
        _build_lord_score_text_overlay_v1(overlay)

    overlay.set_anchors_and_offsets_preset(
        Control.PRESET_FULL_RECT
    )

    var title := overlay.get_node_or_null("LordName") as Label
    if title != null:
        title.text = lord_name.to_upper()

    _set_lord_score_cell_v1(
        overlay,
        "Souls",
        "SOULS",
        souls
    )
    _set_lord_score_cell_v1(
        overlay,
        "Defense",
        "DEF",
        defense
    )
    _set_lord_score_cell_v1(
        overlay,
        "Tears",
        "TEARS",
        tears
    )
    _set_lord_score_cell_v1(
        overlay,
        "Hand",
        "HAND",
        hand
    )
    _set_lord_score_cell_v1(
        overlay,
        "Threat",
        "THREAT",
        threat
    )
    _set_lord_score_cell_v1(
        overlay,
        "Retinue",
        "RETINUE",
        retinue
    )

    # Keep the original PlayerPuck alive and updating, but stop drawing its
    # legacy text. That way this presentation layer never owns game state.
    modulate = Color(1.0, 1.0, 1.0, 0.0)
    overlay.visible = true


func _build_lord_score_text_overlay_v1(
    overlay: Control
) -> void:
    var title := Label.new()
    title.name = "LordName"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    title.add_theme_font_size_override("font_size", 13)
    title.add_theme_color_override(
        "font_color",
        Color(0.95, 0.90, 0.76, 1.0)
    )
    title.add_theme_color_override(
        "font_shadow_color",
        Color(0.0, 0.0, 0.0, 0.85)
    )
    title.add_theme_constant_override("shadow_offset_x", 1)
    title.add_theme_constant_override("shadow_offset_y", 1)
    overlay.add_child(title)
    _place_lord_score_control_v1(
        title,
        0.20,
        0.00,
        0.80,
        0.28
    )

    _make_lord_score_cell_v1(
        overlay,
        "Souls",
        0.07,
        0.34,
        0.47,
        0.52
    )
    _make_lord_score_cell_v1(
        overlay,
        "Defense",
        0.53,
        0.34,
        0.93,
        0.52
    )
    _make_lord_score_cell_v1(
        overlay,
        "Tears",
        0.07,
        0.55,
        0.47,
        0.73
    )
    _make_lord_score_cell_v1(
        overlay,
        "Hand",
        0.53,
        0.55,
        0.93,
        0.73
    )
    _make_lord_score_cell_v1(
        overlay,
        "Threat",
        0.07,
        0.76,
        0.47,
        0.94
    )
    _make_lord_score_cell_v1(
        overlay,
        "Retinue",
        0.53,
        0.76,
        0.93,
        0.94
    )


func _make_lord_score_cell_v1(
    overlay: Control,
    cell_name: String,
    left: float,
    top: float,
    right: float,
    bottom: float
) -> void:
    var cell := Control.new()
    cell.name = cell_name
    cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(cell)
    _place_lord_score_control_v1(
        cell,
        left,
        top,
        right,
        bottom
    )

    var key := Label.new()
    key.name = "Key"
    key.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    key.add_theme_font_size_override("font_size", 9)
    key.add_theme_color_override(
        "font_color",
        Color(0.66, 0.57, 0.40, 1.0)
    )
    cell.add_child(key)
    _place_lord_score_control_v1(
        key,
        0.0,
        0.0,
        0.63,
        1.0
    )

    var value := Label.new()
    value.name = "Value"
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    value.add_theme_font_size_override("font_size", 11)
    value.add_theme_color_override(
        "font_color",
        Color(0.94, 0.91, 0.83, 1.0)
    )
    value.add_theme_color_override(
        "font_shadow_color",
        Color(0.0, 0.0, 0.0, 0.75)
    )
    value.add_theme_constant_override("shadow_offset_x", 1)
    value.add_theme_constant_override("shadow_offset_y", 1)
    cell.add_child(value)
    _place_lord_score_control_v1(
        value,
        0.60,
        0.0,
        1.0,
        1.0
    )


func _set_lord_score_cell_v1(
    overlay: Control,
    cell_name: String,
    key_text: String,
    value_text: String
) -> void:
    var cell := overlay.get_node_or_null(
        cell_name
    ) as Control
    if cell == null:
        return

    var key := cell.get_node_or_null("Key") as Label
    var value := cell.get_node_or_null("Value") as Label

    if key != null:
        key.text = key_text

    if value != null:
        value.text = value_text


func _place_lord_score_control_v1(
    control: Control,
    left: float,
    top: float,
    right: float,
    bottom: float
) -> void:
    control.anchor_left = left
    control.anchor_top = top
    control.anchor_right = right
    control.anchor_bottom = bottom
    control.offset_left = 0.0
    control.offset_top = 0.0
    control.offset_right = 0.0
    control.offset_bottom = 0.0


func _lord_score_source_text_v1(
    root: Node
) -> String:
    var chunks: Array[String] = []
    _collect_lord_score_label_text_v1(
        root,
        chunks
    )
    return "\n".join(chunks)


func _collect_lord_score_label_text_v1(
    node: Node,
    chunks: Array[String]
) -> void:
    for child in node.get_children():
        if child is Label:
            var text_value: String = String(
                (child as Label).text
            )
            if not text_value.strip_edges().is_empty():
                chunks.append(text_value)

        _collect_lord_score_label_text_v1(
            child,
            chunks
        )


func _lord_score_title_v1(
    source_text: String
) -> String:
    for raw_line in source_text.split("\n"):
        var line: String = String(raw_line).strip_edges()
        if line.is_empty():
            continue

        var lower := line.to_lower()
        if (
            "souls" in lower
            or "tears" in lower
            or "threat" in lower
            or "def " in lower
            or lower.begins_with("def")
            or "hand" in lower
            or "retinue" in lower
        ):
            continue

        return line

    return ""


func _lord_score_value_v1(
    source_text: String,
    key: String
) -> String:
    var regex := RegEx.new()
    var pattern: String = (
        "(?i)\\b%s\\s+([^\\s]+)"
        % key
    )

    if regex.compile(pattern) != OK:
        return "—"

    var match_result := regex.search(source_text)
    if match_result == null:
        return "—"

    return match_result.get_string(1)
