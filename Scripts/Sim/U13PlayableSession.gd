extends "res://Scripts/Sim/U13LoadoutBoardSession.gd"

# Production match authority with the existing board's animation capture.
# UI choices belong to seat 0; seat 1 sees only the doctrine planning facade.
const Game = preload("res://Scripts/Sim/U13GameConductor.gd")
const Doctrine = preload("res://Scripts/Sim/U13BasicDoctrine.gd")
const SAVE_VERSION: String = "U13_PLAYABLE_SAVE_V1"
var pending_choice: Dictionary = {}
var match_seed: String = ""
var _read_owner
var _read_revision: int = -1
var _board_cache: Dictionary = {}
var _planning_cache
var _preview_cache: Dictionary = {}
var _summon_cache: Dictionary = {}
var _finished_known: bool = false
var _finished_value: bool = false

func _sync_read_cache() -> void:
	var revision: int = -1 if _owner == null else _owner.revision()
	if _read_owner == _owner and _read_revision == revision:
		return
	_read_owner = _owner
	_read_revision = revision
	_board_cache = {}
	_planning_cache = null
	_preview_cache = {}
	_summon_cache = {}
	_finished_known = false

func board_view() -> Dictionary:
	_sync_read_cache()
	if _board_cache.is_empty():
		_board_cache = super.board_view()
	return _board_cache.duplicate(true)

func power_status(power: String) -> Dictionary:
	var view: Dictionary = board_view()
	var result: Dictionary = {"remaining": 0, "ready_round": round_number(), "fire_round": 0, "awaiting_expiration": false}
	for row in view.cooldowns:
		var source: Dictionary = row.get("declaration", {})
		if source.get("player_id") == 0 and source.get("power_id") == power:
			result.awaiting_expiration = row.get("phase") == "awaiting_expiration"
			result.ready_round = int(row.ready_round)
			result.remaining = maxi(0, result.ready_round - round_number())
	for row in view.pending:
		var source: Dictionary = row.get("declaration", {})
		if source.get("player_id") == 0 and source.get("power_id") == power:
			result.fire_round = int(source.fire_round)
	return result

func _preview_cart(powers: Array, order: Dictionary) -> Dictionary:
	_sync_read_cache()
	if not Data.is_data(powers) or not Data.is_data(order):
		return Data.invalid("submission_data_invalid")
	var key: String = var_to_bytes([powers, order]).hex_encode()
	if not _preview_cache.has(key):
		# Bound spatial target/edited-cart caches during a long planning pause.
		if _preview_cache.size() >= 64:
			_preview_cache = {}
			_planning_cache = null
		if _planning_cache == null:
			_planning_cache = _owner.planning_session(0)
		if _planning_cache == null:
			_preview_cache[key] = _owner.preview_submission(0, powers, order)
		elif not _planning_cache.legal_order_candidates(0, powers, [order]).is_empty():
			_preview_cache[key] = {"action": "legal"}
		else:
			# Preserve precise rejection reasons; live submit still revalidates.
			_preview_cache[key] = _planning_cache.preview_submission(0, powers, order)
	return _preview_cache[key].duplicate(true)

func choose(powers: Array, order: Dictionary) -> Dictionary:
	if next_hook() != Timeline.SUBMISSION_LOCK:
		return Data.invalid("planning_closed")
	var result: Dictionary = _preview_cart(powers, order)
	if result.action != "invalid":
		_powers = powers.duplicate(true)
		_order = order.duplicate(true)
	return result

func preview() -> Dictionary:
	return _preview_cart(_powers, _order)

func preview_power(power: String, target: Dictionary, queued: Array, order: Dictionary) -> Dictionary:
	var draft: Array = queued.duplicate(true)
	draft.append(declaration(power, draft.size(), target))
	return _preview_cart(draft, order)

func summon_preview(cards: Array) -> Dictionary:
	_sync_read_cache()
	if not Data.is_data(cards):
		return Data.invalid("summon_choice_invalid")
	var key: String = var_to_bytes(cards).hex_encode()
	if not _summon_cache.has(key):
		if _summon_cache.size() >= 64: _summon_cache = {}
		_summon_cache[key] = super.summon_preview(cards)
	return _summon_cache[key].duplicate(true)

func game():
	var result = Game.new()
	result._owner = _owner
	return result

func configure(lords: Array, castles: Array, _quick: bool = false) -> Dictionary:
	var seed_value: String = str(Time.get_unix_time_from_system()) + ":" + str(Time.get_ticks_usec())
	return configure_seed(seed_value, lords, castles)

func configure_seed(seed_value: String, lords: Array, castles: Array) -> Dictionary:
	var candidate = Game.new()
	var result: Dictionary = candidate.start(seed_value, lords, castles)
	if result.action == "invalid":
		return result
	_owner = candidate._owner
	setup_lords = lords.duplicate(true)
	setup_castles = castles.duplicate(true)
	match_seed = seed_value
	quick_start = false
	hunt_enabled = true
	_lane = "Castle"
	_clear_round()
	return _to_planning()

func _clear_round() -> void:
	_powers = []
	_order = {}
	_opponent = {}
	_last_marching = []
	_artillery_events = []
	pending_choice = {}
	odradek_visuals = []
	kroni_guard_events = []
	valak_events = []
	kanifous_events = []

func random_opponent_plan() -> Dictionary:
	return Doctrine.plan(_owner, 1)

