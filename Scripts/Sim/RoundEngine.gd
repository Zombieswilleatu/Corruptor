class_name RoundEngine
extends RefCounted


const BASE_DRAW_COUNT: int = 5
const STOCKPILE_DRAW_BONUS: int = 1

const SIGIL_ZONES: Array[String] = [
	"Lord",
	"Castle",
]


static func advance_to_round_draw(
	game,
	round_number: int,
	rules: RuleConfig
) -> void:
	begin_round(
		game,
		round_number
	)

	_update_sigils(
		game,
		rules
	)

	_apply_veil_drift(
		game,
		rules
	)

	_run_draw_step(
		game,
		rules
	)

	game.refresh_derived_values()


static func begin_round(
	game,
	round_number: int
) -> void:
	assert(
		game != null,
		"RoundEngine requires a GameState."
	)

	assert(
		round_number >= 1,
		"Round number must be at least 1."
	)

	game.round = round_number
	game.reflex_winner = -1

	for player in game.players:
		player.reset_round_state()

	game.refresh_derived_values()


static func _update_sigils(
	game,
	rules: RuleConfig
) -> void:
	for player in game.players:
		var preserved_zone: String = ""

		if (
			rules.humbaba_patient
			and player.humbaba_patient
		):
			player.humbaba_patient = false

			if _sigil_state(
				player,
				"Lord"
			) == "fresh":
				preserved_zone = "Lord"
			elif _sigil_state(
				player,
				"Castle"
			) == "fresh":
				preserved_zone = "Castle"
			elif _sigil_state(
				player,
				"Lord"
			) == "flipped":
				preserved_zone = "Lord"
			elif _sigil_state(
				player,
				"Castle"
			) == "flipped":
				preserved_zone = "Castle"

		for zone: String in SIGIL_ZONES:
			if zone == preserved_zone:
				continue

			var state: String = _sigil_state(
				player,
				zone
			)

			if state == "flipped":
				player.sigils[zone] = ""
			elif state == "fresh":
				player.sigils[zone] = "flipped"


static func _apply_veil_drift(
	game,
	rules: RuleConfig
) -> void:
	if rules.veil_drift <= 0:
		return

	if game.round <= 1:
		return

	if game.round % rules.veil_drift != 0:
		return

	game.neutral_tears += 1
	game.refresh_derived_values()


static func _run_draw_step(
	game,
	rules: RuleConfig
) -> void:
	for player in game.players:
		var draw_count: int = BASE_DRAW_COUNT

		if player.castles.has(
			"Stockpile"
		):
			draw_count += STOCKPILE_DRAW_BONUS

		for draw_index in range(
			draw_count
		):
			_draw_to_hand(
				game,
				player,
				rules.hand_limit
			)


static func _draw_to_hand(
	game,
	player,
	hand_limit: int
) -> bool:
	if player.hand.size() >= hand_limit:
		return false

	var card = _draw_top_card(
		game
	)

	if card == null:
		return false

	player.hand.append(
		card
	)

	return true


static func _draw_top_card(
	game
):
	# The seed-one Round 1 checkpoint does not exhaust the deck.
	# Deterministic discard recycling will be added with the engine RNG.
	if game.deck.is_empty():
		return null

	return game.deck.pop_back()


static func _sigil_state(
	player,
	zone: String
) -> String:
	return String(
		player.sigils.get(
			zone,
			""
		)
	)
