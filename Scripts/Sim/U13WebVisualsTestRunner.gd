extends SceneTree

const Visuals = preload("res://Prototype/U13/U13WebVisuals.gd")
const Preview = preload("res://Prototype/U13/U13WebPreview.gd")
var failures: int = 0


func _init() -> void:
	var visual = Visuals.new()
	visual.warm_next()
	visual.warm_next()
	_check(visual.web != null and visual.spider != null, "web_original_assets_load")
	var lane := Rect2(10, 20, 600, 2400)
	var area: Rect2 = Visuals.region_rect(lane, {"x_fp": 1200, "y_fp": 300}, 270)
	_check(
		area.get_center() == lane.get_center() and area.size == Vector2(540, 540),
		"web_art_matches_canonical_region"
	)
	var previous: Vector2 = visual.spider_pose().position
	var frames: Dictionary = {}
	var moves: int = 0
	for index in range(96):
		visual.advance(0.125)
		var pose: Dictionary = visual.spider_pose()
		frames[pose.frame] = true
		_check(Rect2(0, 0, 1, 1).has_point(pose.position), "spider_stays_on_web_" + str(index))
		if pose.position != previous:
			moves += 1
		previous = pose.position
	_check(frames.size() == 6 and moves == 96, "spider_crawls_with_all_six_frames")
	_check(
		visual.spider_pose().position.is_equal_approx(Visuals.PATH[0]),
		"spider_path_closes_without_teleport"
	)
	var scene = Preview.new()
	_check(scene.radius_fp == 270, "web_preview_initial_width_is_ninety_percent")
	scene.free()
	print("U13 Web visuals failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print(("PASS  " if ok else "FAIL  ") + label)
