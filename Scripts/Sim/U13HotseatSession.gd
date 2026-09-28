extends "res://Scripts/Sim/U13PlayableSession.gd"

const Perspective = preload("res://Scripts/Sim/U13HotseatPerspective.gd")
const HotGame = preload("res://Scripts/Sim/U13HotseatGame.gd")
const HOTSEAT_VERSION: String = "U13_HOTSEAT_SAVE_V1"
var active_seat: int = 0
var first_planner: int = 0
var watch_mode: String = "own_turn"
var sealed: Array = [{}, {}]
var replay: Dictionary = {}
var _choice: Dictionary = {}
var _record_cursor: int = 0
var _record_before: Array = [[], []]
var _before_combat: Array = [{}, {}]
var _before_marching: Array = [{}, {}]
var _recorded: Array = [{}, {}]

func is_hotseat() -> bool: return true

func game():
	var result = HotGame.new()
	result._owner = _owner.canonical
	return result

func configure_seed(seed_value: String, lords: Array, castles: Array) -> Dictionary:
	var conductor = HotGame.new()
	var result: Dictionary = conductor.start(seed_value, lords, castles, false, true)
	if result.action == "invalid": return result
	active_seat = 0
	first_planner = 0
	sealed = [{}, {}]
	replay = {}
	_owner = Perspective.new()
	_owner.canonical = conductor._owner
	match_seed = seed_value
	quick_start = false
	hunt_enabled = true
	_clear_round()
	_sync_seat()
	return _to_planning()

func reset(_scenario_index: int = 0) -> Dictionary:
	var w: Dictionary = _owner.canonical.player_view(0, 0).world
	return configure(w.lord_ids, w.castle_loadouts, false)

func _sync_seat() -> void:
	_owner.seat = active_seat
	var world: Dictionary = _owner.player_view(0, 0).world
	setup_lords = world.lord_ids.duplicate(true)
	setup_castles = world.castle_loadouts.duplicate(true)
	pending_choice = Perspective.orient(_choice, active_seat)
	_read_owner = null

func required_seat() -> int:
	if not _choice.is_empty(): return int(_choice.player_id)
	if next_hook() == Timeline.SUBMISSION_LOCK:
		return first_planner if sealed[first_planner].is_empty() else 1 - first_planner
	return active_seat

func switch_to(seat_value: int) -> void:
	assert(seat_value in [0, 1])
	active_seat = seat_value
	# New facade identity invalidates all cached projections/legality previews.
	var facade = Perspective.new()
	facade.canonical = _owner.canonical
	_owner = facade
	_powers = []
	_order = {}
	_opponent = {}
	_lane = "Castle"
	_opening_marching = []
	odradek_visuals = []
	kroni_guard_events = []
	valak_events = []
	kanifous_events = []
	_sync_seat()

func _to_planning() -> Dictionary:
	var conductor = game()
	var cursor: int = _owner._event_cursor()
	var result: Dictionary = conductor.to_planning()
	if result.action == "invalid": return result
	_choice = result.duplicate(true) if result.action in ["game_draw_choice", "game_market_choice"] else {}
	pending_choice = Perspective.orient(_choice, active_seat)
	var events: Array = _owner._player_events_since(0, cursor)
	_opening_marching = events.filter(func(e): return e.data.get("marching_phase") == "opening")
	return result

func choose_economy(choice: Dictionary) -> Dictionary:
	if _choice.is_empty() or required_seat() != active_seat or is_finished():
		return Data.invalid("hotseat_wrong_player")
	var conductor = game()
	var result: Dictionary = conductor.choose_stockpile(active_seat, str(choice.get("keep_id", ""))) if _choice.action == "game_draw_choice" else conductor.choose_market(active_seat, choice)
	if result.action == "invalid": return result
	return _to_planning()

func choose(powers: Array, order: Dictionary) -> Dictionary:
	if required_seat() != active_seat or not sealed[active_seat].is_empty():
		return Data.invalid("hotseat_plan_already_sealed")
	return super.choose(powers, order)