func lock_plans() -> Dictionary:
	if is_finished() or next_hook() != Timeline.SUBMISSION_LOCK:
		return Data.invalid("planning_closed")
	# Choose before either seat commits. Never give the bot the human cart.
	var opponent: Dictionary = random_opponent_plan()
	if opponent.get("action") == "invalid":
		return opponent
	var candidate = game()
	var result: Dictionary = candidate.submit([plans(), opponent])
	if result.action == "invalid":
		return result
	result = candidate.step()
	if result.action != "invalid":
		_owner = candidate._owner
		_opponent = opponent
	return result

func _to_planning() -> Dictionary:
	var conductor = game()
	var cursor: int = _owner._event_cursor()
	var before: Array = _owner.player_view(0, 0).world.entities
	for attempt in range(12):
		var result: Dictionary = conductor.to_planning()
		if result.action in ["game_draw_choice", "game_market_choice"] and result.player_id == 1:
			result = Doctrine.resolve_choice(conductor, result)
			if result.action == "invalid":
				return result
			continue
		pending_choice = result.duplicate(true) if result.action in ["game_draw_choice", "game_market_choice"] else {}
		var events: Array = _owner._player_events_since(0, cursor)
		_capture_odradek_visuals(before, events)
		for event in events:
			if event.type == "GUARD_DEVOURED":
				kroni_guard_events.append(event)
			if event.type.begins_with("KANIFOUS_") or event.type.begins_with("WISHMASTER_"):
				kanifous_events.append(event)
			if event.type.begins_with("VALAK_") or event.type == "GRAVITY_ORB_STARTED":
				valak_events.append(event)
		return result
	return Data.invalid("playable_choice_limit")

func choose_economy(choice: Dictionary) -> Dictionary:
	if pending_choice.get("player_id", -1) != 0 or is_finished():
		return Data.invalid("playable_no_human_choice")
	var conductor = game()
	var result: Dictionary
	if pending_choice.action == "game_draw_choice":
		result = conductor.choose_stockpile(0, str(choice.get("keep_id", "")))
	else:
		result = conductor.choose_market(0, choice)
	if result.action == "invalid":
		return result
	return _to_planning()

func next_round() -> Dictionary:
	if is_finished():
		return outcome()
	var result: Dictionary = game().next_round()
	if result.action == "invalid":
		return result
	_clear_round()
	return _to_planning()

func is_finished() -> bool:
	_sync_read_cache()
	if not _finished_known:
		_finished_value = _owner != null and _owner.is_finished()
		_finished_known = true
	return _finished_value

func outcome() -> Dictionary:
	return game().outcome()

func _fork_for_job():
	var candidate = super._fork_for_job()
	if candidate != null:
		candidate.pending_choice = pending_choice.duplicate(true)
		candidate.match_seed = match_seed
	return candidate

func debug_action(_action: String, _pid: int, _lane_value: String) -> Dictionary:
	return Data.invalid("playable_debug_disabled")

func checkpoint() -> Dictionary:
	var planning: bool = next_hook() == Timeline.SUBMISSION_LOCK
	return {"version": SAVE_VERSION, "match": _owner.snapshot(), "lane": _lane,
		"pending_choice": pending_choice.duplicate(true), "powers": _powers.duplicate(true) if planning else [],
		"order": _order.duplicate(true) if planning else {}}

func restore_checkpoint(raw: Dictionary) -> Dictionary:
	if not Data.is_data(raw) or raw.get("version") != SAVE_VERSION or typeof(raw.get("match")) != TYPE_DICTIONARY or raw.get("lane") not in ["Lord", "Castle"] or typeof(raw.get("pending_choice")) != TYPE_DICTIONARY or typeof(raw.get("powers")) != TYPE_ARRAY or typeof(raw.get("order")) != TYPE_DICTIONARY:
		return Data.invalid("playable_save_invalid")
	var conductor = Game.new()
	var result: Dictionary = conductor.restore(raw.match)
	if result.action == "invalid":
		return result
	var world: Dictionary = conductor._owner.player_view(0, 0).world
	var expected: Dictionary = {}
	if not world.game_economy.stockpile_pending.is_empty():
		expected = {"action": "game_draw_choice", "player_id": world.game_economy.stockpile_pending.player_id}
	elif world.game_market.seat != 2:
		expected = {"action": "game_market_choice", "player_id": world.game_market.seat}
	if raw.pending_choice != expected:
		return Data.invalid("playable_save_choice_mismatch")
	if not expected.is_empty() and expected.player_id != 0:
		return Data.invalid("playable_save_not_human_choice")
	if expected.is_empty() and conductor._owner.next_hook() not in [Timeline.SUBMISSION_LOCK, ""]:
		return Data.invalid("playable_save_not_a_pause")
	if conductor._owner.next_hook() == Timeline.SUBMISSION_LOCK:
		result = conductor._owner.preview_submission(0, raw.powers, raw.order)
		if result.action == "invalid":
			return result
	elif not raw.powers.is_empty() or not raw.order.is_empty():
		# Resolution saves store no editable cart; declarations are in the match.
		return Data.invalid("playable_save_draft_phase")
	_owner = conductor._owner
	setup_lords = world.lord_ids.duplicate(true)
	setup_castles = world.castle_loadouts.duplicate(true)
	match_seed = _owner.rng_seed()
	hunt_enabled = true
	quick_start = false
	_clear_round()
	_lane = raw.lane
	pending_choice = expected
	_powers = raw.powers.duplicate(true)
	_order = raw.order.duplicate(true)
	return {"action": "playable_restored"}
