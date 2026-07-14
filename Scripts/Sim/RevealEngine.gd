class_name RevealEngine
extends RefCounted


const GameSetupData = preload(
	"res://Scripts/Sim/GameSetup.gd"
)

const LordMathData = preload(
	"res://Scripts/Sim/LordMath.gd"
)


const ACTION_HUNT: String = "Hunt"
const ACTION_SIEGE: String = "Siege"
const ACTION_WARD: String = "Ward"
const ACTION_PROFANE: String = "Profane"

const ZONE_LORD: String = "Lord"
const ZONE_CASTLE: String = "Castle"


static func resolve(
	game,
	rules: RuleConfig
) -> Dictionary:
	assert(
		game != null,
		"Reveal resolution requires a GameState."
	)

	assert(
		rules != null,
		"Reveal resolution requires RuleConfig."
	)

	assert(
		game.players.size() == 2,
		"Reveal currently requires two players."
	)

	var validation: Dictionary = _validate_reveal_state(
		game
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
					"invalid_reveal_state"
				)
			),
			"invalid_player_id": int(
				validation.get(
					"player_id",
					-1
				)
			),
			"players": [],
		}

	var threat_before: Dictionary = {}
	var committed_values: Dictionary = {}
	var ward_events: Dictionary = {}
	var kanifous_events: Dictionary = {}

	for player in game.players:
		var player_id: int = int(
			player.pid
		)

		threat_before[player_id] = int(
			player.threat
		)

		committed_values[player_id] = _committed_value(
			player.committed
		)

		ward_events[player_id] = _empty_ward_event()

		kanifous_events[player_id] = _empty_kanifous_event(
			int(
				player.threat
			)
		)

	# Hunt Threat is applied before Ward Threat reduction and Kanifous Invoke.
	for player in game.players:
		if player.action != ACTION_HUNT:
			continue

		player.threat = min(
			rules.max_threat,
			int(
				player.threat
			) + 1
		)

	# Register this round's Sigils.
	for player in game.players:
		if player.action != ACTION_WARD:
			continue

		var player_id: int = int(
			player.pid
		)

		var zone: String = String(
			player.ward_target
		)

		var opponent = game.get_opponent(
			player_id
		)

		assert(
			opponent != null,
			"Reveal Ward requires an opponent."
		)

		var contested: bool = (
			(
				opponent.action == ACTION_HUNT
				and zone == ZONE_LORD
			)
			or (
				opponent.action == ACTION_SIEGE
				and zone == ZONE_CASTLE
			)
		)

		var own_value: int = int(
			committed_values.get(
				player_id,
				0
			)
		)

		var opponent_value: int = int(
			committed_values.get(
				int(
					opponent.pid
				),
				0
			)
		)

		var sigil_state: String = "fresh"

		if (
			contested
			and opponent_value > own_value
		):
			sigil_state = "flipped"

		player.sigils[zone] = sigil_state

		if zone == ZONE_LORD:
			player.threat = max(
				0,
				int(
					player.threat
				) - 1
			)

		ward_events[player_id] = {
			"warded": true,
			"zone": zone,
			"contested": contested,
			"own_committed_value": own_value,
			"opposing_committed_value": opponent_value,
			"sigil_state": sigil_state,
		}

	# Kanifous invokes after Hunt and Ward Threat changes.
	for player in game.players:
		if (
			player.lord != "Kanifous"
			or not player.alive
		):
			continue

		var player_id: int = int(
			player.pid
		)

		kanifous_events[player_id] = _resolve_kanifous(
			game,
			player,
			rules
		)

	for player in game.players:
		player.derived_lord_def = _calculate_lord_defense(
			player,
			rules
		)

	game.refresh_derived_values()

	var player_results: Array[Dictionary] = []

	for player in game.players:
		var player_id: int = int(
			player.pid
		)

		player_results.append({
			"player_id": player_id,
			"action": String(
				player.action
			),
			"committed_value": int(
				committed_values.get(
					player_id,
					0
				)
			),
			"threat_before": int(
				threat_before.get(
					player_id,
					0
				)
			),
			"threat_after": int(
				player.threat
			),
			"derived_lord_def": int(
				player.derived_lord_def
			),
			"ward": ward_events.get(
				player_id,
				_empty_ward_event()
			),
			"kanifous": kanifous_events.get(
				player_id,
				_empty_kanifous_event(
					int(
						player.threat
					)
				)
			),
		})

	return {
		"action": "reveal",
		"reason": "",
		"invalid_player_id": -1,
		"players": player_results,
	}


