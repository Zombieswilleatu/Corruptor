class_name UI2DevPanel
extends PanelContainer


const LORDS: Array[String] = [
    "Orias",
    "Deimos",
    "Valak",
    "Kroni",
    "Kalligan",
    "Gremory",
    "Odradek",
    "Kanifous",
    "Humbaba",
]


signal start_requested(human_lord, bot_lord, seed_value)
signal export_snapshot_requested


var human_select: OptionButton = null
var bot_select: OptionButton = null
var seed_edit: LineEdit = null
var validation_label: Label = null


func _ready() -> void:
    visible = false
    custom_minimum_size = Vector2(460, 330)
    set_anchors_preset(Control.PRESET_CENTER)
    offset_left = -230
    offset_top = -165
    offset_right = 230
    offset_bottom = 165

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_top", 16)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_bottom", 16)
    add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    margin.add_child(box)

    var title := Label.new()
    title.text = "DEV MATCH SETUP"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 19)
    box.add_child(title)

    human_select = _lord_selector("Your Lord")
    box.add_child(human_select)

    bot_select = _lord_selector("Bot Lord")
    box.add_child(bot_select)

    var seed_row := HBoxContainer.new()
    seed_row.add_theme_constant_override("separation", 8)
    box.add_child(seed_row)

    var seed_label := Label.new()
    seed_label.text = "Seed"
    seed_label.custom_minimum_size.x = 88
    seed_row.add_child(seed_label)

    seed_edit = LineEdit.new()
    seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    seed_edit.placeholder_text = "integer seed"
    seed_row.add_child(seed_edit)

    var random_button := Button.new()
    random_button.text = "RANDOM"
    random_button.pressed.connect(_on_random_pressed)
    seed_row.add_child(random_button)

    validation_label = Label.new()
    validation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(validation_label)

    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(spacer)

    var buttons := HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 10)
    box.add_child(buttons)

    var close_button := Button.new()
    close_button.text = "CLOSE"
    close_button.pressed.connect(hide_panel)
    buttons.add_child(close_button)

    var export_button := Button.new()
    export_button.text = "EXPORT SNAPSHOT"
    export_button.pressed.connect(
        _on_export_snapshot_pressed
    )
    buttons.add_child(export_button)

    var start_button := Button.new()
    start_button.text = "START / RESTART"
    start_button.pressed.connect(_on_start_pressed)
    buttons.add_child(start_button)


func open_panel(human_lord: String, bot_lord: String, seed_value: int) -> void:
    _select_lord(human_select, human_lord)
    _select_lord(bot_select, bot_lord)
    seed_edit.text = str(seed_value)
    validation_label.text = ""
    visible = true
    move_to_front()


func hide_panel() -> void:
    visible = false


func set_status_message(message: String) -> void:
    if validation_label != null:
        validation_label.text = message


func _on_export_snapshot_pressed() -> void:
    validation_label.text = ""
    export_snapshot_requested.emit()


func _lord_selector(label_text: String) -> OptionButton:
    var selector := OptionButton.new()
    for lord_name in LORDS:
        selector.add_item("%s · %s" % [label_text, lord_name])
        selector.set_item_metadata(selector.item_count - 1, lord_name)
    return selector


func _select_lord(selector: OptionButton, lord_name: String) -> void:
    for index in range(selector.item_count):
        if String(selector.get_item_metadata(index)) == lord_name:
            selector.select(index)
            return


func _on_random_pressed() -> void:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    seed_edit.text = str(rng.randi_range(1, 2147483646))


func _on_start_pressed() -> void:
    if not seed_edit.text.is_valid_int():
        validation_label.text = "Seed must be an integer."
        return

    var human_lord: String = String(human_select.get_item_metadata(human_select.selected))
    var bot_lord: String = String(bot_select.get_item_metadata(bot_select.selected))
    var seed_value: int = int(seed_edit.text)
    validation_label.text = ""
    start_requested.emit(human_lord, bot_lord, seed_value)
