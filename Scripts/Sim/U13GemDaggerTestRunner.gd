extends SceneTree

const View = preload("res://Prototype/U13/U13GemDaggerView.gd")
const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const Scenario = preload("res://Scripts/Sim/U13KalliganScenario.gd")
const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
var failures: int = 0
var impacts: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world: Dictionary = Scenario.world()
	world.data.breach_lord = "Gremory"
	var guard: Dictionary = {}
	for entity in world.entities.entities:
		if entity.kind == "card" and entity.attributes.get("role") == "guard":
			guard = entity
			break
	if not _check(not guard.is_empty(), "gem_fixture_has_guard"):
		quit(1)
		return
	var hit: Dictionary = Battle.apply(
		world,
		{"command_id": "gem-visual-guard", "kind": "defeat_guard", "target_id": guard.id},
		1,
		Timeline.COMBAT_RESOLUTION
	)
	if not _check(hit.action != "invalid", "gem_guard_defeat_fact"):
		quit(1)
		return
	var content = Gremory.new()
	var reaction: Dictionary = content.react(hit.world, hit.event, "gem-visual", [0, 1])
	if not _check(reaction.action != "invalid", "gem_real_reward_resolves"):
		quit(1)
		return
	var events: Array = [hit.event]
	for row in reaction.events:
		if row.views[0] != null:
			events.append(row.views[0])
	var source_events: Array = events.duplicate(true)
	var final_view: Dictionary = {"world": content.project(reaction.world, 0), "events": events}
	var untouched: Dictionary = final_view.duplicate(true)
	var visual = View.new()
	root.add_child(visual)
	visual.impact.connect(_on_impact)
	visual.play_events(events, [])
	_check(
		visual._shots.size() == 1 and visual._shots[0].rewards.size() == 2,
		"gem_two_draws_one_triggering_guard_drop"
	)
	var expected_hand: int = final_view.world.hand.size()
	var own_draw: int = 0
	var enemy_draw: int = 0
	for event in visual._shots[0].rewards:
		if event.data.player_id == 0 and event.data.drawn:
			own_draw += 1
		elif event.data.player_id == 1 and event.data.drawn:
			enemy_draw += 1
			_check(not event.data.has("card_id"), "gem_opponent_reward_identity_remains_hidden")
	_check(own_draw == 1 and enemy_draw == 1, "gem_fixture_exercises_both_rewards")
	var masked: Dictionary = visual.mask_view(final_view)
	_check(
		(
			masked.world.hand.size() == expected_hand - own_draw
			and (
				masked.world.opponent_hand_count
				== final_view.world.opponent_hand_count - enemy_draw
			)
		),
		"gem_rewards_wait_for_impact"
	)
	_check(guard in masked.world.entities, "gem_triggering_guard_remains_until_hit")
	visual.advance(View.FLIGHT_SECONDS - 0.01)
	_check(
		impacts == 0 and visual._texture != null, "gem_flight_has_no_early_impact_and_sprite_loads"
	)
	visual.advance(0.02)
	_check(
		impacts == 1 and visual.mask_view(final_view) == final_view,
		"gem_impact_reveals_guard_defeat_and_rewards_together"
	)
	visual.advance(View.BURST_SECONDS + 0.01)
	visual.advance(1.0)
	_check(impacts == 1 and not visual.active(), "gem_impact_fires_once")
	visual.play_events(events, [])
	visual.clear()
	_check(
		not visual.active() and visual.mask_view(final_view) == final_view,
		"gem_skip_clears_pending_presentation"
	)
	_check(
		final_view == untouched and events == source_events,
		"gem_visuals_leave_authoritative_inputs_untouched"
	)
	var destination := Vector2(220, 450)
	_check(
		(
			View.pose(0.0, destination).position.x == destination.x
			and View.pose(0.35, destination).position.x == destination.x
			and View.pose(0.70, destination).position == destination
		),
		"gem_drops_vertically_to_guard"
	)
	_check(
		View.pose(0.70, destination).frame == 3 and View.pose(0.90, destination).frame == 4,
		"gem_burst_uses_last_two_frames"
	)
	visual.free()
	var preview_scene = load("res://Prototype/U13/U13GemDaggerPreview.tscn").instantiate()
	root.add_child(preview_scene)
	preview_scene.set_process(false)
	preview_scene.looping = false
	_check(preview_scene.animation.active(), "gem_preview_starts_without_hand_payment")
	preview_scene.animation.advance(View.FLIGHT_SECONDS + 0.01)
	_check(
		(
			preview_scene.status.text.contains("You +1 card")
			and preview_scene.guard_box.get_child(1).modulate.a < 0.3
		),
		"gem_preview_guard_and_rewards_change_at_impact"
	)
	preview_scene.play()
	_check(
		preview_scene.guard_box.get_child(1).modulate.a == 1.0 and preview_scene.animation.active(),
		"gem_preview_replays_cleanly"
	)
	preview_scene.free()
	print("U13 Gem Dagger visuals failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _on_impact(_shot: Dictionary) -> void:
	impacts += 1


func _check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
	print(("PASS  " if ok else "FAIL  ") + label)
	return ok
