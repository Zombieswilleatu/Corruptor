extends Control

# A public, presentation-only view. Browsing never writes to the match or reveals
# future identities. Only arrived Lords appear on the public rim.
const Victory = preload("res://Scripts/Sim/U13Victory.gd")
const Rites = preload("res://Scripts/Sim/U13DominionRites.gd")
const LIMIT: int = Victory.FINAL_COLLAPSE_VEIL
const HALF_WINDOW: float = 3.0
const ARRIVALS: Array = [5, 9, 13, 17]
const GOLD := Color("d0b784")
const INK := Color("111015")
const VEIL := Color("d3b0f2")
const OWNERS: Array = [Color("a3cee9"), Color("efada5")]

var tempo_rules: bool = false
var current_value: int = 0
var selected_value: int = 0
var round_number: int = 1
var personal_tears: Array = [0, 0]
var neutral_tears: int = 0
var arrivals: Array = []
const LordRules = preload("res://Prototype/U13/U13LordRules.gd")
var following_current: bool = true
var current_button: Button
var previous_button: Button
var next_button: Button
var detail: Label
var round_label: Label
var neutral_label: Label
var _center: float = HALF_WINDOW
var _target_center: float = HALF_WINDOW
var _initialized: bool = false
var _dragging: bool = false
var _drag_start: Vector2
var _drag_center: float = 0.0
var _drag_distance: float = 0.0
var _hover_value: int = -1


