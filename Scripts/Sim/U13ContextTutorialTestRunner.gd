extends SceneTree

const Journal = preload("res://Prototype/U13/U13TutorialJournal.gd")
const Preferences = preload("res://Prototype/U13/U13TutorialPreferences.gd")
const Catalog = preload("res://Prototype/U13/U13TutorialCatalog.gd")
const Board = preload("res://Prototype/U13/U13TutorialBoard.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const Events = preload("res://Scripts/Sim/U13EventLog.gd")
var failures: int = 0
var checks: int = 0
var board
var preference_path: String = "user://u13-context-test-%d.cfg" % Time.get_ticks_usec()

func _initialize() -> void:
	ProjectSettings.set_setting("debug/gdscript/warnings/integer_division", 2)
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func ids(context: Dictionary) -> Array:
	return Catalog.candidates(context).map(func(row): return row.id)

func context() -> Dictionary:
	return {"world": {"ward_experiment": "U13_SPLIT_WARD_V1", "tempo_experiment": "U13_VEIL_ATTACK_ROUND25_V1", "entities": [], "players": [], "guard_placement_limits": [6, 6], "veil_total": 0}, "round": 1, "phase": "Combat", "planning": true, "order": {}, "powers": [], "visible_units": [], "events": []}

func journal_checks() -> void:
	var preferences = Preferences.new(preference_path)
	var journal = Journal.new()
	for i in range(5):
		var lesson: Dictionary = Catalog.lesson("unit:Vulture")
		lesson.id = "budget:%d" % i
		check(not journal.choose([lesson], 1, str(i), preferences).is_empty(), "ordinary allowance %d" % (i + 1))
	check(journal.choose([Catalog.lesson("forecast")], 1, "six-normal", preferences).is_empty(), "sixth ordinary explanation waits")
	check(not journal.choose([Catalog.lesson("restriction")], 1, "six-urgent", preferences).is_empty(), "sixth place reserved for immediate constraint")
	check(journal.choose([Catalog.lesson("resolve")], 1, "seven", preferences).is_empty(), "hard limit six even for urgent lessons")
	check(journal.choose([], 2, "new-round", preferences).is_empty(), "no FIFO dump when next round starts")
	check(not journal.choose([Catalog.lesson("forecast")], 2, "relevant-again", preferences).is_empty(), "deferred concept can return only with fresh relevance")
	check(journal.choose([Catalog.lesson("hunt")], 2, "relevant-again", preferences).is_empty(), "one explanation per opportunity, no chain on close")
	var snapshot: Dictionary = journal.snapshot()
	var restored = Journal.new()
	restored.restore(snapshot)
	check(restored.snapshot() == snapshot, "counts, seen topics and opportunity survive save/load")
	check(restored.choose([Catalog.lesson("resolve")], 1, "reload", preferences).is_empty(), "reload cannot refill a spent round allowance")
	journal.reset()
	for name in ["objective", "guards"]: journal.choose([Catalog.lesson(name)], 1, name, preferences, 2)
	check(journal.choose([Catalog.lesson("slaver")], 1, "early-third", preferences, 2).is_empty(), "early round-one topics leave room for commitment and powers")
	preferences.dismiss("ward")
	var reloaded = Preferences.new(preference_path)
	check(not reloaded.should_show("ward"), "per-topic suppression persists")
	preferences.mark_learned(["subjects", "guards", "hunt"])
	check(not reloaded.should_show("subjects") and not reloaded.should_show("hunt") and reloaded.should_show("split_ward"), "prologue suppresses only concepts actually taught")
	preferences.set_automatic(false)
	check(not reloaded.should_show("slaver") and Catalog.book(context().world).size() > 60, "disable-all persists while Help remains available")
	preferences.reset_all()
	check(reloaded.should_show("ward") and reloaded.should_show("guards"), "reset restores dismissed and learned concepts")
	preferences.dismiss(Preferences.KEEP_LOADOUT)
	preferences.mark_learned(["subjects"])
	check(not reloaded.should_show(Preferences.KEEP_LOADOUT), "learning a concept preserves existing loadout preferences")
	preferences.reset_all()

func trigger_checks() -> void:
	var c: Dictionary = context()
	check("grimoires" not in ids(c), "visible hint panel alone does not trigger a tour")
	c.grimoire_interest = true
	check("grimoires" in ids(c), "explicit grimoire interest explains hints")
	c.order = {"action": "Ward", "lane": "Lord", "card_ids": ["p"]}
	check("ward" in ids(c) and "split_ward" in ids(c), "paid Ward introduces separate defense")
	var legacy: Dictionary = c.duplicate(true)
	legacy.world.erase("ward_experiment"); legacy.world.erase("tempo_experiment")
	check("split_ward" not in ids(legacy) and "half" in Catalog.lesson("ward", legacy.world).body, "legacy Ward gets legacy text")
	check(not Catalog.book(legacy.world).any(func(row): return row.id in ["deadline", "veil_bonus", "ward_reward"]), "legacy Help excludes new-profile mechanics")
	c.phase = "Lord Powers"
	check("lord_inspection" in ids(c) and "hold" in Catalog.lesson("lord_inspection").body and "passives" in Catalog.lesson("lord_inspection").body, "Lord Powers introduces long press and passive-card inspection")
	c.phase = "Guards"; c.world.guard_placement_limits = [1, 6]; c.world.snare_rounds = [1, 0]
	check("restriction" in ids(c) and Catalog.candidates(c).any(func(row): return row.id == "restriction" and row.body.contains("opponent's Snare")), "public Snare explains the actual placement limit")
	c.world.entities = [{"id": "w1", "kind": "card", "attributes": {"suit": "Wright"}}, {"id": "w2", "kind": "card", "attributes": {"suit": "Wright"}}]
	c.order = {"guard_moves": [{"card_id": "w1", "lane": "Lord"}, {"card_id": "w2", "lane": "Lord"}]}
	check("pair:Wright" in ids(c), "fresh same-zone pair explains its work before lock")
	c.order.guard_moves[1].lane = "Castle"
	check("pair:Wright" not in ids(c), "split zones do not invent a Guard pair")
	c = context()
	for i in range(5): c.visible_units.append({"id": str(i), "owner": 0, "attributes": {"suit": "Penitent", "waiting": true, "lane": "Lord"}})
	check("supplicants" in ids(c) and "supplicant_trade" in ids(c), "five same-lane Supplicants explain attack use and Tear alternative")
	c.visible_units[4].attributes.lane = "Castle"
	check("supplicant_trade" not in ids(c), "Supplicant trade never combines lanes")
	c = context(); c.world.game_staging = {"lanes": {"Lord": {"units": [{"id": "new", "owner": 0, "attributes": {"staged_round": 1}}]}}}
	check("recruitment" in ids(c) and "march" not in ids(c), "newborns introduce staging but are not advertised as launchable")
	c.round = 2
	check("march" in ids(c), "eligible prior-round reserve introduces MARCH")
	c.round = 24; c.world.veil_total = 17
	check("late_reward" in ids(c) and "deadline" in ids(c) and "veil_bonus" in ids(c), "late rules trigger only at relevant public thresholds")
	c = context()
	var hidden: Dictionary = {"type": "GUARD_DEVOURED", "text": "hidden", "data": {"round": 1, "player_id": 1, "before": {"owner": 0}}}
	var log = Events.new()
	log.append(hidden, [null, hidden])
	c.events = log.selected_for_player(0, 0, Board.TUTORIAL_EVENTS)
	check("enemy_consume" not in ids(c), "hidden event cannot enter tutorial candidates")
	log.append(hidden, [hidden, hidden])
	c.events = log.selected_for_player(0, 0, Board.TUTORIAL_EVENTS)
	check("enemy_consume" in ids(c), "visible enemy Consume explains the Guard loss")
	c.events[0].data.player_id = 0
	check("enemy_consume" not in ids(c), "own cannibal feeding is not mislabeled as an enemy attack")
	c.events = [{"type": "PARADOX_GEOMETRY", "data": {"kind": "none"}}, {"type": "REDIRECT_RESOLVED", "data": {"changes": []}}]
	check("allegiance" not in ids(c) and "displacement" not in ids(c), "powers with no changed targets do not claim a transfer")
	c.events = [{"type": "GUARD_RECONFIGURED", "data": {"before": {"owner": 0}, "after": {"owner": 1}}}]
	check("allegiance" in ids(c) and "displacement" not in ids(c), "Guard transfer explains ownership instead of just movement")
	c.events = [{"type": "PERSONAL_TEAR_CREATED", "data": {}}]
	check("tears" in ids(c), "actual Personal Tear event introduces the Veil")
	c.events = [{"type": "FEAR_AURA", "data": {"returned_ids": []}}, {"type": "ENDURANCE_CHECKED", "data": {"threshold_met": false}}]
	check("passive:fear" not in ids(c) and "passive:endurance" not in ids(c), "unsuccessful passive checks do not claim effects")
	c.events[0].data.returned_ids = ["guard"]
	c.events[1].data.threshold_met = true
	check("passive:fear" in ids(c) and "passive:endurance" in ids(c), "real passive effects introduce their explanations")
	var original: Dictionary = c.duplicate(true)
	Catalog.candidates(c)
	check(c == original, "lesson generation never mutates input context")

func new_rule_checks() -> void:
	var c: Dictionary = context()
	c.world.merge({"embolden_experiment": 10, "embolden_ramp_experiment": true, "ward_conversion_experiment": "regular", "guard_work": {}})
	check("15 Souls" in Catalog.lesson("objective", c.world).body and "7 Personal Tears" in Catalog.lesson("objective", c.world).body, "objective matches current victory thresholds")
	check("full printed value" in Catalog.lesson("forecast", c.world).body, "current forecast explains removed suit penalty")
	check("lose 1 strength" in Catalog.lesson("forecast", {}).body, "legacy forecast retains legacy suit rule")
	check("RESERVE WARD" not in Catalog.lesson("split_ward", c.world).body and "Drag" in Catalog.lesson("split_ward", c.world).body, "split Ward teaches direct drag without reserve click")
	check("Veil 15, 19 and 23" in Catalog.lesson("veil_bonus", c.world).body, "Veil explanation matches live thresholds")
	check("2 Integrity" in Catalog.lesson("passive:forge", c.world).body and "two enemy kills" in Catalog.lesson("passive:bones", c.world).body, "restored passive explanations preserve current lord balance")
	var book_ids: Array = Catalog.book(c.world).map(func(row): return row.id)
	check("embolden" in book_ids and "ward_conversion" in book_ids, "new systems are available in searchable Help")
	check(not Catalog.book({}).any(func(row): return row.id in ["embolden", "ward_conversion"]), "legacy Help does not promise inactive new systems")
	check("embolden" not in ids(c) and "ward_conversion" not in ids(c), "enabled rules alone do not start a tutorial tour")
	c.order = {"action": "Ward", "lane": "Lord", "card_ids": ["p"]}
	check("ward_conversion" in ids(c), "Ward planning explains conversion before commitment locks")
	c.order = {"action": "Siege", "ward": {"action": "Ward", "lane": "Lord", "card_ids": ["p"]}}
	check("ward_conversion" in ids(c), "split Ward also introduces conversion")
	c.order = {}
	c.events = [{"type": "WARD_CONTESTED", "data": {"saved": false}}]
	check("ward_conversion" not in ids(c), "failed or unnecessary Ward never claims a theft")
	c.events = [{"type": "WARD_RECRUITS_CONVERTED", "data": {"regular_count": 3, "player_id": 1, "lane": "Lord"}}]
	var lesson: Dictionary = Catalog.candidates(c).filter(func(row): return row.id == "ward_conversion")[0]
	check(lesson.urgent and "opponent claimed 3" in lesson.body and "Lord lane" in lesson.body, "actual enemy theft explains number, owner and lane with urgent priority")
	c.events[0].data.player_id = 0
	check(Catalog.candidates(c).any(func(row): return row.id == "ward_conversion" and "You claimed 3" in row.body), "own conversion uses correct perspective")
	c.events[0].data.regular_count = 0
	check("ward_conversion" not in ids(c), "empty transfer does not invent an outcome")
	var log = Events.new()
	var e: Dictionary = {"type": "WARD_RECRUITS_CONVERTED", "text": "", "data": {"regular_count": 3, "player_id": 1, "lane": "Lord"}}
	log.append(e, [null, e])
	c.events = log.selected_for_player(0, 0, Board.TUTORIAL_EVENTS)
	check("ward_conversion" not in ids(c), "hidden conversion cannot leak through tutorials")
	log.append(e, [e, e])
	c.events = log.selected_for_player(0, 0, Board.TUTORIAL_EVENTS)
	check("ward_conversion" in ids(c), "real public conversion reaches tutorial event filter")
	c.events = []
	c.visible_units = [{"id": "p", "owner": 1, "attributes": {"suit": "Penitent", "lane": "Castle", "_embolden_percent": 30}}]
	check(Catalog.candidates(c).any(func(row): return row.id == "embolden" and "Enemy" in row.body and "+30%" in row.body), "visible enemy bonus introduces Embolden with current magnitude")
	c.visible_units[0].attributes._embolden_percent = 0
	check("embolden" not in ids(c), "zero bonus does not introduce an active buff")
	c.phase = "Guards"
	c.world.embolden_guard_history = {"slots": [{"Lord": [{"age": 0}, {"age": 0}, {"age": 0}]}, {}]}
	check("embolden" not in ids(c), "freshly lost Guard receives grace without active-bonus warning")
	c.world.embolden_guard_history.slots[0].Lord[1].age = 1
	check("embolden" in ids(c), "old empty slot warns during Guard choices before lock")
	c.order = {"guard_moves": [{"lane": "Lord", "slot": 1}]}
	check("embolden" not in ids(c), "planned replacement removes the vacancy warning")
	c.order = {}
	c.world.entities = [{"id": "guard", "owner": 0, "attributes": {"role": "guard", "lane": "Lord", "slot": 1}}]
	check("embolden" not in ids(c), "occupied slot does not produce stale vacancy warning")
	var prefs = Preferences.new(preference_path)
	prefs.dismiss("ward_conversion")
	var journal = Journal.new()
	check(journal.choose([lesson], 9, "conversion", prefs).is_empty(), "Don't show again suppresses even urgent conversion explanations")
	prefs.reset_all()

func run() -> void:
	journal_checks()
	trigger_checks()
	new_rule_checks()
	board = Board.new()
	board.tutorial_preferences = Preferences.new(preference_path)
	board.tutorial_preferences.set_automatic(false)
	root.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board._runtime_ok = true
	await process_frame
	board.start_loadout(["Deimos", "Gremory"], [Slots.TYPES, Slots.TYPES], false)
	await process_frame
	await choices()
	check(board._planning(), "real playable reaches planning with tutorial layer installed")
	board.tutorial_preferences.set_automatic(true)
	board.tutorial_journal.reset()
	board._tutorial_first_board = true
	var authority: Dictionary = board.session.checkpoint()
	var cart: Dictionary = board._order().duplicate(true)
	board._tutorial_consider()
	check(board.context_help.visible and paused, "automatic explanation pauses presentation")
	check(not board.phase_prompt.visible and not board.game_menu.visible, "underlying decision modal is suspended, not stacked")
	check(board.session.checkpoint() == authority and board._order() == cart, "opening explanation leaves authority and cart unchanged")
	var number: int = board.session.round_number()
	var used: int = int(board.tutorial_journal.counts.get(str(number), 0))
	board.context_help.close_button.pressed.emit()
	check(not paused and not board.context_help.visible and board.phase_prompt.visible, "Close restores the same decision")
	board._tutorial_consider()
	check(not board.context_help.visible and int(board.tutorial_journal.counts[str(number)]) == used, "closing does not chain another topic")
	check(board.session.checkpoint() == authority and board._order() == cart, "Close performs no action and makes no random draw")
	board._open_context_help()
	check(board.context_help.visible and board.context_help.search.visible, "manual Help opens the complete searchable guide")
	board.context_help.search.text = "Supplicant"
	check(board.context_help.topics.item_count >= 2, "Help contains both Supplicant decisions")
	var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true
	board.context_help._input(escape)
	check(not paused and not board.context_help.visible, "Escape closes Help without changing the plan")
	check(board.tutorial_journal.counts[str(number)] == used, "manual Help consumes no automatic budget")
	var encoded: String = board._encode_playable_save()
	var envelope: Dictionary = JSON.parse_string(encoded)
	check(envelope.has("context_tutorials") and bytes_to_var(Marshalls.base64_to_raw(envelope.payload)) == authority, "tutorial save data lives outside the authoritative payload")
	var journal: Dictionary = board.tutorial_journal.snapshot()
	var save_path: String = "user://u13-context-tutorial-save-test.json"
	var file = FileAccess.open(save_path, FileAccess.WRITE); file.store_string(encoded); file.close()
	board._load_game(save_path)
	check(board.tutorial_journal.snapshot() == journal and board.session.checkpoint() == authority, "real save/load preserves tutorial counts and exact match")
	board.tutorial_preferences.set_automatic(false)
	board._open_context_help()
	check(board.context_help.visible and not board.context_help.automatic.button_pressed, "Help works with automatic tutorials disabled")
	board.context_help.reset_button.pressed.emit()
	check(board.tutorial_journal.counts[str(number)] == used and board.tutorial_preferences.should_show("subjects"), "reset allows relearning without bypassing the round cap")
	board.context_help.dismiss()
	board.tutorial_preferences.set_automatic(false)
	check(board.session.checkpoint() == authority, "all Help settings preserve simulation and choices")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	await playback_checks()
	board.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(preference_path))
	print("Context tutorials: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func choices() -> void:
	for attempt in range(12):
		if board.session.pending_choice.is_empty(): return
		var choice: Dictionary = {"market": "Pass"}
		if board.session.pending_choice.action == "game_draw_choice": choice = {"keep_id": board.session.board_view().world.game_economy.stockpile_pending.card_ids[0]}
		board._economy(choice)
		var deadline: int = Time.get_ticks_msec() + 90000
		while board._job != null and Time.get_ticks_msec() < deadline: await process_frame
		check(board._job == null, "economy worker completes")
		await process_frame

func job_done() -> void:
	var deadline: int = Time.get_ticks_msec() + 90000
	while board._job != null and Time.get_ticks_msec() < deadline: await process_frame
	check(board._job == null, "round worker completes with tutorial layer")

func playback_checks() -> void:
	board._goto_flow(5)
	board.pass_round()
	await job_done()
	check(board.playing, "real closing march starts")
	if board.playing:
		var authority: Dictionary = board.session.checkpoint()
		var clock: float = board.clock
		board._open_context_help()
		for frame in range(3): await process_frame
		check(board.context_help.visible and board.clock == clock and board.session.checkpoint() == authority, "reading Help pauses closing playback without changing combat")
		board.context_help.dismiss()
		board.finish_playback()
		await job_done()
	board.next_round()
	await job_done()
	check(board._opening_playback != null, "real next round has opening playback")
	if board._opening_playback != null:
		var authority: Dictionary = board.session.checkpoint()
		var clock: float = board._opening_clock
		board._open_context_help()
		for frame in range(3): await process_frame
		check(board.context_help.visible and board._opening_clock == clock and board.session.checkpoint() == authority, "reading Help pauses opening playback without changing the prepared round")
		board.context_help.dismiss()
