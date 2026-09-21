extends Control

signal march_requested(lane: String)
const Tray = preload("res://Prototype/U13/U13GameStagingTray.gd")
const Layout = preload("res://Prototype/U13/U13LiveLaneLayout.gd")
var trays: Dictionary = {}
var captions: Dictionary = {}
var scrolls: Dictionary = {}
var pickers: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lane in ["Lord", "Castle"]:
		var picker := Button.new()
		picker.text = "MARCH"
		picker.tooltip_text = "Send this lane's staged group next round. Recruits added this round join that release. Reserves stay protected until you press MARCH."
		picker.pressed.connect(func(): march_requested.emit(lane))
		add_child(picker)
		pickers[lane] = picker
		for pid in [0, 1]:
			var key: String = lane + str(pid)
			var caption := Label.new()
			caption.add_theme_font_size_override("font_size", 12)
			caption.modulate = Color("92c7eb") if pid == 0 else Color("ef9993")
			caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(caption)
			captions[key] = caption
			var scroll := ScrollContainer.new()
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			add_child(scroll)
			scrolls[key] = scroll
			var tray = Tray.new()
			tray.compact = true
			tray.reserve_owner = pid
			tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(tray)
			trays[key] = tray
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	for lane in pickers:
		var col: Rect2 = Layout.column(size, lane)
		pickers[lane].position = Vector2(col.position.x, size.y - 34)
		pickers[lane].size = Vector2(col.size.x, 28)
		for pid in [0, 1]:
			var key: String = lane + str(pid)
			var top: float = size.y - 154 if pid == 0 else 48.0
			captions[key].position = Vector2(col.position.x, top)
			captions[key].size = Vector2(col.size.x, 20)
			scrolls[key].position = Vector2(col.position.x, top + 22)
			scrolls[key].size = Vector2(col.size.x, 90)

func bind(state: Dictionary, number: int, modes: Dictionary, editable: bool) -> void:
	visible = not state.is_empty()
	if not visible: return
	for lane in pickers:
		var requested: bool = modes.get(lane, "Hold") == "March"
		pickers[lane].text = "MARCH · ROUND %d" % (number + 1) if requested else "MARCH"
		pickers[lane].disabled = not editable or requested
		var decisions: Array = state.lanes[lane].decisions
		for pid in [0, 1]:
			var key: String = lane + str(pid)
			var units: Array = state.lanes[lane].units.filter(func(u): return u.owner == pid)
			var due: int = int(state.lanes[lane].get("march_round", [0, 0])[pid])
			captions[key].text = "%s · %d%s" % ["YOUR STAGING" if pid == 0 else "ENEMY STAGING", units.size(), " · MARCH R%d" % due if due > 0 else ""]
			trays[key].bind(units, number)
			trays[key].tooltip_text = "Protected reserves." if decisions.is_empty() else decisions[pid].reason

func set_editable(editable: bool) -> void:
	for picker in pickers.values(): picker.disabled = not editable
