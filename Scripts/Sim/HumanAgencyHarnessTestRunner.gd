# HUMAN_AGENCY_RUNTIME_CONTRACT_LAYER_B0_V1
extends SceneTree

const AgencyTestsData = preload(
	"res://Scripts/Sim/HumanAgencyContractTests.gd"
)
const DecisionTestsData = preload(
	"res://Scripts/Sim/HumanDecisionContractTests.gd"
)
const TimingTestsData = preload(
	"res://Scripts/Sim/CommitmentTimingContractTests.gd"
)

func _initialize() -> void:
	var failures := 0
	var total := 0

	var suites: Array = [
		["LAYER A - AGENCY CENSUS", AgencyTestsData.run()],
		["LAYER A2 - COMMITMENT TIMING", TimingTestsData.run()],
		["LAYER B0 - RUNTIME CONTRACT", DecisionTestsData.run()],
	]

	for suite in suites:
		print("")
		print("============================================================")
		print(String(suite[0]))
		print("============================================================")

		for raw_result in suite[1]:
			var result: Dictionary = raw_result
			total += 1
			print(String(result.get("text", str(result))))
			if not bool(result.get("passed", false)):
				failures += 1

	print("")
	print("============================================================")
	print("HUMAN AGENCY HARNESS: %d/%d passed" % [
		total - failures,
		total,
	])
	print("============================================================")

	if failures > 0:
		print("")
		print("Failures are contract findings, not harness noise.")
		print("Do not reclassify powers merely to make this green.")

	quit(1 if failures > 0 else 0)
