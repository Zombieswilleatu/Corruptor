extends Control

signal closed
const Sim = preload("res://Scripts/Sim/U13LaneSandbox.gd")
const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")
const Preparation = preload("res://Prototype/U13/U13LanePreparation.gd")
const Lane = preload("res://Prototype/U13/U13SandboxLaneView.gd")
const INTERVAL: float = 15.0
const SPEEDS: Array = [0.5, 1.0, 2.0, 3.0, 5.0]
@export var balance_preview: bool = false
@export var standalone: bool = false
var goal_advance_toggle: CheckBox
var staging_capacity: OptionButton
var release_choices: Array = []
var staging_note: Label
var swap_seats_button: Button
var seats_swapped: bool = false
var manual_opening: Array = []
var sim = Sim.new()
var playback = Playback.new()
var field
var job: Thread
var next_job: Thread
var next_key: Dictionary = {}
var next_packet: Dictionary = {}
var waiting_next: bool = false
var waiting_key: Dictionary = {}
var arena_generation: int = 0
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
var home_toggle: CheckBox
var mode: OptionButton
var prepare_ahead: CheckBox
var speed: OptionButton
var seed_entry: LineEdit
var status: Label
var round_note: Label
var home_goal_note: Label
var enemy_goal_note: Label
var counts: Label
var wave_note: Label
var home_wave_note: Label
var totals_note: Label
var run_button: Button
var pause_button: Button
var reset_button: Button
var new_arena_button: Button
var spawn_buttons: Dictionary = {}
var monster_button: Button
var spawn_status: Label
var feedback_cursor: int = 0
var goal_rows: Array = []
var goal_cursor: int = 0
var round_goals: Array = [0, 0]

