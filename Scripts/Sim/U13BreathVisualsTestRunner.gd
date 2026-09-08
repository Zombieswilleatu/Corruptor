extends SceneTree

const Visuals = preload("res://Prototype/U13/U13BreathVisuals.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func _record(id: String = "visual-test") -> Dictionary:
	return {
		"effect_id": id,
		"declaration": {"power_id": "BreathOfLife", "player_id": 0},
		"payload": {"lane_aura": {}},
		"target": {"lane": "Lord"},
		"activated_round": 1,
		"stages": [{}, {}]
	}


func _run() -> void:
	var visuals = Visuals.new()
	visuals.sync([_record()], 1)
	var group: Dictionary = visuals.groups["visual-test"]
	_check(group.flowers.size() == 14, "breath_bounded_flower_count")
	var clone = Visuals.new()
	clone.sync([_record()], 1)
	_check(clone.groups == visuals.groups, "breath_cosmetic_layout_stable_by_instance")
	var variants: Dictionary = {}
	var delays: Dictionary = {}
	for flower in group.flowers:
		variants[flower.variant] = true
		delays[flower.die_after] = true
		_check(Rect2(0, 0, 1, 1).has_point(flower.position), "flower_position_inside_area")
		for frame in range(4):
			group.age = flower.grow_at + (float(frame) + 0.25) * Visuals.GROW_FRAME
			_check(
				Visuals.flower_frame(group, flower) == frame,
				"flower_growth_frame_" + str(frame + 1)
			)
	_check(variants.size() > 1 and delays.size() > 1, "flower_variants_and_death_times_vary")
	group.age = 20.0
	visuals.sync([_record()], 2)
	_check(group.age == 20.0, "board_refresh_does_not_restart_growth")
	for flower in group.flowers:
		_check(Visuals.flower_frame(group, flower) == 3, "flower_holds_mature_frame")
	visuals.sync([], 3)
	_check(group.retired == 20.0, "expiry_starts_visual_tail")
	for flower in group.flowers:
		group.age = group.retired + flower.die_after + 0.1
		_check(Visuals.flower_frame(group, flower) == 4, "flower_first_death_frame")
		group.age = group.retired + flower.die_after + 0.5
		_check(Visuals.flower_frame(group, flower) == 5, "flower_last_death_frame")
		group.age = group.retired + flower.die_after + 0.9
		_check(Visuals.flower_frame(group, flower) == -1, "dead_flower_removed")
	group.age = group.retired + 9.9
	visuals.advance(0.2)
	_check(visuals.groups.is_empty(), "all_flowers_cleaned_by_ten_seconds")
	visuals.sync([_record()], 1)
	visuals.sync([], 3)
	visuals.sync([_record("new-instance")], 3)
	# The new fixture's activation must belong to the current round.
	var fresh: Dictionary = _record("new-instance")
	fresh.activated_round = 3
	visuals.sync([fresh], 3)
	_check(
		(
			visuals.groups.size() == 2
			and visuals.groups["visual-test"].retired >= 0
			and visuals.groups["new-instance"].retired < 0
		),
		"new_aura_independent_of_retiring_flowers"
	)
	visuals.clear()
	_check(visuals.groups.is_empty(), "restart_clears_visual_tails")
	# Asset dimensions/frame layout and cache readiness, without wall-clock waits.
	for _asset in range(5):
		visuals.warm_next()
	for texture in visuals.textures:
		_check(
			texture != null and texture.get_size() == Vector2(1536, 1024),
			"breath_asset_six_frame_atlas"
		)
	print("U13 Breath visuals failures: %d" % failures)
	quit(0 if failures == 0 else 1)