func _ready() -> void:
	custom_minimum_size = Vector2(0, 104)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	round_label = _label(12, GOLD)
	neutral_label = _label(12, Color("aca3b5"))
	neutral_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	neutral_label.tooltip_text = "Shared Neutral Tears add to the Veil. Automatic pressure: +1 per round from 13; +2 from 21."
	current_button = _button("", follow_current)
	current_button.add_theme_font_size_override("font_size", 15)
	current_button.add_theme_color_override("font_color", VEIL)
	current_button.tooltip_text = "Return to the current Veil. Total Veil = both players' Personal Tears + shared Neutral Tears."
	previous_button = _button("‹", browse.bind(-1))
	previous_button.tooltip_text = "Look behind · Left arrow"
	next_button = _button("›", browse.bind(1))
	next_button.tooltip_text = "Look ahead · Right arrow"
	detail = _label(12, GOLD)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	resized.connect(_layout)
	mouse_exited.connect(func(): _hover_value = -1; _update_controls(); queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_layout()
	_update_controls()
	set_process(false)


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button(caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.flat = true
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", GOLD)
	button.add_theme_color_override("font_hover_color", Color("fff0d1"))
	button.pressed.connect(callback)
	add_child(button)
	return button


func _layout() -> void:
	if not is_instance_valid(detail):
		return
	round_label.position = Vector2(2, 0)
	round_label.size = Vector2(85, 22)
	neutral_label.position = Vector2(size.x - 113, 0)
	neutral_label.size = Vector2(111, 22)
	current_button.position = Vector2((size.x - 186) * 0.5, 0)
	current_button.size = Vector2(186, 22)
	previous_button.position = Vector2(0, 30)
	previous_button.size = Vector2(25, 43)
	next_button.position = Vector2(size.x - 25, 30)
	next_button.size = Vector2(25, 43)
	detail.position = Vector2(0, size.y - 18)
	detail.size = Vector2(size.x, 18)
	queue_redraw()


func bind_world(world: Dictionary, round_now: int) -> void:
	tempo_rules = world.get("tempo_experiment") == "U13_VEIL_ATTACK_ROUND25_V1"
	var reset: bool = not _initialized or round_now < round_number
	current_value = int(world.get("veil_total", 0))
	round_number = round_now
	personal_tears = world.get("personal_tears", [0, 0]).duplicate()
	neutral_tears = int(world.get("neutral_tears", 0))
	arrivals = world.get("veil_breaches", {}).get("arrivals", []).duplicate(true)
	if reset:
		following_current = true
	if following_current:
		selected_value = clampi(current_value, 0, LIMIT)
		_target_center = clampf(float(selected_value), HALF_WINDOW, LIMIT - HALF_WINDOW)
		if reset:
			_center = _target_center
	_initialized = true
	_update_controls()
	set_process(not is_equal_approx(_center, _target_center))
	queue_redraw()


func follow_current() -> void:
	following_current = true
	select_value(clampi(current_value, 0, LIMIT), true)


func select_value(value: int, follow: bool = false) -> void:
	selected_value = clampi(value, 0, LIMIT)
	following_current = follow
	_target_center = clampf(float(selected_value), HALF_WINDOW, LIMIT - HALF_WINDOW)
	_hover_value = -1
	_update_controls()
	set_process(true)
	queue_redraw()


func browse(direction: int) -> void:
	# Move the visible rim immediately, including when the current value is 0.
	select_value(roundi(_target_center) + direction)


func visible_values() -> Array:
	var first: int = clampi(roundi(_target_center) - int(HALF_WINDOW), 0, LIMIT - 6)
	return range(first, first + 7)


func stamp_owners(value: int) -> Array:
	var tier: int = ARRIVALS.find(value) + 1
	if value == Victory.DOMINION_VEIL:
		tier = Victory.DOMINION_TEARS
	if tier <= 0:
		return []
	var owners: Array = []
	for pid in [0, 1]:
		if int(personal_tears[pid]) >= tier:
			owners.append(pid)
	return owners


func milestone(value: int) -> Dictionary:
	var result: Dictionary = _milestone(value)
	if tempo_rules and value in [13, 17, 21]:
		var bonus: int = [13, 17, 21].find(value) + 1
		result.detail += " · attack +%d" % bonus
		result.tooltip += "\nHunt and Siege gain +%d committed attack strength from this Veil threshold." % bonus
	return result

func _milestone(value: int) -> Dictionary:
	var tier: int = ARRIVALS.find(value)
	if tier >= 0:
		var arrived: Array = arrivals.filter(func(row): return row.threshold == value)
		if not arrived.is_empty():
			var lord: String = arrived[0].lord_id
			var status: String = "You: %s · Enemy: %s" % ["protected" if 0 in stamp_owners(value) else "exposed", "protected" if 1 in stamp_owners(value) else "exposed"]
			return {"label": lord.to_upper(), "planned": false, "detail": "%s · %s" % [lord, status], "tooltip": _arrival_tooltip(arrived[0]) + "\n" + status}
		return {"label": "BREACH " + ["I", "II", "III", "IV"][tier], "planned": false,
			"detail": "Unknown Lord · %d Personal Tear%s for protection" % [tier + 1, "" if tier == 0 else "s"],
			"tooltip": "An absent Lord enters permanently at the next round start after Veil %d. Identity stays hidden until arrival. %d Personal Tear%s protect against this arrival." % [value, tier + 1, "" if tier == 0 else "s"]}
	if value == Rites.INVOCATION_GATE:
		return {"label": "INVOKE", "planned": false, "detail": "Invocation · once per game · commit value %d" % Rites.INVOCATION_COST,
			"tooltip": "Invocation unlocks at Veil %d. Once per game, pay uncommitted cards totaling at least %d printed value." % [Rites.INVOCATION_GATE, Rites.INVOCATION_COST]}
	if value == Victory.DOMINION_VEIL:
		return {"label": "DOMINION", "planned": false, "detail": "Dominion · %d+ Personal Tears and a strict Tear lead" % Victory.DOMINION_TEARS,
			"tooltip": "Dominion becomes eligible at Veil %d: at least %d Personal Tears and strictly more than the opponent, subject to round-end victory checks. A fifth Tear earns the Dominion stamp, not extra Breach protection." % [Victory.DOMINION_VEIL, Victory.DOMINION_TEARS]}
	if value == 21:
		var cascade: Array = arrivals.filter(func(row): return row.threshold == 21)
		var names: String = ", ".join(cascade.map(func(row): return row.lord_id))
		var tooltip: String = "All remaining absent Lords enter at round start once BOTH Veil 21 and round 21 are reached. No Personal Tear protection. %s" % ("Round gate reached." if round_number >= 21 else "Round gate pending: round %d / 21." % round_number)
		for row in cascade:
			tooltip += "\n\n" + _arrival_tooltip(row)
		return {"label": "CASCADE", "planned": false, "detail": (names if not names.is_empty() else "Cascade · Veil 21 AND round 21") + " · no protection", "tooltip": tooltip}
	if value == LIMIT and tempo_rules:
		return {"label": "VEIL", "planned": false, "detail": "Attack +3 · game ends by round 25", "tooltip": "Veil no longer triggers Final Collapse. At round 25, check Ritual and Dominion, then compare Souls."}
	if value == LIMIT:
		return {"label": "COLLAPSE", "planned": false, "detail": "Final Collapse · higher Souls wins · round-end check",
			"tooltip": "At Veil %d, Final Collapse ends the match at the round-end victory check if Ritual has not already won. Higher Souls wins; a Soul tie favors you." % LIMIT}
	return {}


func _update_controls() -> void:
	if not is_instance_valid(detail):
		return
	round_label.text = ("R %d / 25" if tempo_rules else "ROUND %d") % round_number
	round_label.tooltip_text = "From round 20: +1 Soul for Hunt banishment or Siege destruction, once per round. Veil 13/17/21 adds +1/+2/+3 committed attack strength." if tempo_rules else ""
	neutral_label.text = "NEUTRAL %d" % neutral_tears
	current_button.text = ("VEIL %d%s" % [current_value, "" if following_current else "  ↩"]) if tempo_rules else ("VEIL %d / %d%s" % [current_value, LIMIT, "" if following_current else "  ↩"])
	previous_button.disabled = _target_center <= HALF_WINDOW
	next_button.disabled = _target_center >= LIMIT - HALF_WINDOW
	var inspected: int = _hover_value if _hover_value >= 0 else selected_value
	var mark: Dictionary = milestone(inspected)
	if not mark.is_empty():
		detail.text = mark.detail
	else:
		var next_mark: int = LIMIT
		for value in [5, Rites.INVOCATION_GATE, 9, Victory.DOMINION_VEIL, 13, 17, 21, LIMIT]:
			if value > inspected:
				next_mark = value
				break
		var ahead: Dictionary = milestone(next_mark)
		detail.text = "Next: %s at %d%s · drag / scroll to inspect" % [ahead.label, next_mark, " (planned)" if ahead.planned else ""]


func _process(delta: float) -> void:
	if not _dragging:
		_center = lerpf(_center, _target_center, 1.0 - exp(-15.0 * delta))
		if absf(_center - _target_center) < 0.002:
			_center = _target_center
			set_process(false)
	queue_redraw()


func _rim_point(offset: float, y: float) -> Vector2:
	var angle: float = offset * 0.16
	var radius: float = maxf(1.0, (size.x * 0.5 - 39.0) / sin(3.5 * 0.16))
	return Vector2(size.x * 0.5 + sin(angle) * radius, y + (1.0 - cos(angle)) * 66.0)


func _value_at(point: Vector2) -> int:
	if point.y < 22 or point.y > size.y - 18 or point.x < 26 or point.x > size.x - 26:
		return -1
	var best: int = -1
	var distance: float = INF
	for value in range(LIMIT + 1):
		if absf(value - _center) > 3.55:
			continue
		var dx: float = absf(point.x - _rim_point(value - _center, 48).x)
		if dx < distance:
			distance = dx
			best = value
	return best


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			browse(-1 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				grab_focus()
				_dragging = true
				_drag_start = event.position
				_drag_center = _center
				_drag_distance = 0.0
			elif _dragging:
				_dragging = false
				if _drag_distance < 5.0:
					var value: int = _value_at(event.position)
					if value >= 0:
						select_value(value)
				else:
					select_value(roundi(_center))
			accept_event()
	elif event is InputEventMouseMotion:
		if _dragging:
			_drag_distance = maxf(_drag_distance, absf(event.position.x - _drag_start.x))
			_center = clampf(_drag_center - (event.position.x - _drag_start.x) / maxf(1.0, (size.x - 60.0) / 7.0), HALF_WINDOW, LIMIT - HALF_WINDOW)
			_target_center = _center
			selected_value = roundi(_center)
			following_current = false
			queue_redraw()
		_hover_value = _value_at(event.position)
		_update_controls()
	elif event is InputEventPanGesture:
		browse(1 if event.delta.x + event.delta.y > 0 else -1)
		accept_event()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT: browse(-1)
			KEY_RIGHT: browse(1)
			KEY_HOME: select_value(0)
			KEY_END: select_value(LIMIT)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: follow_current()
			_: return
		accept_event()


func _get_tooltip(at_position: Vector2) -> String:
	var value: int = _value_at(at_position)
	if value < 0:
		return "Drag, scroll, or use the arrows to turn the wheel. Click VEIL to return to now."
	var mark: Dictionary = milestone(value)
	var result: String = "VEIL %d%s" % [value, " · CURRENT" if value == current_value else ""]
	if not mark.is_empty():
		result += "\n" + mark.tooltip
	if value in ARRIVALS or value == Victory.DOMINION_VEIL:
		var owners: Array = stamp_owners(value)
		result += "\nBlue seal: YOU %s · Red seal: OPPONENT %s" % ["stamped" if 0 in owners else "unstamped", "stamped" if 1 in owners else "unstamped"]
	return result


func _text(value: String, center: Vector2, font_size: int, color: Color) -> void:
	var font: Font = get_theme_default_font()
	var width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center - Vector2(width * 0.5, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _seal(point: Vector2, pid: int, earned: bool) -> void:
	var color: Color = OWNERS[pid] if earned else Color("6c606a65")
	var shape := PackedVector2Array([point + Vector2(-6, -5), point + Vector2(6, -5), point + Vector2(6, 1), point + Vector2(0, 7), point + Vector2(-6, 1)])
	if earned:
		draw_colored_polygon(shape, Color(color, 0.23))
	shape.append(shape[0])
	draw_polyline(shape, color, 1.4 if earned else 0.8, true)
	if earned:
		_text("Y" if pid == 0 else "O", point + Vector2(0, 3), 9, color)


func _draw() -> void:
	if size.x < 100:
		return
	# Only the upper rim is exposed through the banner, like a recessed brass dial.
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for sample in range(81):
		var offset: float = lerpf(-3.55, 3.55, sample / 80.0)
		upper.append(_rim_point(offset, 24))
		lower.append(_rim_point(offset, 73))
	var face: PackedVector2Array = upper.duplicate()
	var reversed: PackedVector2Array = lower.duplicate()
	reversed.reverse()
	face.append_array(reversed)
	draw_colored_polygon(face, Color("19151de6"))
	draw_polyline(upper, Color("9a7c4d"), 1.4, true)
	draw_polyline(lower, Color("655237"), 1.0, true)
	for tick in range(int(floor(_center * 4 - 14)), int(ceil(_center * 4 + 14)) + 1):
		var value: float = tick / 4.0
		if value < 0 or value > LIMIT or absf(value - _center) > 3.5:
			continue
		var point: Vector2 = _rim_point(value - _center, 25)
		draw_line(point, point + Vector2(0, 5 if tick % 4 == 0 else 2), Color("8d77537f"), 1, true)
	for value in range(LIMIT + 1):
		var offset: float = value - _center
		if absf(offset) > 3.5:
			continue
		var opacity: float = clampf((3.65 - absf(offset)) * 2, 0, 1)
		var position: Vector2 = _rim_point(offset, 57)
		var active: bool = value == clampi(current_value, 0, LIMIT)
		var selected: bool = value == selected_value
		var mark: Dictionary = milestone(value)
		if active:
			draw_circle(position + Vector2(0, -9), 18, Color(VEIL, 0.10 * opacity), true, -1, true)
			draw_arc(position + Vector2(0, -9), 18, PI * 0.12, PI * 0.88, 24, Color(VEIL, opacity), 1.6, true)
			var pointer := PackedVector2Array([position + Vector2(-4, -34), position + Vector2(4, -34), position + Vector2(0, -29)])
			draw_colored_polygon(pointer, Color(VEIL, opacity))
		elif selected or value == _hover_value:
			draw_circle(position + Vector2(0, -9), 18, Color(GOLD, 0.09 * opacity), true, -1, true)
		_text(str(value), position, 28 if active else 24, Color(VEIL if active else GOLD, opacity))
		if not mark.is_empty():
			var label: String = mark.label + ("*" if mark.planned else "")
			_text(label, position + Vector2(0, -25), 9 if size.x < 620 else 10, Color(GOLD, opacity * 0.85))
		if value in ARRIVALS or value == Victory.DOMINION_VEIL:
			var owners: Array = stamp_owners(value)
			_seal(position + Vector2(-9, 12), 0, 0 in owners)
			_seal(position + Vector2(9, 12), 1, 1 in owners)
	if has_focus():
		draw_line(Vector2(28, size.y - 1), Vector2(size.x - 28, size.y - 1), Color(GOLD, 0.5), 1)

func _arrival_tooltip(row: Dictionary) -> String:
	var text: String = LordRules.RULES.get(row.lord_id, {}).get("breach", "")
	var protection: String = {"Gremory": "Protection denies the enemy bonus card; your own draw remains.", "Kalligan": "Protection denies the enemy restoration; your own restoration remains.", "Kanifous": "Protection denies the enemy Breach Wish access; your own access remains."}.get(row.lord_id, "Protection makes your side immune to this permanent Breach.")
	return "%s · arrived round %d\n%s\n\n%s" % [row.lord_id, row.round, text, protection if row.protection > 0 else "Cascade: neither player can protect against this arrival."]
