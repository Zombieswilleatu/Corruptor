extends SceneTree

const Visual = preload("res://Prototype/U13/U13ValakVisual.gd")
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, title: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(title)


func _run() -> void:
	var visual = Visual.new()
	root.add_child(visual)
	visual.staff_position = Vector2(50, 90)
	visual.hover_position = Vector2(100, 140)
	_check(visual.energy_textures.size() == 5 and visual.energy_textures.all(func(t): return t != null), "all_five_original_layers_load")
	_check(visual.flight_texture != null and visual.form_texture != null and visual.rotate_texture != null, "all_three_orb_sheets_load")
	visual.cast(Vector2(500, 200))
	_check(visual.orb_point() == visual.staff_position and visual.phase == "flight", "launch_starts_at_staff")
	visual.advance(0.4)
	_check(visual.orb_point().is_equal_approx(Vector2(275, 145)), "flight_moves_to_target")
	visual.advance(0.4)
	_check(visual.phase == "singularity" and visual.orb_point() == Vector2(500, 200), "formation_only_after_arrival")
	visual.advance(0.8)
	_check(visual.phase == "rotate" and visual.frame_index() == 0, "rotation_starts_after_formation")
	visual.advance(20.0)
	_check(visual.frame_index() >= 2 and visual.frame_index() <= 6, "loop_never_replays_small_growth_frames")
	visual.cast(Vector2(400, 300))
	visual.advance(1.75)
	_check(visual.phase == "rotate" and is_equal_approx(visual.phase_time, 0.15), "large_frame_preserves_transition_overflow")
	visual.clear()
	visual.absorb_charge(Vector2(500, 200))
	visual.absorb_charge(Vector2(510, 210))
	visual.advance(0.3)
	_check(visual.charges == 0, "charges_wait_for_absorption_arrival")
	visual.advance(0.35)
	_check(visual.charges == 2 and visual.absorptions.is_empty(), "each_arrival_adds_one_charge")
	_check(visual.project(Vector2(800, 400)) and visual.charges == 0 and visual.projections[0].charges == 2, "projection_carries_and_clears_stored_layers")
	_check(not visual.project(Vector2.ZERO), "empty_projection_rejected")
	visual.advance(0.8)
	_check(visual.projections.is_empty(), "projection_completes_at_destination")
	visual.set_charges(7)
	_check(visual.charges == 7, "renderer_does_not_impose_five_charge_gameplay_cap")
	visual.absorb_charge(Vector2.ZERO)
	visual.cast(Vector2.ONE)
	visual.clear()
	_check(visual.charges == 0 and visual.phase == "idle" and visual.absorptions.is_empty() and visual.projections.is_empty(), "clear_cancels_every_active_effect")
	visual.free()
	var preview = load("res://Prototype/U13/U13ValakPreview.tscn").instantiate()
	preview.embedded = true
	preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	preview.size = Vector2(1280, 900)
	root.add_child(preview)
	preview.pause = true
	var before: float = preview.visual.clock
	preview._process(1.0)
	_check(preview.visual.clock == before, "preview_pause_freezes_all_animation")
	preview.visual.set_charges(5)
	preview._absorb()
	_check(preview.visual.absorptions.is_empty(), "preview_showcases_five_layers_without_extra_queue")
	var fired_at: Vector2 = preview.destination
	preview.visual.project(fired_at)
	preview.destination += Vector2(80, 60)
	preview.pause = false
	preview._process(preview.visual.flight_seconds)
	_check(preview.impact_position == fired_at, "moving_aim_does_not_move_inflight_projection_impact")
	_check(preview.impact_time > 0.0, "arrival_flash_survives_a_large_frame")
	preview._reset()
	_check(preview.visual.charges == 0 and preview.visual.phase == "flight", "preview_reset_restarts_staff_cast")
	var closed: Array = []
	preview.close_requested.connect(func(): closed.append(true))
	preview._close_preview()
	_check(closed.size() == 1, "embedded_close_returns_to_gallery")
	preview.free()
	var gallery = load("res://Prototype/U13/U13AnimationPreviews.gd").new()
	root.add_child(gallery)
	gallery.open_preview(0)
	_check(gallery.active_preview != null and gallery.active_preview.embedded, "valak_opens_in_existing_gallery")
	gallery.close_preview()
	_check(gallery.active_preview == null, "gallery_stops_and_releases_valak_preview")
	gallery.free()
	await process_frame
	print("U13 Valak visual checks: %d/%d; failures: %d" % [checks - failures, checks, failures])
	quit(1 if failures > 0 else 0)
