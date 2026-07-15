class_name SeededGameSetup
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameSetupData = preload(
	"res://Scripts/Sim/GameSetup.gd"
)

const PythonRandomData = preload(
	"res://Scripts/Sim/PythonRandom.gd"
)


const SUITS: Array[String] = [
	"Butcher",
	"Penitent",
	"Vulture",
	"Wright",
]

const CARD_VALUES: Array[int] = [
	1,
	2,
	3,
	4,
	5,
]

const CARD_COUNTS: Dictionary = {
	1: 4,
	2: 4,
	3: 4,
	4: 3,
	5: 3,
}

const REMOVED_PER_SUIT: int = 3


static func setup_locked_game(
	player_zero_lord: String,
	player_one_lord: String,
	seed_value: int,
	rules: RuleConfig = null
) -> Dictionary:
	assert(
		not player_zero_lord.is_empty(),
		"Player zero requires a Lord."
	)

	assert(
		not player_one_lord.is_empty(),
		"Player one requires a Lord."
	)

	var effective_rules: RuleConfig = rules

	if effective_rules == null:
		effective_rules = RuleConfig.de_v2()

	var random_source = PythonRandomData.new(
		seed_value
	)

	var ordered_deck: Array = _make_python_deck(
		random_source
	)

	var first_player: int = random_source.randint(
		0,
		1
	)

	var player_zero_pool: Array[String] = [
		player_zero_lord,
	]

	var player_one_pool: Array[String] = [
		player_one_lord,
	]

	var game = GameSetupData.setup_game(
		player_zero_pool,
		player_one_pool,
		ordered_deck,
		first_player,
		effective_rules
	)

	return {
		"game": game,
		"rng": random_source,
		"seed": seed_value,
	}


static func setup_deimos_valak_seed_one(
	rules: RuleConfig = null
) -> Dictionary:
	return setup_locked_game(
		"Deimos",
		"Valak",
		1,
		rules
	)


static func _make_python_deck(
	random_source
) -> Array:
	var cards: Array = []

	for suit_name: String in SUITS:
		for card_value: int in CARD_VALUES:
			var card_count: int = int(
				CARD_COUNTS.get(
					card_value,
					0
				)
			)

			for copy_index: int in range(
				card_count
			):
				cards.append(
					CardData.new(
						suit_name,
						card_value
					)
				)

	assert(
		cards.size() == 72,
		"Corruptor's untrimmed two-player deck must contain 72 cards."
	)

	random_source.shuffle(
		cards
	)

	var removed_counts: Dictionary = {}

	for suit_name: String in SUITS:
		removed_counts[suit_name] = 0

	var trimmed_deck: Array = []

	for card in cards:
		var suit_name: String = String(
			card.suit
		)

		var removed_count: int = int(
			removed_counts.get(
				suit_name,
				0
			)
		)

		if removed_count < REMOVED_PER_SUIT:
			removed_counts[suit_name] = (
				removed_count + 1
			)

			continue

		trimmed_deck.append(
			card
		)

	assert(
		trimmed_deck.size() == 60,
		"Corruptor's trimmed two-player deck must contain 60 cards."
	)

	random_source.shuffle(
		trimmed_deck
	)

	return trimmed_deck
