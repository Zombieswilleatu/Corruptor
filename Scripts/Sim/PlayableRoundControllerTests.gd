class_name PlayableRoundControllerTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const SeededGameSetupData = preload(
	"res://Scripts/Sim/SeededGameSetup.gd"
)

const PlayableRoundControllerData = preload(
	"res://Prototype/PlayableRoundController.gd"
)


const WARD_CLEANUP_TEST_NAME := "unit_playable_frontline_ward_commitment_cleanup"


static func run(
	_rules: RuleConfig
) -> Array:
	return [
		_test_frontline_ward_cleanup(),
	]


static func _test_frontline_ward_cleanup() -> Dictionary:
	var rules: RuleConfig = RuleConfig.lab_v6_5()
	var setup: Dictionary = SeededGameSetupData.setup_locked_game(
		"Deimos",
		"Valak",
		20260724,
		rules
	)

	var game = setup.get("game", null)
	var random_source = setup.get("rng", null)

	if game == null or random_source == null:
		return _fail(
			WARD_CLEANUP_TEST_NAME,
			"Seeded playable fixture did not initialize."
		)

	var warder = game.get_player(1)
	if warder == null:
		return _fail(
			WARD_CLEANUP_TEST_NAME,
			"Playable fixture bot player is missing."
		)

	if game.deck.size() < 2:
		return _fail(
			WARD_CLEANUP_TEST_NAME,
			"Playable fixture deck does not have two cards to commit."
		)

	# setup_locked_game() has not dealt a Hand yet. Borrow two physical cards
	# from the seeded 60-card deck, then verify the playable Ward boundary moves
	# those exact objects into discard instead of losing them at round reset.
	var first_card = game.deck.pop_back()
	var second_card = game.deck.pop_back()

	warder.action = "Ward"
	warder.tgt_pid = 1
	warder.tgt_type = "Castle"
	warder.ward_target = "Castle"
	warder.committed.clear()
	warder.committed.append(first_card)
	warder.committed.append(second_card)

	# Stop at the human Reflex prompt after the primary-action window. This is
	# the exact seam where PlayableRoundController previously skipped the Ward
	# flush and left reset_round_state() to erase the cards next round.
	game.reflex_winner = 0

	var controller = PlayableRoundControllerData.new()
	controller.game = game
	controller.rules = rules
	controller.random_source = random_source
	controller.resolution_state = {
		"action_choices": {},
		"prelude_result": {},
		"order": [1],
		"next_action_index": 0,
		"action_events": [],
		"reflex_result": {},
		"finale_result": {},
		"cleanup_result": {},
		"stopped_stage": "",
	}

	var discard_before: int = game.discard.size()
	var deck_after_commit: int = game.deck.size()

	controller._advance_human_resolution()

	if (
		controller.stage
		!= PlayableRoundControllerData.Stage.RESOLUTION_REFLEX
	):
		return _fail(
			WARD_CLEANUP_TEST_NAME,
			"Playable controller did not reach the Reflex boundary."
		)

	if not warder.committed.is_empty():
		return _fail(
			WARD_CLEANUP_TEST_NAME,
			"Ward commitments survived the primary-action window."
		)

	if game.discard.size() != discard_before + 2:
		return _fail(
			WARD_CLEANUP_TEST_NAME,
			"Ward commitments were not transferred to discard."
		)

	if (
		not game.discard.has(first_card)
		or not game.discard.has(second_card)
	):
		return _fail(
			WARD_CLEANUP_TEST_NAME,
			"The exact Ward card objects were not conserved into discard."
		)

	if game.deck.size() != deck_after_commit:
		return _fail(
			WARD_CLEANUP_TEST_NAME,
			"Ward cleanup unexpectedly changed the deck after commitment."
		)

	return _pass(
		WARD_CLEANUP_TEST_NAME
	)


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

