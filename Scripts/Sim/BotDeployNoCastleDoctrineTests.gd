class_name BotDeployNoCastleDoctrineTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const RuleConfigData = preload(
	"res://Scripts/Sim/RuleConfig.gd"
)

const SeededGameSetupData = preload(
	"res://Scripts/Sim/SeededGameSetup.gd"
)

const BotDeployDoctrineData = preload(
	"res://Scripts/Sim/BotDeployDoctrine.gd"
)

const DeployEngineData = preload(
	"res://Scripts/Sim/DeployEngine.gd"
)


static func run() -> Array[Dictionary]:
	return [
		_test_castleless_lord_routes_to_lord(
			"Humbaba"
		),
		_test_castleless_lord_routes_to_lord(
			"Orias"
		),
		_test_live_castle_preserves_castle_priority(),
	]


static func _fixture(
	lord_name: String
) -> Dictionary:
	var rules = RuleConfigData.lab_v6_5()
	var setup: Dictionary = (
		SeededGameSetupData.setup_locked_game(
			lord_name,
			"Valak",
			1856146580,
			rules
		)
	)

	var game = setup.get(
		"game",
		null
	)

	if game == null:
		return {
			"error": "setup_missing_game",
		}

	var player = game.get_player(
		0
	)
	var opponent = game.get_player(
		1
	)

	if (
		player == null
		or opponent == null
	):
		return {
			"error": "setup_missing_player",
		}

	player.lord = lord_name
	player.alive = true
	player.threat = 0
	player.orias_snare_active = false
	player.repaired_this_round = false
	player.repair_token_used_this_repair = false

	player.hand.clear()
	player.garrison.clear()
	player.castle_guards.clear()
	player.lord_guards.clear()

	# Garrison cannot be committed, so this is an unambiguous Guard
	# deployment opportunity independent of Commitment reservation policy.
	player.garrison.append(
		CardData.new(
			"Butcher",
			4
		)
	)

	opponent.alive = true

	return {
		"game": game,
		"rules": rules,
		"player": player,
		"opponent": opponent,
	}


static func _test_castleless_lord_routes_to_lord(
	lord_name: String
) -> Dictionary:
	var test_name: String = (
		"bot_deploy_no_castles_%s"
		% lord_name.to_lower()
	)

	var fixture: Dictionary = _fixture(
		lord_name
	)
	if fixture.has(
		"error"
	):
		return _fail(
			test_name,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var rules = fixture["rules"]
	var player = fixture["player"]

	# Preserve the names as Ruins for a realistic "all Castles destroyed"
	# board, but leave the active Castle list empty.
	var active_castles: Array[String] = []
	for raw_castle_name in player.castles:
		active_castles.append(
			String(
				raw_castle_name
			)
		)

	player.castles.clear()

	for castle_name: String in active_castles:
		if not player.ruined_castles.has(
			castle_name
		):
			player.ruined_castles.append(
				castle_name
			)

	var choices: Dictionary = (
		BotDeployDoctrineData.deploy_choices(
			game,
			rules
		)
	)

	var decision: Dictionary = (
		_decision_for_player(
			choices,
			0
		)
	)

	var moves: Array = decision.get(
		"moves",
		[]
	)

	if moves.is_empty():
		return _fail(
			test_name,
			(
				"Castleless bot wasted an available Garrison Guard "
				+ "instead of protecting its Lord."
			)
		)

	for raw_move in moves:
		if typeof(
			raw_move
		) != TYPE_DICTIONARY:
			return _fail(
				test_name,
				"Deploy doctrine emitted a non-dictionary move."
			)

		var move: Dictionary = raw_move
		var target: String = String(
			move.get(
				"target",
				""
			)
		)

		if target == "Castle":
			return _fail(
				test_name,
				(
					"Bot still deployed a Guard to Castle with "
					+ "zero live Castles."
				)
			)

		if target != "Lord":
			return _fail(
				test_name,
				"Castleless deployment did not route to the Lord zone."
			)

	var results: Array[Dictionary] = (
		DeployEngineData.resolve(
			game,
			rules,
			choices
		)
	)

	var result: Dictionary = (
		results[0]
		if not results.is_empty()
		else {}
	)

	if int(
		result.get(
			"invalid_count",
			-1
		)
	) != 0:
		return _fail(
			test_name,
			"DeployEngine rejected the castleless doctrine move."
		)

	if (
		player.lord_guards.is_empty()
		or not player.castle_guards.is_empty()
	):
		return _fail(
			test_name,
			(
				"Resolved castleless deployment did not protect "
				+ "the Lord exclusively."
			)
		)

	return _pass(
		test_name
	)


static func _test_live_castle_preserves_castle_priority() -> Dictionary:
	var test_name: String = (
		"bot_deploy_live_castle_priority"
	)

	var fixture: Dictionary = _fixture(
		"Orias"
	)
	if fixture.has(
		"error"
	):
		return _fail(
			test_name,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var rules = fixture["rules"]
	var player = fixture["player"]

	# setup_locked_game normally supplies the Castle package. This fallback
	# keeps the control fixture deterministic if setup changes later.
	if player.castles.is_empty():
		player.castles.append(
			"Keep"
		)

	var choices: Dictionary = (
		BotDeployDoctrineData.deploy_choices(
			game,
			rules
		)
	)

	var decision: Dictionary = (
		_decision_for_player(
			choices,
			0
		)
	)

	var moves: Array = decision.get(
		"moves",
		[]
	)

	if moves.is_empty():
		return _fail(
			test_name,
			"Live-Castle control fixture generated no Guard move."
		)

	var found_castle: bool = false

	for raw_move in moves:
		if typeof(
			raw_move
		) != TYPE_DICTIONARY:
			continue

		var move: Dictionary = raw_move
		if String(
			move.get(
				"target",
				""
			)
		) == "Castle":
			found_castle = true
			break

	if not found_castle:
		return _fail(
			test_name,
			(
				"No-Castle fix accidentally removed normal "
				+ "Castle-Guard priority."
			)
		)

	return _pass(
		test_name
	)


static func _decision_for_player(
	choices: Dictionary,
	player_id: int
) -> Dictionary:
	if choices.has(
		player_id
	):
		var direct = choices[
			player_id
		]
		return (
			direct
			if typeof(
				direct
			) == TYPE_DICTIONARY
			else {}
		)

	var string_key: String = str(
		player_id
	)

	if choices.has(
		string_key
	):
		var string_value = choices[
			string_key
		]
		return (
			string_value
			if typeof(
				string_value
			) == TYPE_DICTIONARY
			else {}
		)

	return {}


static func _pass(
	name: String
) -> Dictionary:
	return {
		"name": name,
		"passed": true,
		"detail": "",
	}


static func _fail(
	name: String,
	detail: String
) -> Dictionary:
	return {
		"name": name,
		"passed": false,
		"detail": detail,
	}
