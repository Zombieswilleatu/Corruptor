extends "res://Prototype/U13/U13ActionFlowBoard.gd"

# This subclass observes public presentation and suspends it for explanations.
# It never supplies a move, replaces a choice, or writes to match authority.
const TutorialCatalog = preload("res://Prototype/U13/U13TutorialCatalog.gd")
const TutorialJournal = preload("res://Prototype/U13/U13TutorialJournal.gd")
const TutorialPreferences = preload("res://Prototype/U13/U13TutorialPreferences.gd")
const ContextHelp = preload("res://Prototype/U13/U13ContextHelp.gd")
const TUTORIAL_EVENTS: Array = ["WARD_RECRUITS_CONVERTED", "WARD_SOUL_GAINED", "COMBAT_ORDER_REVEALED", "GUARD_DEVOURED", "MARCHER_ALLEGIANCE_CHANGED", "GUARD_RECONFIGURED", "REDIRECT_RESOLVED", "PARADOX_GEOMETRY", "LORD_BANISHED", "LORD_RESUMMONED", "CASTLE_DESTROYED", "VEIL_LORD_ARRIVED", "NEUTRAL_TEAR_CREATED", "PERSONAL_TEAR_CREATED", "STAGING_OVERFLOW_RELEASED", "STAGING_RECRUITMENT_CAPPED", "ACCELERATE", "PICKING_THE_BONES", "SIFTING_THE_RUINS", "FORGE_REPAIR", "PSYCHIC_INTERLOCK", "RECONFIGURATION_GAINED", "KRONI_HUNGER_CHANGED", "VALAK_ESSENCE_GAINED", "VALAK_ESSENCE_REINFORCED", "KANIFOUS_PRICE_RESOLVED", "KANIFOUS_PRICE_DEFERRED", "FEAR_AURA", "ENDURANCE_CHECKED"]
var tutorial_preferences = TutorialPreferences.new()
var tutorial_journal = TutorialJournal.new()
var context_help
var help_button: Button
var _tutorial_deferred: bool = false
var _tutorial_poll_clock: float = 0.0
var _tutorial_hidden: Array = []
var _tutorial_prior_focus: WeakRef
var _tutorial_prior_pause: bool = false
var _tutorial_event_cursor: int = 0
var _tutorial_events: Array = []
var _tutorial_threat: Dictionary = {}
var _tutorial_threat_change: Dictionary = {}
var _tutorial_number: int = 0
var _tutorial_first_board: bool = true
var _tutorial_loading: bool = false
var _tutorial_grimoire_interest: bool = false
var _tutorial_context_cache: Dictionary = {}

func _build() -> void:
	super._build()
	help_button = _button(header.history_box, "HELP", _open_context_help)
	help_button.tooltip_text = "Read the field guide, disable explanations, or reset tutorial history."
	context_help = ContextHelp.new()
	context_help.name = "ContextHelp"
	add_child(context_help)
	context_help.closed.connect(_tutorial_closed)
	context_help.suppression_requested.connect(func(id): _tutorial_preference_result(tutorial_preferences.dismiss(id)))
	context_help.automatic_changed.connect(func(value): _tutorial_preference_result(tutorial_preferences.set_automatic(value)))
	context_help.reset_requested.connect(_reset_context_tutorials)

func _tutorial_preference_result(result: Error) -> void:
	if result != OK:
		context_help.note.text = "The preference could not be saved. You can still close this explanation and keep playing."

func _reset_context_tutorials() -> void:
	var result: Error = tutorial_preferences.reset_all()
	if result != OK:
		_tutorial_preference_result(result)
		return
	# Reset learning, but never replenish this round's presentation allowance.
	tutorial_journal.seen.clear()
	context_help.automatic.set_pressed_no_signal(true)
	context_help.note.text = "Tutorial history reset. Explanations can appear at later relevant moments; this round's allowance stays in force."

# Future Aldric teaching steps call this only after delivering these concepts.
# Example: record_taught_concepts(["subjects", "guards", "ward"]).
func record_taught_concepts(concepts: Array) -> Error:
	return tutorial_preferences.mark_learned(concepts)

func _refresh(presented: Dictionary = {}) -> void:
	super._refresh(presented)
	_queue_tutorial_check()

func _update_direct_ui() -> void:
	super._update_direct_ui()
	_queue_tutorial_check()

func _sync_flow() -> void:
	super._sync_flow()
	if context_help != null and context_help.visible:
		# Deferred layout/binding must not reveal a second modal behind Help.
		phase_prompt.hide()

func _queue_tutorial_check() -> void:
	if context_help == null or _tutorial_deferred or _tutorial_loading: return
	_tutorial_deferred = true
	call_deferred("_tutorial_check_deferred")

func _tutorial_check_deferred() -> void:
	_tutorial_deferred = false
	_tutorial_consider()

