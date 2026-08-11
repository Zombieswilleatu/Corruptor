extends SceneTree

const Tests = preload("res://Scripts/Sim/CastleRulesV74Tests.gd")

func _init() -> void:
	var failures: int = 0
	for result: Dictionary in Tests.run():
		if bool(result.get("passed", false)):
			print("PASS ", String(result.get("name", "unnamed")))
		else:
			failures += 1
			printerr("FAIL ", String(result.get("name", "unnamed")), ": ", String(result.get("message", "")))
	print("Castle Rules v7.4 failures: ", failures)
	quit(0 if failures == 0 else 1)
