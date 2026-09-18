extends Control

signal closed
const Sim = preload("res://Scripts/Sim/U13LaneSandbox.gd")
const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")
const Lane = preload("res://Prototype/U13/U13SandboxLaneView.gd")
const INTERVAL: float = 15.0
var sim = Sim.new()
var playback = Playback.new()
var field
var job: Thread
var result: Dictionary = {}
var pending: Array = []
var running: bool = false
var elapsed: float = 0
var active: bool = false
var owner_choice: OptionButton
var spawn_point: OptionButton
var monster_choice: OptionButton
var turret: CheckBox
var monster_note: Label
var enemy_toggle: CheckBox
var mode: OptionButton
var speed: OptionButton
var seed_entry: LineEdit
var status: Label
var counts: Label
var wave_note: Label
var totals_note: Label
var run_button: Button
var pause_button: Button
var reset_button: Button
var spawn_buttons: Dictionary = {}
var monster_button: Button
var spawn_status: Label
var feedback_cursor: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 110
	var bg := ColorRect.new()
	bg.color = Color("111310")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := label(top, "MARCHER & MONSTER BALANCE", 25)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(top, "MAIN MENU", dismiss)
	status = label(column, "Spawn both sides, then run the lane.", 17)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	var controls := VBoxContainer.new()
	controls.custom_minimum_size.x = 310
	row.add_child(controls)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls.add_child(scroll)
	var choices := VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 10)
	scroll.add_child(choices)
	label(choices, "SPAWN UNITS", 19)
	owner_choice = option(choices, ["Your side · blue", "Enemy side · red"])
	spawn_point = option(choices, ["Spawn at gate", "Spawn nearer the center"])
	var grid := GridContainer.new()
	grid.columns = 2
	choices.add_child(grid)
	for name in Sim.Marching.SUITS:
		spawn_buttons[name] = button(grid, "+ " + name, request_spawn.bind(name))
		spawn_buttons[name].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var profile: Dictionary = Sim.Marching.profile(name, "Lord", 0, 0, 1, true)
		spawn_buttons[name].tooltip_text = "%d HP · %d Attack · %d Armor" % [profile.max_hp, profile.attack, profile.armor]
	label(choices, "MONSTERS", 19)
	monster_choice = option(choices, Sim.Monsters.NAMES)
	monster_choice.item_selected.connect(func(_i): _monster_changed())
	turret = CheckBox.new()
	turret.text = "Sooge: start in turret form"
	turret.toggled.connect(func(_enabled): _monster_changed())
	choices.add_child(turret)
	monster_button = button(choices, "+ SPAWN MONSTER", func(): request_spawn(Sim.Monsters.NAMES[monster_choice.selected]))
	monster_note = label(choices, "", 14)
	spawn_status = label(choices, "Choose a side and add units.", 14)
	_monster_changed()
	label(choices, "RANDOM ENEMY", 19)
	enemy_toggle = CheckBox.new()
	enemy_toggle.text = "Enemy spawns each interval"
	choices.add_child(enemy_toggle)
	label(choices, "Five-card draws, one Slaver trade, spare defensive pairs and up to two saved cards. Actual commitment values and unlocked recipes determine the wave.", 14)
	label(choices, "PLAYBACK", 19)
	mode = option(choices, ["15-second rounds · pause between", "Continuous · repeat rounds"])
	mode.item_selected.connect(func(_i): _sync_controls())
	speed = option(choices, ["0.5× speed", "1× speed", "2× speed"])
	speed.select(1)
	label(choices, "Seed · applied on Reset", 14)
	seed_entry = LineEdit.new()
	seed_entry.text = "lane-balance-1"
	choices.add_child(seed_entry)
	label(choices, "Manual spawns are ready to move. Enemy commitments deploy next interval, as in the game. Spawns clicked during playback join the next interval.", 14)
	var actions := HBoxContainer.new()
	controls.add_child(actions)
	run_button = button(actions, "RUN 15s", start)
	run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_button = button(actions, "PAUSE", pause)
	reset_button = button(controls, "RESET ARENA", reset)
	field = Lane.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	var report_scroll := ScrollContainer.new()
	report_scroll.custom_minimum_size.x = 270
	report_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(report_scroll)
	var report := VBoxContainer.new()
	report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report.add_theme_constant_override("separation", 16)
	report_scroll.add_child(report)
	label(report, "ON THE FIELD", 19)
	counts = label(report, "", 16)
	label(report, "SESSION TOTALS", 19)
	totals_note = label(report, "", 15)
	label(report, "LAST ENEMY COMMITMENT", 19)
	wave_note = label(report, "Enemy spawning is off.", 15)
	label(report, "Hover a unit for HP and Armor. Units reaching the far gate count as escapes and leave after the interval.\n\nCombat uses the live game's movement, damage, regeneration and monster abilities. No Lords, castles, Veil or victory conditions.", 14)
	_show_idle()
	_sync_controls()

