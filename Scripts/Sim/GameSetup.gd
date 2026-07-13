class_name GameSetup
extends RefCounted


const GameStateData = preload(
	"res://Scripts/Sim/GameState.gd"
)


const OPENING_HAND_SIZE: int = 5
const SUMMONING_CIRCLE_DISCOUNT: int = 2
const BREACH_SUMMON_PENALTY: int = 3


const ALL_CASTLES: Array[String] = [
	"Keep",
	"Bastion",
	"SummoningCircle",
	"Stockpile",
	"SiegeEngine",
]


const LORD_CONTENT: Dictionary = {
	"Orias": {
		"summon_cost": 6,
		"base_defense": 6,
		"return_threat": 0,
	},
	"Deimos": {
		"summon_cost": 9,
		"base_defense": 4,
		"return_threat": 0,
	},
	"Valak": {
		"summon_cost": 6,
		"base_defense": 5,
		"return_threat": 1,
	},
	"Kroni": {
		"summon_cost": 5,
		"base_defense": 4,
		"return_threat": 1,
	},
	"Kalligan": {
		"summon_cost": 4,
		"base_defense": 4,
		"return_threat": 1,
	},
	"Gremory": {
		"summon_cost": 5,
		"base_defense": 4,
		"return_threat": 2,
	},
	"Odradek": {
		"summon_cost": 8,
		"base_defense": 5,
		"return_threat": 2,
	},
	"Kanifous": {
		"summon_cost": 4,
		"base_defense": 5,
		"return_threat": 1,
	},
	"Humbaba": {
		"summon_cost": 6,
		"base_defense": 2,
		"return_threat": 2,
	},
}


static func setup_game(
	player_zero_lord_pool: Array[String],
	player_one_lord_pool: Array[String],
	ordered_deck: Array,
	first_player: int,
	rules: RuleConfig
):
	assert(
		first_player == 0 or first_player == 1,
		"First player must be either 0 or 1."
	)

	assert(
		not player_zero_lord_pool.is_empty(),
		"Player zero must have at least one Lord."
	)

	assert(
		not player_one_lord_pool.is_empty(),
		"Player one must have at least one Lord."
	)

	var required_card_count: int = (
		rules.market_size
		+ OPENING_HAND_SIZE
		+ OPENING_HAND_SIZE
	)

	assert(
		ordered_deck.size() >= required_card_count,
		"Setup deck needs at least %d cards, but received %d."
		% [
			required_card_count,
			ordered_deck.size(),
		]
	)

	var game = GameStateData.new(
		player_zero_lord_pool,
		player_one_lord_pool
	)

	_reset_game_state(game)

	game.deck = _duplicate_cards(
		ordered_deck
	)

	_deal_market(
		game,
		rules.market_size
	)

	game.first_player = first_player

	for player in game.players:
		_prepare_player_for_setup(
			player
		)

		for draw_index in range(
			OPENING_HAND_SIZE
		):
			var drew_card: bool = _draw_to_hand(
				game,
				player,
				rules.hand_limit
			)

			assert(
				drew_card,
				"Unable to deal opening card %d to player %d."
				% [
					draw_index + 1,
					int(player.pid),
				]
			)

	for player in game.players:
		_force_opening_summon(
			game,
			player,
			rules
		)

	game.refresh_derived_values()

	return game


static func _reset_game_state(game) -> void:
	game.round = 0
	game.first_player = -1

	game.breach = ""
	game.breach_owner = -1
	game.reflex_winner = -1

	game.neutral_tears = 0
	game.veil_total = 0

	game.winner = -1
	game.win_by = ""

	game.deck.clear()
	game.discard.clear()
	game.market.clear()


