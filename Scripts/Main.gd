extends Control


@onready var root_margin: MarginContainer = $RootMargin_MarginContainer
@onready var main_layout: VBoxContainer = $RootMargin_MarginContainer/MainLayout_VBoxContainer

@onready var opponent_area: Control = $RootMargin_MarginContainer/MainLayout_VBoxContainer/OpponentArea_Control
@onready var center_area: Control = $RootMargin_MarginContainer/MainLayout_VBoxContainer/CenterArea_Control
@onready var player_area: Control = $RootMargin_MarginContainer/MainLayout_VBoxContainer/PlayerArea_Control
@onready var action_bar: HBoxContainer = $RootMargin_MarginContainer/MainLayout_VBoxContainer/ActionBar_HBoxContainer

@onready var new_game_button: Button = %NewGame_Button
@onready var deal_test_button: Button = %DealTest_Button
@onready var next_phase_button: Button = %NextPhase_Button
@onready var status_label: Label = %Status_Label
@onready var event_log: RichTextLabel = %EventLog_RichTextLabel

@onready var veil_title_label: Label = %VeilTitle_Label
@onready var veil_value_label: Label = %VeilValue_Label

@onready var breach_slot_label: Label = %BreachSlot_Label
@onready var active_breach_count_label: Label = %ActiveBreachCount_Label

@onready var phase_panel_label: Label = %PhasePanel_Label

@onready var market_title_label: Label = %MarketTitle_Label
@onready var market_draw_label: Label = %MarketDraw_Label


var run_state: CampaignRunState = null
var rule_config: RuleConfig = null

var layout_debug_enabled: bool = false

var event_log_entries: Array[String] = []
var event_log_render_pending: bool = false


func _ready() -> void:
	print("Corruptor UI root loaded.")

	rule_config = RuleConfig.de_v2()

	_force_layout_to_viewport()
	_force_container_size_flags()

	get_viewport().size_changed.connect(
		_on_viewport_size_changed
	)

	event_log.add_theme_font_size_override(
		"normal_font_size",
		18
	)

	event_log.add_theme_font_size_override(
		"bold_font_size",
		18
	)

	event_log.add_theme_font_size_override(
		"italics_font_size",
		18
	)

	event_log.add_theme_font_size_override(
		"bold_italics_font_size",
		18
	)

	new_game_button.text = "New Claim"
	deal_test_button.text = "Advance Contest"
	next_phase_button.text = "Claim Tribute"

	# Automatic line following was producing stale wrapped-line indexes.
	# The log is rendered and scrolled manually instead.
	event_log.scroll_following = false
	event_log.clear()

	event_log_entries.clear()

	new_game_button.pressed.connect(
		_on_new_run_pressed
	)

	deal_test_button.pressed.connect(
		_on_advance_match_pressed
	)

	next_phase_button.pressed.connect(
		_on_next_boss_pressed
	)

	_set_status(
		"No claim recorded."
	)

	_render_event({
		"type": "INFO",
		"text": "The record is empty.",
		"data": {}
	})

	_update_center_hud()

	_log(
		"[color=gray]Golden tests ready. Press F2 to run.[/color]"
	)


func _on_viewport_size_changed() -> void:
	_force_layout_to_viewport()
	_force_container_size_flags()

	if layout_debug_enabled:
		_show_layout_debug()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event: InputEventKey = event

	if (
		key_event.pressed
		and not key_event.echo
		and key_event.keycode == KEY_F1
	):
		layout_debug_enabled = not layout_debug_enabled

		if layout_debug_enabled:
			_show_layout_debug()
		else:
			_update_status()

	if (
		key_event.pressed
		and not key_event.echo
		and key_event.keycode == KEY_F2
	):
		_log("")
		_log("[b]RUNNING GOLDEN TESTS[/b]")

		print("")
		print("RUNNING GOLDEN TESTS")

		_run_golden_startup_checks()


func _force_layout_to_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	set_position(Vector2.ZERO)
	set_size(viewport_size)

	root_margin.set_position(Vector2.ZERO)
	root_margin.set_size(viewport_size)

	main_layout.set_position(Vector2.ZERO)
	main_layout.set_size(viewport_size)


