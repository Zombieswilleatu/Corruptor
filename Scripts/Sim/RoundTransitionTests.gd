class_name RoundTransitionTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const RoundEngineData = preload(
	"res://Scripts/Sim/RoundEngine.gd"
)


const TEST_NAME: String = (
	"unit_round1_reset_and_draw"
)


const EXPECTED_PLAYER_ZERO_HAND: Array[String] = [
	"Butcher:4",
	"Penitent:3",
	"Wright:4",
	"Penitent:3",
	"Vulture:1",
	"Butcher:1",
	"Penitent:2",
	"Penitent:5",
	"Penitent:1",
]


const EXPECTED_PLAYER_ONE_HAND: Array[String] = [
	"Butcher:4",
	"Vulture:2",
	"Wright:3",
	"Butcher:2",
	"Butcher:3",
	"Wright:3",
	"Vulture:4",
	"Vulture:5",
	"Wright:3",
]


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_round1_reset_and_draw(
			rules
		)
	]


static func _test_round1_reset_and_draw(
	rules: RuleConfig
) -> Dictionary:
	var game = (
		GameDealFixtureData
		.build_game_deimos_valak_s1(
			rules
		)
	)

	if game == null:
		return _fail(
			"Fixture returned no GameState."
		)

	var player_zero = game.get_player(0)
	var player_one = game.get_player(1)

	if player_zero == null:
		return _fail(
			"Player zero is missing."
		)

	if player_one == null:
		return _fail(
			"Player one is missing."
		)

	_dirty_round_state(
		game,
		player_zero,
		player_one
	)

	RoundEngineData.advance_to_round_draw(
		game,
		1,
		rules
	)

	var validation_error: String = (
		_validate_round_state(
			game,
			player_zero,
			player_one
		)
	)

	if not validation_error.is_empty():
		return _fail(
			validation_error
		)

	return _pass()


static func _dirty_round_state(
	game,
	player_zero,
	player_one
) -> void:
	game.reflex_winner = 1

	player_zero.action = "Hunt"
	player_zero.tgt_pid = 1
	player_zero.tgt_type = "Lord"
	player_zero.ward_target = "Castle"

	player_zero.was_hunted = true
	player_zero.was_sieged = false

	player_zero.committed.append(
		CardData.new(
			"Butcher",
			1
		)
	)

	player_zero.penitent_temp_guards.append(
		CardData.new(
			"Penitent",
			1
		)
	)

	player_one.action = "Siege"
	player_one.tgt_pid = 0
	player_one.tgt_type = "Castle"
	player_one.ward_target = "Lord"

	player_one.was_hunted = false
	player_one.was_sieged = true

	player_one.committed.append(
		CardData.new(
			"Wright",
			1
		)
	)

	player_zero.sigils = {
		"Lord": "fresh",
		"Castle": "flipped",
	}

	player_one.sigils = {
		"Lord": "",
		"Castle": "fresh",
	}


