class_name U13SpatialSpace
extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const VERSION: String = "U13_SPATIAL_SPACE_V1"
const LANE_FP: int = 2400
const WIDTH_FP: int = 600
const LANES: Array[String] = ["Lord", "Castle"]
# Representation bound, not a power's radius. This already covers the lane.
const MAX_RADIUS_FP: int = LANE_FP + WIDTH_FP
const MAX_SAMPLE_ATTEMPTS: int = 1024


# x is forward travel; y is lateral. Boundaries are inclusive.
# Empty dictionary means invalid; integral JSON floats are normalized.
static func position(raw) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or raw.size() != 2:
		return {}
	if not Data.is_integer(raw.get("x_fp")) or not Data.is_integer(raw.get("y_fp")):
		return {}
	var x: int = int(raw.x_fp)
	var y: int = int(raw.y_fp)
	if x < 0 or x > LANE_FP or y < 0 or y > WIDTH_FP:
		return {}
	return {"x_fp": x, "y_fp": y}


static func lane_region(lane) -> Dictionary:
	if typeof(lane) != TYPE_STRING or lane not in LANES:
		return {}
	return {"shape": "lane", "lane": lane}


static func circle_region(lane, center, radius_fp) -> Dictionary:
	var area: Dictionary = lane_region(lane)
	var point: Dictionary = position(center)
	if area.is_empty() or point.is_empty() or not valid_radius(radius_fp):
		return {}
	return {"shape": "circle", "lane": lane, "field_position": point, "radius_fp": int(radius_fp)}


static func region(raw) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	if raw.get("shape") == "lane" and raw.size() == 2:
		return lane_region(raw.get("lane"))
	if raw.get("shape") == "circle" and raw.size() == 4:
		return circle_region(raw.get("lane"), raw.get("field_position"), raw.get("radius_fp"))
	return {}


static func valid_radius(raw) -> bool:
	return Data.is_integer(raw) and raw >= 0 and raw <= MAX_RADIUS_FP


# Invalid data is distinct from a valid miss. Padding is explicit: no implied
# body collider size, allegiance filter, or Godot physics membership.
static func contains(raw_region, lane, raw_position, padding_fp: Variant = 0) -> Dictionary:
	var area: Dictionary = region(raw_region)
	var point: Dictionary = position(raw_position)
	if (
		area.is_empty()
		or point.is_empty()
		or lane_region(lane).is_empty()
		or not valid_radius(padding_fp)
	):
		return Data.invalid("spatial_query_invalid")
	return {
		"action": "u13_spatial_contains",
		"inside": lane == area.lane and _contains(area, point, int(padding_fp))
	}


# Validated bounded points only. Integer arithmetic avoids sqrt/tolerance ties.
static func _distance_squared(a: Dictionary, b: Dictionary) -> int:
	var dx: int = int(a.x_fp) - int(b.x_fp)
	var dy: int = int(a.y_fp) - int(b.y_fp)
	return dx * dx + dy * dy


static func _contains(area: Dictionary, point: Dictionary, padding_fp: int = 0) -> bool:
	if area.shape == "lane":
		return true
	var reach: int = int(area.radius_fp) + padding_fp
	return _distance_squared(area.field_position, point) <= reach * reach


# Uniform over canonical integer points in lane intersected with the circle.
# Each sample and axis has its own key; unrelated draws cannot shift it.
# No obstacle avoidance or collision-free promise is implicit in "valid".
static func random_position(
	raw_region, seed_value: String, effect_id: String, purpose: String, sample_index: Variant = 0
) -> Dictionary:
	var area: Dictionary = region(raw_region)
	if area.is_empty() or seed_value.is_empty() or effect_id.is_empty() or purpose.is_empty():
		return Data.invalid("spatial_sample_invalid")
	if not Data.is_integer(sample_index) or sample_index < 0:
		return Data.invalid("spatial_sample_index_invalid")
	var low_x: int = 0
	var high_x: int = LANE_FP
	var low_y: int = 0
	var high_y: int = WIDTH_FP
	if area.shape == "circle":
		low_x = maxi(0, int(area.field_position.x_fp) - int(area.radius_fp))
		high_x = mini(LANE_FP, int(area.field_position.x_fp) + int(area.radius_fp))
		low_y = maxi(0, int(area.field_position.y_fp) - int(area.radius_fp))
		high_y = mini(WIDTH_FP, int(area.field_position.y_fp) + int(area.radius_fp))
	var draw_id: String = Data.instance_id(VERSION, effect_id, str(int(sample_index)))
	for attempt in range(MAX_SAMPLE_ATTEMPTS):
		var x_roll: Dictionary = Rng.draw(
			seed_value, draw_id, purpose + ":x", attempt, high_x - low_x + 1
		)
		var y_roll: Dictionary = Rng.draw(
			seed_value, draw_id, purpose + ":y", attempt, high_y - low_y + 1
		)
		if x_roll.action == "invalid" or y_roll.action == "invalid":
			return Data.invalid("spatial_sample_rng_failed")
		var point: Dictionary = {
			"x_fp": low_x + int(x_roll.value), "y_fp": low_y + int(y_roll.value)
		}
		if _contains(area, point):
			return {"action": "u13_spatial_position", "lane": area.lane, "field_position": point}
	return Data.invalid("spatial_sample_rejection_limit")
