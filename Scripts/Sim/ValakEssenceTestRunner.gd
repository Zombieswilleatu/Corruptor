extends SceneTree


const ValakEssenceTestsData = preload(
	"res://Scripts/Sim/ValakEssenceTests.gd"
)


func _initialize() -> void:
	print("")
	print("============================================================")
	print("VALAK LIFE ESSENCE / PROJECTION TESTS")
	print("============================================================")

	var failed: int = 0

	for result: Dictionary in ValakEssenceTestsData.run():
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
				"PASS  ",
				name
			)
		else:
			failed += 1
			print(
				"FAIL  ",
				name,
				" — ",
				String(
					result.get(
						"reason",
						""
					)
				)
			)

	print("")
	print(
		"RESULT: ",
		"PASS" if failed == 0 else "FAIL",
		" (",
		failed,
		" failed)"
	)
	print("")

	quit(
		0 if failed == 0 else 1
	)