func _force_container_size_flags() -> void:
	opponent_area.custom_minimum_size = Vector2(0, 360)
	center_area.custom_minimum_size = Vector2(0, 180)
	player_area.custom_minimum_size = Vector2(0, 380)
	action_bar.custom_minimum_size = Vector2(0, 64)

	opponent_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_area.size_flags_vertical = Control.SIZE_FILL
	player_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_bar.size_flags_vertical = Control.SIZE_FILL

	opponent_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _show_layout_debug() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var window_size: Vector2i = DisplayServer.window_get_size()

	var root_pos: Vector2 = position
	var root_size: Vector2 = size

	var root_margin_pos := Vector2.ZERO
	var root_margin_size := Vector2.ZERO

	if root_margin != null:
		root_margin_pos = root_margin.position
		root_margin_size = root_margin.size

	var main_layout_pos := Vector2.ZERO
	var main_layout_size := Vector2.ZERO

	if main_layout != null:
		main_layout_pos = main_layout.position
		main_layout_size = main_layout.size

	var opponent_size := Vector2.ZERO
	var center_size := Vector2.ZERO
	var player_size := Vector2.ZERO
	var action_size := Vector2.ZERO

	if opponent_area != null:
		opponent_size = opponent_area.size

	if center_area != null:
		center_size = center_area.size

	if player_area != null:
		player_size = player_area.size

	if action_bar != null:
		action_size = action_bar.size

	var debug_text: String = (
		"Viewport %s | Window %s | Root %s pos %s | "
		+ "Margin %s pos %s | VBox %s pos %s | "
		+ "Opp %s | Center %s | Player %s | Bar %s"
	) % [
		_vec2_text(viewport_size),
		str(window_size),
		_vec2_text(root_size),
		_vec2_text(root_pos),
		_vec2_text(root_margin_size),
		_vec2_text(root_margin_pos),
		_vec2_text(main_layout_size),
		_vec2_text(main_layout_pos),
		_vec2_text(opponent_size),
		_vec2_text(center_size),
		_vec2_text(player_size),
		_vec2_text(action_size)
	]

	print(debug_text)

	_log(
		"[color=gray]%s[/color]"
		% debug_text
	)

	_set_status(
		"Layout debug written to log/output."
	)


func _vec2_text(value: Vector2) -> String:
	return "%dx%d" % [
		int(value.x),
		int(value.y)
	]


func _run_golden_startup_checks() -> void:
	var messages: Array = GoldenTests.run_startup_checks(
		rule_config
	)

	var passed_count: int = 0
	var failed_count: int = 0

	for message in messages:
		var text: String = String(
			message.get(
				"text",
				""
			)
		)

		var passed: bool = bool(
			message.get(
				"passed",
				false
			)
		)

		if passed:
			passed_count += 1

			_log(
				"[color=green]%s[/color]"
				% text
			)

			print(text)
		else:
			failed_count += 1

			_log(
				"[color=red]%s[/color]"
				% text
			)

			push_error(text)

	var summary: String = (
		"Golden checks complete: %d passed, %d failed."
		% [
			passed_count,
			failed_count
		]
	)

	if failed_count == 0:
		_log(
			"[color=green][b]%s[/b][/color]"
			% summary
		)
	else:
		_log(
			"[color=red][b]%s[/b][/color]"
			% summary
		)

	print(summary)


func _update_center_hud() -> void:
	if run_state == null:
		veil_title_label.text = "DOMINION"
		veil_value_label.text = "Veil 0/15"

		breach_slot_label.text = "No Lord in breach."

		active_breach_count_label.text = (
			"Active Breach Count: 0"
		)

		active_breach_count_label.tooltip_text = (
			"No breach effects are active."
		)

		phase_panel_label.text = "No contest"

		market_title_label.text = "Market"
		market_draw_label.text = "No market drawn."

		return

	var current_match = run_state.current_match

	if current_match == null:
		veil_title_label.text = "DOMINION"
		veil_value_label.text = "Veil --/--"
		phase_panel_label.text = "No contest"
	else:
		veil_title_label.text = "DOMINION"

		veil_value_label.text = (
			"Veil %d/%d"
			% [
				current_match.get_veil(),
				current_match.rules.final_collapse_threshold
			]
		)

		phase_panel_label.text = (
			current_match.get_phase_name()
		)

	breach_slot_label.text = "No Lord in breach."

	_update_active_breach_count_hud()

	market_title_label.text = "Market"
	market_draw_label.text = "No market drawn."


