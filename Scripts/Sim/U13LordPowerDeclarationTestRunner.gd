extends SceneTree

const U13LordPowerDeclarationData = preload(
	"res://Scripts/Sim/U13LordPowerDeclaration.gd"
)
const U13RoundTimelineData = preload(
	"res://Scripts/Sim/U13RoundTimeline.gd"
)

var failures: int = 0


func _init() -> void:
	_test_basic_declaration()
	_test_spatial_payload_round_trip()
	_test_rejects_node_like_payload()
	_test_future_fire_round()

	print("U13 Lord declaration failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _test_basic_declaration() -> void:
	var declaration: Dictionary = U13LordPowerDeclarationData.create(
		"d_r3_p0_gremory_predator_0",
		0,
		"Gremory",
		"PredatorOfRuin",
		3,
		U13RoundTimelineData.POST_RESOLUTION_SPAWNS,
		3,
		0,
		U13LordPowerDeclarationData.VISIBILITY_PUBLIC,
		{"lane": "Lord"}
	)
	var result: Dictionary = U13LordPowerDeclarationData.validate(declaration)
	if not bool(result.get("valid", false)):
		_fail("basic_declaration", str(result))
		return
	_pass("basic_declaration")


func _test_spatial_payload_round_trip() -> void:
	var position: Dictionary = U13LordPowerDeclarationData.canonical_position(
		1375,
		-240
	)
	var original: Dictionary = U13LordPowerDeclarationData.create(
		"d_r8_p1_test_spatial_2",
		1,
		"Orias",
		"SpatialPayloadSmokeTest",
		8,
		U13RoundTimelineData.POST_RESOLUTION_HAZARDS,
		8,
		2,
		U13LordPowerDeclarationData.VISIBILITY_PUBLIC,
		{
			"lane": "Castle",
			"field_position": position,
		},
		{},
		{"radius_fp": 325}
	)

	if not U13LordPowerDeclarationData.position_is_canonical(position):
		_fail("spatial_round_trip", "position was not canonical")
		return

	var encoded: String = U13LordPowerDeclarationData.to_json(original)
	if encoded.is_empty():
		_fail("spatial_round_trip", "serialization failed")
		return

	var restored: Dictionary = U13LordPowerDeclarationData.from_json(encoded)
	if restored.is_empty():
		_fail("spatial_round_trip", "deserialization failed")
		return

	var target: Dictionary = restored.get("target", {})
	var restored_position = target.get("field_position", null)
	if not U13LordPowerDeclarationData.position_is_canonical(restored_position):
		_fail("spatial_round_trip", "canonical position did not survive JSON")
		return

	var position_row: Dictionary = restored_position
	if (
		int(position_row.get("x_fp", 0)) != 1375
		or int(position_row.get("y_fp", 0)) != -240
		or int(restored.get("queue_index", -1)) != 2
		or String(restored.get("fire_hook", ""))
			!= U13RoundTimelineData.POST_RESOLUTION_HAZARDS
	):
		_fail("spatial_round_trip", str(restored))
		return

	_pass("spatial_round_trip")


func _test_rejects_node_like_payload() -> void:
	var declaration: Dictionary = U13LordPowerDeclarationData.create(
		"d_r2_p0_bad_payload",
		0,
		"Gremory",
		"BadPayload",
		2,
		U13RoundTimelineData.POST_RESOLUTION_SPAWNS,
		2
	)
	declaration["parameters"] = {
		"callable": Callable(self, "_pass"),
	}
	var result: Dictionary = U13LordPowerDeclarationData.validate(declaration)
	if bool(result.get("valid", false)):
		_fail("rejects_object_payload", "Callable payload was accepted")
		return
	_pass("rejects_object_payload")


func _test_future_fire_round() -> void:
	var valid_future: Dictionary = U13LordPowerDeclarationData.create(
		"d_r4_p0_inevitable_ruin",
		0,
		"Gremory",
		"InevitableRuin",
		4,
		U13RoundTimelineData.ROUND_START_SCHEDULED,
		5,
		0,
		U13LordPowerDeclarationData.VISIBILITY_PUBLIC,
		{"castle_id": "p1_castle_keep"},
		{"discard_card_ids": ["Butcher:2", "Vulture:3"]}
	)
	var valid_result: Dictionary = U13LordPowerDeclarationData.validate(valid_future)
	if not bool(valid_result.get("valid", false)):
		_fail("future_fire_round", str(valid_result))
		return

	var bad_future: Dictionary = valid_future.duplicate(true)
	bad_future["fire_round"] = 3
	var bad_result: Dictionary = U13LordPowerDeclarationData.validate(bad_future)
	if bool(bad_result.get("valid", false)):
		_fail("future_fire_round", "fire round before declaration was accepted")
		return

	_pass("future_fire_round")


func _pass(name: String) -> void:
	print("PASS  %s" % name)


func _fail(name: String, reason: String) -> void:
	failures += 1
	print("FAIL  %s: %s" % [name, reason])
