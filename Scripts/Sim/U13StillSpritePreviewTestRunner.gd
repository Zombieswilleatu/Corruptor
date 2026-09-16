extends SceneTree

# Run with Godot --headless --path . --script res://Scripts/Sim/U13StillSpritePreviewTestRunner.gd
# Preview-only regression; does not invoke the game or PySim.
var preview
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	preview = load("res://Prototype/U13/U13ButcherLanePreview.gd").new()
	preview.size = Vector2(1100, 800)
	root.add_child(preview)
	await process_frame
	preview.paused = true
	for character in range(preview.CHARACTERS.size()):
		preview._select_character(character)
		await process_frame
		check(preview.use_still and preview.still_texture != null, preview.character_name + " missing still")
		check(preview.still_frames.has(0), preview.character_name + " missing right pose")
		if not preview.still_frames.has(0):
			continue
		for row in preview.still_frames:
			var data: Dictionary = preview.still_frames[row]
			check(data.body > 0 and data.texture.get_width() > 0, "Invalid still dimensions")
		for mode in range(6):
			preview.still_mode = mode
			for t in [0.0, 0.36, 0.7, 1.3, 7.5]:
				preview.clock = t
				preview.queue_redraw()
				await process_frame
		preview._start_death()
		preview._process(0.1)
		check(preview.death_time == 0.0, "Pause advanced death timing")
		preview.death_time = -1.0
		if preview.character_name == "Sooge":
			check(preview.still_frames.has(5), "Missing Sooge turret still")
			preview.still_mode = 0
			preview._start_transform()
			preview.paused = false
			preview._process(20.0)
			preview.paused = true
			check(preview.transform_time >= 20.0, "Sooge unrooted after cycle")
			var pose = preview.StillMotion.pose("March", 4.0, 0.0, "Sooge", true)
			check(pose.offset == Vector2.ZERO and pose.angle == 0.0, "Rooted Sooge moved")
		if preview.sheet != null:
			preview.use_still = false
			preview.inspection_row = 0
			preview.queue_redraw()
			await process_frame
		print("Checked ", preview.character_name)
	print("U13 still sprite preview failures: ", failures)
	quit(1 if failures else 0)
