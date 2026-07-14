class_name CommitmentEngine
extends RefCounted


const ACTION_HUNT: String = "Hunt"
const ACTION_SIEGE: String = "Siege"
const ACTION_WARD: String = "Ward"
const ACTION_PROFANE: String = "Profane"

const TARGET_LORD: String = "Lord"
const TARGET_CASTLE: String = "Castle"

const VALID_SUITS: Array[String] = [
	"Butcher",
	"Penitent",
	"Vulture",
	"Wright",
]


static func resolve(
	game,
	commitment_choices: Dictionary
) -> Dictionary:
	assert(
		game != null,
		"Commitment resolution requires a GameState."
	)

	assert(
		game.players.size() == 2,
		"Commitment currently requires two players."
	)

	var validated_plans: Array[Dictionary] = []

	# Validate every sealed order before mutating either player.
	for player in game.players:
		var player_id: int = int(
			player.pid
		)

		var decision: Dictionary = _decision_for_player(
			commitment_choices,
			player_id
		)

		var validation: Dictionary = _validate_commitment(
			game,
			player,
			decision
		)

		if not bool(
			validation.get(
				"valid",
				false
			)
		):
			return {
				"action": "invalid",
				"reason": String(
					validation.get(
						"reason",
						"invalid_commitment"
					)
				),
				"invalid_player_id": player_id,
				"players": [],
			}

		validated_plans.append(
			validation
		)

	var player_results: Array[Dictionary] = []

	for plan in validated_plans:
		var player_id: int = int(
			plan.get(
				"player_id",
				-1
			)
		)

		var player = game.get_player(
			player_id
		)

		assert(
			player != null,
			"Validated Commitment player no longer exists."
		)

		var selected_cards: Array = plan.get(
			"cards",
			[]
		)

		player.action = String(
			plan.get(
				"action",
				""
			)
		)

		player.tgt_pid = int(
			plan.get(
				"target_pid",
				-1
			)
		)

		player.tgt_type = String(
			plan.get(
				"target_type",
				""
			)
		)

		player.ward_target = String(
			plan.get(
				"ward_target",
				""
			)
		)

		# Specific Siege and Profane Castles are chosen after Reveal.
		player.last_sieged_castle = ""
		player.pending_profane = ""

		player.committed.clear()

		for card in selected_cards:
			assert(
				player.hand.has(
					card
				),
				"Validated Commitment card left the player's hand."
			)

			player.hand.erase(
				card
			)

			player.committed.append(
				card
			)

		player_results.append({
			"player_id": player_id,
			"action": String(
				player.action
			),
			"target_pid": int(
				player.tgt_pid
			),
			"target_type": String(
				player.tgt_type
			),
			"ward_target": String(
				player.ward_target
			),
			"committed_cards": _card_ids(
				player.committed
			),
			"committed_value": _committed_value(
				player.committed
			),
			"suit_counts": _suit_counts(
				player.committed
			),
		})

	return {
		"action": "commit",
		"reason": "",
		"invalid_player_id": -1,
		"players": player_results,
	}


