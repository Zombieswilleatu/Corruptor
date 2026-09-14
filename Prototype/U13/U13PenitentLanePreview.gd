extends "res://Prototype/U13/U13ButcherLanePreview.gd"

# The first source row faces left, the second right. Crops share a ground line.
const PENITENT_FRAMES = {
	0: [
		[Rect2(38, 258, 163, 205), Vector2(120, 460)],
		[Rect2(251, 258, 170, 205), Vector2(337, 460)],
		[Rect2(477, 258, 179, 205), Vector2(568, 460)],
		[Rect2(712, 258, 166, 205), Vector2(798, 460)],
		[Rect2(947, 258, 173, 205), Vector2(1035, 460)],
		[Rect2(1179, 258, 167, 205), Vector2(1264, 460)]
	],
	1: [
		[Rect2(38, 35, 171, 205), Vector2(123, 237)],
		[Rect2(252, 35, 179, 205), Vector2(341, 237)],
		[Rect2(494, 35, 173, 205), Vector2(581, 237)],
		[Rect2(718, 35, 172, 205), Vector2(804, 237)],
		[Rect2(952, 35, 179, 205), Vector2(1041, 237)],
		[Rect2(1183, 35, 165, 205), Vector2(1265, 237)]
	],
	4: [
		[Rect2(33, 921, 174, 185), Vector2(120, 1102)],
		[Rect2(236, 921, 191, 185), Vector2(333, 1102)],
		[Rect2(446, 921, 222, 185), Vector2(557, 1102)],
		[Rect2(670, 921, 237, 185), Vector2(788, 1102)],
		[Rect2(910, 921, 228, 185), Vector2(1024, 1102)],
		[Rect2(1139, 921, 231, 185), Vector2(1254, 1102)]
	],
}

func _ready() -> void:
	character_name = "Penitent"
	frame_regions = PENITENT_FRAMES.duplicate(true)
	# Provisional full-cell cuts for the two attack rows. Keep the existing
	# measured walk/death crops intact; inspect these against the external PNG.
	for row in [2, 3]:
		var poses: Array = []
		for column in range(6):
			var origin := Vector2(column * 229, row * 229)
			poses.append([Rect2(origin, Vector2(229, 229)), origin + Vector2(114.5, 225)])
		frame_regions[row] = poses
	has_redraw = false
	use_redraw = false
	super._ready()
