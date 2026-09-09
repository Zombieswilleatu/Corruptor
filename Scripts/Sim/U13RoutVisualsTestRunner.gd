extends SceneTree

const Visuals = preload("res://Prototype/U13/U13RoutVisuals.gd")
const Lanes = preload("res://Prototype/U13/U13BoardLanes.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
var failures: int = 0


func _init() -> void:
	var actor: Dictionary = {
		"id": "routed",
		"owner": 0,
		"kind": "marcher",
		"attributes": Marching.profile("Butcher", "Lord", 0, 1, 1)
	}
	actor.attributes.rout_round = 2
	actor.attributes.rout_effect_id = "rout-test"
	var untouched: Dictionary = actor.duplicate(true)
	untouched.id = "not-routed"
	untouched.attributes.erase("rout_round")
	untouched.attributes.erase("rout_effect_id")
	var units: Array = [actor, untouched]
	var before: Array = units.duplicate(true)
	var visual = Visuals.new()
	visual.sync(units, 2)
	_expect(visual.subjects.keys() == ["routed"], "rout_mark_only_on_affected_marchers")
	_expect(visual.opacity("routed") == 0.0, "rout_mark_fades_in")
	visual.advance(0.6)
	_expect(visual.texture != null, "rout_uploaded_sprite_loads")
	var alpha: float = visual.opacity("routed")
	visual.advance(0.6)
	_expect(absf(alpha - visual.opacity("routed")) > 0.01, "rout_mark_opacity_pulses")
	var age: float = visual.subjects.routed.age
	actor.attributes.x_fp = 300
	visual.sync(units, 2)
	_expect(visual.subjects.routed.age == age, "playback_refresh_preserves_fade_clock")
	visual.sync(units, 3)
	_expect(visual.subjects.has("routed"), "rout_mark_remains_during_recovery")
	visual.sync(units, 4)
	_expect(visual.subjects.is_empty(), "rout_mark_ends_with_status")
	visual.sync(units, 2)
	visual.sync([], 2)
	_expect(visual.subjects.is_empty(), "removed_marcher_removes_mark")
	actor.attributes.x_fp = before[0].attributes.x_fp
	_expect(units == before, "rout_presentation_does_not_mutate_simulation")
	var lanes = Lanes.new()
	lanes.show_world(units, 2)
	_expect(
		lanes.rout_visuals.subjects.has("routed") and lanes.is_processing(),
		"board_world_enables_rout_pulse"
	)
	lanes.show_frame({"units": units, "clash": []}, 3)
	_expect(lanes.rout_visuals.subjects.has("routed"), "playback_frame_keeps_rout_mark")
	lanes.reset_effects()
	_expect(lanes.rout_visuals.subjects.is_empty(), "board_restart_clears_rout_marks")
	lanes.free()
	print("U13 Rout visuals failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print(("PASS  " if ok else "FAIL  ") + label)
