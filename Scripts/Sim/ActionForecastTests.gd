class_name ActionForecastTests
extends RefCounted


const ActionForecastData = preload(
	"res://Scripts/Sim/ActionForecast.gd"
)
const RuleConfigData = preload(
	"res://Scripts/Sim/RuleConfig.gd"
)
const GameStateData = preload(
	"res://Scripts/Sim/GameState.gd"
)
const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)


static func run() -> Array[Dictionary]:
	var rules: RuleConfig = RuleConfigData.lab_v6_5()

	return [
		_test_known_hunt_contract(rules),
		_test_hidden_guard_no_cheat(rules),
		_test_ward_hand_no_cheat(rules),
		_test_bastion_siege(rules),
	]


static func _test_known_hunt_contract(
	rules: RuleConfig
) -> Dictionary:
	var lethal_game = _base_game(
		"Valak",
		"Gremory"
	)

	var lethal_attacker = lethal_game.get_player(0)

	lethal_attacker.hand = _cards([
		"Butcher:5",
	])

	var lethal: Dictionary = (
		ActionForecastData.forecast_hunt(
			lethal_game,
			rules,
			0
		)
	)

	if not bool(
		lethal.get(
			"available",
			false
		)
	):
		return _fail(
			"action_forecast_known_hunt",
			"Known lethal Hunt was unavailable."
		)

	if not _near(
		_objective_open_probability(
			lethal,
			"banish"
		),
		1.0
	):
		return _fail(
			"action_forecast_known_hunt",
			"Exact feasible Banish did not forecast 100%."
		)

	var equality_game = _base_game(
		"Valak",
		"Gremory"
	)

	var equality_attacker = equality_game.get_player(0)

	equality_attacker.hand = _cards([
		"Butcher:4",
	])

	var equality: Dictionary = (
		ActionForecastData.forecast_hunt(
			equality_game,
			rules,
			0
		)
	)

	if not _near(
		_objective_open_probability(
			equality,
			"banish"
		),
		0.0
	):
		return _fail(
			"action_forecast_known_hunt",
			"Strict Lord equality incorrectly forecast a Banish."
		)

	return _pass(
		"action_forecast_known_hunt"
	)


static func _test_hidden_guard_no_cheat(
	rules: RuleConfig
) -> Dictionary:
	var low_game = _base_game(
		"Orias",
		"Gremory"
	)

	var high_game = _base_game(
		"Orias",
		"Gremory"
	)

	low_game.get_player(0).hand = _cards([
		"Butcher:5",
	])

	high_game.get_player(0).hand = _cards([
		"Butcher:5",
	])

	var low_guard = CardData.new(
		"Wright",
		1
	)

	var high_guard = CardData.new(
		"Wright",
		5
	)

	low_guard.guard_revealed = false
	high_guard.guard_revealed = false

	low_game.get_player(1).lord_guards = [
		low_guard,
	]

	high_game.get_player(1).lord_guards = [
		high_guard,
	]

	var hidden_low: Dictionary = (
		ActionForecastData.forecast_hunt(
			low_game,
			rules,
			0
		)
	)

	var hidden_high: Dictionary = (
		ActionForecastData.forecast_hunt(
			high_game,
			rules,
			0
		)
	)

	var hidden_low_probability: float = (
		_objective_open_probability(
			hidden_low,
			"banish"
		)
	)

	var hidden_high_probability: float = (
		_objective_open_probability(
			hidden_high,
			"banish"
		)
	)

	if not _near(
		hidden_low_probability,
		hidden_high_probability
	):
		return _fail(
			"action_forecast_hidden_guard_no_cheat",
			"Face-down Guard identity leaked into the forecast."
		)

	if not _near(
		hidden_low_probability,
		4.0 / 18.0
	):
		return _fail(
			"action_forecast_hidden_guard_no_cheat",
			"Hidden Guard distribution did not match the 4/18 lethal value-1 case."
		)

	low_guard.guard_revealed = true
	high_guard.guard_revealed = true

	var revealed_low: Dictionary = (
		ActionForecastData.forecast_hunt(
			low_game,
			rules,
			0
		)
	)

	var revealed_high: Dictionary = (
		ActionForecastData.forecast_hunt(
			high_game,
			rules,
			0
		)
	)

	if not _near(
		_objective_open_probability(
			revealed_low,
			"banish"
		),
		1.0
	):
		return _fail(
			"action_forecast_hidden_guard_no_cheat",
			"Revealed Guard 1 did not become exact public information."
		)

	if not _near(
		_objective_open_probability(
			revealed_high,
			"banish"
		),
		0.0
	):
		return _fail(
			"action_forecast_hidden_guard_no_cheat",
			"Revealed Guard 5 did not become exact public information."
		)

	return _pass(
		"action_forecast_hidden_guard_no_cheat"
	)


