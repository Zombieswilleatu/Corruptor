extends "res://Prototype/U13/U13ButcherLanePreview.gd"

func _configure_character() -> void:
	character_name = "Sinodek"
	bundled_sheet_path = "res://Prototype/U13/Assets/SinodekSprite.png"
	source_dimensions = Vector2(2048, 995)
	source_body_height = 125.0
	source_shader_path = ''
	has_redraw = false
	use_redraw = false
	extra_animation_labels = {2: "Inspect idle", 3: "Inspect attack"}
	frame_regions = {}
	frame_polygons = {}
	frame_regions[1] = [
		[Rect2(0, 35, 319, 155), Vector2(170.5, 176)],
		[Rect2(319, 35, 341, 155), Vector2(511.5, 176)],
		[Rect2(660, 35, 341, 155), Vector2(852.5, 176)],
		[Rect2(1001, 35, 341, 155), Vector2(1193.5, 176)],
		[Rect2(1342, 35, 363, 155), Vector2(1534.5, 176)],
	]
	frame_regions[0] = [
		[Rect2(0, 240, 319, 150), Vector2(170.5, 375)],
		[Rect2(319, 240, 341, 150), Vector2(511.5, 375)],
		[Rect2(660, 240, 341, 150), Vector2(852.5, 375)],
		[Rect2(1001, 240, 341, 150), Vector2(1193.5, 375)],
		[Rect2(1342, 240, 363, 150), Vector2(1534.5, 375)],
	]
	frame_regions[2] = [
		[Rect2(0, 440, 319, 140), Vector2(170.5, 572)],
		[Rect2(319, 440, 341, 140), Vector2(511.5, 572)],
		[Rect2(660, 440, 363, 140), Vector2(852.5, 572)],
	]
	frame_regions[3] = [
		[Rect2(0, 605, 319, 185), Vector2(170.5, 775)],
		[Rect2(319, 605, 341, 185), Vector2(511.5, 775)],
		[Rect2(660, 605, 341, 185), Vector2(852.5, 775)],
		[Rect2(1001, 605, 341, 185), Vector2(1193.5, 775)],
		[Rect2(1342, 605, 363, 185), Vector2(1534.5, 775)],
	]
	frame_regions[4] = [
		[Rect2(0, 820, 319, 175), Vector2(170.5, 975)],
		[Rect2(319, 820, 341, 175), Vector2(511.5, 975)],
		[Rect2(660, 820, 341, 175), Vector2(852.5, 975)],
		[Rect2(1001, 820, 341, 175), Vector2(1193.5, 975)],
		[Rect2(1342, 820, 341, 175), Vector2(1534.5, 975)],
		[Rect2(1683, 820, 365, 175), Vector2(1875.5, 975)],
	]
