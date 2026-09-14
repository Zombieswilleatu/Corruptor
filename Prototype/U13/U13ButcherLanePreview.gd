extends "res://Prototype/U13/U13VisualPreview.gd"

# Presentation-only trial: no combat outcomes or authoritative movement are simulated.
# Regions measured against the original 1374x1145 sheet, not an equal grid.
# Each entry is [crop rect, ground anchor in sheet coordinates]. Keep one scale
# for all frames: fitting individual crops would inflate the collapsing body.
const FRAMES = {
	0: [
		[Rect2(20, 10, 240, 205), Vector2(155, 213)],
		[Rect2(267, 10, 221, 205), Vector2(390, 213)],
		[Rect2(495, 10, 225, 205), Vector2(625, 213)],
		[Rect2(720, 10, 232, 205), Vector2(856, 213)],
		[Rect2(952, 10, 226, 205), Vector2(1086, 213)],
		[Rect2(1178, 10, 196, 205), Vector2(1315, 213)]
	],
	1: [
		[Rect2(0, 230, 244, 209), Vector2(106, 436)],
		[Rect2(244, 230, 244, 209), Vector2(350, 436)],
		[Rect2(488, 230, 228, 209), Vector2(582, 436)],
		[Rect2(716, 230, 226, 209), Vector2(813, 436)],
		[Rect2(942, 230, 230, 209), Vector2(1045, 436)],
		[Rect2(1172, 230, 202, 209), Vector2(1268, 436)]
	],
	4: [
		[Rect2(10, 957, 180, 188), Vector2(100, 1139)],
		[Rect2(228, 957, 210, 188), Vector2(315, 1139)],
		[Rect2(453, 957, 234, 188), Vector2(540, 1139)],
		[Rect2(688, 957, 234, 188), Vector2(770, 1139)],
		[Rect2(922, 957, 198, 188), Vector2(1000, 1139)],
		[Rect2(1160, 957, 214, 188), Vector2(1230, 1139)]
	]
}
var character_name: String = "Butcher"
var frame_regions: Dictionary = FRAMES
var has_redraw: bool = true
var redraw_path: String = "res://Prototype/U13/Assets/ButcherWalkV2.png"
var redraw_shader_path: String = "res://Prototype/U13/U13ButcherKey.gdshader"
var redraw_body_height: float = 455.0
var redraw_anchors: Array[Vector2] = []
var extra_animation_labels: Dictionary = {}
var frame_polygons: Dictionary = {}
var inspection_row: int = -1
var inspection_frame: int = 0
var inspection_playing: bool = false
var inspection_elapsed: float = 0.0
var inspection_slider: HSlider
var inspection_label: Label
var facings: Array[bool] = []
var previous_positions: Dictionary = {}
var facing_rng := RandomNumberGenerator.new()
var use_redraw: bool = true
var redraw: Texture2D
var redraw_layer: Node2D
var redraw_commands: Array = []
var sheet: Texture2D
var clock: float = 0.0
var paused: bool = false
var chits: bool = false
var sprite_size: float = 75.0
var unit_count: int = 24
var death_time: float = -1.0
var displayed_units: Array = []
var death_poses: Dictionary = {}
var status: Label

func _configure_character() -> void:
	pass

func _ready() -> void:
	_configure_character()
	_build_preview()

func _select_character(index: int) -> void:
	var selected: String = ["Butcher", "Penitent"][index]
	if selected == character_name:
		return
	var config = load("res://Prototype/U13/U13%sLanePreview.gd" % selected).new()
	config._configure_character()
	for property in ["character_name", "frame_regions", "extra_animation_labels", "frame_polygons",
		"has_redraw", "use_redraw", "redraw_path", "redraw_shader_path", "redraw_body_height", "redraw_anchors"]:
		set(property, config.get(property))
	config.free()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	sheet = null
	redraw = null
	clock = 0.0
	death_time = -1.0
	inspection_row = -1
	inspection_frame = 0
	inspection_elapsed = 0.0
	inspection_playing = false
	previous_positions.clear()
	displayed_units.clear()
	death_poses.clear()
	redraw_commands.clear()
	_build_preview()
	queue_redraw()