static func _validate_reveal_state(
	game
) -> Dictionary:
	for player in game.players:
		var player_id: int = int(
			player.pid
		)

		if not [
			ACTION_HUNT,
			ACTION_SIEGE,
			ACTION_WARD,
			ACTION_PROFANE,
		].has(
			String(
				player.action
			)
		):
			return {
				"valid": false,
				"reason": "unknown_or_missing_action",
				"player_id": player_id,
			}

		if (
			player.action == ACTION_WARD
			and not [
				ZONE_LORD,
				ZONE_CASTLE,
			].has(
				String(
					player.ward_target
				)
			)
		):
			return {
				"valid": false,
				"reason": "invalid_ward_target",
				"player_id": player_id,
			}

	return {
		"valid": true,
		"reason": "",
		"player_id": -1,
	}


static func _resolve_kanifous(
	game,
	player,
	rules: RuleConfig
) -> Dictionary:
	var threat_before: int = int(
		player.threat
	)

	var revealed_cards: Array = []

	for reveal_index in range(
		2
	):
		var revealed_card = _draw_top_card(
			game
		)

		if revealed_card == null:
			break

		revealed_cards.append(
			revealed_card
		)

	if revealed_cards.is_empty():
		return {
			"invoked": false,
			"reason": "deck_empty",
			"threat_before": threat_before,
			"threat_after": int(
				player.threat
			),
			"revealed_cards": [],
			"chosen_card": "",
			"discarded_cards": [],
			"neutral_tear_gain": 0,
			"harvested_card": "",
			"harvested_by": -1,
			"drawn_cards": [],
			"hand_discarded": "",
			"moved_guards": [],
			"temporary_guards": [],
			"banked_card": "",
			"garrison_overflow": false,
			"soul_gain": 0,
		}

	player.kanifous_invokes_this_round += 1

	player.threat = min(
		rules.max_threat,
		int(
			player.threat
		) + 1
	)

	var neutral_tear_gain: int = 0
	var harvested_card: String = ""
	var harvested_by: int = -1

	var kanifous_card = revealed_cards[0]

	if int(
		kanifous_card.value
	) >= 4:
		var tear_event: Dictionary = _gain_neutral_tear(
			game
		)

		neutral_tear_gain = 1

		harvested_card = String(
			tear_event.get(
				"harvested_card",
				""
			)
		)

		harvested_by = int(
			tear_event.get(
				"harvested_by",
				-1
			)
		)

	var chosen_card = _choose_kanifous_card(
		revealed_cards,
		player
	)

	assert(
		chosen_card != null,
		"Kanifous revealed cards but selected no Invoke card."
	)

	var discarded_cards: Array = []

	for card in revealed_cards:
		if card == chosen_card:
			continue

		game.discard.append(
			card
		)

		discarded_cards.append(
			card
		)

	player.kanifous_invoked_suit = String(
		chosen_card.suit
	)

	var drawn_cards: Array = []
	var hand_discarded = null
	var moved_guards: Array = []
	var temporary_guards: Array = []

	match String(
		chosen_card.suit
	):
		"Vulture":
			for draw_index in range(
				3
			):
				var drawn_card = _draw_outside_development(
					game,
					player,
					rules
				)

				if drawn_card != null:
					drawn_cards.append(
						drawn_card
					)

			if player.hand.size() > 1:
				var lowest_index: int = _lowest_card_index(
					player.hand
				)

				if lowest_index >= 0:
					hand_discarded = player.hand[
						lowest_index
					]

					player.hand.remove_at(
						lowest_index
					)

					game.discard.append(
						hand_discarded
					)

		"Wright":
			var moved_count: int = 0

			while (
				moved_count < 2
				and not player.lord_guards.is_empty()
				and player.castle_guards.size()
				< _max_castle_guards(
					player,
					rules
				)
			):
				var guard = player.lord_guards.pop_front()

				player.castle_guards.append(
					guard
				)

				moved_guards.append(
					guard
				)

				moved_count += 1

		"Penitent":
			for guard_index in range(
				2
			):
				var temporary_guard = _draw_top_card(
					game
				)

				if temporary_guard == null:
					break

				if (
					player.lord_guards.size()
					<= player.castle_guards.size()
				):
					player.lord_guards.append(
						temporary_guard
					)
				else:
					player.castle_guards.append(
						temporary_guard
					)

				player.penitent_temp_guards.append(
					temporary_guard
				)

				temporary_guards.append(
					temporary_guard
				)

			player.kanifous_invoked_high = true

		"Butcher":
			pass

	var soul_gain: int = 0

	if int(
		chosen_card.value
	) == int(
		player.threat
	):
		player.souls += 1
		soul_gain = 1

	var banked_card: String = ""
	var garrison_overflow: bool = false

	if (
		player.garrison.size() < rules.garrison_max
		and not player.garrison.has(
			chosen_card
		)
	):
		player.garrison.append(
			chosen_card
		)

		banked_card = _card_id(
			chosen_card
		)
	else:
		game.discard.append(
			chosen_card
		)

		discarded_cards.append(
			chosen_card
		)

		garrison_overflow = true

	var hand_discarded_id: String = ""

	if hand_discarded != null:
		hand_discarded_id = _card_id(
			hand_discarded
		)

	return {
		"invoked": true,
		"reason": "",
		"threat_before": threat_before,
		"threat_after": int(
			player.threat
		),
		"revealed_cards": _card_ids(
			revealed_cards
		),
		"chosen_card": _card_id(
			chosen_card
		),
		"discarded_cards": _card_ids(
			discarded_cards
		),
		"neutral_tear_gain": neutral_tear_gain,
		"harvested_card": harvested_card,
		"harvested_by": harvested_by,
		"drawn_cards": _card_ids(
			drawn_cards
		),
		"hand_discarded": hand_discarded_id,
		"moved_guards": _card_ids(
			moved_guards
		),
		"temporary_guards": _card_ids(
			temporary_guards
		),
		"banked_card": banked_card,
		"garrison_overflow": garrison_overflow,
		"soul_gain": soul_gain,
	}


