# One lifecycle round plus replay per process, under the existing watchdog.
extends "res://Scripts/Sim/U13OriasWebTestRunner.gd"


func _run() -> void:
	_lifetime_replay(1)
	print("U13 Orias Web lifetime 1 failures: %d" % failures)
	quit(0 if failures == 0 else 1)
