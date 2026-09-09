extends "res://Scripts/Sim/U13HazardsTestRunner.gd"

const Feedback = preload("res://Prototype/U13/U13MarcherFeedback.gd")
const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")
const EventLog = preload("res://Scripts/Sim/U13EventLog.gd")


func _run() -> void:
	_hazard_numbers()
	_regeneration_numbers()
	_tick_numbers()
	_filtered_projection()
	print("U13 Marcher feedback failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _public_rows(envelopes: Array) -> Array:
	var result: Array = []
	for envelope in envelopes:
		if envelope.event.type in Feedback.TYPES:
			result.append(envelope.views[0])
	return result


func _hazard_numbers() -> void:
	var content = Content.new()
	var world: Dictionary = Scenario.world()
	var armored: String = _unit(world, 0, "Lord", 2, 1)
	var fragile: String = _unit(world, 1, "Lord", 1, 0)
	var untouched: String = _unit(world, 1, "Castle", 2, 0)
	var before: Dictionary = world.duplicate(true)
	var active: Dictionary = _active({"kind": "lane", "lane": "Lord"})
	var first: Dictionary = Content.Hazards.pulse(
		_context(world, 2, Timeline.POST_RESOLUTION_DIRECT),
		active,
		"feedback-extra",
		Callable(content._humbaba, "react")
	)
	if not _check(first.action != "invalid", "feedback_real_extra_pulse_resolves"):
		return
	var second: Dictionary = Content.Hazards.pulse(
		_context(first.world, 2, Timeline.MARCHING_START),
		active,
		"feedback-normal",
		Callable(content._humbaba, "react")
	)
	if not _check(second.action != "invalid", "feedback_real_step_eleven_pulse_resolves"):
		return
	var events: Array = _public_rows(first.events) + _public_rows(second.events)
	var rows: Array = Feedback.outside_marching(events, second.world.entities.entities)
	var shield_hits: Array = rows.filter(func(hit): return hit.id == armored)
	var deaths: Array = rows.filter(func(hit): return hit.id == fragile)
	_check(
		(
			shield_hits.size() == 2
			and shield_hits[0].hp == 0
			and shield_hits[0].armor == -1
			and shield_hits[1].hp == -1
		),
		"scorch_armor_then_hp_numbers"
	)
	_check(
		shield_hits.size() == 2 and shield_hits[0].at < shield_hits[1].at,
		"extra_and_normal_pulses_present_sequentially"
	)
	_check(
		deaths.size() == 1 and deaths[0].hp == -1 and deaths[0].lane == "Lord",
		"lethal_scorch_keeps_dead_unit_anchor"
	)
	_check(
		rows.filter(func(hit): return hit.id == untouched).is_empty(),
		"other_lane_has_no_fake_damage"
	)
	_check(world == before, "feedback_does_not_mutate_authoritative_input")
	var empty: Dictionary = Content.Hazards.pulse(
		_context(Scenario.world(), 2, Timeline.POST_RESOLUTION_DIRECT),
		active,
		"feedback-empty-pyro",
		Callable(content._humbaba, "react")
	)
	var empty_rows: Array = Feedback.outside_marching(
		_public_rows(empty.events), empty.world.entities.entities
	)
	_check(
		empty_rows.size() == 1 and empty_rows[0].get("pulse", "") == active.effect_id,
		"empty_pyroclasm_still_schedules_visual_flash"
	)

	# Overkill reports remaining HP, never the nominal pulse strength.
	var lethal: Dictionary = Content.Hazards.pulse(
		_context(world, 2, Timeline.MARCHING_START),
		_active({"kind": "lane", "lane": "Lord"}, 3),
		"feedback-overkill",
		Callable(content._humbaba, "react")
	)
	var capped: Array = Feedback.outside_marching(
		_public_rows(lethal.events), lethal.world.entities.entities
	)
	_check(
		capped.filter(func(hit): return hit.id == fragile and hit.hp == -1).size() == 1,
		"overkill_number_clamped_to_actual_hp"
	)


func _regeneration_numbers() -> void:
	var world: Dictionary = Scenario.world()
	var healing: String = _unit(world, 0, "Lord", 4, 1)
	var full: String = _unit(world, 1, "Lord", 5, 1)
	var waiting: String = _unit(world, 1, "Castle", 1, 0)
	_put(world, healing, {"waiting": false, "waiting_since_round": 0, "regen": 3})
	_put(world, full, {"waiting": false, "waiting_since_round": 0})
	var result: Dictionary = Marching.regenerate(_context(world, 2, Timeline.ROUND_START_AUTOMATIC))
	if not _check(result.action != "invalid", "feedback_real_regeneration_resolves"):
		return
	var rows: Array = Feedback.outside_marching(
		_public_rows(result.events), result.world.entities.entities
	)
	_check(
		rows.size() == 1 and rows[0].id == healing and rows[0].hp == 1,
		"healing_number_uses_actual_capped_regeneration"
	)
	_check(
		rows.filter(func(hit): return hit.id == full or hit.id == waiting).is_empty(),
		"full_hp_and_waiters_do_not_show_fake_healing"
	)


func _picture(id: String, hp: int, armor: int, x: int = 1200) -> Dictionary:
	return {
		"id": id,
		"kind": "marcher",
		"owner": 0,
		"attributes":
		{
			"lane": "Lord",
			"hp": hp,
			"max_hp": 5,
			"armor": armor,
			"x_fp": x,
			"y_fp": 300,
			"suit": "Butcher",
			"waiting": false,
			"movement_ready_round": 1
		}
	}


func _tape(bypass: bool = false) -> Array:
	var start: Dictionary = _picture("victim", 2 if bypass else 5, 4 if bypass else 1)
	var struck: Dictionary = _picture("victim", 2, 4 if bypass else 0)
	var survivor: Dictionary = _picture("survivor", 5, 1, 1000)
	var removed: Dictionary = _picture("consumed", 3, 0)
	return [
		{
			"type": "MARCHING_STARTED",
			"data":
			{
				"model": "U13_MARCHING_SPATIAL_V2",
				"round": 1,
				"ticks": 2,
				"units": [start, survivor, removed]
			}
		},
		{
			"type": "MARCHING_TICK",
			"data": {"tick": 0, "units": [struck, survivor], "clash": ["victim", "survivor"]}
		},
		{
			"type": "MARCHER_CLASH",
			"data":
			{
				"units": [start, survivor],
				"exchanges":
				[
					{"hp": [2, 5], "armor": [4 if bypass else 0, 1]},
					{"hp": [0, 5], "armor": [4 if bypass else 0, 1]}
				]
			}
		},
		{"type": "MARCHING_TICK", "data": {"tick": 1, "units": [survivor], "clash": []}},
		{"type": "MARCHING_FINISHED", "data": {"units": [survivor]}}
	]


func _tick_numbers() -> void:
	var tape: Array = _tape()
	var original: Array = tape.duplicate(true)
	var playback = Playback.new()
	if not _check(playback.build(tape), "feedback_tick_tape_builds"):
		return
	var changes: Dictionary = playback.feedback_through(playback.duration, 0)
	_check(
		(
			changes.rows.size() == 2
			and changes.rows[0].hp == -3
			and changes.rows[0].armor == -1
			and changes.rows[1].hp == -2
		),
		"low_fps_retains_every_exchange_and_lethal_remainder"
	)
	_check(
		playback.feedback_through(playback.duration, changes.cursor).rows.is_empty(),
		"feedback_cursor_never_repeats_hits"
	)
	playback.sample(0)
	playback.sample(playback.duration)
	_check(
		tape == original and playback.feedback_rows == changes.rows,
		"sampling_is_pure_and_never_emits_or_changes_damage"
	)
	_check(
		changes.rows.filter(func(hit): return hit.id == "consumed").is_empty(),
		"consumption_is_not_mislabeled_as_damage"
	)
	_check(
		(
			playback.build(_tape(true))
			and playback.feedback_rows.size() == 1
			and playback.feedback_rows[0].armor == 0
		),
		"lethal_bypass_does_not_invent_armor_loss"
	)
	var visual = Feedback.new()
	visual.show_rows(changes.rows)
	_check(
		visual.visible.size() == 1 and visual.visible[0].hp == -5 and visual.visible[0].armor == -1,
		"rapid_exchange_numbers_accumulate_without_losing_amounts"
	)
	visual.advance(Feedback.LIFETIME)
	_check(visual.visible.is_empty(), "damage_labels_expire_without_timers")
	var dense: Array = []
	for index in range(150):
		dense.append(Feedback.row(_picture(str(index), 5, 0), -1, 0))
	visual.show_rows(dense)
	_check(visual.visible.size() == Feedback.MAX_VISIBLE, "dense_field_has_bounded_label_budget")
	visual.clear()
	_check(visual.visible.is_empty(), "restart_clears_feedback")


func _filtered_projection() -> void:
	var log = EventLog.new()
	var hit: Dictionary = {
		"type": "MARCHER_DAMAGED", "text": "", "data": {"hook": Timeline.MARCHING_START}
	}
	log.append(hit, [null, hit])
	log.append(hit, [hit, hit])
	var hidden_type: Dictionary = {"type": "SECRET", "text": "", "data": {"secret": true}}
	log.append(hidden_type, [hit, null])
	var marching: Dictionary = hit.duplicate(true)
	marching.data.hook = Timeline.MARCHING
	log.append(marching, [marching, marching])
	var rows: Array = log.selected_for_player(0, 0, Feedback.TYPES, Timeline.MARCHING)
	_check(
		rows.size() == 2 and not str(rows).contains("secret"),
		"feedback_reads_only_player_projection_and_excludes_tick_phase"
	)
	rows[0].data.hook = "changed"
	_check(
		(
			log.selected_for_player(0, 0, Feedback.TYPES, Timeline.MARCHING)[0].data.hook
			== Timeline.MARCHING_START
		),
		"feedback_projection_isolated_from_event_log"
	)
	_check(
		log.selected_for_player(0, 3, Feedback.TYPES, Timeline.MARCHING).is_empty(),
		"feedback_cursor_excludes_prior_rounds"
	)
