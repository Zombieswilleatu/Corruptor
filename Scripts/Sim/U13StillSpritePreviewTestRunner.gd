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
		if preview.character_name == "Batboy":
			var skittered := false
			for t in [0.0, 0.05, 0.13, 0.5, 1.0]:
				var idle = preview.StillMotion.pose("Idle", t, 0.0, "Batboy")
				var march = preview.StillMotion.pose("March", t, 0.0, "Batboy")
				check(idle.offset == Vector2.ZERO and march.offset.y == 0.0, "Batboy hovered above the ground")
				skittered = skittered or absf(march.offset.x) > 0.001
			check(skittered, "Batboy missing skitter movement")
		if preview.character_name == "Sinodek":
			var image: Image = preview.still_texture.get_image()
			check(image.get_size() == Vector2i(1586, 992), "Sinodek still is not the approved full-size art")
			check(image.get_pixel(0, 0).a == 0.0, "Sinodek lost transparency")
			var data: Dictionary = preview.still_frames[0]
			check(data.anchor.is_equal_approx(Vector2(1088, 884)), "Sinodek ground anchor is incorrect")
			check(is_equal_approx(data.body, 777.0), "Sinodek includes transparent margins in its body height")
		if preview.character_name == "Sooge":
			check(preview.still_frames.has(5), "Missing Sooge turret still")
			check(preview.still_transform_frames.size() == 6, "Missing Sooge transformation frames")
			preview.still_mode = 0
			preview._start_transform()
			check(preview._transform_is_playing(), "Sooge skipped transformation")
			for frame in range(6):
				var current: Dictionary = preview._still_transform_frame()
				check(current.texture == preview.still_transform_frames[frame].texture, "Sooge played the wrong transform frame")
				preview._process(0.5)
				check(preview._still_transform_frame().texture == current.texture, "Pause advanced transformation")
				preview.queue_redraw()
				await process_frame
				preview.paused = false
				preview._process(0.125)
				preview.paused = true
			check(not preview._transform_is_playing(), "Sooge transformation did not finish")
			check(preview.status.text.begins_with("Rooted permanently"), "Still mode hides Sooge's rooted status")
			var final_texture: Texture2D = preview.still_frames[5].texture
			preview.paused = false
			preview._process(20.0)
			preview.paused = true
			check(preview.transform_time >= 20.0, "Sooge unrooted after cycle")
			check(preview._still_transform_frame().texture == final_texture, "Sooge failed to hold its final form")
			preview._start_transform()
			check(preview.transform_time >= 20.0, "Transform button restarted a permanently rooted Sooge")
			# Exercise the actual presentation selector: comparison must not unroot.
			for node in preview.find_children("*", "OptionButton", true, false):
				if node.item_count > 0 and node.get_item_text(0) == "Still + Godot motion":
					for mode in [1, 0]:
						node.select(mode)
						node.item_selected.emit(mode)
						check(preview._still_transform_frame().texture == final_texture, "Presentation switch reset Sooge's form")
			var pose = preview.StillMotion.pose("March", 4.0, 0.0, "Sooge", true)
			check(pose.offset == Vector2.ZERO and pose.angle == 0.0, "Rooted Sooge moved")
			preview._restart_preview()
			check(preview.transform_time < 0.0 and preview.rooted_poses.is_empty(), "Restart did not restore Sooge's mobile form")
			check(preview._still_transform_frame().is_empty(), "Restart still shows turret texture")
		if preview.sheet != null:
			preview.use_still = false
			preview.inspection_row = 0
			preview.queue_redraw()
			await process_frame
		print("Checked ", preview.character_name)
	# Dedicated-still anchors and cached turret frames must not leak on switching.
	preview._select_character(preview.CHARACTERS.find("Penitent"))
	check(preview.still_anchor_uv == Vector2(0.43, 1.0) and preview.still_body_height_ratio == 1.0, "Sinodek anchor leaked to Penitent")
	check(preview.still_transform_frames.is_empty() and preview.transform_time < 0.0, "Sooge transformation leaked to another character")
	print("U13 still sprite preview failures: ", failures)
	quit(1 if failures else 0)
