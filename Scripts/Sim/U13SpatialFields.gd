extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Space = preload("res://Scripts/Sim/U13SpatialSpace.gd")
const VERSION: String = "U13_SPATIAL_WEB_FIELDS_V1"
const WEB: String = "Web"


static func target_valid(target: Dictionary) -> bool:
	return (
		target.size() == 2
		and not Space.lane_region(target.get("lane")).is_empty()
		and not Space.position(target.get("field_position")).is_empty()
	)


# Compile geometry once per Marching phase. Membership is still evaluated
# against each actor's actual position at the start of every movement tick.
# No captured cohort, match clones, registry copies or RNG inside that loop.
static func compile(effects: Array, round_number: int) -> Dictionary:
	var lanes: Dictionary = {}
	for active in effects:
		if not active.payload.has("spatial_field"):
			continue
		if active.declaration.power_id != WEB or not target_valid(active.target):
			return Data.invalid("spatial_field_source_invalid")
		if typeof(active.payload.spatial_field) != TYPE_DICTIONARY:
			return Data.invalid("spatial_field_payload_invalid")
		var spec: Dictionary = active.payload.spatial_field
		if (
			spec.get("kind") != "web"
			or spec.size() != 2
			or not Space.valid_radius(spec.get("radius_fp"))
		):
			return Data.invalid("spatial_field_payload_invalid")
		if (
			round_number < active.activated_round
			or round_number >= active.activated_round + active.stages.size()
		):
			continue
		var area: Dictionary = Space.circle_region(
			active.target.lane, active.target.field_position, spec.radius_fp
		)
		if not lanes.has(active.target.lane):
			lanes[active.target.lane] = []
		lanes[active.target.lane].append({"owner": active.declaration.player_id, "region": area})
	return {"action": "spatial_fields_compiled", "lanes": lanes}


static func slowed(lanes: Dictionary, owner: int, attributes: Dictionary) -> bool:
	for field in lanes.get(attributes.lane, []):
		if field.owner != owner and Space._contains(field.region, attributes):
			return true
	return false