func _build_preview() -> void:
	facing_rng.randomize()
	_roll_facings()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path := "res://ConceptImages/Sprites/%sSprite.png" % character_name
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--%s-sheet=" % character_name.to_lower()):
			path = argument.trim_prefix("--%s-sheet=" % character_name.to_lower())
	# A runner may point at a separate art checkout; use its sibling sheet.
	if not FileAccess.file_exists(path):
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--butcher-sheet=") or argument.begins_with("--penitent-sheet="):
				var sibling := argument.substr(argument.find("=") + 1).get_base_dir().path_join("%sSprite.png" % character_name)
				if FileAccess.file_exists(sibling):
					path = sibling
					break
	var source: Image = Image.load_from_file(path) if FileAccess.file_exists(path) else null
	if source != null and not source.is_empty():
		sheet = ImageTexture.create_from_image(source)
	if has_redraw:
		var walk_image := Image.load_from_file(redraw_path)
		if walk_image != null and not walk_image.is_empty():
			redraw = ImageTexture.create_from_image(walk_image)
	redraw_layer = Node2D.new()
	redraw_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var key_material := ShaderMaterial.new()
	key_material.shader = load(redraw_shader_path)
	redraw_layer.material = key_material
	redraw_layer.draw.connect(_draw_redraw_layer)
	add_child(redraw_layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(24, 16)
	add_child(panel)
	var heading := HBoxContainer.new()
	panel.add_child(heading)
	var character_picker := OptionButton.new()
	character_picker.add_item("Butcher")
	character_picker.add_item("Penitent")
	character_picker.select(0 if character_name == "Butcher" else 1)
	character_picker.item_selected.connect(func(index: int): _select_character.call_deferred(index))
	heading.add_child(character_picker)
	var title := Label.new()
	title.text = "%s · VERTICAL LANE TRIAL" % character_name.to_upper()
	title.add_theme_font_size_override("font_size", 24)
	heading.add_child(title)
	var controls := HBoxContainer.new()
	panel.add_child(controls)
	_button(controls, "Pause / resume", func(): paused = not paused)
	_button(controls, "Sprites / chits", func(): chits = not chits)
	var count_picker := OptionButton.new()
	for count in [1, 24, 48]:
		count_picker.add_item("%d unit%s" % [count, "" if count == 1 else "s"], count)
	count_picker.select([1, 24, 48].find(unit_count))
	count_picker.item_selected.connect(func(index: int): unit_count = count_picker.get_item_id(index))
	controls.add_child(count_picker)
	_button(controls, "Try lane death", _start_death)
	_button(controls, "Restart", func(): clock = 0.0; death_time = -1.0; _roll_facings())
	_button(controls, "Close", func(): _close_preview())
	var sizing := HBoxContainer.new()
	panel.add_child(sizing)
	var size_label := Label.new()
	size_label.text = "Sprite size: %d px" % int(sprite_size)
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
	var art_picker := OptionButton.new()
	art_picker.add_item("New walk")
	art_picker.add_item("Original walk")
	art_picker.item_selected.connect(func(index: int): use_redraw = index == 0)
	art_picker.visible = has_redraw
	sizing.add_child(art_picker)
	var inspector := HBoxContainer.new()
	panel.add_child(inspector)
	var animation := OptionButton.new()
	var inspection_rows: Array[int] = [-1, 0, 1, 4]
	for caption in ["Live lane", "Inspect right walk", "Inspect left walk", "Inspect death"]:
		animation.add_item(caption)
	for attack_row in [2, 3]:
		if frame_regions.has(attack_row):
			animation.add_item(extra_animation_labels.get(attack_row, "Inspect attack %d" % (attack_row - 1)))
			inspection_rows.append(attack_row)
	animation.item_selected.connect(func(index: int):
		inspection_row = inspection_rows[index]
		inspection_elapsed = 0.0
		inspection_frame = 0
		inspection_slider.set_value_no_signal(0)
		inspection_label.text = "Frame 1 / 6")
	inspector.add_child(animation)
	var frame_label := Label.new()
	inspection_label = frame_label
	frame_label.text = "Frame 1 / 6"
	inspector.add_child(frame_label)
	var frame_slider := HSlider.new()
	inspection_slider = frame_slider
	frame_slider.min_value = 0
	frame_slider.max_value = 5
	frame_slider.step = 1
	frame_slider.custom_minimum_size.x = 200
	frame_slider.value_changed.connect(func(value: float):
		inspection_playing = false
		inspection_frame = int(value)
		frame_label.text = "Frame %d / 6" % (inspection_frame + 1))
	inspector.add_child(frame_slider)
	_button(inspector, "Play / hold", func():
		inspection_playing = not inspection_playing
		inspection_elapsed = float(inspection_frame) / 8.0)
	status = Label.new()
	panel.add_child(status)
	if sheet == null:
		status.text = "Missing %sSprite.png. Pass its path as the runner's second argument." % character_name
		push_error(character_name + " lane preview could not load sprite: " + path)
	set_process(sheet != null)

func _button(parent: Node, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)

func _process(delta: float) -> void:
	if not paused:
		clock += delta
		if inspection_row >= 0 and inspection_playing:
			inspection_elapsed += delta
			inspection_frame = int(inspection_elapsed * 8.0) % 6
			inspection_slider.set_value_no_signal(inspection_frame)
			inspection_label.text = "Frame %d / 6" % (inspection_frame + 1)
		if death_time >= 0.0:
			death_time += delta
			if death_time > 2.0:
				death_time = -1.0
	status.text = "Walk → idle at contact → reset. Death stops in place. Inspect individual frames above."
	if inspection_row >= 0:
		status.text = "Inspection: %s · 8 FPS · scrub to hold a frame." % ("playing" if inspection_playing and not paused else "held")
	queue_redraw()

func _draw() -> void:
	redraw_commands.clear()
	if redraw_layer != null:
		redraw_layer.queue_redraw()
	draw_rect(Rect2(Vector2.ZERO, size), Color("11151c"))
	var top := 205.0
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
	var progress := minf(phase / 7.0, 1.0) if inspection_row < 0 else 0.0
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
				units.append({"slot": lane * 24 + owner * 12 + index, "feet": Vector2(x, y), "owner": owner, "index": index, "left": _facing_for_position(lane * 24 + owner * 12 + index, Vector2(x, y))})
	if unit_count == 1:
		units = [{"slot": 1, "feet": Vector2(size.x * 0.5, size.y - 65.0 - progress * 28.0), "owner": 0, "index": 1, "left": facings[1]}]
	if death_time >= 0.0 and inspection_row < 0:
		for unit in units:
			if death_poses.has(unit.slot):
				unit.feet = death_poses[unit.slot].feet
				unit.left = death_poses[unit.slot].left
	displayed_units = units.duplicate(true)
	units.sort_custom(func(a: Dictionary, b: Dictionary): return a.feet.y < b.feet.y)
	for unit in units:
		_draw_unit(unit.feet, unit.owner, unit.index, walking, unit.left)
	var caption := "Idle / engaged · attacks belong in the action window" if not walking else "Walking vertically · stable left/right facing"
	if inspection_row >= 0:
		caption = "Animation inspection · movement held"
	draw_string(ThemeDB.fallback_font, Vector2(24, size.y - 20), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)

func _draw_unit(feet: Vector2, owner: int, index: int, walking: bool, face_left: bool) -> void:
	var dying := death_time >= 0.0 and index == 1 and inspection_row < 0
	var tint := Color("64c8f0") if owner == 0 else Color("f29d68")
	var opacity := 1.0 - clampf((death_time - 1.1) / 0.6, 0.0, 1.0) if dying else 1.0
	tint.a = opacity
	draw_arc(feet, 15.0, 0.0, TAU, 24, tint, 2.0, true)
	if chits:
		draw_circle(feet - Vector2(0, 13), 12, tint)
		draw_string(ThemeDB.fallback_font, feet + Vector2(-5, -7), character_name.left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
		return
	var frame := int(clock * 8.0 + index) % 6 if walking else 0
	var row := 1 if face_left else 0
	if dying:
		row = 4
		frame = mini(5, int(death_time * 7.0))
	if inspection_row >= 0:
		row = inspection_row
		frame = inspection_frame
	if use_redraw and redraw != null and row in [0, 1]:
		# Same body scale and ground line for all six frames. Bottom row's
		# artwork baseline is 974, top row's is 502 in the 1536x1024 source.
		var origin := Vector2((frame % 3) * 512, floori(float(frame) / 3.0) * 512)
		var baseline := 502.0 if frame < 3 else 462.0
		var anchor := Vector2(300, baseline)
		if redraw_anchors.size() == 6:
			anchor = redraw_anchors[frame]
		var factor := sprite_size / redraw_body_height
		var offset := -anchor * factor
		var dimensions := Vector2(512, 512) * factor
		var destination := Rect2(feet + offset, dimensions)
		if row == 1:
			destination.position.x = feet.x - offset.x - dimensions.x
			destination.size.x = -dimensions.x
		redraw_commands.append([destination, Rect2(origin, Vector2(512, 512))])
		return
	var crop: Rect2 = frame_regions[row][frame][0]
	var anchor: Vector2 = frame_regions[row][frame][1]
	var source_scale := sheet.get_size() / Vector2(1374, 1145)
	var source := Rect2(crop.position * source_scale, crop.size * source_scale)
	var factor := sprite_size / 229.0
	var offset := (crop.position - anchor) * factor
	var dimensions := crop.size * factor
	var destination := Rect2(feet + offset, dimensions)
	if dying and face_left:
		destination.position.x = feet.x - offset.x - dimensions.x
		destination.size.x = -dimensions.x
	if frame_polygons.has(row) and frame_polygons[row].has(frame):
		var vertices := PackedVector2Array()
		var uvs := PackedVector2Array()
		for point in frame_polygons[row][frame]:
			vertices.append(feet + (point - anchor) * factor)
			uvs.append(point / Vector2(1374, 1145))
		draw_colored_polygon(vertices, Color(1, 1, 1, opacity), uvs, sheet)
	else:
		draw_texture_rect_region(sheet, destination, source, Color(1, 1, 1, opacity))
	if not dying:
		draw_line(feet + Vector2(-13, 9), feet + Vector2(13, 9), tint, 3.0)

func _draw_redraw_layer() -> void:
	for command in redraw_commands:
		redraw_layer.draw_texture_rect_region(redraw, command[0], command[1])

func _roll_facings() -> void:
	# Cosmetic preview RNG only. Roll once per slot, never during frame drawing.
	facings.clear()
	previous_positions.clear()
	for slot in range(48):
		facings.append(facing_rng.randf() < 0.5)

func _facing_for_position(slot: int, point: Vector2) -> bool:
	if previous_positions.has(slot):
		var movement: Vector2 = point - Vector2(previous_positions[slot])
		# Ignore subpixel jitter; horizontal travel overrides the vertical choice.
		if absf(movement.x) > 0.01:
			facings[slot] = movement.x < 0.0
	previous_positions[slot] = point
	return facings[slot]

func _start_death() -> void:
	death_poses.clear()
	for unit in displayed_units:
		if unit.index == 1:
			death_poses[unit.slot] = {"feet": unit.feet, "left": unit.left}
	death_time = 0.0
