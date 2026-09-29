extends Control
signal closed
const Model = preload("res://Prototype/U13/Encounters/U13EncounterModel.gd")
const Field = preload("res://Prototype/U13/Encounters/U13EncounterField.gd")
const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")
var model
var field
var playback = Playback.new()
var worker: Thread
var result: Dictionary = {}
var elapsed: float = 0.0
# A fresh presentation identity each round; objective time also runs on empty fields.
class MarchClock extends RefCounted:
	var duration: float
	func _init(seconds: float) -> void: duration = seconds
	func has_marching_activity() -> bool: return true
var march_clock: MarchClock
var march_intro := true
var objective_tape: Array = []
var objective_cursor: int = 0
var shown_objective: Dictionary = {}
var selected: String = ""
var selected_index: int = -1
var paused: bool = false
var embedded: bool = false
var scenario: OptionButton
var power: OptionButton
var leader: OptionButton
var withdraw_button: Button
var withdraw_dialog: ConfirmationDialog
const SPEEDS: Array = [1.0, 3.0, 6.0, 9.0]
var threat: OptionButton
var speed: OptionButton
var seed_entry: LineEdit
var status: Label
var score: Label
var forecast: Label
var reserve_note: Label
var hand_row: HBoxContainer
var reserve_row: HBoxContainer
var flip: Button
var undo_button: Button
var pause_button: Button
var reset_button: Button
var objective_label: Label
var previous_scale: Vector2i
var previous_scale_mode: int
var previous_scale_aspect: int

func _ready() -> void:
	previous_scale = get_window().content_scale_size
	previous_scale_mode = get_window().content_scale_mode
	previous_scale_aspect = get_window().content_scale_aspect
	get_window().content_scale_size = Vector2i(1440, 810)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 120
	var bg := ColorRect.new()
	bg.color = Color("0e1416")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var theme_style := Theme.new()
	theme_style.default_font_size = 16
	theme = theme_style
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := label(top, "THE CROSSING", 29)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(top, "ASCENT ENCOUNTER  /  PLAYTEST", 14)
	button(top, "DEV MENU" if embedded else "CLOSE", dismiss)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	column.add_child(controls)
	scenario = option(controls, ["Break the Gate", "Recover the Lamp"])
	power = option(controls, ["+1 power / round", "+2 power / round", "+3 power / round"])
	power.select(1)
	leader = option(controls, ["Penitent retinue", "Vulture retinue", "Wright retinue", "Butcher retinue", "No retinue"])
	leader.tooltip_text = "Local test leader: +2 recruits of this type, regardless of rank. No campaign writes."
	threat = option(controls, ["Light opposition", "Standard opposition", "Heavy opposition"])
	threat.select(1)
	threat.tooltip_text = "Each objective has its own finite opposition. Light gives more room to recover; Standard and Heavy demand stronger counters. Gate Light uses finite patrols; other tiers use pushes on rounds 6, 9 and 12. Enemy schedules are fixed before play."
	seed_entry = LineEdit.new()
	seed_entry.text = "crossing-1"
	seed_entry.placeholder_text = "Encounter seed"
	seed_entry.custom_minimum_size.x = 150
	seed_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(seed_entry)
	reset_button = button(controls, "RESTART / APPLY", restart)
	speed = option(controls, ["1× inspect", "3× normal", "6× fast", "9× fastest"])
	speed.select(1)
	var briefing := HBoxContainer.new()
	column.add_child(briefing)
	var brief_text := VBoxContainer.new()
	brief_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brief_text.add_theme_constant_override("separation", 8)
	briefing.add_child(brief_text)
	var clock_slot := MarginContainer.new()
	clock_slot.custom_minimum_size.x = 108
	briefing.add_child(clock_slot)
	objective_label = label(brief_text, "", 16)
	score = label(brief_text, "", 23)
	forecast = label(brief_text, "", 14)
	forecast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	field = Field.new()
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(field)
	field.placement.connect(_place)
	field.hourglass.reparent(clock_slot)
	field.hourglass.scale = Vector2.ONE
	status = label(column, "", 16)
	status.custom_minimum_size.y = 34
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var hand_title := label(actions, "EXPEDITION RESERVE · 4 deployments/round · construction takes 7.2s", 15)
	hand_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	withdraw_button = button(actions, "WITHDRAW", _request_withdraw)
	withdraw_dialog = ConfirmationDialog.new()
	withdraw_dialog.title = "Withdraw from the mission?"
	withdraw_dialog.dialog_text = "No reward. Marring eligible, as for defeat. The run continues.\nThis is a local preview; campaign data will not change."
	withdraw_dialog.confirmed.connect(_withdraw)
	add_child(withdraw_dialog)
	undo_button = button(actions, "UNDO PLACEMENT", _undo)
	pause_button = button(actions, "PAUSE", _pause)
	flip = button(actions, "FLIP HOURGLASS  ▶", _begin)
	flip.custom_minimum_size.x = 205
	hand_row = HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 10)
	column.add_child(hand_row)
	reserve_note = label(column, "MONSTERS · spend regenerating power · share 7 capacity · all unlocked for this test", 15)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 65
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	reserve_row = HBoxContainer.new()
	reserve_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reserve_row.add_theme_constant_override("separation", 7)
	scroll.add_child(reserve_row)
	restart()

