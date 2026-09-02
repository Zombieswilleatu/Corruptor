extends SceneTree


const ExistingValakTestsData = preload(
	"res://Scripts/Sim/ValakEssenceTests.gd"
)

const ValakControllerRuntimeTestsData = preload(
	"res://Scripts/Sim/ValakControllerRuntimeTests.gd"
)


func _init() -> void:
	print("")
	print("============================================================")
	print("VALAK ENGINE + CONTROLLER RUNTIME TESTS")
	print("============================================================")

	var results: Array[Dictionary] = []

	for result: Dictionary in ExistingValakTestsData.run():
		results.append(
			result
		)

	for result: Dictionary in ValakControllerRuntimeTestsData.run():
		results.append(
			result
		)

	var failed: int = 0

	for result: Dictionary in results:
		var passed: bool = bool(
			result.get(
				"passed",
				false
			)
		)
		var name: String = String(
			result.get(
				"name",
				"unnamed"
			)
		)

		if passed:
			print(
				"PASS  %s"
				% name
			)
		else:
			failed += 1
			print(
				"FAIL  %s - %s"
				% [
					name,
					String(
						result.get(
							"detail",
							""
						)
					),
				]
			)

	print("")
	print(
		"RESULT: %s (%d failed / %d total)"
		% [
			"PASS" if failed == 0 else "FAIL",
			failed,
			results.size(),
		]
	)

	quit(
		0 if failed == 0 else 1
	)
