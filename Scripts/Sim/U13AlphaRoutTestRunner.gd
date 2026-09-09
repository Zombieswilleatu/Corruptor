extends "res://Scripts/Sim/U13AlphaInteractionTestRunner.gd"


func _run() -> void:
	_interaction("Deimos")
	print("U13 alpha Scorch Rout failures: %d" % failures)
	quit(0 if failures == 0 else 1)
