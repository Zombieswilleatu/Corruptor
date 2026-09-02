extends SceneTree


const BotDeployNoCastleDoctrineTestsData = preload(
	"res://Scripts/Sim/BotDeployNoCastleDoctrineTests.gd"
)


func _init() -> void:
	print("")
	print("============================================================")
	print("BOT DEPLOY — NO LIVE CASTLE DOCTRINE")
	print("============================================================")

	var results: Array[Dictionary] = (
		BotDeployNoCastleDoctrineTestsData.run()
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
