# One lifecycle round and its restored replay, under the normal watchdog.
extends "res://Scripts/Sim/U13BreathTestRunner.gd"


func _run() -> void:
	_lifetime_replay(3)
	print("U13 Breath lifetime 3 failures: %d" % failures)
	quit(0 if failures == 0 else 1)
