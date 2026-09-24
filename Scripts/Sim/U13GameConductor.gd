extends RefCounted

const Content = preload("res://Scripts/Sim/U13GameContent.gd")
const Scenario = preload("res://Scripts/Sim/U13KanifousScenario.gd")
const Economy = preload("res://Scripts/Sim/U13GameEconomy.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const GameBot = preload("res://Scripts/Sim/U13GameRandomLegal.gd")
const LORDS: Array = ["Gremory", "Deimos", "Humbaba", "Kalligan", "Orias", "Odradek", "Kroni", "Valak", "Kanifous"]
var _owner


# Owns setup, round advancement and terminal outcomes. Permanent Veil arrivals
# resolve at round start; automatic neutral pressure starts after round 12.
func start(seed_value: String, lords: Array, castles: Array, compact_events: bool = false, promoted_rules: bool = false, defensive_pressure: bool = true) -> Dictionary:
	if _owner != null:
		return Data.invalid("game_already_started")
	if lords.size() != 2 or castles.size() != 2:
		return Data.invalid("game_setup_invalid")
	for pid in [0, 1]:
		if lords[pid] not in LORDS or not Slots.selection_valid(castles[pid]):
			return Data.invalid("game_loadout_invalid")
	var schema: Dictionary = Scenario.loadout_world(lords, castles)
	if schema.get("action") == "invalid":
		return schema
	var opening: Dictionary = Economy.initialize(schema, seed_value)
	if opening.action == "invalid":
		return opening
	Content.Staging.configure(opening.world)
	if promoted_rules:
		Content.SplitWard.configure(opening.world)
		if defensive_pressure: preload("res://Scripts/Sim/U13Embolden.gd").configure(opening.world)
	var candidate = Content.new().create_combat_match(compact_events)
	var result: Dictionary = candidate.start(seed_value, opening.world, [0, 1])
	if result.action != "invalid":
		_owner = candidate
	return result


func step(timings: Dictionary = {}) -> Dictionary:
	if _owner == null:
		return Data.invalid("game_not_started")
	return _owner.run_next_hook(timings)


func to_planning(random_choices: bool = false) -> Dictionary:
	if _owner == null:
		return Data.invalid("game_not_started")
	if is_finished():
		return outcome()
	while _owner.next_hook() != Timeline.SUBMISSION_LOCK:
		if _owner.next_hook().is_empty():
			return outcome() if is_finished() else Data.invalid("game_round_complete")
		var flow: Dictionary = _flow_view(0)
		var pending: Dictionary = flow.game_economy.stockpile_pending
		if not pending.is_empty():
			var pid: int = pending.player_id
			if not random_choices:
				return {"action": "game_draw_choice", "player_id": pid}
			var offered: Array = _flow_view(pid).game_economy.stockpile_pending.card_ids
			var index: int = int(Economy.Rng.draw(_owner.rng_seed(), "STOCKPILE_RANDOM_V1", "%d:%d" % [_owner.round_number(), pid], 0, offered.size()).value)
			var selected: Dictionary = choose_stockpile(pid, offered[index])
			if selected.action == "invalid":
				return selected
			continue
		var market: Dictionary = flow.game_market
		if market.seat != 2:
			if not random_choices:
				return {"action": "game_market_choice", "player_id": market.seat}
			var options: Array = market_choices(market.seat)
			var index: int = int(Economy.Rng.draw(_owner.rng_seed(), "MARKET_RANDOM_V1", "%d:%d" % [_owner.round_number(), market.seat], 0, options.size()).value)
			var selected: Dictionary = choose_market(market.seat, options[index])
			if selected.action == "invalid":
				return selected
			continue
		var result: Dictionary = step()
		if result.action == "invalid":
			return result
	return {"action": "game_planning", "round": _owner.round_number()}


func plan(player_id: int) -> Dictionary:
	if player_id not in [0, 1] or _owner == null or _owner.next_hook() != Timeline.SUBMISSION_LOCK:
		return Data.invalid("game_not_planning")
	return GameBot.plan(_owner, player_id)


func submit(plans: Array) -> Dictionary:
	if _owner == null or plans.size() != 2 or _owner.next_hook() != Timeline.SUBMISSION_LOCK:
		return Data.invalid("game_submissions_invalid")
	# Both plans use one public snapshot. An invalid second submission must not
	# leave the first committed, paid, or queued in the live owner.
	# This is an internal transaction over an already-owned match. Keep its
	# live consistency checks and isolated mutable state, without loading the
	# growing event history through the external save-validation boundary.
	var candidate = _owner._clone()
	if candidate == null:
		return Data.invalid("match_clone_failed")
	for pid in [0, 1]:
		var choice = plans[pid]
		if typeof(choice) != TYPE_DICTIONARY or typeof(choice.get("powers")) != TYPE_ARRAY or typeof(choice.get("order")) != TYPE_DICTIONARY:
			return Data.invalid("game_plan_invalid")
		var accepted: Dictionary = candidate.submit(pid, choice.powers, choice.order)
		if accepted.action == "invalid":
			return accepted
	_owner = candidate
	return {"action": "game_submitted"}


func finish_round(hook_timings: Array = []) -> Dictionary:
	if _owner == null:
		return Data.invalid("game_not_started")
	while not _owner.next_hook().is_empty():
		var hook: String = _owner.next_hook()
		var started: int = Time.get_ticks_usec()
		var detail: Dictionary = {"hook": hook}
		var result: Dictionary = step(detail)
		detail["ms"] = (Time.get_ticks_usec() - started) / 1000.0
		hook_timings.append(detail)
		if result.action == "invalid":
			return result
	return outcome() if is_finished() else {"action": "game_round_complete", "round": _owner.round_number()}


func next_round() -> Dictionary:
	if _owner == null:
		return Data.invalid("game_not_started")
	return _owner.begin_next_round([0, 1])


func player_view(player_id: int) -> Dictionary:
	return Data.invalid("game_not_started") if _owner == null else _owner.player_view(player_id)


func snapshot() -> Dictionary:
	return {} if _owner == null else _owner.snapshot()


func restore(raw: Dictionary) -> Dictionary:
	var policy = raw.get("policy_id", "")
	var compact: bool = typeof(policy) == TYPE_STRING and policy.ends_with(":" + Content.BATCH_EVENTS_VERSION)
	var candidate = Content.new().create_combat_match(compact)
	var result: Dictionary = candidate.restore(raw)
	if result.action != "invalid":
		_owner = candidate
	return result


func choose_stockpile(player_id: int, keep_id: String) -> Dictionary:
	return Data.invalid("game_not_started") if _owner == null else _owner.submit_choice(player_id, {"keep_id": keep_id})


func market_choices(player_id: int) -> Array:
	if _owner == null or player_id not in [0, 1] or _owner.next_hook() != Timeline.PRESENT_PUBLIC_STATE:
		return []
	var view: Dictionary = _flow_view(player_id)
	if view.game_market.seat != player_id:
		return []
	var choices: Array = [{"market": "Pass"}]
	for take in view.market:
		for give in view.hand:
			choices.append({"market": "Swap", "take_id": take, "give_id": give})
	return choices

func choose_market(player_id: int, choice: Dictionary) -> Dictionary:
	if not choice.has("market"):
		return Data.invalid("market_choice_invalid")
	return Data.invalid("game_not_started") if _owner == null else _owner.submit_choice(player_id, choice)


func is_finished() -> bool:
	return _owner != null and _owner.is_finished()


func outcome() -> Dictionary:
	if _owner == null:
		return Data.invalid("game_not_started")
	var state: Dictionary = _flow_view(0).victory
	return {"action": "game_finished" if state.winner != -1 else "game_in_progress", "round": _owner.round_number(), "winner": state.winner, "win_by": state.win_by}


# Godot's JSON float parser can change the last bit even with full_precision.
# Keep a JSON envelope, with a lossless Variant payload restricted to plain data.
static func encode_snapshot(snapshot_data: Dictionary) -> String:
	return JSON.stringify({"codec": "U13_GAME_JSON_SAVE_V1", "payload": Marshalls.raw_to_base64(var_to_bytes(snapshot_data))})


func snapshot_json() -> String:
	return encode_snapshot(snapshot())


func restore_json(encoded: String) -> Dictionary:
	var envelope = JSON.parse_string(encoded)
	if typeof(envelope) != TYPE_DICTIONARY or envelope.size() != 2 or envelope.get("codec") != "U13_GAME_JSON_SAVE_V1" or typeof(envelope.get("payload")) != TYPE_STRING:
		return Data.invalid("game_json_invalid")
	var decoded = bytes_to_var(Marshalls.base64_to_raw(envelope.payload))
	if typeof(decoded) != TYPE_DICTIONARY:
		return Data.invalid("game_json_invalid")
	return restore(decoded)


# Internal conductor flow reads need no entity, guard, effect or history projection.
# Preserve the public view's pre-submission baseline and Stockpile redaction.
# Every returned container is detached; no authoritative reference escapes.
func _flow_view(player_id: int) -> Dictionary:
	var world: Dictionary = _owner._presentation_world if _owner.next_hook() == Timeline.SUBMISSION_LOCK else _owner._world
	var pending: Dictionary = world.data.game_economy.stockpile_pending
	return Data.copy_data({
		"game_economy": {"stockpile_pending": pending if pending.is_empty() or pending.player_id == player_id else {"player_id": pending.player_id}},
		"game_market": world.data.game_market,
		"market": world.data.card_zones.market,
		"hand": world.data.card_zones.hands[player_id],
		"victory": world.data.victory
	})
