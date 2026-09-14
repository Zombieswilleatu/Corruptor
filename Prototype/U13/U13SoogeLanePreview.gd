extends "res://Prototype/U13/U13ButcherLanePreview.gd"

func _configure_character() -> void:
	character_name = "Sooge"
	bundled_sheet_path = "res://Prototype/U13/Assets/SoogeSprite.png"
	source_dimensions = Vector2(1402, 1122)
	source_body_height = 150.0
	source_shader_path = "res://Prototype/U13/U13VultureKey.gdshader"
	has_redraw = false
	use_redraw = false
	permanent_row = 5
	extra_animation_labels = {2: "Inspect idle", 3: "Inspect attack 1", 5: "Inspect attack 2 · turret form"}
	row_sources = {5: {"path": "res://Prototype/U13/Assets/SoogeTurretForm.png", "filename": "SoogeTurretForm.png", "dimensions": Vector2(2172, 724), "body_height": 235.0}}
	frame_regions = {}
	frame_regions[1] = [
		[Rect2(0, 75, 234, 155), Vector2(132.0, 225)],
		[Rect2(234, 75, 233, 155), Vector2(361.5, 225)],
		[Rect2(467, 75, 234, 155), Vector2(594.0, 224)],
		[Rect2(701, 75, 234, 155), Vector2(822.5, 226)],
		[Rect2(935, 75, 233, 155), Vector2(1047.0, 226)],
		[Rect2(1168, 75, 234, 155), Vector2(1274.0, 226)],
	]
	frame_regions[0] = [
		[Rect2(0, 280, 234, 155), Vector2(132.5, 430)],
		[Rect2(234, 280, 233, 155), Vector2(361.0, 429)],
		[Rect2(467, 280, 234, 155), Vector2(583.5, 427)],
		[Rect2(701, 280, 234, 155), Vector2(810.0, 429)],
		[Rect2(935, 280, 231, 155), Vector2(1042.0, 430)],
		[Rect2(1166, 280, 236, 155), Vector2(1269.0, 430)],
	]
	frame_regions[2] = [
		[Rect2(0, 490, 234, 165), Vector2(130.5, 651)],
		[Rect2(234, 490, 233, 165), Vector2(361.0, 651)],
		[Rect2(467, 490, 234, 165), Vector2(587.5, 650)],
		[Rect2(701, 490, 234, 165), Vector2(812.0, 652)],
		[Rect2(935, 490, 233, 165), Vector2(1040.0, 652)],
		[Rect2(1168, 490, 234, 165), Vector2(1269.0, 650)],
	]
	frame_regions[3] = [
		[Rect2(0, 700, 234, 165), Vector2(126.0, 855)],
		[Rect2(234, 700, 223, 165), Vector2(345.5, 856)],
		[Rect2(457, 700, 248, 165), Vector2(581.5, 857)],
		[Rect2(705, 700, 225, 165), Vector2(817.5, 861)],
		[Rect2(930, 700, 238, 165), Vector2(1048.0, 859)],
		[Rect2(1168, 700, 234, 165), Vector2(1275.0, 858)],
	]
	frame_regions[4] = [
		[Rect2(0, 910, 234, 160), Vector2(128.5, 1062)],
		[Rect2(234, 910, 233, 160), Vector2(346.5, 1060)],
		[Rect2(467, 910, 225, 160), Vector2(577.5, 1063)],
		[Rect2(692, 910, 225, 160), Vector2(803.5, 1064)],
		[Rect2(917, 910, 233, 160), Vector2(1033.0, 1064)],
		[Rect2(1150, 910, 252, 160), Vector2(1262.5, 1067)],
	]
	frame_regions[5] = [
		[Rect2(0, 250, 383, 262), Vector2(208.0, 506)],
		[Rect2(383, 250, 344, 262), Vector2(577.0, 498)],
		[Rect2(727, 250, 359, 262), Vector2(911.0, 502)],
		[Rect2(1086, 250, 360, 262), Vector2(1259.0, 503)],
		[Rect2(1446, 250, 360, 262), Vector2(1619.0, 503)],
		[Rect2(1806, 250, 366, 262), Vector2(1976.0, 507)],
	]
