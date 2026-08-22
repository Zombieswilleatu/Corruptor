extends SceneTree


const Tests = preload(
	"res://Scripts/Sim/ActionForecastTests.gd"
)


func _init() -> void:
	var failures: int = 0

	for result: Dictionary in Tests.run():
		print(
			String(
				result.get(
					"text",
					"NO TEST TEXT"
				)
			)
		)

		if not bool(
			result.get(
				"passed",
				false
			)
		):
			failures += 1

	print(
		"Action Forecast failures: ",
		failures
	)

	quit(
		0 if failures == 0 else 1
	)