func _update_active_breach_count_hud() -> void:
	if run_state == null:
		active_breach_count_label.text = (
			"Active Breach Count: 0"
		)

		active_breach_count_label.tooltip_text = (
			"No breach effects are active."
		)

		return

	var breach_count: int = (
		run_state.active_campaign_modifiers.size()
	)

	active_breach_count_label.text = (
		"Active Breach Count: %d"
		% breach_count
	)

	active_breach_count_label.tooltip_text = (
		_get_active_breach_tooltip()
	)


func _get_active_breach_tooltip() -> String:
	if run_state == null:
		return "No breach effects are active."

	if run_state.active_campaign_modifiers.is_empty():
		return "No breach effects are active."

	var lines: Array[String] = [
		"Active breach effects:"
	]

	for breach_id in run_state.active_campaign_modifiers:
		lines.append(
			"- %s"
			% _get_breach_name_raw(
				String(breach_id)
			)
		)

	return "\n".join(lines)


func _get_active_breach_names() -> String:
	if run_state == null:
		return "No breach effects."

	var names: Array[String] = []

	for breach_id in run_state.active_campaign_modifiers:
		names.append(
			_get_breach_name_raw(
				String(breach_id)
			)
		)

	if names.is_empty():
		return "No breach effects."

	return "\n".join(names)


func _get_breach_name_raw(
	breach_id: String
) -> String:
	if run_state == null:
		return breach_id

	for boss in run_state.bosses:
		if boss.breach_id == breach_id:
			return boss.breach_name

	return breach_id


func _get_breach_text(
	breach_id: String
) -> String:
	if run_state == null:
		return "No breach effects."

	for boss in run_state.bosses:
		if boss.breach_id == breach_id:
			return "%s: %s" % [
				boss.breach_name,
				boss.breach_text
			]

	return "No breach effects."


func _on_new_run_pressed() -> void:
	run_state = CampaignRunState.new()

	run_state.setup(
		rule_config
	)

	var boss = run_state.get_current_boss()
	var current_match = run_state.current_match

	_log("")
	_log("[b]NEW CLAIM[/b]")

	_render_event({
		"type": "RUN_STARTED",
		"text": "A Lord extends its reach.",
		"data": {}
	})

	if boss != null:
		_render_event({
			"type": "CURRENT_BOSS",
			"text": "Patron: %s." % boss.display_name,
			"data": {}
		})

		_render_event({
			"type": "BOSS_INTENT",
			"text": boss.intent_text,
			"data": {}
		})

	if current_match != null:
		_render_event({
			"type": "MATCH_SUMMARY",
			"text": current_match.get_match_summary(),
			"data": {}
		})

	_update_status()


func _on_advance_match_pressed() -> void:
	if run_state == null:
		_render_event({
			"type": "ERROR",
			"text": "No claim has been made.",
			"data": {}
		})

		_set_status(
			"No claim recorded."
		)

		return

	if run_state.run_over:
		_render_event({
			"type": "INFO",
			"text": "This claim has ended.",
			"data": {}
		})

		_update_status()
		return

	var current_match = run_state.current_match

	if current_match == null:
		_render_event({
			"type": "ERROR",
			"text": "No contest is recorded.",
			"data": {}
		})

		_update_status()
		return

	if current_match.match_over:
		_render_event({
			"type": "INFO",
			"text": (
				"The contest is settled. "
				+ "Claim what remains."
			),
			"data": {}
		})

		_update_status()
		return

	var events: Array = (
		current_match.advance_fake_phase()
	)

	_render_events(events)

	if (
		current_match.match_over
		and not current_match.player_won
	):
		_render_events(
			run_state.collapse_run(
				"The patron's claim failed."
			)
		)

	if (
		current_match.match_over
		and current_match.player_won
	):
		_render_event({
			"type": "INFO",
			"text": (
				"The rival is diminished. "
				+ "Claim the tribute."
			),
			"data": {}
		})

	_update_status()


