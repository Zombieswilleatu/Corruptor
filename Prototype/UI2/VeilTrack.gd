class_name UI2VeilTrack
extends PanelContainer


var round_label: Label = null
var track_box: HBoxContainer = null
var warning_label: Label = null


func _ready() -> void:
    custom_minimum_size = Vector2(500, 92)

    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 3)
    add_child(outer)

    round_label = Label.new()
    round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    round_label.add_theme_font_size_override("font_size", 16)
    outer.add_child(round_label)

    track_box = HBoxContainer.new()
    track_box.alignment = BoxContainer.ALIGNMENT_CENTER
    track_box.add_theme_constant_override("separation", 2)
    outer.add_child(track_box)

    warning_label = Label.new()
    warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    outer.add_child(warning_label)


func bind_state(
    game,
    rules,
    stage_text: String
) -> void:
    if game == null or rules == null:
        return

    var veil: int = int(game.calculate_veil_total())
    var cataclysm: int = int(rules.dominion_track)

    round_label.text = "ROUND %d — %s" % [
        int(game.round),
        stage_text,
    ]

    for child in track_box.get_children():
        child.free()

    for value: int in range(cataclysm + 1):
        var pip := Label.new()
        pip.custom_minimum_size = Vector2(28, 24)
        pip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        pip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

        if value == veil:
            pip.text = "[%d]" % value
        else:
            pip.text = str(value)

        track_box.add_child(pip)

    var p0 = game.get_player(0)
    var p1 = game.get_player(1)

    if p0 != null and p1 != null:
        warning_label.text = "DOMINION · %s %d/%d · %s %d/%d · FINAL %d" % [
            String(p0.lord).to_upper(),
            int(p0.tears),
            int(rules.dominion_requirement),
            String(p1.lord).to_upper(),
            int(p1.tears),
            int(rules.dominion_requirement),
            int(rules.final_collapse_threshold),
        ]