func label(parent: Node, copy: String, font_size: int = 16) -> Label:
	var item := Label.new()
	item.text = copy
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", font_size)
	parent.add_child(item)
	return item

func button(parent: Node, copy: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = copy
	item.custom_minimum_size.y = 40
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

func option(parent: Node, entries: Array) -> OptionButton:
	var item := OptionButton.new()
	for entry in entries: item.add_item(str(entry))
	parent.add_child(item)
	return item

func _monster_changed() -> void:
	if monster_note == null: return
	var name: String = Sim.Monsters.NAMES[monster_choice.selected]
	var profile: Dictionary = Sim.Monsters.ROSTER[name]
	var rooted: bool = name == "Sooge" and turret.button_pressed
	turret.visible = name == "Sooge"
	monster_button.text = "+ SPAWN VARN SWARM · 3–5" if name == "Varn" else "+ SPAWN " + name.to_upper()
	monster_note.text = "%d HP · %d Attack · %d Armor · %d Speed\n%s" % [profile.hp, 3 if rooted else profile.attack, 6 if rooted else profile.armor, 0 if rooted else profile.speed, profile.ability]

func request_spawn(name: String) -> void:
	var request: Dictionary = {"name": name, "owner": owner_choice.selected, "center": spawn_point.selected == 1, "turret": name == "Sooge" and turret.button_pressed}
	if active or job != null:
		if pending.size() >= 20:
			spawn_status.text = "Spawn queue is full. Finish this interval or reset."
			return
		pending.append(request)
		spawn_status.text = "%s queued for interval %d · %d spawn requests waiting" % [name, sim.round_number + 1, pending.size()]
		return
	_spawn(request)
	_show_idle()

func _spawn(request: Dictionary) -> void:
	var outcome: Dictionary = sim.spawn(request.name, request.owner, request.center, request.turret)
	spawn_status.text = outcome.get("reason", "%s spawned." % request.name)

func start() -> void:
	if running: return
	running = true
	if not active and job == null: _begin_interval()
	_sync_controls()

func pause() -> void:
	running = false
	status.text = "Paused · interval %d at %.1f / 15s" % [sim.round_number, elapsed]
	_sync_controls()

func _begin_interval() -> void:
	for request in pending: _spawn(request)
	pending.clear()
	if enemy_toggle.button_pressed:
		sim.enemy_wave()
		wave_note.text = sim.last_wave.get("summary", "No enemy commitment.")
	if sim.units().is_empty() and not enemy_toggle.button_pressed:
		running = false
		status.text = "Spawn units or enable the random enemy first."
		_sync_controls()
		return
	field.show_world(sim.units(), sim.round_number)
	elapsed = 0
	feedback_cursor = 0
	job = Thread.new()
	var error: Error = job.start(Sim.resolve_round.bind(sim.world.duplicate(true), sim.seed_value, sim.round_number))
	if error != OK:
		job = null
		running = false
		status.text = "Could not start the lane simulation. Reset to try again."
	else:
		status.text = "Preparing interval %d…" % sim.round_number
	_sync_controls()

func _process(delta: float) -> void:
	if job != null and not job.is_alive():
		result = job.wait_to_finish()
		job = null
		if result.get("action") != "resolved" or not playback.build(result.get("events", []).map(func(r): return r.event)):
			running = false
			status.text = "Simulation stopped: " + str(result.get("reason", "playback unavailable"))
			_sync_controls()
			return
		active = true
		field.show_frame(playback.sample(0), sim.round_number)
		if not running: status.text = "Interval %d ready. Resume to play." % sim.round_number
		_sync_controls()
	if not active or not running: return
	elapsed = minf(INTERVAL, elapsed + delta * [0.5, 1.0, 2.0][speed.selected])
	var frame: Dictionary = playback.sample(playback.duration * elapsed / INTERVAL)
	field.show_frame(frame, sim.round_number)
	var hits: Array = []
	while feedback_cursor < playback.feedback_rows.size() and float(playback.feedback_rows[feedback_cursor].at) <= playback.duration * elapsed / INTERVAL:
		hits.append(playback.feedback_rows[feedback_cursor])
		feedback_cursor += 1
	if not hits.is_empty(): field.show_feedback(hits)
	_report(frame.units)
	status.text = "Interval %d · %.1f / 15s · %d queued spawns" % [sim.round_number, elapsed, pending.size()]
	if elapsed >= INTERVAL:
		sim.finish(result)
		result = {}
		active = false
		playback = Playback.new()
		# Escape is not death: retire these pictures quietly at the boundary.
		field.quiet_removal_ids.append_array(field._units.filter(func(u): return u.attributes.waiting).map(func(u): return u.id))
		_show_idle()
		if mode.selected == 1 and running:
			_begin_interval()
		else:
			running = false
			status.text = "Interval %d complete. Add units or run the next 15 seconds." % (sim.round_number - 1)
		_sync_controls()

func _sync_controls() -> void:
	if field == null: return
	field.animation_paused = not running or job != null
	run_button.disabled = running
	run_button.text = "RESUME" if active else ("START" if mode.selected == 1 else "RUN 15s")
	pause_button.disabled = not running
	reset_button.disabled = job != null

func _show_idle() -> void:
	field.show_world(sim.units(), sim.round_number)
	field.monster_fields = sim.world.data.monsters.fields.duplicate(true)
	_report(sim.units())

func _report(rows: Array) -> void:
	var lines: PackedStringArray = []
	var total_lines: PackedStringArray = []
	for pid in [1, 0]:
		var names: Dictionary = {}
		for unit in rows:
			if unit.owner != pid: continue
			var name: String = unit.attributes.get("monster_id", unit.attributes.suit)
			names[name] = names.get(name, 0) + 1
		lines.append("ENEMY" if pid == 1 else "YOUR SIDE")
		if names.is_empty(): lines.append("—")
		for name in names: lines.append("%s × %d" % [name, names[name]])
		lines.append("")
		var t: Dictionary = sim.totals[pid]
		total_lines.append("%s\nSpawned %d · Lost %d\nBanished %d · Escaped %d" % ["ENEMY" if pid == 1 else "YOUR SIDE", t.spawned, t.defeated, t.banished, t.escaped])
	counts.text = "\n".join(lines)
	totals_note.text = "\n\n".join(total_lines)

func reset() -> void:
	if job != null: return
	running = false
	active = false
	elapsed = 0
	pending.clear()
	result = {}
	sim = Sim.new(seed_entry.text)
	playback = Playback.new()
	field.reset_effects()
	wave_note.text = "Enemy draws on the next interval." if enemy_toggle.button_pressed else "Enemy spawning is off."
	status.text = "Arena reset. Spawn both sides, then run the lane."
	spawn_status.text = "Choose a side and add units."
	_show_idle()
	_sync_controls()

func dismiss() -> void:
	running = false
	hide()
	closed.emit()
	queue_free()

func _exit_tree() -> void:
	if job != null:
		job.wait_to_finish()
		job = null

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		dismiss()
	elif event.keycode == KEY_SPACE and not get_viewport().gui_get_focus_owner() is LineEdit:
		get_viewport().set_input_as_handled()
		if running: pause()
		else: start()
