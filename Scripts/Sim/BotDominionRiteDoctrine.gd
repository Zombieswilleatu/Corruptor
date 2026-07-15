class_name BotDominionRiteDoctrine
extends RefCounted


const DominionRiteEngineData = preload(
	"res://Scripts/Sim/DominionRiteEngine.gd"
)

const BotDoctrineData = preload(
	"res://Scripts/Sim/BotDoctrine.gd"
)

const BotPolicyData = preload(
	"res://Scripts/Sim/BotPolicy.gd"
)

const BotSelectorData = preload(
	"res://Scripts/Sim/BotSelector.gd"
)


const INVOCATION_PAYMENT_THRESHOLD: int = 11

const PASS_SCORE: float = 0.0
const ACTION_SCORE: float = 20.0


static func rite_choices(
	game,
	rules: RuleConfig,
	random_source = null,
	policy = null
) -> Dictionary:
	assert(
		game != null,
		"Bot Dominion Rite doctrine requires a GameState."
	)

	assert(
		rules != null,
		"Bot Dominion Rite doctrine requires RuleConfig."
	)

	var effective_policy = _policy_or_default(
		policy
	)

	# Dominion Rites are public and resolve sequentially.
	# The shadow state lets later players evaluate the consequences
	# of earlier players' rites without mutating the real game.
	var shadow = game.duplicate_state()

	var decisions: Dictionary = {}

	for player in shadow.players:
		var player_id: int = int(
			player.pid
		)

		if int(
			shadow.winner
		) >= 0:
			decisions[player_id] = {
				"pass": true,
			}

			continue

		var player_decision: Dictionary = {}

		var invocation_selection: Dictionary = (
			BotSelectorData.choose(
				evaluate_invocation_candidates(
					shadow,
					player_id,
					rules
				),
				random_source,
				effective_policy
			)
		)

		var invocation_payload: Dictionary = (
			_selection_payload(
				invocation_selection
			)
		)

		if not bool(
			invocation_payload.get(
				"pass",
				false
			)
		):
			player_decision["invocation"] = (
				invocation_payload.duplicate(
					true
				)
			)

			_apply_shadow_decision(
				shadow,
				rules,
				player_id,
				{
					"invocation": (
						invocation_payload
						.duplicate(
							true
						)
					),
				}
			)

		if int(
			shadow.winner
		) < 0:
			var profane_selection: Dictionary = (
				BotSelectorData.choose(
					evaluate_profane_candidates(
						shadow,
						player_id,
						rules
					),
					random_source,
					effective_policy
				)
			)

			var profane_payload: Dictionary = (
				_selection_payload(
					profane_selection
				)
			)

			if not bool(
				profane_payload.get(
					"pass",
					false
				)
			):
				player_decision["profane_ruins"] = (
					profane_payload.duplicate(
						true
					)
				)

				_apply_shadow_decision(
					shadow,
					rules,
					player_id,
					{
						"profane_ruins": (
							profane_payload
							.duplicate(
								true
							)
						),
					}
				)

		if player_decision.is_empty():
			player_decision = {
				"pass": true,
			}

		decisions[player_id] = player_decision

	return decisions


static func evaluate_invocation_candidates(
	game,
	player_id: int,
	rules: RuleConfig
) -> Array:
	var player = game.get_player(
		player_id
	)

	var opponent = game.get_opponent(
		player_id
	)

	assert(
		player != null,
		"Invocation evaluator player does not exist."
	)

	assert(
		opponent != null,
		"Invocation evaluator opponent does not exist."
	)

	var candidates: Array = [
		_pass_candidate(
			"invocation_pass"
		),
	]

	if (
		not rules.invocation_repeatable
		and player.cataclysmic_used
	):
		return candidates

	if game.calculate_veil_total() < rules.invocation_gate:
		return candidates

	if _card_total(
		player.hand
	) < INVOCATION_PAYMENT_THRESHOLD:
		return candidates

	var current_plan: String = (
		BotDoctrineData.plan(
			game,
			player_id,
			rules
		)
	)

	var soul_deficit: int = (
		opponent.souls
		- player.souls
	)

	var wants_invocation: bool = (
		current_plan in [
			"race_dominion",
			"deny_dominion",
		]
		or (
			soul_deficit >= 3
			and player.tears + 1
			>= rules.dominion_requirement - 1
		)
	)

	if not wants_invocation:
		return candidates

	var payment_cards: Array = (
		_select_high_payment(
			player.hand,
			INVOCATION_PAYMENT_THRESHOLD
		)
	)

	if _card_total(
		payment_cards
	) < INVOCATION_PAYMENT_THRESHOLD:
		return candidates

	var remaining_hand_size: int = (
		player.hand.size()
		- payment_cards.size()
	)

	var reaches_requirement: bool = (
		player.tears + 1
		>= rules.dominion_requirement
	)

	if (
		remaining_hand_size < 2
		and not reaches_requirement
	):
		return candidates

	candidates.append({
		"id": "cataclysmic_invocation",
		"score": ACTION_SCORE,
		"degraded_score": -1.0,
		"tie_rank": 1,
		"payload": {
			"payment": _card_ids(
				payment_cards
			),
		},
	})

	return candidates


