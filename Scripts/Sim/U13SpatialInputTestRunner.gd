extends SceneTree

const SpatialInput = preload("res://Prototype/U13/U13SpatialInput.gd")
const Declaration = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
var failures: int = 0


func _init() -> void:
	var rect: Rect2 = Rect2(100, 200, 300, 1200)
	var target: Dictionary = SpatialInput.target_at(Vector2(250, 800), rect, "Lord")
	_expect(
		target == {"lane": "Lord", "field_position": {"x_fp": 1200, "y_fp": 300}},
		"ui_center_to_canonical_position"
	)
	_expect(
		(
			SpatialInput.target_at(Vector2(100, 1400), rect, "Lord").field_position
			== {"x_fp": 0, "y_fp": 0}
		),
		"ui_bottom_left_is_spawn_edge"
	)
	_expect(
		(
			SpatialInput.target_at(Vector2(400, 200), rect, "Lord").field_position
			== {"x_fp": 2400, "y_fp": 600}
		),
		"ui_top_right_is_opposing_edge"
	)
	_expect(
		SpatialInput.target_at(Vector2(500, 1600), Rect2(200, 400, 600, 2400), "Lord") == target,
		"viewport_scale_does_not_change_target"
	)
	_expect(
		SpatialInput.target_at(Vector2(99, 800), rect, "Lord").is_empty(),
		"outside_click_rejected_not_clamped"
	)
	_expect(
		SpatialInput.target_at(Vector2(INF, 0), rect, "Lord").is_empty(),
		"nonfinite_ui_position_rejected"
	)
	_expect(
		SpatialInput.target_at(Vector2.ZERO, Rect2(), "Lord").is_empty(), "zero_size_lane_rejected"
	)
	var declaration: Dictionary = Declaration.create(
		"ui-target",
		0,
		"Orias",
		"SpatialPayloadSmokeTest",
		1,
		Timeline.POST_RESOLUTION_HAZARDS,
		1,
		0,
		"public",
		target
	)
	var restored: Dictionary = Declaration.from_json(Declaration.to_json(declaration))
	_expect(
		not restored.is_empty() and restored.target == target,
		"ui_target_serializes_without_screen_state"
	)
	print("U13 spatial input failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print(("PASS  " if ok else "FAIL  ") + label)
