class_name BotGameEngine
extends RefCounted


const BotRoundEngineData = preload(
	"res://Scripts/Sim/BotRoundEngine.gd"
)

const BotPolicyData = preload(
	"res://Scripts/Sim/BotPolicy.gd"
)


static func resolve_game(
	game,
	rules: RuleConfig,
	random_source,
	policy = null,
	max_rounds_override: int = -1
) -> Dictionary:
	assert(
		game != null,
		"BotGameEngine requires a GameState."
	)

	assert(
		rules != null,
		"BotGameEngine requires RuleConfig."
	)

	assert(
		random_source != null,
		"BotGameEngine requires a deterministic random source."
	)

	assert(
		game.players.size() == 2,
		"BotGameEngine currently requires two players."
	)

	var maximum_rounds: int = int(
		rules.max_rounds
	)

	if max_rounds_override >= 0:
		maximum_rounds = max_rounds_override

	assert(
		maximum_rounds >= 0,
		"Maximum rounds cannot be negative."
	)

	var effective_policy = policy

	if effective_policy == null:
		effective_policy = (
			BotPolicyData.golden_core()
		)

	var round_results: Array[Dictionary] = []
	var events: Array[Dictionary] = []

	if int(
		game.winner
	) >= 0:
		return _game_result(
			game,
			round_results,
			events,
			{},
			"game_already_terminal"
		)

	while (
		int(
			game.winner
		) < 0
		and int(
			game.round
		) < maximum_rounds
	):
		var round_before: int = int(
			game.round
		)

		var next_round: int = (
			round_before + 1
		)

		var round_result: Dictionary = (
			BotRoundEngineData.resolve_round(
				game,
				rules,
				random_source,
				next_round,
				effective_policy
			)
		)

		round_results.append(
			round_result
		)

		_append_round_events(
			events,
			round_result
		)

		if String(
			round_result.get(
				"action",
				""
			)
		) == "invalid":
			return {
				"action": "invalid",
				"reason": String(
					round_result.get(
						"reason",
						"invalid_round"
					)
				),
				"terminal": (
					int(
						game.winner
					) >= 0
				),
				"winner": int(
					game.winner
				),
				"win_by": String(
					game.win_by
				),
				"final_round": int(
					game.round
				),
				"round_count": (
					round_results.size()
				),
				"stopped_round": next_round,
				"stopped_phase": String(
					round_result.get(
						"stopped_phase",
						""
					)
				),
				"rounds": round_results,
				"events": events,
				"timeout": {},
			}

		if (
			int(
				game.winner
			) < 0
			and int(
				game.round
			) <= round_before
		):
			return {
				"action": "invalid",
				"reason": (
					"round_did_not_advance"
				),
				"terminal": false,
				"winner": -1,
				"win_by": "",
				"final_round": int(
					game.round
				),
				"round_count": (
					round_results.size()
				),
				"stopped_round": next_round,
				"stopped_phase": "",
				"rounds": round_results,
				"events": events,
				"timeout": {},
			}

	if int(
		game.winner
	) >= 0:
		return _game_result(
			game,
			round_results,
			events,
			{},
			""
		)

	var timeout_result: Dictionary = (
		_resolve_timeout(
			game,
			random_source
		)
	)

	return _game_result(
		game,
		round_results,
		events,
		timeout_result,
		""
	)


static func _resolve_timeout(
	game,
	random_source
) -> Dictionary:
	assert(
		game.players.size() == 2,
		"Timeout resolution requires two players."
	)

	var player_zero = game.players[0]
	var player_one = game.players[1]

	var winner_id: int = -1
	var tie_break: String = ""

	if player_zero.souls != player_one.souls:
		winner_id = (
			0
			if player_zero.souls
				> player_one.souls
			else 1
		)

		tie_break = "souls"

	elif (
		player_zero.castles.size()
		!= player_one.castles.size()
	):
		winner_id = (
			0
			if player_zero.castles.size()
				> player_one.castles.size()
			else 1
		)

		tie_break = "castles"

	elif player_zero.threat != player_one.threat:
		winner_id = (
			0
			if player_zero.threat
				< player_one.threat
			else 1
		)

		tie_break = "threat"

	else:
		winner_id = int(
			random_source.randint(
				0,
				1
			)
		)

		tie_break = "random"

	game.winner = winner_id
	game.win_by = "Timeout"

	game.refresh_derived_values()

	return {
		"applied": true,
		"winner": winner_id,
		"tie_break": tie_break,
		"player_zero": {
			"souls": int(
				player_zero.souls
			),
			"castles": (
				player_zero.castles.size()
			),
			"threat": int(
				player_zero.threat
			),
		},
		"player_one": {
			"souls": int(
				player_one.souls
			),
			"castles": (
				player_one.castles.size()
			),
			"threat": int(
				player_one.threat
			),
		},
	}


static func _append_round_events(
	events: Array[Dictionary],
	round_result: Dictionary
) -> void:
	var raw_events = round_result.get(
		"events",
		[]
	)

	if typeof(
		raw_events
	) != TYPE_ARRAY:
		return

	for raw_event in raw_events:
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event

		events.append(
			event.duplicate(
				true
			)
		)


static func _game_result(
	game,
	round_results: Array[Dictionary],
	events: Array[Dictionary],
	timeout_result: Dictionary,
	reason: String
) -> Dictionary:
	return {
		"action": "game",
		"reason": reason,
		"terminal": (
			int(
				game.winner
			) >= 0
		),
		"winner": int(
			game.winner
		),
		"win_by": String(
			game.win_by
		),
		"final_round": int(
			game.round
		),
		"round_count": (
			round_results.size()
		),
		"stopped_round": -1,
		"stopped_phase": "",
		"rounds": round_results,
		"events": events,
		"timeout": timeout_result,
	}