func seal_first(powers: Array, order: Dictionary) -> Dictionary:
	if active_seat != first_planner: return Data.invalid("hotseat_wrong_player")
	var result: Dictionary = choose(powers, order)
	if result.action == "invalid": return result
	sealed[active_seat] = {"powers": _owner.powers_to_match(powers), "order": Perspective.orient(order, active_seat)}
	_powers = []
	_order = {}
	var handed: Dictionary = _owner.canonical.submit_choice(active_seat, {"hotseat_handoff": true})
	if handed.action == "invalid":
		sealed[active_seat] = {}
		return handed
	return _to_planning()

func lock_plans() -> Dictionary:
	if next_hook() != Timeline.SUBMISSION_LOCK or active_seat == first_planner or sealed[first_planner].is_empty():
		return Data.invalid("hotseat_waiting_for_other_player")
	var plans_for_seats: Array = sealed.duplicate(true)
	plans_for_seats[active_seat] = {"powers": _owner.powers_to_match(_powers), "order": Perspective.orient(_order, active_seat)}
	var conductor = game()
	var result: Dictionary = conductor.submit(plans_for_seats)
	if result.action == "invalid": return result
	result = conductor.step()
	if result.action != "invalid":
		_owner.canonical = conductor._owner
		sealed = plans_for_seats
	return result

func summon_preview(cards: Array) -> Dictionary:
	return Perspective.orient(Orias.Resummon.quote(_owner.canonical._world_snapshot(), active_seat, cards), active_seat)

func outcome() -> Dictionary:
	return Perspective.orient(game().outcome(), active_seat)

func next_round() -> Dictionary:
	if is_finished(): return outcome()
	if not next_hook().is_empty(): return Data.invalid("hotseat_round_not_finished")
	var result: Dictionary = game().next_round()
	if result.action == "invalid": return result
	first_planner = 1 - first_planner
	sealed = [{}, {}]
	_clear_round()
	return _to_planning()

func run_to_marching() -> Dictionary:
	_record_cursor = _owner._event_cursor()
	for pid_value in [0, 1]: _record_before[pid_value] = _owner.canonical.player_view(pid_value, 0).world.entities
	_before_combat = [{}, {}]
	_before_marching = [{}, {}]
	_recorded = [{}, {}]
	var result: Dictionary = super.run_to_marching()
	if result.action == "invalid": return result
	for pid_value in [0, 1]:
		var events: Array = _owner.canonical._player_events_since(pid_value, _record_cursor)
		var visuals = get_script().new()
		visuals._owner = _owner
		visuals._capture_odradek_visuals(_record_before[pid_value], events)
		_recorded[pid_value] = {
			"special": {"odradek_visuals": visuals.odradek_visuals, "kroni_guard_events": events.filter(func(e): return e.type == "GUARD_DEVOURED"), "valak_events": events.filter(func(e): return e.type.begins_with("VALAK_") or e.type == "GRAVITY_ORB_STARTED"), "kanifous_events": events.filter(func(e): return e.type.begins_with("KANIFOUS_") or e.type.begins_with("WISHMASTER_"))},
			"presented": _before_marching[pid_value],
			"resolution": {"before": _before_combat[pid_value], "events": events},
			"events": events,
			"artillery_events": events.filter(func(e): return e.type == "ARTILLERY_FIRED"),
			"marching_events": events.filter(func(e): return e.data.get("marching_phase") != "opening"),
			"before": _before_combat[pid_value].get("world", {})
		}
	return result

func step() -> Dictionary:
	if next_hook() == Timeline.COMBAT_RESOLUTION:
		for pid_value in [0, 1]: _before_combat[pid_value] = _owner.canonical.player_view(pid_value, 15)
	if next_hook() == Timeline.MARCHING:
		for pid_value in [0, 1]: _before_marching[pid_value] = _owner.canonical.player_view(pid_value, 15)
	return super.step()

