extends SceneTree

const Details = preload("res://Prototype/U13/U13PowerDetails.gd")
var checks: int = 0
var failures: int = 0
var actions: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + message)

func run() -> void:
	var section := VBoxContainer.new()
	root.add_child(section)
	var description := Label.new()
	description.text = "One operational Siege Engine fires once more at its retained target."
	description.add_theme_font_size_override("font_size", 13)
	section.add_child(description)
	var state := Label.new()
	state.text = "Ready · cooldown 0\nFree · one extra shot, from one Engine"
	section.add_child(state)
	var action := Button.new()
	action.pressed.connect(func(): actions += 1)
	section.add_child(action)
	var helper = Details.new()
	section.add_child(helper)
	helper.fold_state(state, "Extra Siege Engine shot")
	var row: Dictionary = helper.rows[0]
	check(helper.rows.size() == 1 and not row.body.visible, "one collapsed Details group contains explanation and live status")
	check(row.summary.text == "Extra Siege Engine shot\nReady · Free", "default shows a short effect and compact readiness/cost")
	state.text += "\nNo operational Siege Engine.\nArtillery: Choose one Engine for one extra shot. It keeps its current enemy Castle target."
	helper.sync()
	check(row.summary.text.contains("Unavailable · no Siege Engine") and not row.summary.text.contains("Artillery:") and not row.body.visible, "late-bound artillery prose stays collapsed while availability updates")
	row.toggle.pressed.emit()
	check(row.body.visible and row.body.text.contains("Artillery:") and actions == 0, "Details reveals full live explanation without selecting the power")
	row.toggle.pressed.emit()
	check(not row.body.visible and not state.visible and not description.visible, "collapsing hides both original prose sources")
	action.pressed.emit()
	check(actions == 1 and state.text.contains("Artillery:") and action.get_parent() == section, "original text binding and power action remain intact")
	check(Details.status_summary("Ready · cooldown 0\nDiscard 2 · enemy Castle above 8 health\nReduces it to 8 next round. Fizzles if already at 8 or below.") == "Ready · Discard 2", "Ruin keeps cost visible while hiding rules prose")
	section.queue_free()
	await process_frame
	print("U13 Power Details: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
