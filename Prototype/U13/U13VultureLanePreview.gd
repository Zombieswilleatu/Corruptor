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