func retire_completed_visual_samples() -> int:
	var retired: int = super.retire_completed_visual_samples()
	if not _recorded[0].is_empty():
		var seen: Array = [watch_mode == "together", watch_mode == "together"]
		seen[active_seat] = true
		replay = {"round": round_number(), "match": _owner.canonical.snapshot(), "seats": _recorded.duplicate(true), "seen": seen}
		_recorded = [{}, {}]
	return retired

func has_replay(pid_value: int) -> bool:
	return not replay.is_empty() and not replay.seen[pid_value]

func replay_session(pid_value: int):
	if not has_replay(pid_value): return null
	var conductor = HotGame.new()
	if conductor.restore(replay.match).action == "invalid": return null
	var result = get_script().new()
	result._owner = Perspective.new()
	result._owner.canonical = conductor._owner
	result.active_seat = pid_value
	result.watch_mode = watch_mode
	result.first_planner = first_planner
	result.match_seed = match_seed
	result.hunt_enabled = true
	result.quick_start = false
	result._sync_seat()
	var tape: Dictionary = Perspective.orient(replay.seats[pid_value], pid_value)
	result._last_marching = tape.marching_events
	for property in tape.get("special", {}): result.set(property, tape.special[property])
	return result

func _fork_for_job():
	var candidate = super._fork_for_job()
	if candidate == null: return null
	for property in ["active_seat", "first_planner", "watch_mode", "_record_cursor"]: candidate.set(property, get(property))
	for property in ["sealed", "replay", "_choice", "_record_before", "_before_combat", "_before_marching", "_recorded"]: candidate.set(property, get(property).duplicate(true))
	return candidate

func checkpoint() -> Dictionary:
	return {"version": HOTSEAT_VERSION, "match": _owner.canonical.snapshot(), "active_seat": active_seat, "first_planner": first_planner, "watch_mode": watch_mode, "sealed": sealed.duplicate(true), "replay": replay.duplicate(true), "choice": _choice.duplicate(true), "lane": _lane, "powers": _powers.duplicate(true) if next_hook() == Timeline.SUBMISSION_LOCK else [], "order": _order.duplicate(true) if next_hook() == Timeline.SUBMISSION_LOCK else {}}

