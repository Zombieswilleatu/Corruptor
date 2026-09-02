# HUMAN_AGENCY_CONTRACT_LAYER_A_V1
# HUMAN_AGENCY_RUNTIME_CONTRACT_LAYER_B0_V1
class_name HumanAgencyContractTests
extends RefCounted

const ManifestData = preload(
	"res://Scripts/Sim/HumanContractManifest.gd"
)

static func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {
		"name": name,
		"passed": passed,
		"text": "%s  %s - %s" % [
			"PASS" if passed else "FAIL",
			name,
			message,
		],
	}

static func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var expected: Array[String] = [
		"Orias","Deimos","Valak","Kroni","Kalligan",
		"Gremory","Odradek","Kanifous","Humbaba",
	]

	results.append(
		_result(
			"ROSTER",
			ManifestData.LORDS == expected,
			"exactly 9 production Lords; Vanilla excluded"
		)
	)

	results.append(
		_result(
			"MANIFEST_SCHEMA",
			ManifestData.POWERS.size() == 41,
			"41 production semantic powers classified; Valak Projection restored as production active"
		)
	)

	# COMMITMENT_TIMING_FIELD_SCHEMA_V1
	var timing_fields_ok := true
	for power_id in ManifestData.POWERS:
		var timing_entry: Dictionary = ManifestData.POWERS[power_id]
		if not timing_entry.has("commitment_timing"):
			timing_fields_ok = false
			break
		var timing_value := int(
			timing_entry.get(
				"commitment_timing",
				-1
			)
		)
		if timing_value not in [
			ManifestData.CommitmentTiming.PRE_COMMITMENT,
			ManifestData.CommitmentTiming.POST_COMMITMENT,
			ManifestData.CommitmentTiming.CROSS_COMMITMENT,
		]:
			timing_fields_ok = false
			break

	results.append(
		_result(
			"COMMITMENT_TIMING_FIELDS",
			timing_fields_ok,
			"all 41 powers carry PRE / POST / CROSS commitment metadata"
		)
	)

	for lord_name in ManifestData.LORDS:
		var active := ManifestData.active_powers_for_lord(lord_name)
		var names: Array[String] = []
		for entry in active:
			names.append(String(entry.get("name", "")))

		results.append(
			_result(
				"%s/PLAYER_ACTIVATED" % lord_name.to_upper(),
				not active.is_empty(),
				", ".join(names) if not names.is_empty() else "no true player-activated power"
			)
		)

	return results
