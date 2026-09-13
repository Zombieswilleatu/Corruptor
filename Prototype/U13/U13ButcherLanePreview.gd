extends "res://Prototype/U13/U13VisualPreview.gd"

# Presentation-only trial: no combat outcomes or authoritative movement are simulated.
var sheet: Texture2D
var clock: float = 0.0
var paused: bool = false
var chits: bool = false
var sprite_size: float = 56.0
var unit_count: int = 24
var death_time: float = -1.0
var status: Label

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path := "res://ConceptImages/Sprites/ButcherSprite.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--butcher-sheet="):
			path = argument.trim_prefix("--butcher-sheet=")
	var source := Image.load_from_file(path)
	if source != null and not source.is_empty():
		sheet = ImageTexture.create_from_image(source)
	var panel := VBoxContainer.new()
	panel.position = Vector2(24, 16)
	add_child(panel)
	var title := Label.new()
	title.text = "BUTCHER · VERTICAL LANE TRIAL"
	title.add_theme_font_size_override("font_size", 24)
	panel.add_child(title)
	var controls := HBoxContainer.new()
	panel.add_child(controls)
	_button(controls, "Pause / resume", func(): paused = not paused)
	_button(controls, "Sprites / chits", func(): chits = not chits)
	var count_picker := OptionButton.new()
	for count in [1, 24, 48]:
		count_picker.add_item("%d unit%s" % [count, "" if count == 1 else "s"], count)
	count_picker.select(1)
	count_picker.item_selected.connect(func(index: int): unit_count = count_picker.get_item_id(index))
	controls.add_child(count_picker)
	_button(controls, "Try lane death", func(): death_time = 0.0)
	_button(controls, "Restart", func(): clock = 0.0; death_time = -1.0)
	_button(controls, "Close", func(): _close_preview())
	var sizing := HBoxContainer.new()
	panel.add_child(sizing)
	var size_label := Label.new()
	size_label.text = "Sprite size: 56 px"
	sizing.add_child(size_label)
	var slider := HSlider.new()
	slider.min_value = 32
	slider.max_value = 512
	slider.step = 1
	slider.value = sprite_size
	slider.custom_minimum_size.x = 300
	slider.value_changed.connect(func(value: float):
		sprite_size = value
		size_label.text = "Sprite size: %d px" % int(value))
	sizing.add_child(slider)
	status = Label.new()
	panel.add_child(status)
	if sheet == null:
		status.text = "Missing ButcherSprite.png. Launch with the sprite path as the runner's second argument."
		push_error("Butcher lane preview could not load sprite: " + path)
	set_process(sheet != null)

func _button(parent: Node, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)

func _process(delta: float) -> void:
	if not paused:
		clock += delta
		if death_time >= 0.0:
			death_time += delta
			if death_time > 2.0:
				death_time = -1.0
	status.text = "Walk → idle at contact → reset. No lane attack animation. Death button previews one casualty per side."
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("11151c"))
	var top := 166.0
	var bottom := maxf(top + 260.0, size.y - 55.0)
	var middle := (top + bottom) * 0.5
	var width := minf(290.0, size.x * 0.32)
	for lane in range(2):
		var center := size.x * (0.30 if lane == 0 else 0.70)
		draw_rect(Rect2(center - width * 0.5, top, width, bottom - top), Color("202833"))
		draw_line(Vector2(center, top), Vector2(center, bottom), Color("384353"), 1.0)
		draw_line(Vector2(center - width * 0.5, middle), Vector2(center + width * 0.5, middle), Color("576170"), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(center - 55, top - 20), "LORD LANE" if lane == 0 else "CASTLE LANE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	if sheet == null:
		return
	var phase := fmod(clock, 10.0)
	var walking := phase < 7.0
	var progress := minf(phase / 7.0, 1.0)
	# Depth sorting keeps feet and ownership markers legible through overlapping sprites.
	var units: Array = []
	for lane in range(2):
		for owner in range(2):
			for index in range(12 if unit_count == 48 else 6):
				var center := size.x * (0.30 if lane == 0 else 0.70)
				var x := center + (index % 3 - 1) * 61.0
				var start := top + 135.0 if owner == 1 else bottom - 110.0
				var target := middle - 28.0 if owner == 1 else middle + 43.0
				var rank := floorf(float(index) / 3.0)
				var y := lerpf(start, target, progress) + rank * 32.0 * (-1.0 if owner == 1 else 1.0)
				y = clampf(y, top + 32.0, bottom - 8.0)
				units.append({"feet": Vector2(x, y), "owner": owner, "index": index})
	if unit_count == 1:
		units = [{"feet": Vector2(size.x * 0.5, size.y - 65.0 - progress * 28.0), "owner": 0, "index": 1}]
	units.sort_custom(func(a: Dictionary, b: Dictionary): return a.feet.y < b.feet.y)
	for unit in units:
		_draw_unit(unit.feet, unit.owner, unit.index, walking)
	var caption := "Idle / engaged · attacks belong in the action window" if not walking else "Walking vertically · stable left/right facing"
	draw_string(ThemeDB.fallback_font, Vector2(24, size.y - 20), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)

func _draw_unit(feet: Vector2, owner: int, index: int, walking: bool) -> void:
	var dying := death_time >= 0.0 and index == 1
	var tint := Color("64c8f0") if owner == 0 else Color("f29d68")
	var opacity := 1.0 - clampf((death_time - 1.1) / 0.6, 0.0, 1.0) if dying else 1.0
	tint.a = opacity
	draw_arc(feet, 15.0, 0.0, TAU, 24, tint, 2.0, true)
	if chits:
		draw_circle(feet - Vector2(0, 13), 12, tint)
		draw_string(ThemeDB.fallback_font, feet + Vector2(-5, -7), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
		return
	var frame := int(clock * 8.0 + index) % 6 if walking else 0
	var row := owner # right-facing bottom army, left-facing top army
	if dying:
		row = 4
		frame = mini(5, int(death_time * 7.0))
	var cell := sheet.get_size() / Vector2(6, 5)
	var source := Rect2(Vector2(frame, row) * cell, cell)
	var destination := Rect2(feet - Vector2(sprite_size * 0.5, sprite_size - 7), Vector2.ONE * sprite_size)
	if dying and owner == 1:
		destination.position.x += sprite_size
		destination.size.x = -sprite_size
	draw_texture_rect_region(sheet, destination, source, Color(1, 1, 1, opacity))
	if not dying:
		draw_line(feet + Vector2(-13, 9), feet + Vector2(13, 9), tint, 3.0)