static func _prepare_player_for_setup(player) -> void:
	assert(
		not player.lord_pool.is_empty(),
		"Player %d has no Lords in their pool."
		% int(player.pid)
	)

	player.lord = String(
		player.lord_pool[0]
	)

	player.alive = false

	player.souls = 0
	player.tears = 0
	player.threat = 0
	player.kroni_hunger = 0
	player.repair_token = 0

	player.first_summon_done = false
	player.cataclysmic_used = false
	player.vessel_used = false
	player.vessel_offered_lord = ""
	player.kalligan_repair_used = false
	player.kroni_ravenous_used = false
	player.deimos_breach_claimed = false

	player.action = ""
	player.tgt_pid = -1
	player.tgt_type = ""
	player.ward_target = ""
	player.prev_ward_target = ""

	player.was_hunted = false
	player.was_sieged = false
	player.was_lord_attacked_prev = false
	player.was_castle_attacked_prev = false
	player.last_sieged_castle = ""

	player.pending_profane = ""
	player.orias_snare_active = false
	player.profane_ruins_used_this_round = false
	player.profane_this_round = false

	player.humbaba_patient = false

	player.odradek_recoil_done = false
	player.odradek_guards_defeated = 0

	player.gremory_ruin_done = false
	player.gremory_inevitable_ruin_done = false
	player.gremory_veil_draw_done = false
	player.gremory_lord_guard_draw_done = false

	player.kanifous_outside_draws = 0
	player.kanifous_invoked_suit = ""
	player.kanifous_invoked_high = false
	player.kanifous_invokes_this_round = 0

	player.kroni_consume_done = false
	player.kroni_personally_defeated_guard = false
	player.kroni_enemy_destroyed = false
	player.kroni_tear_milestone_fired = false

	player.hand.clear()
	player.garrison.clear()
	player.castle_guards.clear()
	player.lord_guards.clear()
	player.committed.clear()
	player.penitent_temp_guards.clear()

	player.castles.clear()

	for castle_name: String in ALL_CASTLES:
		player.castles.append(
			castle_name
		)

	player.ruined_castles.clear()
	player.profaned_castles.clear()

	player.sigils = {
		"Castle": "",
		"Lord": "",
	}

	player.derived_lord_def = 0


static func _deal_market(
	game,
	market_size: int
) -> void:
	game.market.clear()

	for market_index in range(
		market_size
	):
		var card = _draw_top_card(
			game
		)

		assert(
			card != null,
			"Deck exhausted while dealing market card %d."
			% (
				market_index
				+ 1
			)
		)

		game.market.append(
			card
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


static func _draw_top_card(game):
	if game.deck.is_empty():
		return null

	return game.deck.pop_back()


static func _force_opening_summon(
	game,
	player,
	rules: RuleConfig
) -> void:
	var chosen_lord := String(
		player.lord_pool[0]
	)

	assert(
		LORD_CONTENT.has(
			chosen_lord
		),
		"Unknown Lord during setup: %s"
		% chosen_lord
	)

	player.lord = chosen_lord

	var summon_cost: int = _summon_cost(
		chosen_lord,
		player,
		game,
		rules
	)

	_pay_from_hand(
		game,
		player,
		summon_cost
	)

	player.alive = true
	player.threat = _return_threat(
		chosen_lord
	)

	player.first_summon_done = true

	if chosen_lord == "Kroni":
		player.kroni_tear_milestone_fired = false

	player.derived_lord_def = _calculate_lord_defense(
		player,
		rules
	)


static func _summon_cost(
	lord_id: String,
	player,
	game,
	rules: RuleConfig
) -> int:
	var lord_data: Dictionary = LORD_CONTENT.get(
		lord_id,
		{}
	)

	var cost := int(
		lord_data.get(
			"summon_cost",
			0
		)
	)

	if lord_id == "Deimos" and rules.deimos_summon_cost > 0:
		cost = rules.deimos_summon_cost

	if lord_id == "Gremory" and rules.gremory_summon_cost > 0:
		cost = rules.gremory_summon_cost

	if player.castles.has(
		"SummoningCircle"
	):
		cost -= SUMMONING_CIRCLE_DISCOUNT

	if game.breach == lord_id:
		cost += BREACH_SUMMON_PENALTY

	return max(
		0,
		cost
	)


static func _pay_from_hand(
	game,
	player,
	cost: int
) -> int:
	if cost <= 0:
		return 0

	var paid_total: int = 0

	while (
		paid_total < cost
		and not player.hand.is_empty()
	):
		var lowest_index: int = _lowest_card_index(
			player.hand
		)

		assert(
			lowest_index >= 0,
			"Unable to locate a summon payment card."
		)

		var card = player.hand[
			lowest_index
		]

		player.hand.remove_at(
			lowest_index
		)

		game.discard.append(
			card
		)

		paid_total += int(
			card.value
		)

	return paid_total


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


static func _return_threat(
	lord_id: String
) -> int:
	var lord_data: Dictionary = LORD_CONTENT.get(
		lord_id,
		{}
	)

	return int(
		lord_data.get(
			"return_threat",
			0
		)
	)


static func _calculate_lord_defense(
	player,
	rules: RuleConfig
) -> int:
	if player.lord == "Humbaba":
		return LordMath.lord_base_def(
			"Humbaba",
			player.castles,
			player.threat,
			rules
		)

	var lord_data: Dictionary = LORD_CONTENT.get(
		player.lord,
		{}
	)

	var defense := int(
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


static func _duplicate_cards(
	cards: Array
) -> Array:
	var result: Array = []

	for card in cards:
		if (
			card != null
			and card.has_method(
				"duplicate_card"
			)
		):
			result.append(
				card.duplicate_card()
			)
		else:
			result.append(
				card
			)

	return result
