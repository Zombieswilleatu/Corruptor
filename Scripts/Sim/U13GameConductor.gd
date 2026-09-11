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


# Milestone 1 owns setup and round advancement. Victory/Veil and the remaining
# Development choices are still pending; a bounded exercise is not a won game.
func start(seed_value: String, lords: Array, castles: Array) -> Dictionary:
	if _owner != null:
		return Data.invalid("game_already_started")
	if lords.size() != 2 or castles.size() != 2:
		return Data.invalid("game_setup_invalid")
	for pid in [0, 1]:
		if lords[pid] not in LORDS or not Slots.selection_valid(castles[pid]) or castles[pid][0] != "Keep":
			return Data.invalid("game_loadout_invalid")
	var schema: Dictionary = Scenario.loadout_world(lords, castles)
	if schema.get("action") == "invalid":
		return schema
	var opening: Dictionary = Economy.initialize(schema, seed_value)
	if opening.action == "invalid":
		return opening
	var candidate = Content.new().create_combat_match()
	var result: Dictionary = candidate.start(seed_value, opening.world, [0, 1])
	if result.action != "invalid":
		_owner = candidate
	return result


func step() -> Dictionary:
	if _owner == null:
		return Data.invalid("game_not_started")
	return _owner.run_next_hook()


func to_planning() -> Dictionary:
	if _owner == null:
		return Data.invalid("game_not_started")
	while _owner.next_hook() != Timeline.SUBMISSION_LOCK:
		if _owner.next_hook().is_empty():
			return Data.invalid("game_round_complete")
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
	var candidate = Content.new().create_combat_match()
	var restored: Dictionary = candidate.restore(_owner.snapshot())
	if restored.action == "invalid":
		return restored
	for pid in [0, 1]:
		var choice = plans[pid]
		if typeof(choice) != TYPE_DICTIONARY or typeof(choice.get("powers")) != TYPE_ARRAY or typeof(choice.get("order")) != TYPE_DICTIONARY:
			return Data.invalid("game_plan_invalid")
		var accepted: Dictionary = candidate.submit(pid, choice.powers, choice.order)
		if accepted.action == "invalid":
			return accepted
	_owner = candidate
	return {"action": "game_submitted"}


func finish_round() -> Dictionary:
	if _owner == null:
		return Data.invalid("game_not_started")
	while not _owner.next_hook().is_empty():
		var result: Dictionary = step()
		if result.action == "invalid":
			return result
	return {"action": "game_round_complete", "round": _owner.round_number()}


func next_round() -> Dictionary:
	if _owner == null:
		return Data.invalid("game_not_started")
	return _owner.begin_next_round([0, 1])


func player_view(player_id: int) -> Dictionary:
	return Data.invalid("game_not_started") if _owner == null else _owner.player_view(player_id)


func snapshot() -> Dictionary:
	return {} if _owner == null else _owner.snapshot()


func restore(raw: Dictionary) -> Dictionary:
	var candidate = Content.new().create_combat_match()
	var result: Dictionary = candidate.restore(raw)
	if result.action != "invalid":
		_owner = candidate
	return result
