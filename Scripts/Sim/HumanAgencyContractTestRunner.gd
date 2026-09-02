# HUMAN_AGENCY_CONTRACT_LAYER_A_V1
# HUMAN_AGENCY_RUNTIME_CONTRACT_LAYER_B0_V1
extends SceneTree

const ManifestData = preload(
	"res://Scripts/Sim/HumanContractManifest.gd"
)
const TestsData = preload(
	"res://Scripts/Sim/HumanAgencyContractTests.gd"
)

func _initialize() -> void:
	var failures := 0
	var total := 0

	print("")
	print("RUNNING HUMAN AGENCY CONTRACT TESTS")
	print("Layer A - production-truth agency census")
	print("Roster: %d Lords | Manifest: %d powers" % [
		ManifestData.LORDS.size(),
		ManifestData.POWERS.size(),
	])
	print("")

	for result in TestsData.run():
		total += 1
		print(String(result.get("text", str(result))))
		if not bool(result.get("passed", false)):
			failures += 1

	print("")
	print("AGENCY CENSUS")
	print("------------------------------------------------")
	for lord_name in ManifestData.LORDS:
		var active := ManifestData.active_powers_for_lord(lord_name)
		var names: Array[String] = []
		for entry in active:
			names.append(String(entry.get("name", "")))

		print("%-10s %s" % [
			lord_name,
			"NONE" if names.is_empty() else ", ".join(names),
		])

	print("")
	print("HUMAN AGENCY CONTRACT LAYER A: %d/%d passed" % [
		total - failures,
		total,
	])
	quit(1 if failures > 0 else 0)