func _process(delta: float) -> void:
	if context_help != null and context_help.visible: return
	super._process(delta)
	if help_button != null: help_button.disabled = _job != null or not match_started or setup_open
	_tutorial_poll_clock += delta
	if _tutorial_poll_clock >= 0.25:
		_tutorial_poll_clock = 0.0
		_tutorial_consider()

func _goto_flow(index: int, skip_unavailable: bool = false) -> void:
	super._goto_flow(index, skip_unavailable)
	_tutorial_consider()

func _offer_grimoire_summons() -> bool:
	var offered: bool = super._offer_grimoire_summons()
	if offered: _tutorial_consider()
	return offered

func _open_recipes() -> void:
	_tutorial_grimoire_interest = true
	super._open_recipes()
	_tutorial_consider()

func _tutorial_busy() -> bool:
	if _resolution_pending(): return true
	if _job != null or _tutorial_loading or not match_started or setup_open or not session is PlaySession: return true
	if get_tree().paused or context_help == null or context_help.visible: return true
	if price_visual != null and price_visual.visible: return true
	if guard_chomp != null and guard_chomp.active(): return true
	if kroni_visual != null and kroni_visual.busy(): return true
	if load_dialog != null and load_dialog.visible: return true
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or get_viewport().gui_is_dragging(): return true
	return false

func _ruin_modal_controls() -> Array:
	var controls: Array = super._ruin_modal_controls()
	controls.append(context_help)
	return controls

func _tutorial_observe_public_results() -> void:
	# Read only the player's projected event rows, after their playback is over.
	# Filtering before copying avoids duplicating dense movement tapes.
	if playing or _opening_playback != null: return
	var cursor: int = session._owner._event_cursor()
	if cursor > _tutorial_event_cursor:
		var fresh: Array = session._owner._player_selected_events_since(0, _tutorial_event_cursor, TUTORIAL_EVENTS)
		_tutorial_events.append_array(fresh.filter(func(e): return int(e.data.get("round", session.round_number())) == session.round_number()))
		_tutorial_event_cursor = cursor
		if _tutorial_events.size() > 64: _tutorial_events = _tutorial_events.slice(-64)
	for row in _visible_world.get("entities", []):
		if row.get("kind") != "lord" or not row.attributes.has("threat"): continue
		var value: int = int(row.attributes.threat)
		if _tutorial_threat.has(row.id) and int(_tutorial_threat[row.id]) != value:
			var reason: String = "See the public round result for its cause."
			for event in _tutorial_events:
				if str(event.get("text", "")).to_lower().contains("threat"): reason = event.text
			_tutorial_threat_change = {"lord": str(row.attributes.get("lord_id", "Lord")), "before": int(_tutorial_threat[row.id]), "after": value, "reason": reason}
		_tutorial_threat[row.id] = value

func _tutorial_context() -> Dictionary:
	var number: int = session.round_number()
	if number != _tutorial_number:
		_tutorial_number = number
		_tutorial_events = []
		_tutorial_threat_change = {}
		_tutorial_grimoire_interest = false
	_tutorial_observe_public_results()
	var frame: Dictionary = {}
	if playing: frame = playback.sample(clock)
	elif _opening_playback != null: frame = _opening_playback.sample(_opening_clock)
	else:
		frame = {"units": _visible_world.get("entities", []).filter(func(e): return e.kind == "marcher"), "field_structures": _visible_world.get("field_structures", [])}
	var order: Dictionary = _order() if _planning() else {}
	var reserved_waiters: Array = []
	for group in order.get("rites", {}).get("waiter_spends", []): reserved_waiters.append_array(group.get("marcher_ids", []))
	var public_units: Array = frame.get("units", []).filter(func(u): return u.id not in reserved_waiters)
	var result: Dictionary = {
		"world": _visible_world, "round": number, "phase": _flow_title(), "planning": _planning(),
		"order": order, "powers": queued, "intent": _intent, "board_entry": _tutorial_first_board,
		"visible_units": public_units, "visible_structures": frame.get("field_structures", []),
		"events": _tutorial_events, "opening": _opening_playback != null, "closing": playing,
		"summon_choice": summon_menu != null and summon_menu.visible,
		"grimoire_interest": _tutorial_grimoire_interest and recipe_menu.visible,
		"pillage": _pillage_available(), "aftermath": phase_prompt.stage_key == "AFTERMATH",
		"breach_wish": _visible_world.get("breach_wish_access", [false, false])[0]
	}
	if not _tutorial_threat_change.is_empty(): result["threat_change"] = _tutorial_threat_change
	return result

