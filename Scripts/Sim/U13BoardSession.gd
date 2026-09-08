class_name U13BoardSession
extends "res://Scripts/Sim/U13SmokeSession.gd"

# The board has manual submissions; inherited methods only drive the U13 owner.
const RandomLegal = preload("res://Scripts/Sim/U13RandomLegal.gd")
const Candidates = preload("res://Scripts/Sim/U13GremoryCandidates.gd")
var _artillery_events: Array = []
var _powers: Array = []
var _order: Dictionary = {}
var _opponent: Dictionary = {}


func reset(scenario: int = 0) -> Dictionary:
	_powers = []
	_order = {}
	_opponent = {}
	return super.reset(scenario)


func next_round() -> Dictionary:
	var result: Dictionary = super.next_round()
	if result.action != "invalid":
		_powers = []
		_order = {}
		_opponent = {}
	return result


func choose(powers: Array, order: Dictionary) -> Dictionary:
	if next_hook() != Timeline.SUBMISSION_LOCK:
		return Data.invalid("planning_closed")
	var result: Dictionary = _owner.preview_submission(0, powers, order)
	if result.action != "invalid":
		_powers = powers.duplicate(true)
		_order = order.duplicate(true)
	return result


func declaration(
	power: String, index: int, target: Dictionary, cost: Dictionary = {}
) -> Dictionary:
	return _source(0, power, index, target, cost)


func plans() -> Dictionary:
	return {"powers": _powers.duplicate(true), "order": _order.duplicate(true)}


func preview() -> Dictionary:
	return _owner.preview_submission(0, _powers, _order)


func lock_plans() -> Dictionary:
	if next_hook() != Timeline.SUBMISSION_LOCK:
		return Data.invalid("planning_closed")
	if _opponent.is_empty():
		_opponent = random_opponent_plan()
		if _opponent.get("action") == "invalid":
			return _opponent
	var before = _owner._clone()
	if before == null:
		return Data.invalid("match_clone_failed")
	for pid in [0, 1]:
		var selected: Dictionary = plans() if pid == 0 else _opponent
		var result: Dictionary = _owner.submit(pid, selected.powers, selected.order)
		if result.action == "invalid":
			_owner = before
			return result
	var result: Dictionary = _owner.run_next_hook()
	if result.action == "invalid":
		_owner = before
	return result


# Reuse the same legality/chooser path as headless frequency batches.
func random_opponent_plan() -> Dictionary:
	return RandomLegal.plan(_owner, 1, Callable(Candidates, "enumerate"))


# Read-only UI status from the same public clocks used by the owner.
func power_status(power: String) -> Dictionary:
	var result: Dictionary = {
		"remaining": 0, "ready_round": round_number(), "fire_round": 0, "awaiting_expiration": false
	}
	var public: Dictionary = _owner.player_view(0, 0)
	for row in public.cooldowns:
		var source: Dictionary = row.get("declaration", {})
		if source.get("player_id") == 0 and source.get("power_id") == power:
			result.awaiting_expiration = row.get("phase") == "awaiting_expiration"
			result.ready_round = int(row.ready_round)
			result.remaining = maxi(0, result.ready_round - round_number())
	for row in public.pending:
		var source: Dictionary = row.get("declaration", {})
		if source.get("player_id") == 0 and source.get("power_id") == power:
			result.fire_round = int(source.fire_round)
	return result


func board_view() -> Dictionary:
	return _owner.player_view(0, 15)


# The worker gets independent mutable state. Match forks share only immutable
# past event rows and stateless content callbacks, just like hook transactions.
func _fork_for_job():
	var candidate = get_script().new()
	candidate._owner = _owner._clone()
	if candidate._owner == null:
		return null
	candidate._scenario = _scenario
	candidate._lane = _lane
	candidate._last_marching = _last_marching
	candidate._powers = _powers.duplicate(true)
	candidate._order = _order.duplicate(true)
	candidate._opponent = _opponent.duplicate(true)
	return candidate


func run_to_marching() -> Dictionary:
	_artillery_events = []
	return super.run_to_marching()


func step() -> Dictionary:
	var capture: bool = next_hook() == Timeline.POST_REPAIR_ARTILLERY
	var cursor: int = _owner._event_cursor() if capture else 0
	var result: Dictionary = super.step()
	if capture and result.action != "invalid":
		for event in _owner._player_events_since(0, cursor):
			if event.type == "ARTILLERY_FIRED":
				_artillery_events.append(event)
	return result


func artillery_events() -> Array:
	return _artillery_events.duplicate(true)
