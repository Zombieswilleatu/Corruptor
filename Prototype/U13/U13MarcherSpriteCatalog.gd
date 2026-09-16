extends RefCounted

# Shared, presentation-only assets. Preview configs own the measured crops;
# instantiating a config without entering the tree does not build its window.
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const Frame = preload("res://Prototype/U13/U13StillFrame.gd")
const CHARACTERS = ["Butcher", "Penitent", "Vulture", "Wright", "Batboy", "BottleTree", "Dogger", "Kopita", "Lemek", "Pixie", "Ratton", "Sinodek", "Wraith", "Sooge"]
const MONSTERS = {"Lemek": "Lemek", "Varn": "Ratton", "Fyra": "Pixie", "Kopita": "Kopita", "Tumler": "Dogger", "Kurchin": "BottleTree", "Muno": "Wraith", "Dotra": "Batboy", "Sooge": "Sooge", "Sinodek": "Sinodek"}
static var _cache: Dictionary = {}

static func resolve_name(value: String) -> String:
	for name in MONSTERS:
		if name.to_lower() == value.to_lower():
			return MONSTERS[name]
	for name in CHARACTERS:
		if name.to_lower() == value.to_lower():
			return name
	return ""

static func character_for(unit: Dictionary) -> String:
	var attributes: Dictionary = unit.get("attributes", {})
	# An unknown explicit monster must not silently become a subject sprite.
	for key in ["sprite_id", "monster_id", "suit"]:
		if not String(attributes.get(key, "")).is_empty():
			return resolve_name(String(attributes[key]))
	return ""

static func assets(character: String) -> Dictionary:
	character = resolve_name(character)
	if character.is_empty():
		return {"frames": {}, "transform": []}
	if _cache.has(character):
		return _cache[character]
	var config = load("res://Prototype/U13/U13%sLanePreview.gd" % character).new()
	config._configure_character()
	var still: Texture2D = _texture(config.still_path)
	var sheet: Texture2D = null
	var redraw: Texture2D = null
	if still == null:
		if character == "Butcher":
			redraw = _texture(config.redraw_path)
		else:
			sheet = _texture(config.bundled_sheet_path)
	var rows: Dictionary = {}
	for row in config.row_sources:
		var texture: Texture2D = _texture(config.row_sources[row].path)
		if texture != null:
			rows[row] = texture
	var result := build_frames(config, sheet, redraw, still, rows)
	config.free()
	_cache[character] = result
	return result

static func _texture(path: String) -> Texture2D:
	if path.is_empty() or (not FileAccess.file_exists(path) and not ResourceLoader.exists(path)):
		return null
	return Art.texture(path)

static func build_frames(config, sheet: Texture2D, redraw: Texture2D,
		still: Texture2D, row_textures: Dictionary) -> Dictionary:
	var frames: Dictionary = {}
	var transformation: Array[Dictionary] = []
	if still != null:
		frames[0] = {"texture": still, "anchor": still.get_size() * config.still_anchor_uv,
			"body": float(still.get_height()) * config.still_body_height_ratio}
	else:
		for row in [0, 1]:
			if sheet == null or not config.frame_regions.has(row):
				continue
			var entry: Array = config.frame_regions[row][0]
			var mask: PackedVector2Array = config.frame_polygons.get(row, {}).get(0, PackedVector2Array())
			var data := Frame.from_sheet(sheet, config.source_dimensions, config.source_body_height,
				entry[0], entry[1], mask, "black" if not config.source_shader_path.is_empty() else "")
			if not data.is_empty():
				frames[row] = data
		if config.character_name == "Butcher" and redraw != null:
			frames.clear()
			frames[0] = Frame.from_sheet(redraw, Vector2(1536, 1024),
				config.redraw_body_height, Rect2(0, 0, 512, 512), Vector2(300, 502),
				PackedVector2Array(), "green")
	if config.permanent_row >= 0 and row_textures.has(config.permanent_row):
		var row: int = config.permanent_row
		var source: Dictionary = config.row_sources[row]
		for frame in range(config.frame_regions[row].size()):
			var entry: Array = config.frame_regions[row][frame]
			var mask: PackedVector2Array = config.frame_polygons.get(row, {}).get(frame, PackedVector2Array())
			var data := Frame.from_sheet(row_textures[row], source.dimensions, source.body_height,
				entry[0], entry[1], mask, "black" if not config.source_shader_path.is_empty() else "")
			if not data.is_empty():
				transformation.append(data)
		if not transformation.is_empty():
			frames[row] = transformation.back()
	return {"frames": frames, "transform": transformation}

static func pose_frame(character: String, face_left: bool, transform_age: float = -1.0) -> Dictionary:
	var data := assets(character)
	if transform_age >= 0.0 and not data.transform.is_empty():
		var index := mini(int(transform_age * 8.0), data.transform.size() - 1)
		return {"frame": data.transform[index], "mirror": face_left}
	var row := 1 if face_left else 0
	if data.frames.has(row):
		return {"frame": data.frames[row], "mirror": false}
	return {"frame": data.frames.get(0, {}), "mirror": face_left}
