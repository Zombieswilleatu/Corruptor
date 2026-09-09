extends Control

# Visual-only harness: the same lane renderer used by the playable board.
const Lanes = preload("res://Prototype/U13/U13BoardLanes.gd")
const Feedback = preload("res://Prototype/U13/U13MarcherFeedback.gd")
var lanes
var _generation: int = 0
var _units: Array = []
var _records: Array = []
var _intense: bool = false


func _ready() -> void:
	var column := VBoxContainer.new()
	column.position = Vector2(420, 32)
	column.size = Vector2(490, 500)
	add_child(column)
	var title := Label.new()
	title.text = "SCORCH · VISUAL PREVIEW"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var note := Label.new()
	note.text = (
		"No match or damage simulation.\n\n12 flames per lane, staggered.\n"
		+ "Four Fire1 loops, then one Fire2 loop.\nGroundFire uses soft radial brush stamps.\n\n"
		+ "Chits and health rings draw above fire.\nNumber buttons show cosmetic examples only."
	)
	column.add_child(note)
	_button(column, "New fire arrangement", _restart)
	_button(column, "Toggle intensity 1 / 2", _intensity)
	_button(column, "Pyroclasm flash (one second)", _pyroclasm)
	_button(column, "Expire fire", func(): lanes.bind_scorch([]))
	_button(column, "Show −1 HP", _number.bind(-1, 0))
	_button(column, "Show +1 HP", _number.bind(1, 0))
	_button(column, "Show −1 ARM", _number.bind(0, -1))
	_button(column, "Exit", func(): get_tree().quit())
	lanes = Lanes.new()
	lanes.position = Vector2(20, 0)
	lanes.size = Vector2(370, 880)
	add_child(lanes)
	for index in range(6):
		_units.append(
			{
				"id": "preview:" + str(index),
				"kind": "marcher",
				"owner": index % 2,
				"attributes":
				{
					"suit": "Vulture" if index % 2 == 0 else "Butcher",
					"lane": "Lord" if index < 3 else "Castle",
					"hp": 3,
					"max_hp": 5,
					"armor": 1,
					"x_fp": 500 + (index % 3) * 650,
					"y_fp": 180 + (index % 2) * 200,
					"waiting": false,
					"movement_ready_round": 1
				}
			}
		)
	lanes.show_world(_units, 1)
	_restart()


func _button(parent: Node, text_value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	parent.add_child(button)
	button.pressed.connect(callback)


func _restart() -> void:
	_generation += 1
	var records: Array = []
	for index in range(2):
		records.append(
			{
				"id": "scorch-preview:%d:%d" % [_generation, index],
				"owner": index,
				"target": {"kind": "lane", "lane": "Lord" if index == 0 else "Castle"},
				"intensity": 2 if _intense else 1,
				"remaining": 3,
				"fire_round": 0
			}
		)
	_records = records
	lanes.bind_scorch(records)


func _number(hp: int, armor: int) -> void:
	var rows: Array = []
	for unit in _units:
		rows.append(Feedback.row(unit, hp, armor, 0.0, "PREVIEW"))
	lanes.show_feedback(rows)


func _intensity() -> void:
	_intense = not _intense
	for record in _records:
		record.intensity = 2 if _intense else 1
	lanes.bind_scorch(_records)


func _pyroclasm() -> void:
	for id in lanes.scorch_visuals.groups:
		lanes.flash_scorch(id)
