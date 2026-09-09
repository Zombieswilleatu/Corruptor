extends "res://Prototype/U13/U13VisualPreview.gd"

# Visual-only harness using the board's real renderer. No match or worker.
const Visuals = preload("res://Prototype/U13/U13BreathVisuals.gd")
var visuals = Visuals.new()
var _status: Label
var _automatic: CheckButton
var _age: float = 0.0
var _expired: bool = false
var _generation: int = 0


func _ready() -> void:
	var column := VBoxContainer.new()
	column.position = Vector2(24, 16)
	column.size = Vector2(1100, 150)
	add_child(column)
	var title := Label.new()
	title.text = "BREATH OF LIFE — grow, hold, expire"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var note := Label.new()
	note.text = "Actual board renderer, enlarged. Auto: 8 seconds active, then 10 seconds of staggered dying."
	column.add_child(note)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_button(buttons, "Restart / sprout", _restart)
	_button(buttons, "Expire now", _expire)
	_button(buttons, "New flower arrangement", _new_arrangement)
	_automatic = CheckButton.new()
	_automatic.text = "Auto cycle"
	_automatic.button_pressed = true
	buttons.add_child(_automatic)
	_button(buttons, "Back to previews" if embedded else "Exit", _close_preview)
	_status = Label.new()
	column.add_child(_status)
	_restart()


func _button(parent: Node, text_value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	parent.add_child(button)
	button.pressed.connect(callback)


func _restart() -> void:
	_age = 0.0
	_expired = false
	visuals.clear()
	var records: Array = []
	for player_id in [0, 1]:
		records.append(
			{
				"effect_id": "breath-preview:%d:%d" % [_generation, player_id],
				"declaration": {"power_id": "BreathOfLife", "player_id": player_id},
				"payload": {"lane_aura": {}},
				"target": {"lane": "Lord" if player_id == 0 else "Castle"},
				"activated_round": 1,
				"stages": [{}, {}]
			}
		)
	visuals.sync(records, 1)


func _new_arrangement() -> void:
	_generation += 1
	_restart()


func _expire() -> void:
	if _expired:
		return
	_expired = true
	_age = 0.0
	visuals.sync([], 3)


func _process(delta: float) -> void:
	visuals.warm_next()
	visuals.advance(delta)
	_age += delta
	if _automatic.button_pressed:
		if not _expired and _age >= 8.0:
			_expire()
		elif _expired and _age >= 11.5:
			_restart()
	_status.text = (
		(
			"Expired · flowers dying over 10 seconds · %.1fs"
			if _expired
			else "Active · grow frames 1–4, then hold · %.1fs"
		)
		% _age
	)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("141714"))
	var width: float = (size.x - 72.0) * 0.5
	for index in range(2):
		var rect := Rect2(24.0 + float(index) * (width + 24.0), 190, width, size.y - 214)
		draw_rect(rect, Color("28241b"))
		draw_rect(rect, Color("7c8b62"), false, 2.0)
		draw_string(
			ThemeDB.fallback_font,
			rect.position + Vector2(12, -12),
			"LORD LANE · your sweep ↑" if index == 0 else "CASTLE LANE · enemy sweep ↓",
			HORIZONTAL_ALIGNMENT_LEFT,
			width,
			18,
			Color("d9e9c1")
		)
		visuals.draw_lane(self, rect, "Lord" if index == 0 else "Castle", 2.0)
