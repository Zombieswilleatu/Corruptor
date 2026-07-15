class_name BotDeployDoctrine
extends RefCounted


const BotDoctrineData = preload(
	"res://Scripts/Sim/BotDoctrine.gd"
)

const BotPolicyData = preload(
	"res://Scripts/Sim/BotPolicy.gd"
)


const FRENZY_THRESHOLD: int = 6
const BASE_CASTLE_GUARD_LIMIT: int = 3
const BASE_LORD_GUARD_LIMIT: int = 3


static func deploy_choices(
	game,
	rules: RuleConfig
) -> Dictionary:
	assert(
		game != null,
		"Bot Deploy doctrine requires a GameState."
	)

	assert(
		rules != null,
		"Bot Deploy doctrine requires RuleConfig."
	)

	var decisions: Dictionary = {}

	for player in game.players:
		var player_id: int = int(
			player.pid
		)

		var moves: Array = _deploy_moves_for_player(
			game,
			player_id,
			rules
		)

		if moves.is_empty():
			decisions[player_id] = {
				"pass": true,
			}
		else:
			decisions[player_id] = {
				"moves": moves,
			}

	return decisions


static func reserved_cards(
	game,
	player_id: int,
	rules: RuleConfig
) -> Array:
	var player = game.get_player(
		player_id
	)

	assert(
		player != null,
		"Deploy reservation player does not exist."
	)

	var commitment_choices: Dictionary = (
		BotDoctrineData.commitment_choices(
			game,
			null,
			rules,
			BotPolicyData.golden_core()
		)
	)

	var commitment_decision: Dictionary = (
		_decision_for_player(
			commitment_choices,
			player_id
		)
	)

	var raw_card_ids = commitment_decision.get(
		"cards",
		[]
	)

	var commitment_card_ids: Array = []

	if typeof(
		raw_card_ids
	) == TYPE_ARRAY:
		commitment_card_ids = raw_card_ids

	var reserved: Array = []
	var available_hand: Array = (
		player.hand.duplicate()
	)

	for raw_card_id in commitment_card_ids:
		var card_identifier: String = String(
			raw_card_id
		)

		var selected_card = _find_card(
			available_hand,
			card_identifier
		)

		if selected_card == null:
			continue

		reserved.append(
			selected_card
		)

		available_hand.erase(
			selected_card
		)

	# Preserve one cheap card for the next Reflex Bid.
	if not available_hand.is_empty():
		var bid_card = _stable_sorted_cards(
			available_hand,
			false
		)[0]

		reserved.append(
			bid_card
		)

	return reserved


static func _deploy_moves_for_player(
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
		"Deploy doctrine player does not exist."
	)

	assert(
		opponent != null,
		"Deploy doctrine opponent does not exist."
	)

	var hand: Array = player.hand.duplicate()
	var garrison: Array = player.garrison.duplicate()

	var castle_guard_count: int = (
		player.castle_guards.size()
	)

	var lord_guard_count: int = (
		player.lord_guards.size()
	)

	var maximum_castle_guards: int = (
		_maximum_castle_guards(
			player,
			rules
		)
	)

	var maximum_lord_guards: int = (
		BASE_LORD_GUARD_LIMIT
	)

	var frenzy_blocked: bool = (
		_frenzy_blocks_garrison(
			game,
			player
		)
	)

	var repair_blocks_hand: bool = (
		player.repaired_this_round
		and not player.repair_token_used_this_repair
	)

	var reserved: Array = reserved_cards(
		game,
		player_id,
		rules
	)

	var moves: Array = []

	if player.orias_snare_active:
		return _snared_deploy_moves(
			player,
			opponent,
			hand,
			garrison,
			reserved,
			castle_guard_count,
			lord_guard_count,
			maximum_castle_guards,
			maximum_lord_guards,
			frenzy_blocked,
			repair_blocks_hand
		)

	var garrison_moves: int = 0

	var ordered_garrison: Array = (
		_stable_sorted_cards(
			garrison,
			true
		)
	)

	# Garrison cannot be committed, so Castle defense receives it first.
	if not frenzy_blocked:
		while (
			castle_guard_count
			< maximum_castle_guards
			and not ordered_garrison.is_empty()
			and garrison_moves
			< rules.garrison_max
		):
			var card = ordered_garrison.pop_front()

			garrison.erase(
				card
			)

			moves.append(
				_move(
					"Garrison",
					"Castle",
					card
				)
			)

			castle_guard_count += 1
			garrison_moves += 1

	# Chaff goes to Castle Guards while combat cards remain reserved.
	if not repair_blocks_hand:
		var deployable_hand: Array = (
			_unreserved_cards(
				hand,
				reserved,
				false
			)
		)

		for card in deployable_hand:
			if (
				castle_guard_count
				>= maximum_castle_guards
			):
				break

			moves.append(
				_move(
					"Hand",
					"Castle",
					card
				)
			)

			hand.erase(
				card
			)

			castle_guard_count += 1

	var castle_full: bool = (
		castle_guard_count
		>= maximum_castle_guards
	)

	# Once Castle defense is full, remaining Garrison cards protect the Lord.
	if (
		castle_full
		and not frenzy_blocked
	):
		ordered_garrison = _stable_sorted_cards(
			garrison,
			true
		)

		while (
			lord_guard_count
			< maximum_lord_guards
			and not ordered_garrison.is_empty()
			and garrison_moves
			< rules.garrison_max
		):
			var card = ordered_garrison.pop_front()

			garrison.erase(
				card
			)

			moves.append(
				_move(
					"Garrison",
					"Lord",
					card
				)
			)

			lord_guard_count += 1
			garrison_moves += 1

	if not repair_blocks_hand:
		var remaining_deployable: Array = (
			_unreserved_cards(
				hand,
				reserved,
				false
			)
		)

		for card in remaining_deployable:
			if (
				lord_guard_count
				>= maximum_lord_guards
			):
				break

			moves.append(
				_move(
					"Hand",
					"Lord",
					card
				)
			)

			hand.erase(
				card
			)

			lord_guard_count += 1

	return moves