func _ready() -> void:
	sim = Sim.new(fresh_seed(), balance_preview, true, false, Sim.Staging.DEFAULT_CAPACITY)
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
	var title := label(top, "MARCHER BALANCE · monster tuning V21 · range 400 · tower 600" if balance_preview else "MARCHER & MONSTER BALANCE · monster tuning V21", 25)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(top, "EXIT PREVIEW" if standalone else "MAIN MENU", dismiss)
	var scoreboard := HBoxContainer.new()
	scoreboard.add_theme_constant_override("separation", 32)
	column.add_child(scoreboard)
	round_note = label(scoreboard, "ROUND 1", 26)
	round_note.custom_minimum_size.x = 180
	home_goal_note = label(scoreboard, "", 22)
	home_goal_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_goal_note.add_theme_color_override("font_color", Color("8fc4ff"))
	enemy_goal_note = label(scoreboard, "", 22)
	enemy_goal_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_goal_note.add_theme_color_override("font_color", Color("f29b98"))
	for note in [home_goal_note, enemy_goal_note]:
		note.tooltip_text = "Total units reaching the far gate, including monsters. Each body counts once per side, even if it dies after arrival. Resets with the arena."
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
	if balance_preview:
		goal_advance_toggle = CheckBox.new()
		goal_advance_toggle.text = "Advance when GOAL is within range"
		goal_advance_toggle.button_pressed = true
		choices.add_child(goal_advance_toggle)
		label(choices, "Vultures: +1 damage against Butchers only. Inside the final 400 distance: advance toward the goal while firing. Melee, walls and taunts still apply. Changing this option resets the arena with the same seed.", 14)
		goal_advance_toggle.toggled.connect(func(_enabled): reset())
	label(choices, "PROTECTED STAGING", 19)
	staging_capacity = option(choices, ["15 slots per side", "12 slots per side", "Off · old field hold"])
	staging_capacity.item_selected.connect(func(_i): reset())
	label(choices, "Produced this round → protected off-field. From the following round, release the whole ready group. Overflow sends the oldest ready group; newborns always wait.", 14)
	for side_name in ["Your side", "Enemy"]:
		label(choices, side_name + " · next interval", 14)
		release_choices.append(option(choices, ["Auto · assess pressure", "Hold reserves", "March ready group once"]))
	staging_note = label(choices, "", 14)
	label(choices, "SPAWN UNITS", 19)
	owner_choice = option(choices, ["Your side · blue", "Enemy side · red"])
	spawn_point = option(choices, ["Spawn at gate", "Spawn nearer the center"])
	spawn_point.visible = false
	var grid := GridContainer.new()
	grid.columns = 2
	choices.add_child(grid)
	for name in Sim.Marching.SUITS:
		spawn_buttons[name] = button(grid, "+ " + name, request_spawn.bind(name))
		spawn_buttons[name].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var profile: Dictionary = Sim.Marching.profile(name, "Lord", 0, 0, 1, true)
		spawn_buttons[name].tooltip_text = "%d HP · %d Attack · %d Armor" % [profile.max_hp, profile.attack, profile.armor]
		if name == "Penitent": spawn_buttons[name].tooltip_text += "\n" + preload("res://Scripts/Sim/U13PenitentDefense.gd").DESCRIPTION
		if name == "Wright": spawn_buttons[name].tooltip_text += "\n" + preload("res://Scripts/Sim/U13FieldFortifications.gd").DESCRIPTION
		if name == "Vulture": spawn_buttons[name].tooltip_text += "\nShooting range: %d\n+1 damage against Butchers only (before Armor)." % Sim.Marching.Ranged.vulture_range(sim.world)
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
	label(choices, "RANDOM SPAWNS", 19)
	home_toggle = CheckBox.new()
	home_toggle.text = "Your side spawns each interval"
	choices.add_child(home_toggle)
	enemy_toggle = CheckBox.new()
	enemy_toggle.text = "Enemy spawns each interval"
	choices.add_child(enemy_toggle)
	label(choices, "Each side uses its own five-card draws, one Slaver trade, spare defensive pairs and up to two saved cards. A legal field unit takes priority over an empty wave. Enable both and choose Continuous to watch hands-free.", 14)
	label(choices, "PLAYBACK", 19)
	mode = option(choices, ["15-second rounds · pause between", "Continuous · repeat rounds"])
	mode.item_selected.connect(func(_i): _sync_controls())
	prepare_ahead = CheckBox.new()
	prepare_ahead.text = "Prepare next interval during playback"
	prepare_ahead.button_pressed = true
	prepare_ahead.tooltip_text = "Continuous mode: prepare one interval ahead. Changes to queued spawns or next-interval choices replace that preparation. The first interval still needs to prepare."
	choices.add_child(prepare_ahead)
	speed = option(choices, ["0.5× speed", "1× speed", "2× speed", "3× speed", "5× speed"])
	speed.select(1)
	label(choices, "Seed · same seed repeats the same fight", 14)
	seed_entry = LineEdit.new()
	seed_entry.text = sim.seed_value
	choices.add_child(seed_entry)
	label(choices, "Manual additions also enter staging. Choices made during playback apply at the next interval. Auto may march early when viable, and holds against clearly stronger pressure. Staging Off restores the comparison rules.", 14)
	var actions := HBoxContainer.new()
	controls.add_child(actions)
	run_button = button(actions, "RUN 15s", start)
	run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_button = button(actions, "PAUSE", pause)
	new_arena_button = button(controls, "NEW RANDOM ARENA", new_random_arena)
	reset_button = button(controls, "REPLAY / APPLY SEED", reset)
	swap_seats_button = button(controls, "SWAP SEATS · SAME SEED", swap_seats)
	swap_seats_button.tooltip_text = "Restart this seed with the original armies, draw streams and manual opening in opposite seats. Click again to restore the original seats."
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
	label(report, "LAST HOME COMMITMENT", 19)
	home_wave_note = label(report, "Your side's random spawning is off.", 15)
	home_toggle.toggled.connect(func(_enabled): _update_wave_notes())
	enemy_toggle.toggled.connect(func(_enabled): _update_wave_notes())
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
	if active or preparing():
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
	if outcome.action == "spawned":
		# After stopping between rounds, an old worker can still be finishing.
		# An immediate idle spawn changes its base world, not the pending queue.
		arena_generation += 1
		next_packet = {}
	if outcome.action == "spawned" and sim.round_number == 1:
		var opening: Dictionary = request.duplicate(true)
		opening.owner = 1 - int(request.owner) if seats_swapped else int(request.owner)
		manual_opening.append(opening)
	spawn_status.text = outcome.get("reason", "%s spawned." % request.name)

