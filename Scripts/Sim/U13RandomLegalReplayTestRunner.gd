# Keep the two-round trial and complete replay together, with their own watchdog.
extends "res://Scripts/Sim/U13RandomLegalTestRunner.gd"


func _run() -> void:
	_batch_replay()
	print("U13 random-legal replay failures: %d" % failures)
	quit(0 if failures == 0 else 1)
