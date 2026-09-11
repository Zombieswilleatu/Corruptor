extends Control

# Each collected Price remains readable until acknowledged, including multiple
# debts falling due together. Presentation consumes only public outcome events.
var pending: Array = []
var current: Dictionary = {}
var side_center: Vector2 = Vector2.ZERO
var clock: float = 0.0
var copy: Label
var frame: PanelContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 120
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	frame = PanelContainer.new()
	frame.custom_minimum_size = Vector2(520, 190)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("241330")
	style.border_color = Color("bd7de8")
	style.set_border_width_all(3)
	style.set_content_margin_all(24)
	frame.add_theme_stylebox_override("panel", style)
	center.add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	frame.add_child(column)
	copy = Label.new()
	copy.custom_minimum_size.x = 470
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_font_size_override("font_size", 22)
	copy.add_theme_color_override("font_color", Color("f0d6ff"))
	column.add_child(copy)
	var button := Button.new()
	button.text = "CONTINUE"
	button.pressed.connect(_next)
	column.add_child(button)
	hide()

func present(events: Array, sides: Array) -> void:
	for event in events:
		if event.type != "KANIFOUS_PRICE_RESOLVED":
			continue
		var row: Dictionary = event.data.duplicate(true)
		var side = sides[1 if int(row.player_id) == 0 else 0]
		row["center"] = get_global_transform().affine_inverse() * side.get_global_rect().get_center()
		pending.append(row)
	if not visible and not pending.is_empty():
		_next()

static func description(row: Dictionary) -> String:
	var amount: int = row.get("targets", []).size()
	var detail: String = "Nothing could be collected."
	match row.outcome:
		"Cards": detail = "%d hand card(s) discarded." % amount
		"Blood": detail = "%d Marcher(s) destroyed." % amount
		"Guards": detail = "A Guard was defeated."
		"Stone": detail = "A Castle lost up to 5 Integrity."
		"Soul": detail = "1 Soul taken."
		"Ruin": detail = "A Castle was reduced to 0 Integrity."
		"Wishmaster": detail = "Kanifous was banished. The Breach is active."
	if row.outcome in ["Stone", "Soul", "Ruin", "Wishmaster"]:
		detail += "\n+1 neutral Tear."
	if not row.get("taken", []).is_empty():
		detail += "\n\n" + "\n".join(row.taken)
	return "THE PRICE OF WISHES\n%s PRICE · %s\n%s" % ["YOUR" if int(row.player_id) == 0 else "ENEMY", row.outcome.to_upper(), detail]

func _next() -> void:
	if pending.is_empty():
		current = {}
		hide()
		return
	current = pending.pop_front()
	side_center = current.center
	copy.text = description(current)
	clock = 0.0
	show()

func _process(delta: float) -> void:
	if visible:
		clock += delta
		queue_redraw()

func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.01, 0.09, 0.35))
	for i in range(18):
		var rise: float = fposmod(clock * 0.22 + i / 18.0, 1.0)
		var at: Vector2 = side_center + Vector2(sin(clock + i * 2.1) * (28 + rise * 60), 60 - rise * 220)
		draw_circle(at, 20 + rise * 35, Color(0.7, 0.25, 0.95, (1 - rise) * 0.32))
