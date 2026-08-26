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
