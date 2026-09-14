extends "res://Prototype/U13/U13ButcherLanePreview.gd"

func _configure_character() -> void:
	character_name = "Vulture"
	source_dimensions = Vector2(1330, 1182)
	source_body_height = 190.0
	source_shader_path = "res://Prototype/U13/U13VultureKey.gdshader"
	bundled_sheet_path = "res://Prototype/U13/Assets/VultureSprite.png"
	has_redraw = false
	use_redraw = false
	extra_animation_labels = {2: "Inspect celebrate", 3: "Inspect attack"}
	frame_regions = {}
	# Per-row baselines hold the falling body at its original ground level.
	var tops := [24, 237, 451, 687, 900]
	var bottoms := [224, 438, 665, 877, 1075]
	var grounds := [218, 430, 658, 868, 1068]
	var edges := [0, 222, 442, 661, 880, 1100, 1320]
	for row in range(5):
		var poses: Array = []
		for column in range(6):
			var left: int = edges[column]
			var right: int = edges[column + 1]
			# Thrusting daggers reach beyond the regular column spacing.
			if row == 3 and column in [2, 3, 4]:
				right += 38 if column < 4 else 24
			poses.append([Rect2(left, tops[row], right - left, bottoms[row] - tops[row]),
				Vector2((edges[column] + edges[column + 1]) * 0.5, grounds[row])])
		frame_regions[row] = poses

	# Follow the black gaps around the extended blades; rectangles include
	# neighboring cloaks and leave preceding dagger tips in the next frame.
	frame_polygons = {3: {
		2: PackedVector2Array([
			Vector2(442, 687), Vector2(442, 877), Vector2(670, 877), Vector2(670, 764), Vector2(671, 763),
			Vector2(671, 762), Vector2(683, 761), Vector2(685, 760), Vector2(686, 759), Vector2(691, 758),
			Vector2(693, 757), Vector2(698, 756), Vector2(700, 755), Vector2(700, 753), Vector2(699, 752),
			Vector2(694, 751), Vector2(693, 750), Vector2(684, 749), Vector2(670, 748), Vector2(670, 687),
		]),
		3: PackedVector2Array([
			Vector2(670, 687), Vector2(670, 748), Vector2(684, 749), Vector2(693, 750), Vector2(694, 751),
			Vector2(699, 752), Vector2(700, 753), Vector2(700, 755), Vector2(698, 756), Vector2(693, 757),
			Vector2(691, 758), Vector2(686, 759), Vector2(685, 760), Vector2(683, 761), Vector2(671, 762),
			Vector2(671, 763), Vector2(670, 764), Vector2(670, 877), Vector2(890, 877), Vector2(890, 760),
			Vector2(894, 758), Vector2(894, 757), Vector2(901, 756), Vector2(907, 755), Vector2(906, 754),
			Vector2(915, 753), Vector2(915, 752), Vector2(921, 751), Vector2(922, 750), Vector2(922, 749),
			Vector2(914, 748), Vector2(904, 747), Vector2(904, 746), Vector2(890, 745), Vector2(890, 687),
		]),
		4: PackedVector2Array([
			Vector2(890, 687), Vector2(890, 745), Vector2(904, 746), Vector2(904, 747), Vector2(914, 748),
			Vector2(922, 749), Vector2(922, 750), Vector2(921, 751), Vector2(915, 752), Vector2(915, 753),
			Vector2(906, 754), Vector2(907, 755), Vector2(901, 756), Vector2(894, 757), Vector2(894, 758),
			Vector2(890, 760), Vector2(890, 877), Vector2(1110, 877), Vector2(1110, 757), Vector2(1122, 755),
			Vector2(1123, 754), Vector2(1122, 753), Vector2(1120, 752), Vector2(1115, 751), Vector2(1115, 750),
			Vector2(1110, 749), Vector2(1110, 687),
		]),
		5: PackedVector2Array([
			Vector2(1110, 687), Vector2(1110, 749), Vector2(1115, 750), Vector2(1115, 751), Vector2(1120, 752),
			Vector2(1122, 753), Vector2(1123, 754), Vector2(1122, 755), Vector2(1110, 757), Vector2(1110, 877),
			Vector2(1320, 877), Vector2(1320, 687),
		]),
	}}
