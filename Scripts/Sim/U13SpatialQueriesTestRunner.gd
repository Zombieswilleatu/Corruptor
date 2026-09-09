extends SceneTree

const Space = preload("res://Scripts/Sim/U13SpatialSpace.gd")
const Queries = preload("res://Scripts/Sim/U13SpatialQueries.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
var failures: int = 0


func _init() -> void:
	_run()
	print("U13 spatial queries failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print(("PASS  " if ok else "FAIL  ") + label)


func _fixture(reverse_order: bool = false):
	var registry = Ids.new()
	var rows: Array = [
		[0, 0, "Lord", 90, 100],
		[1, 1, "Lord", 110, 100],
		[2, 1, "Lord", 100, 100],
		[3, 1, "Castle", 100, 100],
		[4, 1, "Lord", 111, 100]
	]
	if reverse_order:
		rows.reverse()
	for row in rows:
		var attributes: Dictionary = Marching.profile("Penitent", row[2], row[1], 1, 1)
		attributes.x_fp = row[3]
		attributes.y_fp = row[4]
		# Waiters remain physical query subjects.
		attributes.waiting = row[0] == 2
		registry.create("marcher", "query-fixture", row[0], row[1], attributes)
	registry.create("castle", "query-fixture", 0, 1, {})
	return registry


func _run() -> void:
	var queries = Queries.new()
	var area: Dictionary = Space.circle_region("Lord", {"x_fp": 100, "y_fp": 100}, 10)
	_expect(queries.members(area).action == "invalid", "query_requires_capture")
	var registry = _fixture()
	var before: Dictionary = registry.snapshot()
	_expect(queries.capture(before).get("count") == 5, "capture_actual_marching_profiles")
	var ids: Array = []
	for index in range(5):
		ids.append(Ids.identity("marcher", "query-fixture", index))
	_expect(
		queries.members(area).ids == [ids[0], ids[1], ids[2]], "membership_stable_ids_not_distance"
	)
	_expect(
		queries.members(area, 1).ids == [ids[1], ids[2]],
		"current_allegiance_filter_includes_waiter"
	)
	_expect(queries.members(area, -1).ids.is_empty(), "valid_empty_query")
	_expect(
		queries.members(area, 1, 1).ids == [ids[1], ids[2], ids[4]], "overlap_uses_explicit_reach"
	)
	_expect(
		queries.nearest(area, area.field_position).id == ids[2],
		"nearest_is_explicit_distance_order"
	)
	var tie_area: Dictionary = Space.circle_region("Lord", {"x_fp": 100, "y_fp": 110}, 15)
	# Remove the central actor so both remaining boundary actors are equidistant.
	registry.retire(ids[2])
	queries.capture(registry.snapshot())
	_expect(
		queries.nearest(tie_area, tie_area.field_position).id == ids[0],
		"nearest_tie_uses_stable_id"
	)
	queries.capture(before)
	var other = Queries.new()
	other.capture(_fixture(true).snapshot())
	_expect(other.members(area) == queries.members(area), "insertion_order_does_not_change_query")
	other.capture(JSON.parse_string(JSON.stringify(before)))
	_expect(
		(
			other.members(area) == queries.members(area)
			and (
				other.nearest(area, area.field_position)
				== queries.nearest(area, area.field_position)
			)
		),
		"query_replays_after_json_restore"
	)
	var returned: Dictionary = queries.members(area)
	returned.ids.clear()
	_expect(queries.members(area).ids.size() == 3, "returned_ids_are_isolated")
	var malformed: Dictionary = before.duplicate(true)
	malformed.entities[0].id = "not-a-stable-id"
	_expect(
		queries.capture(malformed).action == "invalid" and queries.members(area).ids.size() == 3,
		"invalid_capture_is_atomic"
	)
	malformed = before.duplicate(true)
	for row in malformed.entities:
		if row.kind == "marcher":
			row.attributes.x_fp = 90.5
			break
	_expect(
		queries.capture(malformed).action == "invalid" and queries.members(area).ids.size() == 3,
		"fractional_capture_rejected_atomically"
	)
	var moving = _fixture()
	var actor: Dictionary = moving.get_entity(ids[1])
	actor.attributes.x_fp = 200
	moving.update(ids[1], 0, actor.attributes)
	_expect(queries.members(area, 1).ids == [ids[1], ids[2]], "capture_is_owned_snapshot")
	queries.capture(moving.snapshot())
	_expect(queries.members(area, 1).ids == [ids[2]], "recapture_observes_movement_and_allegiance")
	_expect(
		queries.members(Space.lane_region("Lord"), 0).ids == [ids[0], ids[1]],
		"lane_query_uses_current_owner"
	)
	moving.retire(ids[1])
	queries.capture(moving.snapshot())
	_expect(
		queries.members(Space.lane_region("Lord"), 0).ids == [ids[0]],
		"recapture_removes_retired_actor"
	)
	_expect(
		queries.members(area, 0.5).action == "invalid" and queries.members({}).action == "invalid",
		"invalid_query_distinct_from_empty"
	)
	_expect(queries.nearest(area, area.field_position, -1).id == "", "nearest_empty_is_explicit")
	_expect(before == _fixture().snapshot(), "queries_leave_source_untouched")
	queries.capture(Ids.new().snapshot())
	_expect(queries.members(area).ids.is_empty(), "empty_registry_clears_capture")