static func _choose_kanifous_card(
	revealed_cards: Array,
	player
):
	if revealed_cards.is_empty():
		return null

	var chosen_card = revealed_cards[0]
	var chosen_score: float = _kanifous_card_score(
		chosen_card,
		player
	)

	for index in range(
		1,
		revealed_cards.size()
	):
		var candidate = revealed_cards[
			index
		]

		var candidate_score: float = _kanifous_card_score(
			candidate,
			player
		)

		if candidate_score > chosen_score:
			chosen_card = candidate
			chosen_score = candidate_score

	return chosen_card


static func _kanifous_card_score(
	card,
	player
) -> float:
	match String(
		card.suit
	):
		"Butcher":
			if [
				ACTION_HUNT,
				ACTION_SIEGE,
			].has(
				String(
					player.action
				)
			):
				return 1.5

			return 0.5

		"Penitent":
			var total_guards: int = (
				player.lord_guards.size()
				+ player.castle_guards.size()
			)

			if total_guards <= 2:
				return 1.2

			return 0.6

		"Vulture":
			if player.hand.size() <= 3:
				return 1.3

			return 0.7

		"Wright":
			var imbalance: int = abs(
				player.lord_guards.size()
				- player.castle_guards.size()
			)

			return (
				0.8
				+ float(
					imbalance
				) * 0.2
			)

	return 0.5


