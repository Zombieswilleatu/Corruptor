extends "res://Prototype/U13/U13ButcherLanePreview.gd"

# Approved September replacement. Reference pixels, not uniform grid cells.
# Source rows: left walk, right walk, celebrate, shield attack, death.
func _configure_character() -> void:
	character_name = "Penitent"
	bundled_sheet_path = "res://Prototype/U13/Assets/PenitentSpriteV3.png"
	source_dimensions = Vector2(1374, 1145)
	source_body_height = 205.0
	has_redraw = false
	use_redraw = false
	extra_animation_labels = {2: "Inspect celebrate", 3: "Inspect attack"}
	frame_regions = {}
	frame_polygons = {}
	frame_regions[1] = [
		[Rect2(47, 10, 142, 196), Vector2(120, 207)],
		[Rect2(281, 10, 130, 199), Vector2(344, 207)],
		[Rect2(493, 10, 148, 198), Vector2(566, 207)],
		[Rect2(759, 10, 139, 198), Vector2(830, 207)],
		[Rect2(1001, 11, 143, 198), Vector2(1070, 207)],
		[Rect2(1219, 10, 149, 199), Vector2(1300, 207)],
	]
	frame_regions[0] = [
		[Rect2(35, 221, 142, 206), Vector2(106, 426)],
		[Rect2(267, 223, 149, 204), Vector2(342, 426)],
		[Rect2(498, 223, 151, 205), Vector2(574, 426)],
		[Rect2(766, 223, 135, 204), Vector2(834, 426)],
		[Rect2(991, 224, 152, 203), Vector2(1067, 426)],
		[Rect2(1236, 221, 138, 207), Vector2(1305, 426)],
	]
	frame_polygons[0] = {
		3: PackedVector2Array([Vector2(766, 223), Vector2(901, 223), Vector2(901, 427), Vector2(772, 427), Vector2(770, 425), Vector2(769, 425), Vector2(766, 422)]),
	}
	frame_regions[2] = [
		[Rect2(30, 451, 167, 227), Vector2(112, 677)],
		[Rect2(253, 451, 183, 227), Vector2(340, 677)],
		[Rect2(490, 439, 178, 240), Vector2(573, 677)],
		[Rect2(732, 419, 183, 260), Vector2(821, 677)],
		[Rect2(973, 452, 182, 227), Vector2(1063, 677)],
		[Rect2(1214, 452, 160, 227), Vector2(1295, 677)],
	]
	frame_polygons[2] = {
		3: PackedVector2Array([Vector2(732, 429), Vector2(733, 428), Vector2(734, 428), Vector2(742, 420), Vector2(743, 420), Vector2(744, 419), Vector2(763, 419), Vector2(769, 425), Vector2(770, 425), Vector2(779, 434), Vector2(832, 434), Vector2(833, 433), Vector2(834, 434), Vector2(837, 434), Vector2(838, 433), Vector2(839, 434), Vector2(840, 433), Vector2(841, 434), Vector2(857, 434), Vector2(858, 435), Vector2(859, 434), Vector2(861, 434), Vector2(862, 435), Vector2(863, 434), Vector2(864, 435), Vector2(865, 435), Vector2(866, 436), Vector2(868, 434), Vector2(915, 434), Vector2(915, 679), Vector2(732, 679)]),
	}
	frame_regions[3] = [
		[Rect2(31, 698, 177, 207), Vector2(113, 904)],
		[Rect2(258, 710, 182, 194), Vector2(347, 904)],
		[Rect2(493, 706, 181, 198), Vector2(579, 904)],
		[Rect2(727, 694, 205, 211), Vector2(828, 904)],
		[Rect2(973, 697, 177, 209), Vector2(1062, 904)],
		[Rect2(1204, 698, 170, 208), Vector2(1290, 904)],
	]
	frame_polygons[3] = {
		0: PackedVector2Array([Vector2(31, 698), Vector2(208, 698), Vector2(208, 905), Vector2(111, 905), Vector2(110, 904), Vector2(109, 904), Vector2(108, 903), Vector2(107, 904), Vector2(106, 903), Vector2(102, 903), Vector2(101, 904), Vector2(100, 903), Vector2(98, 905), Vector2(31, 905)]),
	}
	frame_regions[4] = [
		[Rect2(34, 912, 176, 211), Vector2(115, 1119)],
		[Rect2(254, 951, 174, 167), Vector2(340, 1119)],
		[Rect2(470, 978, 194, 140), Vector2(566, 1119)],
		[Rect2(677, 1000, 216, 119), Vector2(786, 1119)],
		[Rect2(902, 1027, 223, 93), Vector2(1009, 1119)],
		[Rect2(1131, 1025, 232, 95), Vector2(1248, 1119)],
	]