func _tutorial_opportunity(c: Dictionary) -> String:
	var kinds: Array = []
	var waiting: Dictionary = {"Lord": 0, "Castle": 0}
	for unit in c.visible_units:
		var a: Dictionary = unit.attributes
		var kind: String = str(a.get("monster_id", a.get("suit", "")))
		if kind not in kinds: kinds.append(kind)
		if unit.owner == 0 and a.get("waiting", false): waiting[a.lane] += 1
	kinds.sort()
	# Position ticks and mouse motion never create new popup opportunities.
	return JSON.stringify([c.round, c.phase, c.intent, c.order, c.powers, kinds, waiting, not c.visible_structures.is_empty(), c.opening, c.closing, c.summon_choice, c.grimoire_interest, c.events.map(func(e): return e.type), c.get("threat_change", {}), not TutorialCatalog._embolden_detail(c).is_empty(), TutorialCatalog.opening_march_visible(c)])

func _tutorial_consider() -> void:
	if _tutorial_busy() or _resolution_pending(): return
	var c: Dictionary = _tutorial_context()
	_tutorial_context_cache = c
	var candidates: Array = TutorialCatalog.candidates(c)
	var limit: int = 5
	# Leave room for commitment, Lord inspection, and the final lock in round one.
	if c.round == 1:
		if c.phase in ["Stockpile", "Slaver", "Work Target", "Resummon", "Guards"]: limit = 2
		elif c.phase == "Combat": limit = 4
	var lesson: Dictionary = tutorial_journal.choose(candidates, c.round, _tutorial_opportunity(c), tutorial_preferences, limit)
	_tutorial_first_board = false
	if lesson.is_empty(): return
	_tutorial_suspend()
	context_help.present(lesson, tutorial_preferences.automatic_enabled(), int(tutorial_journal.counts.get(str(c.round), 0)))

func _tutorial_suspend() -> void:
	_sample_playtime()
	var focus: Control = get_viewport().gui_get_focus_owner()
	_tutorial_prior_focus = weakref(focus) if focus != null else null
	_tutorial_hidden = []
	for node in [phase_prompt, game_menu, recipe_menu, summon_menu, reconfiguration_menu, history_panel]:
		if node != null and node.visible:
			_tutorial_hidden.append(weakref(node))
			node.hide()
	_tutorial_prior_pause = get_tree().paused
	get_tree().paused = true

func _tutorial_closed() -> void:
	get_tree().paused = _tutorial_prior_pause
	for ref in _tutorial_hidden:
		var node = ref.get_ref()
		if node != null: node.show()
	_tutorial_hidden = []
	var focus = _tutorial_prior_focus.get_ref() if _tutorial_prior_focus != null else null
	if focus != null and focus.is_visible_in_tree(): focus.grab_focus()
	_previous_frame_us = Time.get_ticks_usec()
	_sample_playtime()
	# No continuation callbacks, no submission, and no immediate next lesson.

func _open_context_help() -> void:
	if _tutorial_busy(): return
	_tutorial_suspend()
	context_help.open_book(TutorialCatalog.book(_visible_world), tutorial_preferences.automatic_enabled())

func _playtime_mode() -> String:
	if context_help != null and context_help.visible: return "excluded"
	return super._playtime_mode()

func _encode_playable_save() -> String:
	var envelope: Dictionary = JSON.parse_string(super._encode_playable_save())
	envelope["context_tutorials"] = {"journal": tutorial_journal.snapshot(), "event_cursor": _tutorial_event_cursor, "threat": _tutorial_threat.duplicate(), "round": _tutorial_number}
	return JSON.stringify(envelope)

func _load_game(path: String) -> void:
	var old_session = session
	_tutorial_loading = true
	super._load_game(path)
	if session != old_session:
		var envelope = JSON.parse_string(FileAccess.get_file_as_string(path))
		var raw = envelope.get("context_tutorials", {}) if typeof(envelope) == TYPE_DICTIONARY else {}
		if typeof(raw) != TYPE_DICTIONARY: raw = {}
		tutorial_journal.restore(raw.get("journal", {}))
		_tutorial_event_cursor = clampi(int(raw.get("event_cursor", session._owner._event_cursor())), 0, session._owner._event_cursor())
		_tutorial_threat = raw.get("threat", {}).duplicate() if typeof(raw.get("threat")) == TYPE_DICTIONARY else {}
		_tutorial_number = session.round_number()
		_tutorial_events = []
		_tutorial_threat_change = {}
		_tutorial_first_board = not tutorial_journal.seen.has("objective")
	_tutorial_loading = false
	_queue_tutorial_check()

func start_loadout(lords: Array, castles: Array, quick: bool) -> void:
	var old_session = session
	_tutorial_loading = true
	super.start_loadout(lords, castles, quick)
	if session != old_session:
		tutorial_journal.reset()
		_tutorial_event_cursor = 0
		_tutorial_events = []
		_tutorial_threat = {}
		_tutorial_threat_change = {}
		_tutorial_number = 0
		_tutorial_first_board = true
	_tutorial_loading = false
	_queue_tutorial_check()

func _exit_tree() -> void:
	if context_help != null and context_help.visible: get_tree().paused = _tutorial_prior_pause
	super._exit_tree()