static func _draw_outside_development(
	game,
	player,
	rules: RuleConfig
):
	if player.hand.size() >= rules.hand_limit:
		return null

	var card = _draw_top_card(
		game
	)

	if card == null:
		return null

	player.hand.append(
		card
	)

	player.kanifous_outside_draws += 1

	if game.breach == "Kanifous":
		player.threat = min(
			rules.max_threat,
			int(
				player.threat
			) + 1
		)

	return card


static func _draw_top_card(
	game
):
	if game.deck.is_empty():
		return null

	return game.deck.pop_back()


static func _gain_neutral_tear(
	game
) -> Dictionary:
	game.neutral_tears += 1

	var harvested_card: String = ""
	var harvested_by: int = -1

	for candidate in game.players:
		if (
			candidate.lord != "Gremory"
			or not candidate.alive
			or candidate.gremory_veil_draw_done
		):
			continue

		for index in range(
			game.discard.size() - 1,
			-1,
			-1
		):
			var card = game.discard[
				index
			]

			if int(
				card.value
			) < 4:
				continue

			game.discard.remove_at(
				index
			)

			candidate.hand.append(
				card
			)

			candidate.gremory_veil_draw_done = true

			harvested_card = _card_id(
				card
			)

			harvested_by = int(
				candidate.pid
			)

			break

		break

	game.refresh_derived_values()

	return {
		"harvested_card": harvested_card,
		"harvested_by": harvested_by,
	}


static func _calculate_lord_defense(
	player,
	rules: RuleConfig
) -> int:
	if not player.alive:
		return 0

	if player.lord == "Humbaba":
		return LordMathData.lord_base_def(
			"Humbaba",
			player.castles,
			int(
				player.threat
			),
			rules
		)

	var lord_data: Dictionary = (
		GameSetupData.LORD_CONTENT.get(
			player.lord,
			{}
		)
	)

	var defense: int = int(
		lord_data.get(
			"base_defense",
			0
		)
	)

	if player.threat >= 4:
		defense -= 3
	elif player.threat >= 3:
		defense -= 2
	elif player.threat >= 2:
		defense -= 1

	if player.castles.has(
		"Bastion"
	):
		defense += 2

	return max(
		0,
		defense
	)


static func _max_castle_guards(
	player,
	rules: RuleConfig
) -> int:
	if (
		player.lord == "Humbaba"
		and rules.humbaba_gate4
		and player.ruined_castles.is_empty()
	):
		return 4

	return 3


static func _lowest_card_index(
	cards: Array
) -> int:
	if cards.is_empty():
		return -1

	var lowest_index: int = 0
	var lowest_value: int = int(
		cards[0].value
	)

	for index in range(
		1,
		cards.size()
	):
		var current_value: int = int(
			cards[index].value
		)

		if current_value < lowest_value:
			lowest_index = index
			lowest_value = current_value

	return lowest_index


static func _committed_value(
	cards: Array
) -> int:
	var total: int = 0

	for card in cards:
		total += int(
			card.value
		)

	return total


static func _empty_ward_event() -> Dictionary:
	return {
		"warded": false,
		"zone": "",
		"contested": false,
		"own_committed_value": 0,
		"opposing_committed_value": 0,
		"sigil_state": "",
	}


static func _empty_kanifous_event(
	threat: int
) -> Dictionary:
	return {
		"invoked": false,
		"reason": "not_kanifous",
		"threat_before": threat,
		"threat_after": threat,
		"revealed_cards": [],
		"chosen_card": "",
		"discarded_cards": [],
		"neutral_tear_gain": 0,
		"harvested_card": "",
		"harvested_by": -1,
		"drawn_cards": [],
		"hand_discarded": "",
		"moved_guards": [],
		"temporary_guards": [],
		"banked_card": "",
		"garrison_overflow": false,
		"soul_gain": 0,
	}


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
