# One lifecycle round plus replay per process, under the existing watchdog.
extends "res://Scripts/Sim/U13OriasWebTestRunner.gd"


func _run() -> void:
	_lifetime_replay(2)
	print("U13 Orias Web lifetime 2 failures: %d" % failures)
	quit(0 if failures == 0 else 1)
