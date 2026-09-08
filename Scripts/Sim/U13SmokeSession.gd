class_name U13SmokeSession
extends RefCounted

const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const MatchOwner = preload("res://Scripts/Sim/U13Match.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const SCENARIOS: Array = ["Predator clash", "Siege & spoils", "Prepared Ruin"]
const SEED: String = "u13_smoke_20260908_v1"
var _owner
var _scenario: int = 0
var _lane: String = "Castle"
var _last_marching: Array = []


func reset(scenario: int = 0) -> Dictionary:
	if scenario < 0 or scenario >= SCENARIOS.size():
		return Data.invalid("smoke_scenario_invalid")
	var content = Gremory.new()
	var candidate = content.create_combat_match()
	var started: Dictionary = candidate.start(SEED, _initial_world(), [0, 1])
	if started.action == "invalid":
		return started
	_owner = candidate
	_scenario = scenario
	_lane = "Castle"
	_last_marching = []
	return _to_planning()


func view() -> Dictionary:
	if _owner == null:
		return Data.invalid("smoke_not_started")
	return _owner.player_view(0)


func next_hook() -> String:
	return "" if _owner == null else _owner.next_hook()


func round_number() -> int:
	return 0 if _owner == null else _owner.round_number()


func scenario() -> int:
	return _scenario


func lane() -> String:
	return _lane


func set_lane(value: String) -> Dictionary:
	if next_hook() != Timeline.SUBMISSION_LOCK or value not in ["Lord", "Castle"]:
		return Data.invalid("smoke_planning_closed")
	_lane = value
	return {"action": "smoke_lane_selected"}


func plans() -> Dictionary:
	if _owner == null:
		return Data.invalid("smoke_not_started")
	var round_value: int = round_number()
	var own_view: Dictionary = view()
	var powers: Array = []
	var order: Dictionary = {}
	# These are declared scenario recipes, not a general opponent doctrine.
	# Costs and targets still pass the exact match preview/submit path.
	if _scenario in [0, 1] and round_value % 2 == 1:
		powers.append(_source(0, Gremory.PREDATOR, 0, {"lane": _lane}))
	if _scenario == 1 and round_value == 1:
		order = {
			"action": "Siege",
			"lane": "Castle",
			"target_id": _castle_id(1),
			"card_ids": own_view.world.hand.slice(0, 2)
		}
	if _scenario == 2 and round_value == 1:
		powers.append(
			_source(
				0,
				Gremory.RUIN,
				0,
				{"entity_id": _castle_id(1)},
				{"discard_ids": own_view.world.hand.slice(0, 2)}
			)
		)
		powers.append(_source(0, Gremory.PREDATOR, 1, {"lane": _lane}))
	var opponent_powers: Array = []
	if _scenario in [0, 1] and round_value % 2 == 1:
		opponent_powers.append(_source(1, Gremory.PREDATOR, 0, {"lane": _lane}))
	return {
		"action": "smoke_plans",
		"powers": powers,
		"order": order,
		"opponent_powers": opponent_powers
	}


func preview() -> Dictionary:
	if next_hook() != Timeline.SUBMISSION_LOCK:
		return Data.invalid("smoke_planning_closed")
	var chosen: Dictionary = plans()
	return _owner.preview_submission(0, chosen.powers, chosen.order)


func lock_plans() -> Dictionary:
	if next_hook() != Timeline.SUBMISSION_LOCK:
		return Data.invalid("smoke_planning_closed")
	var chosen: Dictionary = plans()
	# Validate both queues first and restore if any acceptance fails. The demo
	# never strands a single submitted player or changes plans after locking.
	var before: Dictionary = _owner.snapshot()
	for player_id in [0, 1]:
		var powers: Array = chosen.powers if player_id == 0 else chosen.opponent_powers
		var order: Dictionary = chosen.order if player_id == 0 else {}
		var checked: Dictionary = _owner.preview_submission(player_id, powers, order)
		if checked.action == "invalid":
			return checked
	for player_id in [0, 1]:
		var powers: Array = chosen.powers if player_id == 0 else chosen.opponent_powers
		var order: Dictionary = chosen.order if player_id == 0 else {}
		var submitted: Dictionary = _owner.submit(player_id, powers, order)
		if submitted.action == "invalid":
			_owner.restore(before)
			return submitted
	var locked: Dictionary = _owner.run_next_hook()
	if locked.action == "invalid":
		_owner.restore(before)
	return locked


func step() -> Dictionary:
	if _owner == null or next_hook().is_empty():
		return Data.invalid("smoke_round_complete")
	if next_hook() == Timeline.SUBMISSION_LOCK:
		return lock_plans()
	var hook: String = next_hook()
	var before_view: Dictionary = {}
	var cursor: int = 0
	if hook == Timeline.MARCHING:
		before_view = _owner.player_view(0, 15)
		cursor = _owner._event_cursor()
	var result: Dictionary = _owner.run_next_hook()
	if result.action != "invalid" and hook == Timeline.MARCHING:
		_last_marching = _owner._player_events_since(0, cursor)
		result["before_marching"] = before_view
	return result


# Stops immediately after Marching so the UI can play its tape before Aftermath.
func run_to_marching() -> Dictionary:
	if _owner == null or next_hook().is_empty():
		return Data.invalid("smoke_round_complete")
	if Timeline.hook_rank(next_hook()) > Timeline.hook_rank(Timeline.MARCHING):
		return Data.invalid("smoke_marching_already_finished")
	for index in range(21):
		var hook: String = next_hook()
		var result: Dictionary = step()
		if result.action == "invalid" or hook == Timeline.MARCHING:
			return result
	return Data.invalid("smoke_hook_limit")


func next_round() -> Dictionary:
	if _owner == null or not next_hook().is_empty():
		return Data.invalid("smoke_round_not_complete")
	var begun: Dictionary = _owner.begin_next_round([0, 1])
	if begun.action == "invalid":
		return begun
	return _to_planning()


func marching_events() -> Array:
	return _last_marching.duplicate(true)


# In-memory checkpoint for the smoke controller/tests, never a player projection.
func checkpoint() -> Dictionary:
	return {
		"scenario": _scenario,
		"lane": _lane,
		"match": _owner.snapshot(),
		"marching_events": _last_marching.duplicate(true)
	}


func restore_checkpoint(raw: Dictionary) -> Dictionary:
	if (
		not Data.is_data(raw)
		or not Data.is_integer(raw.get("scenario"))
		or raw.scenario < 0
		or raw.scenario >= SCENARIOS.size()
		or raw.get("lane") not in ["Lord", "Castle"]
		or typeof(raw.get("match")) != TYPE_DICTIONARY
		or typeof(raw.get("marching_events")) != TYPE_ARRAY
	):
		return Data.invalid("smoke_checkpoint_invalid")
	var content = Gremory.new()
	var candidate = content.create_combat_match()
	var restored: Dictionary = candidate.restore(raw.match)
	if restored.action == "invalid":
		return restored
	_owner = candidate
	_scenario = int(raw.scenario)
	_lane = raw.lane
	_last_marching = Data.copy_data(raw.marching_events)
	return {"action": "smoke_checkpoint_restored"}


func _to_planning() -> Dictionary:
	for index in range(5):
		if next_hook() == Timeline.SUBMISSION_LOCK:
			return {"action": "smoke_ready"}
		var result: Dictionary = step()
		if result.action == "invalid":
			return result
	return Data.invalid("smoke_planning_not_reached")


func _source(
	player_id: int, power: String, index: int, target: Dictionary, cost: Dictionary = {}
) -> Dictionary:
	var current: int = round_number()
	var rule: Dictionary = Gremory.rules()[power]
	return Decl.create(
		MatchOwner.declaration_id(player_id, current, index),
		player_id,
		"Gremory",
		power,
		current,
		rule.fire_hook,
		current + int(rule.delay_rounds),
		index,
		"public",
		target,
		cost,
		{}
	)


static func _castle_id(player_id: int) -> String:
	return Ids.identity("castle", "smoke:castle:" + str(player_id))


static func _initial_world() -> Dictionary:
	var entities = Ids.new()
	var players: Array = []
	var hands: Array = [[], []]
	var deck: Array = []
	for player_id in [0, 1]:
		var lord: Dictionary = entities.create(
			"lord",
			"smoke:lord:" + str(player_id),
			0,
			player_id,
			{"lord_id": "Gremory", "alive": true}
		)
		players.append(
			{"lord_id": "Gremory", "lord_entity_id": lord.entity.id, "resources": {"souls": 0}}
		)
		entities.create(
			"castle",
			"smoke:castle:" + str(player_id),
			0,
			player_id,
			{
				"status": "standing",
				"integrity": 3,
				"max_integrity": 6,
				"combat_profile": "plain_integrity"
			}
		)
		for index in range(4):
			var card: Dictionary = entities.create(
				"card",
				"smoke:hand:" + str(player_id),
				index,
				player_id,
				{"suit": "Butcher" if index < 2 else "Penitent", "value": 3}
			)
			hands[player_id].append(card.entity.id)
		for slot in range(2):
			entities.create(
				"card",
				"smoke:guard:" + str(player_id),
				slot,
				player_id,
				{
					"role": "guard",
					"suit": "Wright",
					"value": 2 - slot,
					"lane": "Castle",
					"slot": slot
				}
			)
	for index in range(24):
		var suits: Array = ["Butcher", "Penitent", "Vulture", "Wright"]
		var card: Dictionary = entities.create(
			"card", "smoke:deck", index, -1, {"suit": suits[index % 4], "value": 1 + index % 3}
		)
		deck.append(card.entity.id)
	return {
		"players": players,
		"entities": entities.snapshot(),
		"data":
		{
			"combat_profile": Combat.VERSION,
			"card_zones": {"hands": hands, "deck": deck, "discard": [], "hand_limit": 10},
			"neutral_tears": 0,
			"breach_lord": "Gremory",
			"sigils": [{"Lord": "", "Castle": ""}, {"Lord": "", "Castle": ""}]
		}
	}
