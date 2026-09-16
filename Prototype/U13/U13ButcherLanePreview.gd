extends "res://Prototype/U13/U13VisualPreview.gd"

# Presentation-only trial: no combat outcomes or authoritative movement are simulated.
# Regions measured against the original 1374x1145 sheet, not an equal grid.
# Each entry is [crop rect, ground anchor in sheet coordinates]. Keep one scale
# for all frames: fitting individual crops would inflate the collapsing body.
const StillMotion = preload("res://Prototype/U13/U13StillSpriteMotion.gd")
const STILL_MODES = ["Lane cycle", "Idle", "March", "Attack", "Hit", "Death"]
# Match U13BoardLanes' continuous battlefield crop and 38% darkening.
const DOMAIN_PATH = "res://ConceptImages/Menus/Domain1.png"
const DOMAIN_CROP = Rect2(0.36, 0.10, 0.24, 0.82)
var domain_texture: Texture2D
var show_domain: bool = true
var show_lane_guides: bool = false
var still_path: String = ""
var still_texture: Texture2D
var use_still: bool = false
var still_mode: int = 0
var still_mode_start: float = 0.0

const CHARACTERS = ["Butcher", "Penitent", "Vulture", "Wright", "Batboy", "BottleTree", "Dogger", "Kopita", "Lemek", "Pixie", "Ratton", "Sinodek", "Wraith", "Sooge"]
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
var source_dimensions := Vector2(1374, 1145)
var source_body_height: float = 229.0
var source_shader_path: String = ""
var bundled_sheet_path: String = ""
var source_layer: Node2D
var source_commands: Array = []
var source_polygon_commands: Array = []
var frame_regions: Dictionary = FRAMES
var has_redraw: bool = true
var redraw_path: String = "res://Prototype/U13/Assets/ButcherWalkV2.png"
var redraw_shader_path: String = "res://Prototype/U13/U13ButcherKey.gdshader"
var redraw_body_height: float = 455.0
var redraw_anchors: Array[Vector2] = []
var extra_animation_labels: Dictionary = {}
var frame_polygons: Dictionary = {}
var row_sources: Dictionary = {}
var row_textures: Dictionary = {}
var permanent_row: int = -1
var transform_time: float = -1.0
var rooted_poses: Dictionary = {}
var inspection_row: int = -1
var inspection_frame: int = 0
var inspection_playing: bool = false
var inspection_elapsed: float = 0.0
var animation_picker: OptionButton
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
	var selected: String = CHARACTERS[index]
	if selected == character_name:
		return
	var config = load("res://Prototype/U13/U13%sLanePreview.gd" % selected).new()
	config._configure_character()
	for property in ["still_path", "row_sources", "permanent_row", "character_name", "frame_regions", "extra_animation_labels", "frame_polygons",
		"has_redraw", "use_redraw", "redraw_path", "redraw_shader_path", "redraw_body_height", "redraw_anchors",
		"source_dimensions", "source_body_height", "source_shader_path", "bundled_sheet_path"]:
		set(property, config.get(property))
	config.free()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	still_texture = null
	still_mode = 0
	still_mode_start = 0.0
	row_textures.clear()
	transform_time = -1.0
	rooted_poses.clear()
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
	if domain_texture == null:
		# Same source-checkout strategy as U13BoardTextures: no editor import needed.
		if FileAccess.file_exists(DOMAIN_PATH):
			var image := Image.new()
			if image.load_png_from_buffer(FileAccess.get_file_as_bytes(DOMAIN_PATH)) == OK:
				domain_texture = ImageTexture.create_from_image(image)
		elif ResourceLoader.exists(DOMAIN_PATH):
			domain_texture = load(DOMAIN_PATH) as Texture2D
	if not still_path.is_empty():
		# Direct scene runners do not import newly pulled PNGs. Prefer the
		# imported resource, but support the raw file on a fresh checkout.
		if FileAccess.file_exists(still_path + ".import"):
			still_texture = load(still_path) as Texture2D
		if still_texture == null and FileAccess.file_exists(still_path):
			var still_image := Image.load_from_file(still_path)
			if still_image != null and not still_image.is_empty():
				still_texture = ImageTexture.create_from_image(still_image)
	use_still = still_texture != null
	facing_rng.randomize()
	_roll_facings()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path := "res://ConceptImages/Sprites/%sSprite.png" % character_name
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--%s-sheet=" % character_name.to_lower()):
			path = argument.trim_prefix("--%s-sheet=" % character_name.to_lower())
	# External sheet paths may point at the Subjects or Monsters folder.
	if not FileAccess.file_exists(path):
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--") and argument.contains("-sheet="):
				var folder := argument.substr(argument.find("=") + 1).get_base_dir()
				for candidate in [folder.path_join("%sSprite.png" % character_name),
					folder.path_join("%s.png" % character_name),
					folder.path_join("Monsters/%s.png" % character_name),
					folder.path_join("%s.png" % character_name.to_lower()),
					folder.path_join("Monsters/%s.png" % character_name.to_lower())]:
					if FileAccess.file_exists(candidate):
						path = candidate
						break
				if FileAccess.file_exists(path):
					break
	# The embedded gallery has no standalone runner sheet argument. Also look
	# beside this checkout, where the user's separate art checkout lives.
	if not FileAccess.file_exists(path):
		for folder in ["res://ConceptImages/Sprites", "res://../Corruptor/ConceptImages/Sprites"]:
			for filename in ["%sSprite.png" % character_name, "%s.png" % character_name,
				"%s.png" % character_name.to_lower(), "Monsters/%s.png" % character_name,
				"Monsters/%s.png" % character_name.to_lower()]:
				var candidate := ProjectSettings.globalize_path(folder.path_join(filename))
				if FileAccess.file_exists(candidate):
					path = candidate
					break
			if FileAccess.file_exists(path):
				break
	if not FileAccess.file_exists(path) and not bundled_sheet_path.is_empty():
		path = bundled_sheet_path
	var source: Image = Image.load_from_file(path) if FileAccess.file_exists(path) else null
	if source != null and not source.is_empty():
		sheet = ImageTexture.create_from_image(source)
	for row in row_sources:
		var row_path: String = row_sources[row].path
		for folder in [path.get_base_dir(), path.get_base_dir().path_join("Monsters")]:
			for filename in [row_sources[row].filename, row_sources[row].filename.to_lower()]:
				var candidate: String = folder.path_join(filename)
				if FileAccess.file_exists(candidate):
					row_path = candidate
		var row_image := Image.load_from_file(row_path)
		if row_image != null and not row_image.is_empty():
			row_textures[row] = ImageTexture.create_from_image(row_image)
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
	source_commands.clear()
	source_polygon_commands.clear()
	source_layer = Node2D.new()
	source_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not source_shader_path.is_empty():
		var source_material := ShaderMaterial.new()
		source_material.shader = load(source_shader_path)
		source_layer.material = source_material
	source_layer.draw.connect(_draw_source_layer)
	add_child(source_layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(24, 16)
	add_child(panel)
	var heading := HBoxContainer.new()
	panel.add_child(heading)
	var character_picker := OptionButton.new()
	for character in CHARACTERS:
		character_picker.add_item(character)
	character_picker.select(CHARACTERS.find(character_name))
	character_picker.item_selected.connect(func(index: int): _select_character.call_deferred(index))
	heading.add_child(character_picker)
	var title := Label.new()
	title.text = "%s · VERTICAL LANE TRIAL" % character_name.to_upper()
	title.add_theme_font_size_override("font_size", 24)
	heading.add_child(title)
	var backdrop_picker := OptionButton.new()
	backdrop_picker.add_item("Domain lanes")
	backdrop_picker.add_item("Plain background")
	backdrop_picker.select(0 if show_domain else 1)
	backdrop_picker.item_selected.connect(func(index: int):
		show_domain = index == 0
		queue_redraw())
	heading.add_child(backdrop_picker)
	var guides := CheckButton.new()
	guides.text = "Guides"
	guides.button_pressed = show_lane_guides
	guides.toggled.connect(func(enabled: bool):
		show_lane_guides = enabled
		queue_redraw())
	heading.add_child(guides)
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
	if permanent_row >= 0:
		_button(controls, "Turret form", _start_transform)
	_button(controls, "Restart", func():
		clock = 0.0
		still_mode_start = 0.0
		death_time = -1.0
		transform_time = -1.0
		rooted_poses.clear()
		_roll_facings())
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
	var still_controls := HBoxContainer.new()
	panel.add_child(still_controls)
	still_controls.visible = use_still
	var motion_label := Label.new()
	motion_label.text = "Still motion:"
	still_controls.add_child(motion_label)
	var motion_picker := OptionButton.new()
	for mode in STILL_MODES:
		motion_picker.add_item(mode)
	motion_picker.item_selected.connect(func(index: int):
		still_mode = index
		still_mode_start = clock
		death_time = -1.0)
	still_controls.add_child(motion_picker)
	_button(still_controls, "Replay motion", func(): still_mode_start = clock)
	var inspector := HBoxContainer.new()
	panel.add_child(inspector)
	inspector.visible = not use_still
	var animation := OptionButton.new()
	animation_picker = animation
	var inspection_rows: Array[int] = [-1, 0, 1, 4]
	for caption in ["Live lane", "Inspect right walk", "Inspect left walk", "Inspect death"]:
		animation.add_item(caption)
	for attack_row in [2, 3, 5]:
		if frame_regions.has(attack_row):
			animation.add_item(extra_animation_labels.get(attack_row, "Inspect attack %d" % (attack_row - 1)))
			inspection_rows.append(attack_row)
	animation.item_selected.connect(func(index: int):
		inspection_row = inspection_rows[index]
		inspection_elapsed = 0.0
		inspection_frame = 0
		inspection_slider.set_value_no_signal(0)
		inspection_slider.max_value = _frame_count(inspection_row) - 1
		inspection_label.text = "Frame 1 / %d" % _frame_count(inspection_row))
	inspector.add_child(animation)
	var frame_label := Label.new()
	inspection_label = frame_label
	frame_label.text = "Frame 1 / %d" % _frame_count(0)
	inspector.add_child(frame_label)
	var frame_slider := HSlider.new()
	inspection_slider = frame_slider
	frame_slider.min_value = 0
	frame_slider.max_value = _frame_count(0) - 1
	frame_slider.step = 1
	frame_slider.custom_minimum_size.x = 200
	frame_slider.value_changed.connect(func(value: float):
		inspection_playing = false
		inspection_frame = int(value)
		frame_label.text = "Frame %d / %d" % [inspection_frame + 1, _frame_count(inspection_row)])
	inspector.add_child(frame_slider)
	_button(inspector, "Play / hold", func():
		inspection_playing = not inspection_playing
		inspection_elapsed = float(inspection_frame) / 8.0)
	if not still_path.is_empty():
		var presentation := OptionButton.new()
		presentation.add_item("Still + Godot motion")
		presentation.add_item("Sprite sheet")
		presentation.set_item_disabled(0, still_texture == null)
		presentation.select(0 if use_still else 1)
		presentation.item_selected.connect(func(index: int):
			use_still = index == 0
			still_controls.visible = use_still
			inspector.visible = not use_still
			inspection_row = -1
			inspection_playing = false
			animation_picker.select(0)
			death_time = -1.0
			clock = 0.0
			still_mode_start = 0.0)
		sizing.add_child(presentation)
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

func _frame_count(row: int) -> int:
	if use_redraw and redraw != null and row in [0, 1]:
		return 6
	return frame_regions.get(row, frame_regions[0]).size()

func _process(delta: float) -> void:
	if not paused:
		clock += delta
		if transform_time >= 0.0:
			transform_time += delta
		if inspection_row >= 0 and inspection_playing:
			inspection_elapsed += delta
			if inspection_row == permanent_row:
				inspection_frame = mini(int(inspection_elapsed * 8.0), _frame_count(inspection_row) - 1)
				if inspection_frame == _frame_count(inspection_row) - 1:
					inspection_playing = false
			else:
				inspection_frame = int(inspection_elapsed * 8.0) % _frame_count(inspection_row)
			inspection_slider.set_value_no_signal(inspection_frame)
			inspection_label.text = "Frame %d / %d" % [inspection_frame + 1, _frame_count(inspection_row)]
		if death_time >= 0.0:
			death_time += delta
			if death_time > 2.0:
				death_time = -1.0
	status.text = "Walk → idle at contact → reset. Death stops in place. Inspect individual frames above."
	if transform_time >= 0.0:
		status.text = "Rooted permanently · Restart restores the mobile form."
	if inspection_row >= 0:
		status.text = "Inspection: %s · 8 FPS · scrub to hold a frame." % ("playing" if inspection_playing and not paused else "held")
	if not still_path.is_empty() and still_texture == null:
		status.text = "Still image could not load: %s" % still_path
	if use_still:
		status.text = "Still + Godot motion · %s · preview only · no skeletal animation" % STILL_MODES[still_mode]
	if show_domain and domain_texture == null:
		status.text += " · Domain1.png unavailable; showing plain background"
	queue_redraw()

func _draw() -> void:
	source_commands.clear()
	source_polygon_commands.clear()
	if source_layer != null:
		source_layer.queue_redraw()
	redraw_commands.clear()
	if redraw_layer != null:
		redraw_layer.queue_redraw()
	draw_rect(Rect2(Vector2.ZERO, size), Color("11151c"))
	var top := 205.0
	var bottom := maxf(top + 260.0, size.y - 55.0)
	var middle := (top + bottom) * 0.5
	var width := minf(290.0, size.x * 0.32)
	var terrain_visible := show_domain and domain_texture != null
	if terrain_visible:
		var field := Rect2(size.x * 0.30 - width * 0.5, top,
			size.x * 0.40 + width, bottom - top)
		var dimensions := domain_texture.get_size()
		draw_texture_rect_region(domain_texture, field,
			Rect2(DOMAIN_CROP.position * dimensions, DOMAIN_CROP.size * dimensions))
		draw_rect(field, Color(0, 0, 0, 0.38))
	for lane in range(2):
		var center := size.x * (0.30 if lane == 0 else 0.70)
		if not terrain_visible:
			draw_rect(Rect2(center - width * 0.5, top, width, bottom - top), Color("202833"))
		if show_lane_guides:
			draw_line(Vector2(center, top), Vector2(center, bottom), Color("7c827d"), 1.0)
			draw_line(Vector2(center - width * 0.5, middle), Vector2(center + width * 0.5, middle), Color("7c827d"), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(center - 55, top - 20), "LORD LANE" if lane == 0 else "CASTLE LANE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	if sheet == null:
		return
	var phase := fmod(clock, 10.0)
	var walking := phase < 7.0
	var progress := minf(phase / 7.0, 1.0) if inspection_row < 0 else 0.0
	if use_still and still_mode != 0:
		progress = 0.0
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
	if transform_time >= 0.0 and inspection_row < 0:
		for unit in units:
			if not rooted_poses.has(unit.slot):
				rooted_poses[unit.slot] = {"feet": unit.feet, "left": unit.left}
			unit.feet = rooted_poses[unit.slot].feet
			unit.left = rooted_poses[unit.slot].left
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
	if use_still:
		caption = "Still art · %s · switch to Sprite sheet above to compare" % STILL_MODES[still_mode]
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
	if use_still and still_texture != null:
		var motion: String = STILL_MODES[still_mode]
		var motion_time := clock - still_mode_start
		if still_mode == 0:
			motion = "March" if walking else "Idle"
			if not walking:
				var contact_time := fmod(clock, 10.0) - 7.0 - float(index % 3) * 0.12
				if contact_time >= 0.3 and contact_time < 1.3:
					motion = "Attack"
					motion_time = contact_time - 0.3
		elif motion in ["Attack", "Hit", "Death"]:
			motion_time = fmod(motion_time, 2.4 if motion == "Death" else 1.8)
		if dying:
			motion = "Death"
			motion_time = death_time
		StillMotion.paint(self, still_texture, feet, sprite_size, face_left,
			motion, motion_time, float(index) * 0.17)
		return
	var row := 1 if face_left else 0
	var frame := int(clock * 8.0 + index) % _frame_count(row) if walking else 0
	if transform_time >= 0.0:
		row = permanent_row
		frame = mini(int(transform_time * 8.0), _frame_count(row) - 1)
	if dying:
		row = 4
		frame = mini(_frame_count(4) - 1, int(death_time * 7.0))
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
	var active_sheet: Texture2D = row_textures.get(row, sheet)
	var active_dimensions: Vector2 = row_sources[row].dimensions if row_sources.has(row) else source_dimensions
	var body_height: float = row_sources[row].body_height if row_sources.has(row) else source_body_height
	var source_scale := active_sheet.get_size() / active_dimensions
	var source := Rect2(crop.position * source_scale, crop.size * source_scale)
	var factor := sprite_size / body_height
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
			uvs.append(point / source_dimensions)
		if not source_shader_path.is_empty():
			source_polygon_commands.append([vertices, Color(1, 1, 1, opacity), uvs])
		else:
			draw_colored_polygon(vertices, Color(1, 1, 1, opacity), uvs, sheet)
	elif not source_shader_path.is_empty():
		source_commands.append([destination, source, Color(1, 1, 1, opacity), active_sheet])
	else:
		draw_texture_rect_region(active_sheet, destination, source, Color(1, 1, 1, opacity))
	if not dying:
		draw_line(feet + Vector2(-13, 9), feet + Vector2(13, 9), tint, 3.0)

func _draw_source_layer() -> void:
	for command in source_polygon_commands:
		source_layer.draw_colored_polygon(command[0], command[1], command[2], sheet)
	for command in source_commands:
		source_layer.draw_texture_rect_region(command[3], command[0], command[1], command[2])

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

func _start_transform() -> void:
	if permanent_row < 0 or transform_time >= 0.0:
		return
	inspection_row = -1
	inspection_playing = false
	animation_picker.select(0)
	rooted_poses.clear()
	for unit in displayed_units:
		rooted_poses[unit.slot] = {"feet": unit.feet, "left": unit.left}
	transform_time = 0.0
