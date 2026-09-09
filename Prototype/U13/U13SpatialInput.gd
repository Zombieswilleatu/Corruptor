class_name U13SpatialInput
extends RefCounted

const Space = preload("res://Scripts/Sim/U13SpatialSpace.gd")


# UI adapter only. The supplied point and lane rectangle must share a canvas
# coordinate space. Player 0 travels bottom to top in the current U13 board.
# No viewport/window pixels leave this adapter. Half points round upward.
static func target_at(point: Vector2, lane_rect: Rect2, lane: String) -> Dictionary:
	if (
		not point.is_finite()
		or not lane_rect.position.is_finite()
		or not lane_rect.size.is_finite()
	):
		return {}
	if lane_rect.size.x <= 0.0 or lane_rect.size.y <= 0.0 or Space.lane_region(lane).is_empty():
		return {}
	var local: Vector2 = point - lane_rect.position
	if local.x < 0.0 or local.y < 0.0 or local.x > lane_rect.size.x or local.y > lane_rect.size.y:
		return {}
	var canonical: Dictionary = (
		Space
		. position(
			{
				"x_fp": int(round((1.0 - local.y / lane_rect.size.y) * Space.LANE_FP)),
				"y_fp": int(round(local.x / lane_rect.size.x * Space.WIDTH_FP)),
			}
		)
	)
	if canonical.is_empty():
		return {}
	return {"lane": lane, "field_position": canonical}