func _on_next_boss_pressed() -> void:
	if run_state == null:
		_render_event({
			"type": "ERROR",
			"text": "No claim has been made.",
			"data": {}
		})

		_set_status(
			"No claim recorded."
		)

		return

	if run_state.run_over:
		_render_event({
			"type": "INFO",
			"text": "This claim has ended.",
			"data": {}
		})

		_update_status()
		return

	var events: Array = (
		run_state.advance_to_next_boss()
	)

	_render_events(events)

	if run_state.run_over:
		if run_state.victory:
			_log(
				"[color=green][b]DOMINION RECORDED[/b][/color]"
			)

			_log(
				"Tribute gathered: [b]%d[/b] Souls."
				% run_state.souls_banked_this_run
			)

			_log(
				"Lords diminished: %s"
				% ", ".join(
					run_state.defeated_bosses
				)
			)
		else:
			_log(
				"[color=red][b]CLAIM FAILED[/b][/color]"
			)

			_log(
				"Cause: %s"
				% run_state.collapse_reason
			)
	else:
		var current_match = run_state.current_match

		_log(
			"[b]THE CLAIM PASSES ON[/b]"
		)

		_log(
			"Breaches carried forward: %s"
			% run_state.get_modifier_summary()
		)

		if current_match != null:
			_log(
				current_match.get_match_summary()
			)

	_update_status()


func _update_status() -> void:
	if layout_debug_enabled:
		_show_layout_debug()
		return

	_update_center_hud()

	if run_state == null:
		_set_status(
			"No claim recorded."
		)

		return

	_set_status(
		run_state.get_run_summary()
	)


func _set_status(
	text: String
) -> void:
	status_label.text = text


func _render_events(
	events: Array
) -> void:
	for event in events:
		_render_event(
			event
		)


func _render_event(
	event: Dictionary
) -> void:
	var event_type: String = String(
		event.get(
			"type",
			"INFO"
		)
	)

	var text: String = String(
		event.get(
			"text",
			""
		)
	)

	match event_type:
		"ERROR":
			_log(
				"[color=red]%s[/color]"
				% text
			)

		"INFO":
			_log(
				"[color=gray]%s[/color]"
				% text
			)

		"PHASE":
			_log("")
			_log(
				"[b]%s[/b]"
				% text
			)

		"MATCH_WON":
			_log(
				"[color=green]%s[/color]"
				% text
			)

		"MATCH_LOST":
			_log(
				"[color=red]%s[/color]"
				% text
			)

		"RUN_COMPLETE":
			_log(
				"[color=green][b]%s[/b][/color]"
				% text
			)

		"RUN_COLLAPSED":
			_log(
				"[color=red][b]%s[/b][/color]"
				% text
			)

		"CAMPAIGN_MODIFIER_GAINED":
			_log(
				"[color=purple]%s[/color]"
				% text
			)

		"CATACLYSM":
			_log(
				"[color=orange]%s[/color]"
				% text
			)

		"FINAL_COLLAPSE":
			_log(
				"[color=red]%s[/color]"
				% text
			)

		_:
			_log(text)


func _log(
	text: String
) -> void:
	event_log_entries.append(text)
	_queue_event_log_render()


func _queue_event_log_render() -> void:
	if event_log_render_pending:
		return

	event_log_render_pending = true

	call_deferred(
		"_flush_event_log"
	)


func _flush_event_log() -> void:
	event_log_render_pending = false

	if event_log == null:
		return

	# Replace the label's content once per frame instead of repeatedly
	# appending and triggering wrapped-line auto-scroll recalculations.
	event_log.text = "\n".join(
		event_log_entries
	)

	await get_tree().process_frame

	if event_log == null:
		return

	var scroll_bar: VScrollBar = (
		event_log.get_v_scroll_bar()
	)

	if scroll_bar == null:
		return

	scroll_bar.value = scroll_bar.max_value
