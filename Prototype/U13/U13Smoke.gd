extends Control

const Session = preload("res://Scripts/Sim/U13SmokeSession.gd")
const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")
const Board = preload("res://Prototype/U13/U13SmokeBoard.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const BACKGROUND: Color = Color("0c1119")
const TEXT: Color = Color("e6e9ee")
const MUTED: Color = Color("a3adbb")
const ACCENT: Color = Color("72cddd")
var session = Session.new()
var _playback = Playback.new()
var _checkpoint: Dictionary = {}
var _playing: bool = false
var _paused: bool = false
var _clock: float = 0.0
var _speed: float = 1.0
var _runtime_ok: bool = true
var _scenario: OptionButton
var _lane: OptionButton
var _phase: Label
var _status: Label
var _plan: Label
var _powers: Label
var _stats: Label
var _roster: RichTextLabel
var _log: RichTextLabel
var _board
var _step: Button
var _run: Button
var _next: Button
var _save: Button
var _restore: Button
var _pause: Button
var _replay: Button
var _skip: Button
var _slider: HSlider
var _caption: Label


func _ready() -> void:
	# Only this explicitly launched scene changes its own window. The project
	# main scene and U12 controller remain untouched.
	if DisplayServer.get_name() != "headless":
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = Vector2i(1440, 960)
		get_window().min_size = Vector2i(1200, 800)
	get_window().content_scale_size = Vector2i(1440, 960)
	_build_ui()
	var version: Dictionary = Engine.get_version_info()
	_runtime_ok = (
		version.major == 4
		and version.minor == 7
		and version.patch == 2
		and version.status == "stable"
	)
	if not _runtime_ok:
		_status.text = "Open this scene with Godot 4.7.2."
		_status.modulate = Color("ef9786")
		_update_controls()
		return
	start_scenario(0)


func start_scenario(index: int) -> void:
	if not _runtime_ok:
		return
	_playing = false
	_paused = false
	_clock = 0.0
	_playback = Playback.new()
	_checkpoint = {}
	_scenario.select(index)
	_lane.select(1)
	if _failed(session.reset(index)):
		return
	_slider.max_value = 1.0
	_slider.set_value_no_signal(0.0)
	_caption.text = "Ready. Run to Marching for the quickest tour."
	_render(session.view())


func advance_phase() -> void:
	if _playing or not _runtime_ok:
		return
	var hook: String = session.next_hook()
	var result: Dictionary = session.step()
	if _failed(result):
		return
	if hook == Timeline.MARCHING:
		_start_playback(result.before_marching)
	else:
		_render(session.view())


func run_marching() -> void:
	if _playing or not _runtime_ok:
		return
	var result: Dictionary = session.run_to_marching()
	if not _failed(result):
		_start_playback(result.before_marching)


func finish_playback() -> void:
	_playing = false
	_paused = false
	_clock = _playback.duration
	_caption.text = "Marching complete. Inspect the results, then advance to Aftermath."
	_render(session.view())
	_slider.set_value_no_signal(_clock)


func _process(delta: float) -> void:
	if not _playing or _paused:
		return
	_clock = minf(_playback.duration, _clock + maxf(0.0, delta) * _speed)
	_draw_playback()
	if _clock >= _playback.duration:
		finish_playback()


func _start_playback(before_view: Dictionary) -> void:
	if not _playback.build(session.marching_events()):
		_failed({"action": "invalid", "reason": "Marching replay is missing"})
		return
	_clock = 0.0
	_playing = true
	_paused = false
	_render(before_view)
	_slider.max_value = maxf(0.001, _playback.duration)
	_draw_playback()


func _draw_playback() -> void:
	var frame: Dictionary = _playback.sample(_clock)
	_board.show_frame(frame, _playback.round_number)
	_caption.text = (
		"Replay round %d: %s  |  %.1f / %.1f s"
		% [_playback.round_number, frame.caption, _clock, _playback.duration]
	)
	_slider.set_value_no_signal(_clock)
	_roster.text = _unit_text(frame.units)


func _on_pause() -> void:
	_paused = not _paused
	_update_controls()


func _on_scrub(value: float) -> void:
	if _playback.duration <= 0:
		return
	_playing = true
	_paused = true
	_clock = value
	_draw_playback()
	_update_controls()


func _on_replay() -> void:
	if _playback.duration <= 0:
		return
	_playing = true
	_paused = false
	_clock = 0.0
	_update_controls()
	_draw_playback()


func _on_next_round() -> void:
	if not _failed(session.next_round()):
		_render(session.view())


func _on_save() -> void:
	_checkpoint = session.checkpoint()
	_status.text = "Checkpoint saved in memory. Restore it to repeat the same outcome."
	_update_controls()


func _on_restore() -> void:
	if _checkpoint.is_empty():
		return
	_playing = false
	_paused = false
	if not _failed(session.restore_checkpoint(_checkpoint)):
		_playback = Playback.new()
		_playback.build(session.marching_events())
		_clock = _playback.duration
		_slider.max_value = maxf(0.001, _playback.duration)
		_slider.set_value_no_signal(_clock)
		_lane.select(0 if session.lane() == "Lord" else 1)
		_caption.text = "Checkpoint restored."
		_render(session.view())


func _on_lane(index: int) -> void:
	if not _failed(session.set_lane("Lord" if index == 0 else "Castle")):
		_render(session.view())


func _on_speed(index: int) -> void:
	var speeds: Array = [0.5, 1.0, 2.0]
	_speed = float(speeds[index])


func _failed(result: Dictionary) -> bool:
	if result.get("action") != "invalid":
		return false
	_status.text = "Stopped: " + String(result.get("reason", "Unknown error"))
	_status.modulate = Color("ef9786")
	push_error("U13 SMOKE: " + _status.text)
	_update_controls()
	return true


func _render(view: Dictionary) -> void:
	var current: String = session.next_hook()
	_phase.text = "ROUND %d  /  NEXT: %s" % [session.round_number(), _phase_name(current)]
	var world: Dictionary = view.world
	_stats.text = (
		(
			"YOUR SOULS  %d     OPPONENT SOULS  %d     NEUTRAL TEARS  %d\n"
			+ "%s     |     %s\nHand: %s     Opponent hand: %d     Deck: %d"
		)
		% [
			world.souls[0],
			world.souls[1],
			world.neutral_tears,
			_castle_text(world.entities, 0),
			_castle_text(world.entities, 1),
			_hand_text(world),
			world.opponent_hand_count,
			world.deck_count
		]
	)
	_plan.text = _plan_text()
	_powers.text = _power_text(view)
	_log.text = _event_text(view.events)
	if not _playing:
		_board.show_world(world.entities, session.round_number())
		var units: Array = []
		for entity in world.entities:
			if entity.kind == "marcher":
				units.append(entity)
		_roster.text = _unit_text(units)
	_status.modulate = MUTED
	if current == Timeline.SUBMISSION_LOCK:
		var checked: Dictionary = session.preview()
		_status.text = (
			"Plan is legal. Lock it with Next phase, or Run to Marching."
			if checked.action == "legal"
			else "Plan unavailable: " + String(checked.get("reason", "unknown"))
		)
	elif current.is_empty():
		_status.text = "Round complete. Next round refreshes the scenario plan."
	elif _playing:
		_status.text = "Showing the resolved battle. Pause or scrub to inspect each exchange."
	else:
		_status.text = "Next phase advances one step. Plans stay locked for this round."
	_update_controls()


func _update_controls() -> void:
	var hook: String = session.next_hook()
	var available: bool = _runtime_ok and session.round_number() > 0
	_step.disabled = not available or _playing or hook.is_empty()
	_step.text = "Lock plans" if hook == Timeline.SUBMISSION_LOCK else "Next phase"
	_run.disabled = (
		not available
		or _playing
		or hook.is_empty()
		or Timeline.hook_rank(hook) > Timeline.hook_rank(Timeline.MARCHING)
	)
	_next.disabled = not available or _playing or not hook.is_empty()
	_save.disabled = not available or _playing
	_restore.disabled = not available or _playing or _checkpoint.is_empty()
	_lane.disabled = not available or _playing or hook != Timeline.SUBMISSION_LOCK
	_pause.disabled = not _playing
	_pause.text = "Resume" if _paused else "Pause"
	_skip.disabled = not _playing
	_replay.disabled = _playing or _playback.duration <= 0
	_slider.editable = _playback.duration > 0


func _plan_text() -> String:
	var description: String = ""
	match session.scenario():
		0:
			description = (
				"PREDATOR CLASH\nBoth Gremories summon three Vultures into the selected lane "
				+ "on odd rounds. Even rounds let the cooldown finish. Watch simultaneous "
				+ "kills trigger Picking the Bones."
			)
		1:
			description = (
				"SIEGE & SPOILS\nRound 1: you commit two Butcher 3s to Siege. "
				+ "The attack meets two Guards and a damaged Castle. Both players also "
				+ "summon Predators. Watch Gem Dagger, Sifting and Bones. "
				+ "Later rounds repeat the Predator cycle."
			)
		2:
			description = (
				"PREPARED RUIN\nRound 1: discard your first two cards to mark the enemy "
				+ "Castle, and summon three Vultures. Finish the round, then choose "
				+ "Next round: Ruin sets that Castle Defunct before new plans. Later plans pass."
			)
	return (
		description
		+ "\n\nThese are preset plans for inspection, not a full opponent AI. Predator lane: "
		+ session.lane()
		+ "."
	)


static func _phase_name(hook: String) -> String:
	if hook.is_empty():
		return "ROUND COMPLETE"
	if hook == Timeline.SUBMISSION_LOCK:
		return "CHOOSE / LOCK PLANS"
	return "%d. %s" % [Timeline.top_level_step_number(hook), hook.replace("_", " ").capitalize()]


static func _castle_text(entities: Array, player_id: int) -> String:
	var prefix: String = "Your Castle" if player_id == 0 else "Enemy Castle"
	var guards: int = 0
	var castle: Dictionary = {}
	for entity in entities:
		if entity.owner != player_id:
			continue
		if entity.kind == "castle":
			castle = entity
		elif entity.kind == "card" and entity.attributes.get("role") == "guard":
			guards += 1
	if castle.is_empty():
		return prefix + ": destroyed | Guards %d" % guards
	return (
		"%s: %s %d/%d | Guards %d"
		% [
			prefix,
			castle.attributes.status,
			castle.attributes.integrity,
			castle.attributes.max_integrity,
			guards
		]
	)


static func _hand_text(world: Dictionary) -> String:
	var names: Array[String] = []
	for card_id in world.hand:
		for entity in world.entities:
			if entity.id == card_id:
				names.append(
					String(entity.attributes.suit).substr(0, 1) + str(entity.attributes.value)
				)
	return " ".join(names) if not names.is_empty() else "empty"


static func _power_name(power_id: String) -> String:
	return "Predator of Ruin" if power_id == Gremory.PREDATOR else "Inevitable Ruin"


static func _power_text(view: Dictionary) -> String:
	var lines: Array[String] = ["POWER STATUS"]
	for row in view.cooldowns:
		if row.get("declaration", {}).get("player_id") != 0:
			continue
		lines.append(
			(
				"%s: ready round %s"
				% [_power_name(row.declaration.power_id), str(row.get("ready_round", "?"))]
			)
		)
	for row in view.pending:
		if row.get("declaration", {}).get("player_id") == 0:
			lines.append(
				"%s fires round %d" % [_power_name(row.declaration.power_id), row.fire_round]
			)
	if lines.size() == 1:
		lines.append("No armed powers or active cooldowns.")
	return "\n".join(lines)


static func _unit_text(units: Array) -> String:
	var lines: Array[String] = ["MARCHERS  |  HP / ARMOR / POSITION"]
	for unit in units:
		var a: Dictionary = unit.attributes
		lines.append(
			(
				"%s  %s  %s   HP %d/%d   Armor %d   x %d%s"
				% [
					"You" if unit.owner == 0 else "Enemy",
					a.suit,
					a.lane,
					a.hp,
					a.max_hp,
					a.armor,
					int(a.get("visual_x", a.x_fp)),
					"  WAITING" if a.waiting else ""
				]
			)
		)
	if units.is_empty():
		lines.append("The field is empty.")
	return "\n".join(lines)


static func _event_text(events: Array) -> String:
	var lines: Array[String] = []
	for event in events:
		var d: Dictionary = event.data
		match event.type:
			"MARCHER_CLASH":
				lines.append("Clash: %s lane, %d exchanges" % [d.lane, d.exchanges.size()])
			"MARCHER_DEFEATED":
				lines.append(
					(
						"%s %s defeated"
						% ["Your" if d.victim.owner == 0 else "Enemy", d.victim.attributes.suit]
					)
				)
			"MARCHER_SPAWNED":
				lines.append(
					(
						"%s %s entered %s lane"
						% [
							"Your" if d.owner == 0 else "Enemy",
							d.attributes.suit,
							d.attributes.lane
						]
					)
				)
			"GUARD_DEFEATED":
				lines.append(
					"Guard defeated: %s %d" % [d.guard.attributes.suit, d.guard.attributes.value]
				)
			"CASTLE_DESTROYED":
				lines.append("Castle destroyed: Sifting can trigger")
			"CASTLE_DEFUNCT":
				lines.append("Inevitable Ruin: marked Castle is now Defunct")
			"GEM_DAGGER", "SIFTING_THE_RUINS", "PICKING_THE_BONES":
				lines.append(
					(
						"%s / %s: %s"
						% [
							event.type.replace("_", " ").capitalize(),
							"you" if d.player_id == 0 else "opponent",
							"card gained" if d.drawn else "no card drawn"
						]
					)
				)
			"NEUTRAL_TEAR_CREATED":
				lines.append("+%d Neutral Tear / %s" % [d.amount, d.source])
			"SIEGE_RESOLVED":
				lines.append(
					(
						"Siege: strength %d, %d Guard defeats, %d Castle damage"
						% [d.strength, d.guards_defeated, d.damage]
					)
				)
			"MARCHER_WAITING":
				lines.append("Marcher arrived: waiting support available")
			"FIZZLE_INVALID_TARGET":
				lines.append("Prepared power fizzled: its target is gone")
	if lines.is_empty():
		return "EVENTS\nResolved combat and reward events appear here."
	return "EVENTS  /  newest first\n" + "\n".join(_reversed_tail(lines, 60))


static func _reversed_tail(lines: Array[String], count: int) -> Array[String]:
	var result: Array[String] = []
	for index in range(lines.size() - 1, maxi(-1, lines.size() - count - 1), -1):
		result.append(lines[index])
	return result


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop = ColorRect.new()
	backdrop.color = BACKGROUND
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margins = MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + edge, 16)
	add_child(margins)
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margins.add_child(root)
	var theme_value = Theme.new()
	theme_value.default_font_size = 17
	root.theme = theme_value
	var heading = HBoxContainer.new()
	heading.add_theme_constant_override("separation", 24)
	heading.add_child(_label("CORRUPTOR  /  U13", 27, TEXT))
	heading.add_child(_label("Gremory smoke scene  /  inspect the combat slice", 15, MUTED))
	root.add_child(heading)
	var toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 9)
	root.add_child(toolbar)
	_scenario = OptionButton.new()
	for item in Session.SCENARIOS:
		_scenario.add_item(item)
	_scenario.custom_minimum_size.x = 210
	_scenario.item_selected.connect(Callable(self, "start_scenario"))
	toolbar.add_child(_scenario)
	_button(toolbar, "Restart", Callable(self, "_on_restart"))
	_step = _button(toolbar, "Lock plans", Callable(self, "advance_phase"))
	_run = _button(toolbar, "Run to Marching", Callable(self, "run_marching"))
	_next = _button(toolbar, "Next round", Callable(self, "_on_next_round"))
	_save = _button(toolbar, "Save checkpoint", Callable(self, "_on_save"))
	_restore = _button(toolbar, "Restore", Callable(self, "_on_restore"))
	_phase = _label("", 19, ACCENT)
	root.add_child(_phase)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)
	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 3.0
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	_stats = _label("", 15, TEXT)
	left.add_child(_stats)
	_board = Board.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_board)
	var playback_bar = HBoxContainer.new()
	left.add_child(playback_bar)
	_pause = _button(playback_bar, "Pause", Callable(self, "_on_pause"))
	_skip = _button(playback_bar, "Show result", Callable(self, "finish_playback"))
	_replay = _button(playback_bar, "Replay battle", Callable(self, "_on_replay"))
	var speed = OptionButton.new()
	for item in ["0.5x", "1x", "2x"]:
		speed.add_item(item)
	speed.select(1)
	speed.item_selected.connect(Callable(self, "_on_speed"))
	playback_bar.add_child(speed)
	_slider = HSlider.new()
	_slider.step = 0.01
	_slider.value_changed.connect(Callable(self, "_on_scrub"))
	left.add_child(_slider)
	_caption = _label("", 15, MUTED)
	left.add_child(_caption)
	_roster = _rich(70)
	left.add_child(_roster)
	var right = VBoxContainer.new()
	right.custom_minimum_size.x = 355
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	right.add_theme_constant_override("separation", 14)
	body.add_child(right)
	_plan = _label("", 17, TEXT)
	_plan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_plan)
	_lane = OptionButton.new()
	_lane.add_item("Predator lane: Lord")
	_lane.add_item("Predator lane: Castle")
	_lane.select(1)
	_lane.item_selected.connect(Callable(self, "_on_lane"))
	right.add_child(_lane)
	_powers = _label("", 16, ACCENT)
	_powers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_powers)
	_log = _rich(180)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_log)
	_status = _label("", 15, MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)
	var scope_text: String = (
		"Scope: Gremory, Siege/Ward, Guards, Sigils, plain Castle Integrity and Marching. "
		+ "Full match rules and victory are not wired here."
	)
	var scope_label = _label(scope_text, 13, MUTED)
	scope_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(scope_label)


func _on_restart() -> void:
	start_scenario(_scenario.selected)


static func _label(value: String, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func _button(parent: Node, text_value: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 36
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


static func _rich(height: float) -> RichTextLabel:
	var rich = RichTextLabel.new()
	rich.custom_minimum_size.y = height
	rich.bbcode_enabled = false
	rich.add_theme_color_override("default_color", TEXT)
	rich.add_theme_font_size_override("normal_font_size", 15)
	return rich
