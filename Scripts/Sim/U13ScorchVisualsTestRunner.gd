extends SceneTree

const Visuals = preload("res://Prototype/U13/U13ScorchVisuals.gd")
const Preview = preload("res://Prototype/U13/U13ScorchPreview.tscn")
var failures: int = 0


func _init() -> void:
	if DisplayServer.get_name() == "headless":
		Engine.max_fps = 60
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func _record() -> Dictionary:
	return {
		"id": "scorch-visual",
		"owner": 0,
		"target": {"kind": "lane", "lane": "Lord"},
		"intensity": 1,
		"remaining": 3,
		"fire_round": 0
	}


func _run() -> void:
	var visuals = Visuals.new()
	var record: Dictionary = _record()
	visuals.sync([record], "lane")
	var group: Dictionary = visuals.groups[record.id]
	_check(group.flames.size() == 12, "scorch_twelve_flames_per_instance")
	var phases: Dictionary = {}
	for flame in group.flames:
		phases[flame.phase] = true
		_check(Rect2(0, 0, 1, 1).has_point(flame.position), "flame_jitter_inside_target")
	_check(phases.size() > 1, "flames_start_at_different_animation_phases")
	var golden: Array = [0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0]
	var flame: Dictionary = {
		"phase": 0, "choice_key": "flame-choice-test", "choice_loop": -1, "choice_sheet": 0
	}
	var holds: bool = true
	for loop in range(golden.size()):
		for frame in range(5):
			var age: float = (float(loop * 5 + frame) + 0.1) / Visuals.FPS
			var value: Dictionary = Visuals.flame_frame(age, flame)
			holds = holds and value.sheet == golden[loop] and value.frame == frame
			var repeated: Dictionary = Visuals.flame_frame(age, flame)
			holds = holds and repeated == value
	_check(holds, "independent_loop_choices_hold_for_all_five_frames")
	_check(golden[13] == 1 and golden[14] == 1, "consecutive_purple_loops_are_allowed")
	var skipped: Dictionary = {
		"phase": 0, "choice_key": "flame-choice-test", "choice_loop": -1, "choice_sheet": 0
	}
	var end_age: float = 79.1 / Visuals.FPS
	_check(
		Visuals.flame_frame(end_age, skipped) == Visuals.flame_frame(end_age, flame),
		"frame_skips_do_not_change_cosmetic_choices"
	)
	var distinct: bool = false
	for loop in range(16):
		var age: float = (float(loop * 5) + 0.1) / Visuals.FPS
		var left: Dictionary = Visuals.flame_frame(age, group.flames[0])
		var right: Dictionary = Visuals.flame_frame(age, group.flames[1])
		distinct = distinct or left.sheet != right.sheet
	_check(distinct, "individual_flames_choose_independently")
	visuals.advance(3.0)
	var initial_age: float = group.age
	var normal: Dictionary = Visuals.strength(group)
	record.intensity = 2
	visuals.sync([record], "lane")
	var hot: Dictionary = Visuals.strength(group)
	_check(
		hot.scale > normal.scale and hot.light > normal.light and hot.alpha > normal.alpha,
		"level_two_all_flames_larger_and_brighter"
	)
	_check(group.age == initial_age, "intensity_change_does_not_restart_animation")
	visuals.flash(record.id)
	visuals.advance(0.2)
	var burst: Dictionary = Visuals.strength(group)
	_check(
		burst.scale > hot.scale and burst.light > hot.light and burst.alpha > hot.alpha,
		"pyroclasm_swell_and_brightness"
	)
	visuals.advance(0.81)
	_check(
		Visuals.strength(group) == hot and group.burst_age < 0,
		"pyroclasm_returns_to_current_intensity_after_one_second"
	)
	record.intensity = 1
	record.target.lane = "Castle"
	visuals.sync([record], "lane")
	_check(
		(
			Visuals.strength(group) == normal
			and group.target.lane == "Castle"
			and group.age > initial_age
		),
		"relocation_and_final_stage_preserve_visual_clock"
	)
	record.fire_round = 5
	visuals.sync([record], "lane")
	_check(visuals.groups.is_empty(), "prepared_inferno_does_not_show_active_flames")
	record.fire_round = 0
	record.target = {"kind": "guard", "lane": "Lord", "player_id": 1}
	visuals.sync([record], "guard", 0)
	_check(visuals.groups.is_empty(), "guard_fire_respects_target_player")
	visuals.sync([record], "guard", 1)
	_check(visuals.groups.size() == 1, "guard_fire_uses_same_renderer")
	visuals.sync([], "guard", 1)
	_check(visuals.groups.is_empty(), "expired_fire_clears_cached_groups")
	for extent in [Vector2(160, 560), Vector2(650, 70), Vector2(90, 240)]:
		var mesh: ArrayMesh = Visuals.ground_mesh(extent, "ground-test")
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		_check(
			mesh.get_surface_count() == 1 and vertices.size() <= Visuals.MAX_STAMPS * 24,
			"ground_brush_one_bounded_mesh"
		)
		var within: bool = true
		var radial: bool = true
		for index in range(vertices.size()):
			within = (
				within
				and vertices[index].x >= 0
				and vertices[index].x <= extent.x
				and vertices[index].y >= 0
				and vertices[index].y <= extent.y
				and uv[index].x >= 0
				and uv[index].x <= 1
				and uv[index].y >= 0
				and uv[index].y <= 1
			)
			radial = radial and (colors[index].a > 0 if index % 3 == 0 else colors[index].a == 0)
		_check(within and radial, "radial_alpha_and_uv_stay_inside_target_and_atlas")
	for _asset in range(3):
		visuals.warm_next()
	for texture in visuals.textures:
		_check(
			texture != null and texture.get_size() == Vector2(2172, 724),
			"exact_user_scorch_assets_loaded"
		)
	# Exercise the actual draw calls, cache reuse, intensity and flash controls.
	var preview = Preview.instantiate()
	root.add_child(preview)
	for _frame in range(12):
		await process_frame
	preview._intensity()
	preview._pyroclasm()
	preview._number(-1, 0)
	await process_frame
	await process_frame
	var cached = preview.lanes.scorch_visuals.groups.values()[0].ground
	await process_frame
	_check(
		cached != null and cached == preview.lanes.scorch_visuals.groups.values()[0].ground,
		"ground_mesh_reused_between_frames"
	)
	preview.queue_free()
	await process_frame
	print("U13 Scorch visuals failures: %d" % failures)
	quit(0 if failures == 0 else 1)