static func _validate_round_state(
	game,
	player_zero,
	player_one
) -> String:
	if game.round != 1:
		return (
			"Expected round 1, received %d."
			% game.round
		)

	if game.reflex_winner != -1:
		return (
			"Reflex winner was not reset."
		)

	if not player_zero.was_lord_attacked_prev:
		return (
			"Player zero did not preserve the previous Hunt flag."
		)

	if player_zero.was_castle_attacked_prev:
		return (
			"Player zero incorrectly preserved a Siege flag."
		)

	if player_one.was_lord_attacked_prev:
		return (
			"Player one incorrectly preserved a Hunt flag."
		)

	if not player_one.was_castle_attacked_prev:
		return (
			"Player one did not preserve the previous Siege flag."
		)

	var player_reset_error: String = (
		_validate_player_reset(
			player_zero,
			"Player zero"
		)
	)

	if not player_reset_error.is_empty():
		return player_reset_error

	player_reset_error = (
		_validate_player_reset(
			player_one,
			"Player one"
		)
	)

	if not player_reset_error.is_empty():
		return player_reset_error

	if String(
		player_zero.sigils.get(
			"Lord",
			""
		)
	) != "flipped":
		return (
			"Player zero Fresh Lord Sigil did not flip."
		)

	if String(
		player_zero.sigils.get(
			"Castle",
			""
		)
	) != "":
		return (
			"Player zero Flipped Castle Sigil was not removed."
		)

	if String(
		player_one.sigils.get(
			"Castle",
			""
		)
	) != "flipped":
		return (
			"Player one Fresh Castle Sigil did not flip."
		)

	var player_zero_hand: Array[String] = (
		_card_ids(
			player_zero.hand
		)
	)

	if player_zero_hand != EXPECTED_PLAYER_ZERO_HAND:
		return (
			"Player zero Round 1 hand mismatch. Expected %s, received %s."
			% [
				str(
					EXPECTED_PLAYER_ZERO_HAND
				),
				str(
					player_zero_hand
				),
			]
		)

	var player_one_hand: Array[String] = (
		_card_ids(
			player_one.hand
		)
	)

	if player_one_hand != EXPECTED_PLAYER_ONE_HAND:
		return (
			"Player one Round 1 hand mismatch. Expected %s, received %s."
			% [
				str(
					EXPECTED_PLAYER_ONE_HAND
				),
				str(
					player_one_hand
				),
			]
		)

	if game.deck.size() != 35:
		return (
			"Expected 35 cards after the Round 1 Draw Step, received %d."
			% game.deck.size()
		)

	if game.deck.is_empty():
		return (
			"Round 1 deck unexpectedly became empty."
		)

	var top_card = game.deck[
		game.deck.size() - 1
	]

	if top_card == null:
		return (
			"Round 1 deck has no top card."
		)

	if top_card.card_id() != "Butcher:4":
		return (
			"Expected Butcher:4 on top of the remaining deck, received %s."
			% top_card.card_id()
		)

	if game.discard.size() != 4:
		return (
			"Opening summon discard changed during the Draw Step."
		)

	if game.neutral_tears != 0:
		return (
			"Round 1 incorrectly triggered Veil drift."
		)

	if game.veil_total != 0:
		return (
			"Round 1 Veil total should remain zero."
		)

	return ""


static func _validate_player_reset(
	player,
	label: String
) -> String:
	if not player.action.is_empty():
		return (
			"%s action was not reset."
			% label
		)

	if player.tgt_pid != -1:
		return (
			"%s target player was not reset."
			% label
		)

	if not player.tgt_type.is_empty():
		return (
			"%s target type was not reset."
			% label
		)

	if not player.ward_target.is_empty():
		return (
			"%s Ward target was not reset."
			% label
		)

	if player.was_hunted:
		return (
			"%s current Hunt flag was not reset."
			% label
		)

	if player.was_sieged:
		return (
			"%s current Siege flag was not reset."
			% label
		)

	if not player.committed.is_empty():
		return (
			"%s committed cards were not cleared."
			% label
		)

	if not player.penitent_temp_guards.is_empty():
		return (
			"%s temporary Penitent Guards were not cleared."
			% label
		)

	return ""


static func _card_ids(
	cards: Array
) -> Array[String]:
	var result: Array[String] = []

	for card in cards:
		if card == null:
			result.append(
				"<null>"
			)

			continue

		if card.has_method(
			"card_id"
		):
			result.append(
				String(
					card.card_id()
				)
			)
		else:
			result.append(
				str(card)
			)

	return result


static func _pass() -> Dictionary:
	return {
		"passed": true,
		"text": "PASS  %s" % TEST_NAME,
	}


static func _fail(
	reason: String
) -> Dictionary:
	return {
		"passed": false,
		"text": "FAIL  %s: %s" % [
			TEST_NAME,
			reason,
		],
	}
