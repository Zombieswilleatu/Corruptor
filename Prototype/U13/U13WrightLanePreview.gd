extends "res://Prototype/U13/U13ButcherLanePreview.gd"

func _configure_character() -> void:
	character_name = "Wright"
	bundled_sheet_path = "res://Prototype/U13/Assets/WrightSprite.png"
	source_dimensions = Vector2(1374, 1145)
	source_body_height = 200.0
	# The approved later sheet already has transparency; no color key needed.
	source_shader_path = ""
	has_redraw = false
	use_redraw = false
	extra_animation_labels = {2: "Inspect celebrate", 3: "Inspect attack"}
	frame_regions = {}
	frame_polygons = {}
	# Measured row gaps preserve raised hammers and celebration feet.
	# Attack/death columns differ from the walk grid as the poses widen.
	var tops := [0, 235, 462, 696, 929]
	var bottoms := [230, 460, 695, 920, 1130]
	var grounds := [224, 454, 688, 913, 1110]
	var columns := {
		0: [0, 229, 458, 687, 916, 1145, 1374],
		1: [0, 229, 458, 687, 916, 1145, 1374],
		2: [0, 229, 458, 687, 916, 1145, 1374],
		3: [0, 230, 440, 690, 917, 1160, 1374],
		4: [0, 225, 450, 672, 890, 1129, 1374],
	}
	for row in range(5):
		var poses: Array = []
		for column in range(6):
			var left: int = columns[row][column]
			var right: int = columns[row][column + 1]
			poses.append([Rect2(left, tops[row], right - left, bottoms[row] - tops[row]),
				Vector2(column * 229 + 120, grounds[row])])
		frame_regions[row] = poses