func start() -> void:
	if running: return
	running = true
	if not active and not preparing(): _begin_interval()
	_sync_controls()

func pause() -> void:
	running = false
	status.text = "Paused · interval %d at %.1f / 15s" % [sim.round_number, elapsed]
	_sync_controls()

func _begin_interval() -> void:
	_clear_goal_playback()
	elapsed = 0
	var inputs: Dictionary = _interval_inputs(sim.round_number)
	# At the boundary these inputs become this interval's commitment. New
	# clicks made while it is finishing preparation belong to the next one.
	_consume_inputs()
	if _ahead_enabled() and inputs == next_key:
		if not next_packet.is_empty():
			_adopt_next()
			return
		if next_job != null:
			waiting_next = true
			waiting_key = inputs
			status.text = "Finishing preparation for interval %d…" % sim.round_number
			_sync_controls()
			return
	var committed: Dictionary = Preparation.commit(sim, inputs)
	_show_commitment(committed)
	if committed.action != "committed":
		_stop_preparation(committed)
		return
	job = Thread.new()
	var error: Error = job.start(Preparation.resolve.bind(sim.world.duplicate(true), sim.seed_value, sim.round_number))
	if error != OK:
		job = null
		_stop_preparation({"reason": "Could not start the lane simulation. Reset to try again."})
	else:
		status.text = "Preparing interval %d…" % sim.round_number
	_sync_controls()

func preparing() -> bool:
	return job != null or waiting_next

func _ahead_enabled() -> bool:
	return mode.selected == 1 and prepare_ahead.button_pressed

func _interval_inputs(number: int) -> Dictionary:
	var owners: Array = []
	if home_toggle.button_pressed: owners.append(0)
	if enemy_toggle.button_pressed: owners.append(1)
	return {"generation": arena_generation, "round": number, "pending": pending.duplicate(true), "owners": owners, "releases": release_choices.map(func(choice): return ["Auto", "Hold", "March"][choice.selected])}

func _consume_inputs() -> void:
	pending.clear()
	for choice in release_choices:
		if choice.selected == 2: choice.select(1)

func _show_commitment(committed: Dictionary) -> void:
	# A sealed interval may finish after another manual request was queued.
	if pending.is_empty() and not committed.get("outcomes", []).is_empty():
		spawn_status.text = committed.outcomes.back().get("reason", "Spawn request processed.")
	_update_wave_notes()
	field.show_world(sim.units(), sim.round_number, sim.world.data.get("field_structures", []))
	_update_staging()
	elapsed = 0
	feedback_cursor = 0
	_report(sim.units())

func _stop_preparation(packet: Dictionary) -> void:
	running = false
	status.text = ("" if packet.get("action") == "idle" else "Simulation stopped: ") + str(packet.get("reason", "playback unavailable"))
	_sync_controls()

func _install_packet(packet: Dictionary) -> void:
	if packet.get("action") != "prepared":
		_stop_preparation(packet)
		return
	result = packet.result
	playback = packet.playback
	active = true
	goal_rows = sim.goal_arrivals(result.events)
	field.show_frame(playback.sample(0), sim.round_number)
	status.text = "Interval %d ready.%s" % [sim.round_number, "" if running else " Resume to play."]
	_sync_controls()

func _adopt_next() -> void:
	var packet: Dictionary = next_packet
	next_packet = {}
	next_key = {}
	waiting_next = false
	waiting_key = {}
	sim = packet.sim
	_show_commitment(packet)
	_install_packet(packet)

func _poll_next() -> void:
	if next_job != null and not next_job.is_alive():
		next_packet = next_job.wait_to_finish()
		next_job = null
	if waiting_next and next_key == waiting_key and not next_packet.is_empty():
		# Already committed at the boundary; do not consume later requests or
		# re-read selectors, even if paused or continuous mode was switched off.
		_adopt_next()

