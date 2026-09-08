# Run the same random-plan and two-round replay checks in their own process.
# The parent supplies fixtures/assertions; its deferred _run dispatches here.
extends "res://Scripts/Sim/U13ConstructionTestRunner.gd"


func _run() -> void:
	var started_ms: int = Time.get_ticks_msec()
	print("CONSTRUCTION STAGE random_path BEGIN")
	_random_path()
	print("CONSTRUCTION STAGE random_path elapsed_ms=", Time.get_ticks_msec() - started_ms)
	print("U13 Construction random failures: %d" % failures)
	quit(0 if failures == 0 else 1)