func label(parent: Node, value: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color("d3c8ae"))
	parent.add_child(l)
	return l

func button(parent: Node, value: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size.y = 36
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var skin := StyleBoxFlat.new()
		skin.bg_color = Color("202c2e") if state in ["normal", "disabled"] else Color("364747")
		skin.border_color = Color("48666b") if state in ["normal", "disabled"] else Color("d8b978")
		skin.set_border_width_all(1)
		skin.content_margin_left = 10
		skin.content_margin_right = 10
		skin.content_margin_top = 7
		skin.content_margin_bottom = 7
		b.add_theme_stylebox_override(state, skin)
	parent.add_child(b)
	b.pressed.connect(action)
	return b

func option(parent: Node, values: Array) -> OptionButton:
	var o := OptionButton.new()
	for value in values: o.add_item(value)
	parent.add_child(o)
	return o

func restart() -> void:
	if worker != null: return
	field.hourglass.reset()
	field.hourglass.set_progress(0.0, 0.0)
	field.hourglass.caption.text = "DEPLOY"
	march_clock = null
	model = Model.new(seed_entry.text, ["gate", "lamp"][scenario.selected], [1, 2, 3][power.selected], threat.selected, Model.Monsters.NAMES, (Model.SUITS + [""])[leader.selected])
	selected = ""
	selected_index = -1
	paused = false
	elapsed = 0.0
	objective_tape.clear()
	result.clear()
	field.sprites.clear()
	field.previous.clear()
	field.ghosts.clear()
	shown_objective = model.arena.world.data.encounter.duplicate(true)
	withdraw_dialog.hide()
	objective_label.text = "Break through enemy walls and towers, then destroy their 24 HP gate. Win within %d rounds." % model.round_limit() if model.scenario == "gate" else "Clear the lamp, hold for 3 seconds, then carry it HOME. Monsters contest and escort; ordinary marchers carry."
	status.text = "Choose a reinforcement, then click the blue deployment zone."
	_idle()
	_refresh()

func _idle() -> void:
	field.show_state({"units": model.arena.units(), "field_structures": Model.Marching.Fort.rows(model.arena.world), "monster_fields": model.arena.world.data.monsters.fields}, shown_objective, model.arena.round_number, false)

func _refresh() -> void:
	var planning: bool = model.phase == "planning"
	var finished: bool = model.phase == "finished"
	score.text = "ROUND %02d / %d   ·   POWER %d (+%d)   ·   CAPACITY %d/7   ·   DEPLOY %d/4" % [model.arena.round_number, model.round_limit(), model.power, model.income, model.capacity_used(), model.deployments]
	forecast.text = "%s · %s approach   |   THIS ROUND: %s\nNEXT ROUND: %s   |   ENEMY RESERVE: %d bodies" % [model.enemy_plan.to_upper(), ("upper" if model.enemy_line < 300 else ("lower" if model.enemy_line > 300 else "central")), _wave_text(model.forecast()), _wave_text(model.forecast(1)), model.remaining_enemy_bodies()]
	if not model.waiting_enemies.is_empty(): forecast.text += "\nQUEUED FROM EARLIER: " + _wave_text(model.waiting_enemies)
	forecast.text += "\n" + model.reinforcement_text()
	forecast.tooltip_text = _forecast_details()
	withdraw_button.disabled = not planning
	flip.disabled = not planning
	undo_button.disabled = not planning or model.undo_stack.is_empty()
	pause_button.disabled = model.phase != "playback"
	pause_button.text = "RESUME" if paused else "PAUSE"
	reset_button.disabled = worker != null
	field.placing = planning and not selected.is_empty()
	field.selection = selected
	for row in [hand_row, reserve_row]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
	for name in Model.SUITS:
		var b := button(hand_row, ("◆ " if selected == name else "") + name.to_upper() + "\n%d remaining" % model.ordinary[name], _select.bind(name, -1))
		b.custom_minimum_size = Vector2(135, 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not model.unavailable(name).is_empty()
		var stats: Dictionary = Model.Marching.profile(name, "Lord", 0, 0, 1, true)
		b.tooltip_text = "%d HP · %d Armor · %d Attack\n%s\nNo power cost; uses one deployment." % [stats.max_hp, stats.armor, stats.attack, _suit_hint(name)]
	for name in Model.Monsters.NAMES:
		var b := button(reserve_row, ("◆ " if selected == name else "") + name + "\n%d power · %d cap" % [Model.COST[name], Model.WEIGHT[name]], _select.bind(name, -1))
		b.custom_minimum_size = Vector2(118, 62)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var reason: String = model.unavailable(name)
		b.disabled = not reason.is_empty()
		b.tooltip_text = Model.monster_ability(name) + "\n" + reason
	if finished: status.text = shown_objective.message + "\n" + model.aftermath_text()

func _suit_hint(name: String) -> String:
	return {"Penitent": "50% chance to block ranged hits and Vulture melee hits.",
		"Vulture": "Ranged fire; +1 damage against Butchers. Penitents can block it.",
		"Butcher": "3 attack in melee; vulnerable to Vulture fire.",
		"Wright": "Builds, guards and repairs. Construction takes 7.2 seconds at the site (3× normal); Wrights can build in parallel. Repair speed is unchanged."}.get(name, "")

func _wave_text(orders: Array) -> String:
	if orders.is_empty(): return "No new arrivals"
	var counts: Dictionary = {}
	for order in orders:
		counts[order.name] = int(counts.get(order.name, 0)) + int(order.bodies)
	var parts: PackedStringArray = []
	for name in counts: parts.append("%s ×%d" % [name, counts[name]])
	return ", ".join(parts)

func _forecast_details() -> String:
	var parts: PackedStringArray = [model.plan_note]
	var seen: Array = []
	for order in model.waiting_enemies + model.forecast() + model.forecast(1):
		if order.name in seen: continue
		seen.append(order.name)
		if order.name in Model.Monsters.NAMES: parts.append(order.name + ": " + Model.monster_ability(order.name))
		else:
			var stats: Dictionary = Model.Marching.profile(order.name, "Lord", 1, 0, 1, true)
			parts.append("%s: %d HP · %d Armor · %d Attack. %s" % [order.name, stats.max_hp, stats.armor, stats.attack, _suit_hint(order.name)])
	return "\n".join(parts)

func _request_withdraw() -> void:
	if model.phase == "planning": withdraw_dialog.popup_centered()

func _withdraw() -> void:
	if not model.withdraw(): return
	selected = ""
	shown_objective = model.arena.world.data.encounter.duplicate(true)
	_idle()
	_refresh()

func _select(name: String, index: int) -> void:
	selected = name
	selected_index = index
	status.text = "Place %s in the blue zone · %s. You can undo before flipping." % [name, ("one recruit" if name in Model.SUITS else "%d power / %d capacity" % [Model.COST[name], Model.WEIGHT[name]])]
	_refresh()

func _place(point: Vector2) -> void:
	if selected.is_empty(): return
	var placed: Dictionary = model.deploy(selected, point, selected_index)
	if placed.has("error"):
		status.text = placed.error
		return
	status.text = "%s deployed (%d %s). Choose another reinforcement or flip the hourglass." % [selected, placed.count, "bodies" if placed.count > 1 else "body"]
	selected = ""
	selected_index = -1
	_idle()
	_refresh()

func _undo() -> void:
	if model.undo():
		selected = ""
		selected_index = -1
		status.text = "Last placement returned to your reserves."
		_idle()
		_refresh()

func _begin() -> void:
	var request: Dictionary = model.begin()
	if request.has("error"):
		status.text = request.error
		return
	selected = ""
	selected_index = -1
	status.text = "Preparing the clash…"
	worker = Thread.new()
	var error: Error = worker.start(Model.resolve.bind(request.world, request.seed, request.round))
	if error != OK:
		worker = null
		model.phase = "error"
		status.text = "Could not start combat. Restart the encounter."
	_refresh()

func _pause() -> void:
	paused = not paused
	field.running = not paused
	if paused: field.hourglass.set_progress(field.progress, 0.0)
	_refresh()

func _process(delta: float) -> void:
	if worker != null and not worker.is_alive():
		result = worker.wait_to_finish()
		worker = null
		if result.get("action") != "resolved":
			model.phase = "error"
			status.text = "Combat could not resolve: %s. Restart to retry." % str(result.get("reason", result))
			_refresh()
			return
		var events: Array = result.events.map(func(row): return row.event)
		if not playback.build(events):
			model.phase = "error"
			status.text = "Could not read the combat replay. Restart to retry."
			_refresh()
			return
		if not str(result.world.data.encounter.outcome).is_empty() and int(result.world.data.encounter.winning_tick) >= 0:
			playback.duration = playback.tick_time(int(result.world.data.encounter.winning_tick))
		objective_tape = events.filter(func(event): return event.type == "MARCHING_TICK" and event.data.has("encounter"))
		objective_cursor = 0
		elapsed = 0.0
		march_clock = MarchClock.new(playback.duration)
		march_intro = true
		paused = false
		model.phase = "playback"
		status.text = "The hourglass is running. Survivors remain for the next deployment."
		_refresh()
	if model == null or model.phase != "playback" or paused: return
	if playback.duration > 0.0:
		elapsed = field.hourglass.advance_tape(march_clock, elapsed, delta if march_intro else delta * float(SPEEDS[speed.selected]))
		march_intro = field.hourglass.is_turning()
	while objective_cursor < objective_tape.size() and playback.tick_time(objective_tape[objective_cursor].data.tick) <= elapsed:
		shown_objective = objective_tape[objective_cursor].data.encounter
		objective_cursor += 1
	field.progress = clampf(elapsed / maxf(0.01, playback.duration), 0, 1)
	field.show_state(playback.sample(elapsed), shown_objective, model.arena.round_number, true)
	if not shown_objective.message.is_empty(): status.text = shown_objective.message
	if elapsed >= playback.duration:
		field.hourglass.finish_tape(march_clock)
		model.accept(result)
		shown_objective = model.arena.world.data.encounter.duplicate(true)
		status.text = "Reinforcements arrived: 2 of each troop added to your reserve. Choose your deployments." if model.reinforcements_received and model.arena.round_number == model.reinforcement_round() else "Forecast advanced. Deploy from reserves or save summoning power."
		_idle()
		_refresh()

func dismiss() -> void:
	if worker != null:
		worker.wait_to_finish()
		worker = null
	if embedded:
		closed.emit()
		queue_free()
	else: get_tree().quit()

func _exit_tree() -> void:
	get_window().content_scale_size = previous_scale
	get_window().content_scale_mode = previous_scale_mode
	get_window().content_scale_aspect = previous_scale_aspect
	if worker != null:
		worker.wait_to_finish()
		worker = null