func restore_checkpoint(raw: Dictionary) -> Dictionary:
	if not Data.is_data(raw) or raw.get("version") != HOTSEAT_VERSION or raw.get("active_seat") not in [0, 1] or raw.get("first_planner") not in [0, 1] or raw.get("watch_mode") not in ["own_turn", "together"] or typeof(raw.get("match")) != TYPE_DICTIONARY or typeof(raw.get("sealed")) != TYPE_ARRAY or raw.sealed.size() != 2 or typeof(raw.get("replay")) != TYPE_DICTIONARY or typeof(raw.get("choice")) != TYPE_DICTIONARY or typeof(raw.get("powers")) != TYPE_ARRAY or typeof(raw.get("order")) != TYPE_DICTIONARY or raw.get("lane") not in ["Lord", "Castle"]:
		return Data.invalid("hotseat_save_invalid")
	var conductor = HotGame.new()
	var checked: Dictionary = conductor.restore(raw.match)
	if checked.action == "invalid": return checked
	if conductor._owner.next_hook() not in [Timeline.PRESENT_PUBLIC_STATE, Timeline.SUBMISSION_LOCK, ""]: return Data.invalid("hotseat_save_not_a_pause")
	var w: Dictionary = conductor._owner.player_view(0, 0).world
	if raw.first_planner != (conductor._owner.round_number() - 1) % 2: return Data.invalid("hotseat_save_turn_order_invalid")
	var phase: String = conductor._owner.next_hook()
	var economy_state: Dictionary = conductor._owner._world.data.hotseat_economy
	var expected: Dictionary = {}
	if not w.game_economy.stockpile_pending.is_empty(): expected = {"action": "game_draw_choice", "player_id": w.game_economy.stockpile_pending.player_id}
	elif w.game_market.seat != 2: expected = {"action": "game_market_choice", "player_id": w.game_market.seat}
	if raw.choice != expected: return Data.invalid("hotseat_save_choice_mismatch")
	for pid_value in [0, 1]:
		var plan = raw.sealed[pid_value]
		if typeof(plan) != TYPE_DICTIONARY: return Data.invalid("hotseat_save_plan_invalid")
		if not plan.is_empty() and (typeof(plan.get("powers")) != TYPE_ARRAY or typeof(plan.get("order")) != TYPE_DICTIONARY): return Data.invalid("hotseat_save_plan_invalid")
		if not plan.is_empty() and conductor._owner.next_hook() == Timeline.SUBMISSION_LOCK:
			checked = conductor._owner.preview_submission(pid_value, plan.powers, plan.order)
			if checked.action == "invalid": return checked
	if phase == Timeline.PRESENT_PUBLIC_STATE and raw.sealed != [{}, {}]: return Data.invalid("hotseat_save_early_commit")
	if phase == Timeline.SUBMISSION_LOCK:
		if not raw.sealed[1 - raw.first_planner].is_empty(): return Data.invalid("hotseat_save_second_commit")
		if economy_state.actor == raw.first_planner and not raw.sealed[raw.first_planner].is_empty(): return Data.invalid("hotseat_save_actor_mismatch")
		if economy_state.actor != raw.first_planner and raw.sealed[raw.first_planner].is_empty(): return Data.invalid("hotseat_save_missing_commit")
	if not raw.replay.is_empty():
		if typeof(raw.replay.get("match")) != TYPE_DICTIONARY or typeof(raw.replay.get("seats")) != TYPE_ARRAY or raw.replay.seats.size() != 2 or typeof(raw.replay.get("seen")) != TYPE_ARRAY or raw.replay.seen.size() != 2: return Data.invalid("hotseat_save_replay_invalid")
		if raw.replay.get("round", 0) not in [conductor._owner.round_number(), conductor._owner.round_number() - 1] or raw.replay.seen.any(func(seen): return typeof(seen) != TYPE_BOOL): return Data.invalid("hotseat_save_replay_clock")
		var replay_game = HotGame.new()
		checked = replay_game.restore(raw.replay.match)
		if checked.action == "invalid" or replay_game._owner.rng_seed() != conductor._owner.rng_seed() or replay_game._owner.round_number() != raw.replay.round or not replay_game._owner.next_hook().is_empty(): return Data.invalid("hotseat_save_replay_match")
		for tape in raw.replay.seats:
			if typeof(tape) != TYPE_DICTIONARY: return Data.invalid("hotseat_save_replay_tape")
			for key in ["presented", "resolution", "before"]:
				if typeof(tape.get(key)) != TYPE_DICTIONARY: return Data.invalid("hotseat_save_replay_tape")
			for key in ["events", "artillery_events", "marching_events"]:
				if typeof(tape.get(key)) != TYPE_ARRAY: return Data.invalid("hotseat_save_replay_tape")
	_owner = Perspective.new()
	_owner.canonical = conductor._owner
	active_seat = raw.active_seat
	first_planner = raw.first_planner
	watch_mode = raw.watch_mode
	sealed = raw.sealed.duplicate(true)
	replay = raw.replay.duplicate(true)
	_choice = expected
	match_seed = conductor._owner.rng_seed()
	hunt_enabled = true
	quick_start = false
	_clear_round()
	_sync_seat()
	_lane = raw.lane
	_powers = raw.powers.duplicate(true)
	_order = raw.order.duplicate(true)
	if next_hook() == Timeline.SUBMISSION_LOCK and sealed[active_seat].is_empty():
		checked = _owner.preview_submission(0, _powers, _order)
		if checked.action == "invalid": return checked
	return {"action": "hotseat_restored"}