static func evaluate_profane_candidates(
	game,
	player_id: int,
	rules: RuleConfig
) -> Array:
	var player = game.get_player(
		player_id
	)

	assert(
		player != null,
		"Profane the Ruins evaluator player does not exist."
	)

	var candidates: Array = [
		_pass_candidate(
			"profane_ruins_pass"
		),
	]

	if player.profane_ruins_used_this_round:
		return candidates

	if (
		player.ruined_castles.size()
		< rules.profane_ruins_req
	):
		return candidates

	var current_plan: String = (
		BotDoctrineData.plan(
			game,
			player_id,
			rules
		)
	)

	var wants_profane: bool = (
		current_plan in [
			"race_dominion",
			"deny_dominion",
		]
		or player.tears >= 1
	)

	if not wants_profane:
		return candidates

	var target_castle: String = (
		_lowest_priority_ruin(
			player
		)
	)

	if target_castle.is_empty():
		return candidates

	candidates.append({
		"id": (
			"profane_ruins_%s"
			% target_castle
		),
		"score": ACTION_SCORE,
		"degraded_score": -1.0,
		"tie_rank": 1,
		"payload": {
			"castle": target_castle,
		},
	})

	return candidates


static func _apply_shadow_decision(
	shadow,
	rules: RuleConfig,
	player_id: int,
	decision: Dictionary
) -> void:
	var choices: Dictionary = {}

	for player in shadow.players:
		choices[int(
			player.pid
		)] = {
			"pass": true,
		}

	choices[player_id] = decision

	DominionRiteEngineData.resolve(
		shadow,
		rules,
		choices
	)


static func _lowest_priority_ruin(
	player
) -> String:
	var raw_priority = (
		BotDoctrineData.CASTLE_PRIORITIES.get(
			String(
				player.lord
			),
			BotDoctrineData.DEFAULT_CASTLE_PRIORITY
		)
	)

	var priority: Array = raw_priority

	for index: int in range(
		priority.size() - 1,
		-1,
		-1
	):
		var castle_name: String = String(
			priority[index]
		)

		if player.ruined_castles.has(
			castle_name
		):
			return castle_name

	if player.ruined_castles.is_empty():
		return ""

	return String(
		player.ruined_castles[0]
	)


static func _select_high_payment(
	cards: Array,
	required_total: int
) -> Array:
	var ordered_cards: Array = (
		_stable_sorted_cards(
			cards,
			true
		)
	)

	var selected_cards: Array = []
	var selected_total: int = 0

	for card in ordered_cards:
		if selected_total >= required_total:
			break

		selected_cards.append(
			card
		)

		selected_total += int(
			card.value
		)

	return selected_cards


static func _stable_sorted_cards(
	cards: Array,
	descending: bool
) -> Array:
	var entries: Array[Dictionary] = []

	for index: int in range(
		cards.size()
	):
		entries.append({
			"card": cards[index],
			"index": index,
			"value": int(
				cards[index].value
			),
		})

	entries.sort_custom(
		func(
			entry_a: Dictionary,
			entry_b: Dictionary
		) -> bool:
			var value_a: int = int(
				entry_a.get(
					"value",
					0
				)
			)

			var value_b: int = int(
				entry_b.get(
					"value",
					0
				)
			)

			if value_a != value_b:
				if descending:
					return value_a > value_b

				return value_a < value_b

			return int(
				entry_a.get(
					"index",
					0
				)
			) < int(
				entry_b.get(
					"index",
					0
				)
			)
	)

	var result: Array = []

	for entry: Dictionary in entries:
		result.append(
			entry.get(
				"card"
			)
		)

	return result


static func _selection_payload(
	selection: Dictionary
) -> Dictionary:
	var raw_payload = selection.get(
		"payload",
		{
			"pass": true,
		}
	)

	if typeof(
		raw_payload
	) != TYPE_DICTIONARY:
		return {
			"pass": true,
		}

	return raw_payload


static func _pass_candidate(
	candidate_id: String
) -> Dictionary:
	return {
		"id": candidate_id,
		"score": PASS_SCORE,
		"degraded_score": PASS_SCORE,
		"tie_rank": 0,
		"payload": {
			"pass": true,
		},
	}


static func _card_total(
	cards: Array
) -> int:
	var total: int = 0

	for card in cards:
		total += int(
			card.value
		)

	return total


static func _card_ids(
	cards: Array
) -> Array[String]:
	var result: Array[String] = []

	for card in cards:
		result.append(
			_card_id(
				card
			)
		)

	return result


static func _card_id(
	card
) -> String:
	if card == null:
		return ""

	if card.has_method(
		"card_id"
	):
		return String(
			card.card_id()
		)

	return "%s:%d" % [
		String(
			card.get(
				"suit"
			)
		),
		int(
			card.get(
				"value"
			)
		),
	]


static func _policy_or_default(
	policy
):
	if policy == null:
		return BotPolicyData.golden_core()

	return policy
