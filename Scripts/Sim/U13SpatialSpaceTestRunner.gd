extends SceneTree

const Space = preload("res://Scripts/Sim/U13SpatialSpace.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
var failures: int = 0


func _init() -> void:
	_geometry()
	_samples()
	print("U13 spatial space failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print(("PASS  " if ok else "FAIL  ") + label)


func _geometry() -> void:
	_expect(
		Marching.LANE_FP == Space.LANE_FP and Marching.WIDTH_FP == Space.WIDTH_FP,
		"canonical_space_matches_marching"
	)
	var point: Dictionary = Space.position({"x_fp": 2400.0, "y_fp": 600.0})
	_expect(
		point == {"x_fp": 2400, "y_fp": 600} and typeof(point.x_fp) == TYPE_INT,
		"inclusive_edge_json_normalized"
	)
	for bad in [
		null,
		Vector2(1, 2),
		{"x_fp": 1},
		{"x_fp": 1.5, "y_fp": 2},
		{"x_fp": "1", "y_fp": 2},
		{"x_fp": true, "y_fp": 2},
		{"x_fp": -1, "y_fp": 2},
		{"x_fp": 2401, "y_fp": 2},
		{"x_fp": 1, "y_fp": 601},
		{"x_fp": INF, "y_fp": 2},
		{"x_fp": 1, "y_fp": 2, "pixels": 3}
	]:
		_expect(Space.position(bad).is_empty(), "invalid_position_" + str(bad))
	var area: Dictionary = Space.circle_region("Lord", {"x_fp": 100, "y_fp": 100}, 5)
	_expect(
		Space.contains(area, "Lord", {"x_fp": 103, "y_fp": 104}).inside,
		"circle_exact_boundary_included"
	)
	_expect(
		not Space.contains(area, "Lord", {"x_fp": 104, "y_fp": 104}).inside,
		"circle_outside_excluded"
	)
	_expect(
		not Space.contains(area, "Castle", {"x_fp": 100, "y_fp": 100}).inside, "other_lane_excluded"
	)
	_expect(
		Space.contains(area, "Lord", {"x_fp": 107, "y_fp": 100}, 2).inside, "explicit_body_padding"
	)
	_expect(
		Space.contains(area, "Lord", {"x_fp": 107, "y_fp": 100}, 1.5).action == "invalid",
		"fractional_padding_rejected"
	)
	for radius in [-1, 0.5, true, "5", INF, Space.MAX_RADIUS_FP + 1]:
		_expect(
			Space.circle_region("Lord", {"x_fp": 0, "y_fp": 0}, radius).is_empty(),
			"invalid_radius_" + str(radius)
		)
	var changed: Dictionary = area.duplicate(true)
	changed.screen_x = 1
	_expect(
		Space.region(changed).is_empty() and Space.lane_region("Castle:A").is_empty(),
		"strict_region_shape_and_lane"
	)
	_expect(Space.region(JSON.parse_string(JSON.stringify(area))) == area, "region_json_round_trip")
	var original: Dictionary = {"x_fp": 100, "y_fp": 100}
	var owned: Dictionary = Space.circle_region("Lord", original, 10)
	original.x_fp = 200
	_expect(owned.field_position.x_fp == 100, "region_owns_position")


func _samples() -> void:
	var areas: Array = [
		Space.lane_region("Castle"),
		Space.circle_region("Lord", {"x_fp": 0, "y_fp": 0}, 100),
		Space.circle_region("Lord", {"x_fp": 1200, "y_fp": 300}, 250)
	]
	# Independently calculated from SHA-256 framing in Python, including Unicode.
	var golden: Array = [
		[[753, 526], [341, 128], [182, 128], [752, 480]],
		[[99, 13], [93, 34], [92, 12], [60, 32]],
		[[1217, 75], [1118, 330], [1277, 294], [1141, 63]]
	]
	for a in range(areas.size()):
		for sample in range(4):
			var draw: Dictionary = Space.random_position(
				areas[a], "spatial-golden", "web:α", "POSITION", sample
			)
			_expect(draw.action == "u13_spatial_position", "sample_succeeds_%d_%d" % [a, sample])
			if draw.action != "u13_spatial_position":
				continue
			_expect(
				draw.field_position == {"x_fp": golden[a][sample][0], "y_fp": golden[a][sample][1]},
				"spatial_rng_golden_%d_%d" % [a, sample]
			)
			Rng.draw("spatial-golden", "unrelated", "BOT_POWER_CHOICE", 5, 17)
			Space.random_position(areas[a], "spatial-golden", "web:α", "OTHER_PURPOSE", 99)
			_expect(
				(
					draw
					== Space.random_position(
						areas[a], "spatial-golden", "web:α", "POSITION", sample
					)
				),
				"sample_independent_of_other_calls_%d_%d" % [a, sample]
			)
	var bounded: bool = true
	for sample in range(128):
		var area: Dictionary = areas[sample % areas.size()]
		var draw: Dictionary = Space.random_position(area, "bounds", "effect", "POSITION", sample)
		if draw.action != "u13_spatial_position":
			bounded = false
			continue
		bounded = bounded and Space.contains(area, draw.lane, draw.field_position).inside
	_expect(bounded, "random_samples_remain_in_clipped_region")
	var zero: Dictionary = Space.circle_region("Castle", {"x_fp": 2400, "y_fp": 600}, 0)
	_expect(
		Space.random_position(zero, "s", "e", "p").get("field_position") == zero.field_position,
		"zero_radius_has_one_valid_point"
	)
	_expect(Space.random_position(zero, "", "e", "p").action == "invalid", "sample_requires_key")
	for bad_index in [-1, 0.5, true, "0"]:
		_expect(
			Space.random_position(zero, "s", "e", "p", bad_index).action == "invalid",
			"sample_index_rejected_" + str(bad_index)
		)
