# Exact old/new comparison, isolated by population under the normal watchdog.
extends "res://Scripts/Sim/U13SpatialMarchingTestRunner.gd"


func _run_suite() -> void:
	_reference_equivalence(48)
	print("U13 spatial reference 48 failures: %d" % failures)
	quit(0 if failures == 0 else 1)
