extends SceneTree

const Artillery = preload("res://Prototype/U13/U13ArtilleryView.gd")
var failures: int = 0


class Side:
	extends Control
	var target_controls: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func _run() -> void:
	var view = Artillery.new()
	root.add_child(view)
	# Synthetic frames isolate clock/event behavior from texture imports.
	var texture := GradientTexture2D.new()
	texture.gradient = Gradient.new()
	view._bolt_frames = []
	view._blast_frames = []
	for _index in range(8):
		view._bolt_frames.append(texture)
		view._blast_frames.append(texture)
	var side = Side.new()
	root.add_child(side)
	for id in ["engine", "castle"]:
		var target := Control.new()
		target.position = Vector2(20, 20) if id == "engine" else Vector2(200, 300)
		target.size = Vector2(100, 150)
		side.add_child(target)
		side.target_controls[id] = target
	var shots: Array = []
	for index in range(2):
		shots.append(
			{
				"type": "ARTILLERY_FIRED",
				"data":
				{
					"round": 1,
					"engine_id": "engine",
					"target_id": "castle",
					"shot": "normal" if index == 0 else "WarMachine",
					"target_before": {"integrity": 4 - index * 2},
					"target_after": {"integrity": 2 - index * 2}
				}
			}
		)
	var impacts: Array = []
	view.impact.connect(func(shot: Dictionary): impacts.append(shot))
	view.play_shots(shots, [side, side])
	_check(
		view.initial_castles().castle.integrity == 4,
		"artillery_rewinds_to_first_shot_not_last_shot"
	)
	view.advance(Artillery.FLIGHT_SECONDS - 0.01)
	_check(impacts.is_empty(), "no_damage_presentation_before_bolt_lands")
	view.advance(0.02)
	_check(
		impacts.size() == 1 and impacts[0].target_after.integrity == 2,
		"first_bolt_applies_first_damage_at_impact"
	)
	view.advance(Artillery.SHOT_SECONDS)
	_check(impacts.size() == 1, "explosion_does_not_repeat_damage_or_start_second_shot")
	view.advance(Artillery.FLIGHT_SECONDS - 0.01)
	_check(impacts.size() == 1, "war_machine_bolt_has_its_own_flight")
	view.advance(0.02)
	_check(
		impacts.size() == 2 and impacts[1].target_after.integrity == 0,
		"second_bolt_applies_lethal_damage_on_its_impact"
	)
	view.clear()
	view.advance(10.0)
	_check(impacts.size() == 2 and not view.active(), "clearing_playback_cancels_pending_impacts")
	view.play_shots(shots, [side, side])
	view.advance(10.0)
	_check(impacts.size() == 3, "large_frame_delta_still_emits_exactly_one_impact_for_current_bolt")
	view.clear()
	view.queue_free()
	side.queue_free()
	await process_frame
	print("U13 artillery impact timing failures: %d" % failures)
	quit(0 if failures == 0 else 1)