func _prepare_next() -> void:
	if waiting_next: return
	if not active or not _ahead_enabled():
		next_packet = {}
		if next_job == null: next_key = {}
		return
	var wanted: Dictionary = _interval_inputs(sim.round_number + 1)
	if next_key != wanted: next_packet = {}
	if next_job != null or not next_packet.is_empty() or not running: return
	next_key = wanted
	# Only this world needs a copy. The current tape is immutable and finish
	# only reads it; copying it every time a selector changes is unnecessary.
	var finished: Dictionary = {"world": result.world.duplicate(true), "events": result.events}
	var candidate = sim.fork()
	next_job = Thread.new()
	if next_job.start(Preparation.next_interval.bind(candidate, finished, wanted.duplicate(true))) != OK:
		next_job = null
		next_key = {}

func _next_status() -> String:
	if not _ahead_enabled(): return ""
	if next_key != _interval_inputs(sim.round_number + 1): return " · next interval updating"
	return " · next interval ready" if not next_packet.is_empty() else " · next interval preparing"

func _process(delta: float) -> void:
	_poll_next()
	if job != null and not job.is_alive():
		var packet: Dictionary = job.wait_to_finish()
		job = null
		_install_packet(packet)
	_prepare_next()
	if not active or not running: return
	elapsed = minf(INTERVAL, elapsed + delta * SPEEDS[speed.selected])
	var playback_time: float = playback.duration * elapsed / INTERVAL
	var frame: Dictionary = playback.sample(playback_time)
	# Drain the tape rather than sampled pictures, so skipped display frames
	# and casualties after arrival cannot lose a point or count it twice.
	while goal_cursor < goal_rows.size() and playback.tick_time(goal_rows[goal_cursor].tick) <= playback_time:
		round_goals[goal_rows[goal_cursor].owner] += 1
		goal_cursor += 1
	field.show_frame(frame, sim.round_number)
	var hits: Array = []
	while feedback_cursor < playback.feedback_rows.size() and float(playback.feedback_rows[feedback_cursor].at) <= playback.duration * elapsed / INTERVAL:
		hits.append(playback.feedback_rows[feedback_cursor])
		feedback_cursor += 1
	if not hits.is_empty(): field.show_feedback(hits)
	_report(frame.units)
	status.text = "Interval %d · %.1f / 15s · %d queued spawns%s" % [sim.round_number, elapsed, pending.size(), _next_status()]
	if elapsed >= INTERVAL:
		sim.finish(result)
		_clear_goal_playback()
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
	field.animation_paused = not running or preparing()
	run_button.disabled = running
	run_button.text = "RESUME" if active else ("START" if mode.selected == 1 else "RUN 15s")
	pause_button.disabled = not running
	reset_button.disabled = job != null
	new_arena_button.disabled = job != null
	swap_seats_button.disabled = job != null
	swap_seats_button.text = "RESTORE SEATS · SAME SEED" if seats_swapped else "SWAP SEATS · SAME SEED"
	if goal_advance_toggle != null: goal_advance_toggle.disabled = job != null
	staging_capacity.disabled = job != null
	prepare_ahead.disabled = mode.selected != 1

func _show_idle() -> void:
	field.ranged_display_settings = {"lane_balance_preview": sim.world.data.get("lane_balance_preview", {})}
	field.show_world(sim.units(), sim.round_number, sim.world.data.get("field_structures", []))
	field.monster_fields = sim.world.data.monsters.fields.duplicate(true)
	_update_staging()
	_report(sim.units())

func _update_staging() -> void:
	var enabled: bool = Sim.Staging.enabled(sim.world)
	field.staging_capacity = int(sim.world.data.marcher_staging.capacity) if enabled else 0
	field.staged_units = sim.staged_units().duplicate(true)
	field.staging_round = sim.round_number
	var lines: PackedStringArray = []
	for decision in sim.world.data.get("marcher_staging", {}).get("decisions", []):
		lines.append(("Yours: " if decision.owner == 0 else "Enemy: ") + decision.reason + " Released %d." % decision.released)
	staging_note.text = "\n".join(lines)
	for choice in release_choices: choice.disabled = not enabled
	spawn_point.visible = not enabled
	field.queue_redraw()