static func _validate_commitment(
	game,
	player,
	decision: Dictionary
) -> Dictionary:
	var player_id: int = int(
		player.pid
	)

	if (
		not player.action.is_empty()
		or not player.committed.is_empty()
	):
		return _invalid_plan(
			player_id,
			"already_committed"
		)

	var action_name: String = _canonical_action(
		String(
			decision.get(
				"action",
				""
			)
		)
	)

	if action_name.is_empty():
		return _invalid_plan(
			player_id,
			"action_required"
		)

	if (
		not player.alive
		and action_name != ACTION_WARD
	):
		return _invalid_plan(
			player_id,
			"banished_lord_must_ward"
		)

	var target_pid: int = int(
		decision.get(
			"target_pid",
			-1
		)
	)

	if (
		target_pid < 0
		or target_pid >= game.players.size()
	):
		return _invalid_plan(
			player_id,
			"invalid_target_player"
		)

	var opponent = game.get_opponent(
		player_id
	)

	assert(
		opponent != null,
		"Commitment requires an opponent."
	)

	var target_type: String = ""
	var ward_target: String = ""

	match action_name:
		ACTION_HUNT:
			target_type = TARGET_LORD

			if target_pid != int(
				opponent.pid
			):
				return _invalid_plan(
					player_id,
					"hunt_must_target_opponent"
				)

			if not opponent.alive:
				return _invalid_plan(
					player_id,
					"hunt_target_is_banished"
				)

		ACTION_SIEGE:
			target_type = TARGET_CASTLE

			if target_pid != int(
				opponent.pid
			):
				return _invalid_plan(
					player_id,
					"siege_must_target_opponent"
				)

			if opponent.castles.is_empty():
				return _invalid_plan(
					player_id,
					"siege_target_has_no_castles"
				)

		ACTION_PROFANE:
			target_type = TARGET_CASTLE

			if target_pid != player_id:
				return _invalid_plan(
					player_id,
					"profane_must_target_self"
				)

			if player.castles.is_empty():
				return _invalid_plan(
					player_id,
					"no_castle_to_profane"
				)

		ACTION_WARD:
			if target_pid != player_id:
				return _invalid_plan(
					player_id,
					"ward_must_target_own_zone"
				)

			target_type = _canonical_target_type(
				String(
					decision.get(
						"target_type",
						""
					)
				)
			)

			if target_type.is_empty():
				return _invalid_plan(
					player_id,
					"ward_target_type_required"
				)

			if (
				target_type == TARGET_LORD
				and not player.alive
			):
				return _invalid_plan(
					player_id,
					"banished_lord_zone_unavailable"
				)

			if player.prev_ward_target == target_type:
				return _invalid_plan(
					player_id,
					"ward_target_repeated"
				)

			ward_target = target_type

	var raw_cards = decision.get(
		"cards",
		[]
	)

	if typeof(raw_cards) != TYPE_ARRAY:
		return _invalid_plan(
			player_id,
			"cards_must_be_array"
		)

	var card_ids: Array = raw_cards

	var selection: Dictionary = _select_hand_cards(
		player,
		card_ids
	)

	if not bool(
		selection.get(
			"valid",
			false
		)
	):
		return _invalid_plan(
			player_id,
			String(
				selection.get(
					"reason",
					"invalid_cards"
				)
			)
		)

	return {
		"valid": true,
		"reason": "",
		"player_id": player_id,
		"action": action_name,
		"target_pid": target_pid,
		"target_type": target_type,
		"ward_target": ward_target,
		"cards": selection.get(
			"cards",
			[]
		),
	}


static func _select_hand_cards(
	player,
	card_ids: Array
) -> Dictionary:
	var selected_cards: Array = []

	for raw_card_id in card_ids:
		var card_identifier: String = String(
			raw_card_id
		)

		var selected_card = _find_unselected_card(
			player.hand,
			card_identifier,
			selected_cards
		)

		if selected_card == null:
			return {
				"valid": false,
				"reason": (
					"commit_card_missing_%s"
					% card_identifier
				),
				"cards": [],
			}

		selected_cards.append(
			selected_card
		)

	return {
		"valid": true,
		"reason": "",
		"cards": selected_cards,
	}


static func _find_unselected_card(
	cards: Array,
	card_identifier: String,
	selected_cards: Array
):
	for card in cards:
		if (
			not selected_cards.has(
				card
			)
			and _card_id(
				card
			) == card_identifier
		):
			return card

	return null


static func _canonical_action(
	raw_action: String
) -> String:
	var action_key: String = (
		raw_action
		.strip_edges()
		.to_lower()
	)

	if action_key == "hunt":
		return ACTION_HUNT

	if action_key == "siege":
		return ACTION_SIEGE

	if (
		action_key == "ward"
		or action_key == "sigil"
	):
		return ACTION_WARD

	if action_key == "profane":
		return ACTION_PROFANE

	return ""


static func _canonical_target_type(
	raw_target_type: String
) -> String:
	var target_key: String = (
		raw_target_type
		.strip_edges()
		.to_lower()
	)

	if target_key == "lord":
		return TARGET_LORD

	if target_key == "castle":
		return TARGET_CASTLE

	return ""


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

	if typeof(raw_decision) != TYPE_DICTIONARY:
		return {}

	return raw_decision


static func _invalid_plan(
	player_id: int,
	reason: String
) -> Dictionary:
	return {
		"valid": false,
		"reason": reason,
		"player_id": player_id,
		"action": "",
		"target_pid": -1,
		"target_type": "",
		"ward_target": "",
		"cards": [],
	}


static func _committed_value(
	cards: Array
) -> int:
	var total: int = 0

	for card in cards:
		total += int(
			card.value
		)

	return total


static func _suit_counts(
	cards: Array
) -> Dictionary:
	var counts: Dictionary = {}

	for suit_name: String in VALID_SUITS:
		counts[suit_name] = 0

	for card in cards:
		var suit_name: String = String(
			card.suit
		)

		counts[suit_name] = int(
			counts.get(
				suit_name,
				0
			)
		) + 1

	return counts


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
