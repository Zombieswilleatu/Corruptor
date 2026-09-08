extends "res://Scripts/Sim/U13BoardTestRunner.gd"


# Preserve the model fixtures and replay rounds without consuming the UI
# runner's deadline. The foundation wrapper runs this before U13Board.
func _run() -> void:
	var started: int = Time.get_ticks_msec()
	_stage("source_textures", started)
	_source_textures()
	_stage("manual_and_payment", started)
	_manual_and_payment()
	_stage("random_and_replay", started)
	_random_and_replay()
	_stage("butcher_movement", started)
	_butcher_movement()
	_stage("model_complete", started)
	print("U13 board model failures: %d" % failures)
	quit(0 if failures == 0 else 1)
