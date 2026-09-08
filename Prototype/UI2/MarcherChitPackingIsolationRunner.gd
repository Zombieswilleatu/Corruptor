# UI2_MARCHER_CHIT_PACKING_ISOLATION_V1
extends SceneTree

const MarchingLaneViewData = preload(
	"res://Prototype/UI2/MarchingLaneView.gd"
)

const TEST_COUNT: int = 12
const FIELD_SIZE := Vector2(118.0, 714.0)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("==============================================")
	print("UI2 MARCHER CHIT PACKING ISOLATION")
	print("==============================================")
	print("12 chits share the exact same logical midpoint.")
	print("6 enemy + 6 player. Production packing code is used.")
	print("Production files modified: NONE")

	var root := Control.new()
	root.name = "MarcherChitPackingIsolationRoot"
	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	get_root().add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	backdrop.color = Color(
		0.018,
		0.018,
		0.022,
		1.0
	)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var outer := VBoxContainer.new()
	outer.custom_minimum_size = Vector2(
		330.0,
		820.0
	)
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_theme_constant_override(
		"separation",
		8
	)
	center.add_child(outer)

	var title := Label.new()
	title.text = "MARCHER PACKING STRESS TEST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(
		"font_size",
		22
	)
	outer.add_child(title)

	var subtitle := Label.new()
	subtitle.text = (
		"12 units · same logical position · production lane width"
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override(
		"font_size",
		13
	)
	outer.add_child(subtitle)

	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(
		156.0,
		742.0
	)

	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = Color(
		0.045,
		0.045,
		0.052,
		1.0
	)
	shell_style.border_color = Color(
		0.34,
		0.31,
		0.25,
		1.0
	)
	shell_style.set_border_width_all(1)
	shell_style.content_margin_left = 18
	shell_style.content_margin_right = 18
	shell_style.content_margin_top = 14
	shell_style.content_margin_bottom = 14
	shell.add_theme_stylebox_override(
		"panel",
		shell_style
	)
	outer.add_child(shell)

	var field := Control.new()
	field.name = "PackingStressField"
	field.custom_minimum_size = FIELD_SIZE
	field.size = FIELD_SIZE
	field.clip_contents = true
	shell.add_child(field)

	var field_bg := ColorRect.new()
	field_bg.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	field_bg.color = Color(
		0.075,
		0.07,
		0.065,
		1.0
	)
	field_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(field_bg)

	var center_line := ColorRect.new()
	center_line.anchor_left = 0.0
	center_line.anchor_right = 1.0
	center_line.anchor_top = 0.5
	center_line.anchor_bottom = 0.5
	center_line.offset_top = -0.5
	center_line.offset_bottom = 0.5
	center_line.color = Color(
		0.62,
		0.57,
		0.45,
		0.28
	)
	center_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(center_line)

	var enemy_label := Label.new()
	enemy_label.text = "ENEMY ↓"
	enemy_label.position = Vector2(
		6.0,
		6.0
	)
	enemy_label.size = Vector2(
		106.0,
		20.0
	)
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_label.add_theme_font_size_override(
		"font_size",
		10
	)
	field.add_child(enemy_label)

	var player_label := Label.new()
	player_label.text = "YOU ↑"
	player_label.position = Vector2(
		6.0,
		688.0
	)
	player_label.size = Vector2(
		106.0,
		20.0
	)
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.add_theme_font_size_override(
		"font_size",
		10
	)
	field.add_child(player_label)

	# We instantiate the production MarchingLaneView only as a renderer helper.
	# It never enters the tree, so none of its normal battlefield UI is built.
	var renderer = MarchingLaneViewData.new()

	var suits: Array[String] = [
		"Butcher",
		"Penitent",
		"Vulture",
		"Wright",
	]

	for i: int in range(TEST_COUNT):
		var enemy_side: bool = (i % 2) == 0
		var marcher := {
			"suit": suits[i % suits.size()],
			"value": 3,
			"pos": 1,
		}

		renderer._add_marcher_chit(
			field,
			marcher,
			enemy_side,
			int(i / 2)
		)

	var footer := Label.new()
	footer.text = (
		"All 12 are at pos=1. Any separation you see is presentation only."
	)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override(
		"font_size",
		12
	)
	outer.add_child(footer)

	print(
		"ISOLATION READY — 12 chits rendered at the same logical midpoint."
	)


func _finalize() -> void:
	pass