static func _snared_deploy_moves(
	player,
	opponent,
	hand: Array,
	garrison: Array,
	reserved: Array,
	castle_guard_count: int,
	lord_guard_count: int,
	maximum_castle_guards: int,
	maximum_lord_guards: int,
	frenzy_blocked: bool,
	repair_blocks_hand: bool
) -> Array:
	var selected_card = null
	var source_name: String = ""

	# Frenzy forbids Garrison deployment, even while Snared.
	if (
		not frenzy_blocked
		and not garrison.is_empty()
	):
		selected_card = _stable_sorted_cards(
			garrison,
			true
		)[0]

		source_name = "Garrison"

	if (
		selected_card == null
		and not repair_blocks_hand
	):
		var deployable_hand: Array = (
			_unreserved_cards(
				hand,
				reserved,
				true
			)
		)

		if not deployable_hand.is_empty():
			selected_card = deployable_hand[0]
			source_name = "Hand"

	if selected_card == null:
		return []

	var prefer_lord: bool = (
		player.alive
		and opponent.alive
		and not frenzy_blocked
		and lord_guard_count
		< maximum_lord_guards
	)

	if prefer_lord:
		return [
			_move(
				source_name,
				"Lord",
				selected_card
			),
		]

	if (
		castle_guard_count
		< maximum_castle_guards
	):
		return [
			_move(
				source_name,
				"Castle",
				selected_card
			),
		]

	if (
		lord_guard_count
		< maximum_lord_guards
	):
		return [
			_move(
				source_name,
				"Lord",
				selected_card
			),
		]

	return []


static func _unreserved_cards(
	hand: Array,
	reserved: Array,
	descending: bool
) -> Array:
	var available: Array = hand.duplicate()

	for reserved_card in reserved:
		available.erase(
			reserved_card
		)

	return _stable_sorted_cards(
		available,
		descending
	)


static func _maximum_castle_guards(
	player,
	rules: RuleConfig
) -> int:
	if (
		player.lord == "Humbaba"
		and rules.humbaba_gate4
		and player.ruined_castles.is_empty()
	):
		return 4

	return BASE_CASTLE_GUARD_LIMIT


static func _frenzy_blocks_garrison(
	game,
	player
) -> bool:
	var frenzy_active: bool = (
		game.breach == "Orias"
		or (
			game.calculate_veil_total()
			>= FRENZY_THRESHOLD
			and player.tears
			< FRENZY_THRESHOLD
		)
	)

	return (
		frenzy_active
		and player.threat >= 3
	)


static func _move(
	source_name: String,
	target_name: String,
	card
) -> Dictionary:
	return {
		"source": source_name,
		"target": target_name,
		"card": _card_id(
			card
		),
	}


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


static func _find_card(
	cards: Array,
	card_identifier: String
):
	for card in cards:
		if _card_id(
			card
		) == card_identifier:
			return card

	return null


static func _decision_for_player(
	decisions: Dictionary,
	player_id: int
) -> Dictionary:
	var raw_decision = decisions.get(
		player_id,
		null
	)

	if raw_decision == null:
		raw_decision = decisions.get(
			str(
				player_id
			),
			{}
		)

	if typeof(
		raw_decision
	) != TYPE_DICTIONARY:
		return {}

	return raw_decision


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
