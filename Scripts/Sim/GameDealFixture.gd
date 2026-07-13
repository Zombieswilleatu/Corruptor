class_name GameDealFixture
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameSetupData = preload(
	"res://Scripts/Sim/GameSetup.gd"
)


# The golden trace begins after setup, so this fixture supplies a
# deterministic pre-setup deck whose pop order reproduces that snapshot.
#
# GameSetup draws from the end of the Array with pop_back().
#
# The untouched portion below becomes the exact remaining deck after:
# - three Market cards
# - five opening cards for player zero
# - five opening cards for player one
# - opening summon payments
const REMAINING_DECK_IDS: Array[String] = [
	"Wright:2",
	"Vulture:3",
	"Vulture:4",
	"Vulture:1",
	"Wright:3",
	"Penitent:4",
	"Wright:5",
	"Butcher:2",
	"Penitent:1",
	"Penitent:1",
	"Vulture:3",
	"Vulture:1",
	"Wright:1",
	"Penitent:3",
	"Penitent:4",
	"Butcher:5",
	"Wright:1",
	"Butcher:2",
	"Butcher:1",
	"Butcher:3",
	"Butcher:1",
	"Butcher:3",
	"Vulture:3",
	"Penitent:2",
	"Vulture:4",
	"Wright:1",
	"Vulture:2",
	"Wright:2",
	"Butcher:3",
	"Vulture:5",
	"Penitent:5",
	"Wright:2",
	"Penitent:4",
	"Butcher:5",
	"Butcher:4",
	"Wright:3",
	"Vulture:5",
	"Vulture:4",
	"Wright:3",
	"Butcher:3",
	"Butcher:2",
	"Penitent:1",
	"Penitent:5",
	"Penitent:2",
	"Butcher:1",
	"Vulture:1",
	"Penitent:3",
]


# Chronological pop order during setup.
#
# Market:
#   Penitent:1
#   Wright:1
#   Wright:5
#
# Player zero opening hand before summoning Deimos:
#   Vulture:2
#   Penitent:3
#   Butcher:4
#   Penitent:3
#   Wright:4
#
# Deimos costs 5 after the Summoning Circle discount.
# Payment: Vulture:2 + Penitent:3.
#
# Player one opening hand before summoning Valak:
#   Wright:2
#   Vulture:2
#   Butcher:4
#   Vulture:2
#   Wright:3
#
# Valak costs 4 after the Summoning Circle discount.
# Payment: Wright:2 + Vulture:2.
const SETUP_POP_SEQUENCE_IDS: Array[String] = [
	"Penitent:1",
	"Wright:1",
	"Wright:5",

	"Vulture:2",
	"Penitent:3",
	"Butcher:4",
	"Penitent:3",
	"Wright:4",

	"Wright:2",
	"Vulture:2",
	"Butcher:4",
	"Vulture:2",
	"Wright:3",
]


static func build_game_deimos_valak_s1(
	rules: RuleConfig = null
):
	var effective_rules: RuleConfig = rules

	if effective_rules == null:
		effective_rules = RuleConfig.de_v2()

	var ordered_deck: Array = _cards_from_ids(
		_build_ordered_deck_ids()
	)

	return GameSetupData.setup_game(
		["Deimos"],
		["Valak"],
		ordered_deck,
		1,
		effective_rules
	)


static func _build_ordered_deck_ids() -> Array:
	var ordered_ids: Array = []

	for card_identifier: String in REMAINING_DECK_IDS:
		ordered_ids.append(
			card_identifier
		)

	# GameSetup uses pop_back(), so the chronological setup sequence
	# must be appended in reverse.
	for index in range(
		SETUP_POP_SEQUENCE_IDS.size() - 1,
		-1,
		-1
	):
		ordered_ids.append(
			SETUP_POP_SEQUENCE_IDS[index]
		)

	assert(
		ordered_ids.size() == 60,
		"Deimos/Valak deterministic setup deck must contain 60 cards."
	)

	return ordered_ids


static func _cards_from_ids(
	card_ids: Array
) -> Array:
	var cards: Array = []

	for card_identifier in card_ids:
		cards.append(
			_card_from_id(
				str(card_identifier)
			)
		)

	return cards


static func _card_from_id(
	card_identifier: String
):
	var separator_index: int = card_identifier.rfind(
		":"
	)

	assert(
		separator_index > 0,
		"Invalid Corruptor card identifier: %s"
		% card_identifier
	)

	var suit: String = card_identifier.substr(
		0,
		separator_index
	)

	var value_text: String = card_identifier.substr(
		separator_index + 1
	)

	assert(
		value_text.is_valid_int(),
		"Invalid Corruptor card value: %s"
		% card_identifier
	)

	return CardData.new(
		suit,
		int(value_text)
	)
