# Exact old/new comparison, isolated by population under the normal watchdog.
extends "res://Scripts/Sim/U13SpatialMarchingTestRunner.gd"


func _run_suite() -> void:
	_reference_equivalence(24)
	print("U13 spatial reference 24 failures: %d" % failures)
	quit(0 if failures == 0 else 1)