func _update_wave_notes() -> void:
	for pid in [0, 1]:
		var toggle: CheckBox = home_toggle if pid == 0 else enemy_toggle
		var note: Label = home_wave_note if pid == 0 else wave_note
		var side: String = "Your side" if pid == 0 else "Enemy"
		note.text = sim.last_waves[pid].get("summary", side + " draws on the next interval.") if toggle.button_pressed else side + " random spawning is off."

func _report(rows: Array) -> void:
	round_note.text = "ROUND %d" % sim.round_number
	home_goal_note.text = "YOUR SIDE · %d reached the goal" % (sim.totals[0].reached_goal + round_goals[0])
	enemy_goal_note.text = "ENEMY · %d reached the goal" % (sim.totals[1].reached_goal + round_goals[1])
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
		total_lines.append("%s\nSpawned %d · Lost %d\nBanished %d · Goals %d" % ["ENEMY" if pid == 1 else "YOUR SIDE", t.spawned, t.defeated, t.banished, t.reached_goal + round_goals[pid]])
	counts.text = "\n".join(lines)
	totals_note.text = "\n\n".join(total_lines)

static func fresh_seed() -> String:
	return "lane-%08x-%08x" % [randi(), randi()]

func _clear_goal_playback() -> void:
	goal_rows = []
	goal_cursor = 0
	round_goals = [0, 0]

func new_random_arena() -> void:
	if job != null: return
	seed_entry.text = fresh_seed()
	reset()

func swap_seats() -> void:
	if job != null: return
	var resume_after: bool = running
	var opening: Array = manual_opening.duplicate(true)
	seed_entry.text = sim.seed_value
	seats_swapped = not seats_swapped
	var home_random: bool = home_toggle.button_pressed
	home_toggle.set_pressed_no_signal(enemy_toggle.button_pressed)
	enemy_toggle.set_pressed_no_signal(home_random)
	owner_choice.select(1 - owner_choice.selected)
	var release_mode: int = release_choices[0].selected
	release_choices[0].select(release_choices[1].selected)
	release_choices[1].select(release_mode)
	reset()
	for original in opening:
		var request: Dictionary = original.duplicate(true)
		request.owner = 1 - int(original.owner) if seats_swapped else int(original.owner)
		_spawn(request)
	_show_idle()
	status.text = "Seats swapped · same seed and opening." if seats_swapped else "Original seats restored · same seed and opening."
	if resume_after: start()

func reset() -> void:
	if job != null: return
	arena_generation += 1
	waiting_next = false
	waiting_key = {}
	next_packet = {}
	# A speculative worker owns no UI state. Let it finish, then discard its
	# old generation; resetting or swapping seats need not wait for it.
	if next_job == null: next_key = {}
	running = false
	active = false
	elapsed = 0
	pending.clear()
	manual_opening.clear()
	result = {}
	_clear_goal_playback()
	sim = Sim.new(seed_entry.text, balance_preview, goal_advance_toggle.button_pressed if goal_advance_toggle != null else false, seats_swapped, [15, 12, 0][staging_capacity.selected])
	seed_entry.text = sim.seed_value
	playback = Playback.new()
	field.reset_effects()
	_update_wave_notes()
	status.text = "Arena reset. Spawn both sides, then run the lane."
	spawn_status.text = "Choose a side and add units."
	_show_idle()
	_sync_controls()

func dismiss() -> void:
	running = false
	hide()
	closed.emit()
	if standalone: get_tree().quit()
	queue_free()

func _exit_tree() -> void:
	if job != null:
		job.wait_to_finish()
		job = null
	if next_job != null:
		next_job.wait_to_finish()
		next_job = null

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		dismiss()
	elif event.keycode == KEY_SPACE and not get_viewport().gui_get_focus_owner() is LineEdit:
		get_viewport().set_input_as_handled()
		if running: pause()
		else: start()
