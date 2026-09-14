extends "res://Prototype/U13/U13ButcherLanePreview.gd"

func _configure_character() -> void:
	character_name = "Wraith"
	bundled_sheet_path = "res://Prototype/U13/Assets/WraithSprite.png"
	source_dimensions = Vector2(1374, 1145)
	source_body_height = 205.0
	source_shader_path = ''
	has_redraw = false
	use_redraw = false
	extra_animation_labels = {2: "Inspect idle", 3: "Inspect attack"}
	frame_regions = {}
	frame_polygons = {}
	frame_regions[0] = [
		[Rect2(0, 20, 226, 227), Vector2(114.5, 238)],
		[Rect2(226, 20, 233, 227), Vector2(343.5, 238)],
		[Rect2(459, 20, 223, 227), Vector2(572.5, 238)],
		[Rect2(682, 20, 219, 227), Vector2(801.5, 238)],
		[Rect2(901, 20, 229, 227), Vector2(1030.5, 238)],
		[Rect2(1130, 20, 244, 227), Vector2(1259.5, 238)],
	]
	frame_regions[1] = [
		[Rect2(0, 248, 225, 220), Vector2(114.5, 463)],
		[Rect2(225, 248, 222, 220), Vector2(343.5, 463)],
		[Rect2(447, 248, 230, 220), Vector2(572.5, 463)],
		[Rect2(677, 248, 217, 220), Vector2(801.5, 463)],
		[Rect2(894, 248, 229, 220), Vector2(1030.5, 463)],
		[Rect2(1123, 248, 251, 220), Vector2(1259.5, 463)],
	]
	frame_regions[2] = [
		[Rect2(0, 468, 207, 237), Vector2(114.5, 693)],
		[Rect2(207, 468, 229, 237), Vector2(343.5, 693)],
		[Rect2(436, 468, 229, 237), Vector2(572.5, 693)],
		[Rect2(665, 468, 229, 237), Vector2(801.5, 693)],
		[Rect2(894, 468, 229, 237), Vector2(1030.5, 693)],
		[Rect2(1123, 468, 251, 237), Vector2(1259.5, 693)],
	]
	frame_regions[3] = [
		[Rect2(0, 707, 212, 227), Vector2(114.5, 919)],
		[Rect2(212, 707, 268, 227), Vector2(343.5, 919)],
		[Rect2(480, 707, 335, 227), Vector2(572.5, 919)],
		[Rect2(755, 707, 193, 227), Vector2(801.5, 919)],
		[Rect2(948, 707, 223, 227), Vector2(1030.5, 919)],
		[Rect2(1171, 707, 203, 227), Vector2(1259.5, 919)],
	]
	frame_regions[4] = [
		[Rect2(0, 935, 207, 210), Vector2(114.5, 1128)],
		[Rect2(207, 935, 229, 210), Vector2(343.5, 1128)],
		[Rect2(436, 935, 229, 210), Vector2(572.5, 1128)],
		[Rect2(665, 935, 240, 210), Vector2(801.5, 1128)],
		[Rect2(905, 935, 233, 210), Vector2(1030.5, 1128)],
		[Rect2(1138, 935, 236, 210), Vector2(1259.5, 1128)],
	]
	frame_polygons = {
		3: {
			2: PackedVector2Array([
				Vector2(480, 707), Vector2(480, 934), Vector2(755, 934), Vector2(755, 822), Vector2(788, 809),
				Vector2(815, 801), Vector2(815, 789), Vector2(787, 785), Vector2(760, 774), Vector2(760, 707),
			]),
			3: PackedVector2Array([
				Vector2(760, 707), Vector2(760, 774), Vector2(787, 785), Vector2(815, 789), Vector2(815, 801),
				Vector2(788, 809), Vector2(755, 822), Vector2(755, 934), Vector2(948, 934), Vector2(948, 707),
			]),
		},
	}