static func _test_ward_hand_no_cheat(
	rules: RuleConfig
) -> Dictionary:
	var low_game = _base_game(
		"Valak",
		"Gremory"
	)

	var high_game = _base_game(
		"Valak",
		"Gremory"
	)

	low_game.get_player(0).hand = _cards([
		"Butcher:5",
	])

	high_game.get_player(0).hand = _cards([
		"Butcher:5",
	])

	low_game.get_player(1).hand = _cards([
		"Wright:1",
		"Vulture:1",
	])

	high_game.get_player(1).hand = _cards([
		"Penitent:5",
		"Penitent:5",
	])

	var low_forecast: Dictionary = (
		ActionForecastData.forecast_hunt(
			low_game,
			rules,
			0
		)
	)

	var high_forecast: Dictionary = (
		ActionForecastData.forecast_hunt(
			high_game,
			rules,
			0
		)
	)

	var low_warded: Dictionary = (
		low_forecast.get(
			"banish",
			{}
		).get(
			"warded_by_cards",
			{}
		)
	)

	var high_warded: Dictionary = (
		high_forecast.get(
			"banish",
			{}
		).get(
			"warded_by_cards",
			{}
		)
	)

	if not low_warded.has("1") or not low_warded.has("2"):
		return _fail(
			"action_forecast_ward_hand_no_cheat",
			"Warded branch did not expose one-card and two-card agency depths."
		)

	if low_warded != high_warded:
		return _fail(
			"action_forecast_ward_hand_no_cheat",
			"Hidden opponent Hand identities leaked into Ward forecast."
		)

	return _pass(
		"action_forecast_ward_hand_no_cheat"
	)


static func _test_bastion_siege(
	rules: RuleConfig
) -> Dictionary:
	var game = _base_game(
		"Valak",
		"Gremory"
	)

	var attacker = game.get_player(0)
	var defender = game.get_player(1)

	attacker.hand = _cards([
		"Butcher:5",
	])

	defender.castles.clear()
	defender.castles.append(
		"Bastion"
	)
	defender.castles.append(
		"Stockpile"
	)

	defender.castle_integrity = {
		"Bastion": 5,
		"Stockpile": 5,
	}

	var forecast: Dictionary = (
		ActionForecastData.forecast_siege(
			game,
			rules,
			0,
			"Stockpile"
		)
	)

	if not _near(
		_objective_open_probability(
			forecast,
			"damage"
		),
		1.0
	):
		return _fail(
			"action_forecast_bastion_siege",
			"Bastion-screened Siege did not recognize guaranteed structure damage."
		)

	if not _near(
		_objective_open_probability(
			forecast,
			"ruin"
		),
		1.0
	):
		return _fail(
			"action_forecast_bastion_siege",
			"Bastion Ruin was not recognized as a Siege Ruin objective."
		)

	if int(
		defender.castle_integrity.get(
			"Bastion",
			0
		)
	) != 5:
		return _fail(
			"action_forecast_bastion_siege",
			"Forecast mutated the live game state."
		)

	return _pass(
		"action_forecast_bastion_siege"
	)


static func _base_game(
	attacker_lord: String,
	defender_lord: String
):
	var game = GameStateData.new(
		[attacker_lord],
		[defender_lord]
	)

	game.breach = ""
	game.breach_owner = -1
	game.reflex_winner = -1
	game.neutral_tears = 0

	var attacker = game.get_player(0)
	var defender = game.get_player(1)

	_reset_player(
		attacker,
		attacker_lord
	)

	_reset_player(
		defender,
		defender_lord
	)

	game.refresh_derived_values()

	return game


static func _reset_player(
	player,
	lord_name: String
) -> void:
	player.lord = lord_name
	player.alive = true
	player.souls = 0
	player.tears = 0
	player.threat = 0
	player.kroni_hunger = 0

	player.action = ""
	player.tgt_pid = -1
	player.tgt_type = ""
	player.ward_target = ""
	player.prev_ward_target = ""

	player.hand.clear()
	player.garrison.clear()
	player.committed.clear()
	player.castle_guards.clear()
	player.lord_guards.clear()
	player.penitent_temp_guards.clear()

	player.castles.clear()
	player.ruined_castles.clear()
	player.profaned_castles.clear()
	player.lost_castles.clear()
	player.castle_integrity.clear()
	player.castle_construction_progress.clear()
	player.castle_repairs.clear()
	player.castle_scars.clear()

	player.sigils = {
		"Castle": "",
		"Lord": "",
	}

	player.ward_turned.clear()
	player.odradek_bank = null
	player.odradek_recoil_done = false
	player.kanifous_invoked_suit = ""


static func _cards(
	identifiers: Array
) -> Array:
	var result: Array = []

	for raw_identifier in identifiers:
		var identifier: String = String(
			raw_identifier
		)

		var split_index: int = identifier.rfind(
			":"
		)

		result.append(
			CardData.new(
				identifier.substr(
					0,
					split_index
				),
				int(
					identifier.substr(
						split_index + 1
					)
				)
			)
		)

	return result


static func _objective_open_probability(
	forecast: Dictionary,
	objective_name: String
) -> float:
	var objective: Dictionary = (
		forecast.get(
			objective_name,
			{}
		)
	)

	var open_result: Dictionary = (
		objective.get(
			"open",
			{}
		)
	)

	return float(
		open_result.get(
			"probability",
			0.0
		)
	)


static func _near(
	actual: float,
	expected: float,
	tolerance: float = 0.000001
) -> bool:
	return absf(
		actual - expected
	) <= tolerance


static func _pass(
	test_name: String
) -> Dictionary:
	return {
		"passed": true,
		"text": "PASS  %s" % test_name,
	}


static func _fail(
	test_name: String,
	reason: String
) -> Dictionary:
	return {
		"passed": false,
		"text": "FAIL  %s: %s" % [
			test_name,
			reason,
		],
	}
