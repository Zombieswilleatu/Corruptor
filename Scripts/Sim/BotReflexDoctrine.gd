class_name BotReflexDoctrine
extends RefCounted


const GameSetupData = preload(
	"res://Scripts/Sim/GameSetup.gd"
)

const LordMathData = preload(
	"res://Scripts/Sim/LordMath.gd"
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


const ACTION_PASS: String = "Pass"
const ACTION_HUNT: String = "Hunt"
const ACTION_SIEGE: String = "Siege"
const ACTION_WARD: String = "Ward"

const ZONE_LORD: String = "Lord"
const ZONE_CASTLE: String = "Castle"

const SIGIL_FRESH: String = "fresh"
const SIGIL_FLIPPED: String = "flipped"

const OMEN_THRESHOLD: int = 3


const CASTLE_DEFENSES: Dictionary = {
	"Keep": 13,
	"Bastion": 11,
	"SummoningCircle": 9,
	"Stockpile": 8,
	"SiegeEngine": 7,
}


const SIEGE_TARGET_ORDER: Array[String] = [
	"SiegeEngine",
	"Stockpile",
	"SummoningCircle",
	"Bastion",
	"Keep",
]


static func build_decisions(
	game,
	rules: RuleConfig,
	random_source = null,
	policy = null
) -> Dictionary:
	assert(
		game != null,
		"Bot Reflex doctrine requires a GameState."
	)

	assert(
		rules != null,
		"Bot Reflex doctrine requires RuleConfig."
	)

	var winner_id: int = int(
		game.reflex_winner
	)

	var winner = game.get_player(
		winner_id
	)

	if winner == null:
		return {
			"winner_decision": {
				"pass": true,
			},
			"breach_decision": {},
		}

	var effective_policy = _policy_or_default(
		policy
	)

	var winner_decision: Dictionary = (
		decision_for_actor(
			game,
			winner_id,
			rules,
			random_source,
			effective_policy
		)
	)

	var breach_decision: Dictionary = {}

	if game.breach == "Odradek":
		var breach_owner_id: int = int(
			game.breach_owner
		)

		var breach_owner = game.get_player(
			breach_owner_id
		)

		if (
			breach_owner != null
			and breach_owner_id != winner_id
			and not breach_owner.hand.is_empty()
		):
			var guessed_action: String = (
				predict_reflex_action(
					game,
					winner_id,
					rules,
					random_source,
					effective_policy
				)
			)

			var stolen_action: Dictionary = (
				decision_for_actor(
					game,
					breach_owner_id,
					rules,
					random_source,
					effective_policy
				)
			)

			breach_decision = {
				"guess": guessed_action,
				"stolen_action": stolen_action,
			}

	return {
		"winner_decision": winner_decision,
		"breach_decision": breach_decision,
	}


static func decision_for_actor(
	game,
	actor_id: int,
	rules: RuleConfig,
	random_source = null,
	policy = null
) -> Dictionary:
	var candidates: Array = evaluate_candidates(
		game,
		actor_id,
		rules
	)

	var selection: Dictionary = (
		BotSelectorData.choose(
			candidates,
			random_source,
			_policy_or_default(
				policy
			)
		)
	)

	return _selection_payload(
		selection
	).duplicate(
		true
	)


static func evaluate_candidates(
	game,
	actor_id: int,
	rules: RuleConfig
) -> Array:
	var actor = game.get_player(
		actor_id
	)

	var opponent = game.get_opponent(
		actor_id
	)

	assert(
		actor != null,
		"Reflex evaluator actor does not exist."
	)

	assert(
		opponent != null,
		"Reflex evaluator opponent does not exist."
	)

	var candidates: Array = [
		{
			"id": "reflex_pass",
			"action": ACTION_PASS,
			"score": 0.0,
			"degraded_score": 0.5,
			"tie_rank": 0,
			"payload": {
				"pass": true,
			},
		},
	]

	if not actor.committed.is_empty():
		return candidates

	if (
		opponent.alive
		and actor.threat < rules.max_threat
	):
		var hunt_cards: Array = (
			_minimal_hunt_commit(
				game,
				actor,
				opponent,
				rules
			)
		)

		if not hunt_cards.is_empty():
			var hunt_score: float = 3.0

			if opponent.souls >= rules.win_souls - 2:
				hunt_score += 0.35

			if actor.lord == "Orias":
				hunt_score += 0.20

			candidates.append({
				"id": "reflex_hunt",
				"action": ACTION_HUNT,
				"score": hunt_score,
				"degraded_score": 1.0,
				"tie_rank": 1,
				"payload": {
					"action": ACTION_HUNT,
					"cards": _card_ids(
						hunt_cards
					),
					"consume_hunt": (
						_should_consume(
							game,
							actor,
							opponent,
							rules
						)
					),
				},
			})

	if not opponent.castles.is_empty():
		var target_castle: String = (
			_best_reflex_siege_target(
				game,
				actor,
				opponent,
				rules
			)
		)

		if not target_castle.is_empty():
			var siege_cards: Array = (
				_minimal_siege_commit(
					game,
					actor,
					opponent,
					target_castle,
					rules
				)
			)

			if not siege_cards.is_empty():
				var siege_score: float = 2.0

				if opponent.castles.size() <= 2:
					siege_score += 0.25

				if actor.lord in [
					"Deimos",
					"Kalligan",
					"Gremory",
				]:
					siege_score += 0.20

				candidates.append({
					"id": (
						"reflex_siege_%s"
						% target_castle
					),
					"action": ACTION_SIEGE,
					"score": siege_score,
					"degraded_score": 1.0,
					"tie_rank": 2,
					"payload": {
						"action": ACTION_SIEGE,
						"cards": _card_ids(
							siege_cards
						),
						"target_castle": target_castle,
						"consume_siege": (
							rules.consume_the_siege
							and _should_consume(
								game,
								actor,
								opponent,
								rules
							)
						),
						"use_inferno": true,
					},
				})

	if (
		actor.alive
		and actor.threat >= 2
		and String(
			actor.sigils.get(
				ZONE_LORD,
				""
			)
		).is_empty()
	):
		candidates.append({
			"id": "reflex_ward_lord",
			"action": ACTION_WARD,
			"score": (
				1.0
				+ float(
					actor.threat
				) * 0.15
			),
			"degraded_score": 1.3,
			"tie_rank": 4,
			"payload": {
				"action": ACTION_WARD,
				"ward_target": ZONE_LORD,
			},
		})

	if (
		not actor.castles.is_empty()
		and String(
			actor.sigils.get(
				ZONE_CASTLE,
				""
			)
		).is_empty()
		and (
			actor.souls >= rules.win_souls - 2
			or actor.tears >= 2
		)
	):
		candidates.append({
			"id": "reflex_ward_castle",
			"action": ACTION_WARD,
			"score": (
				0.9
				+ float(
					actor.souls
				) * 0.05
				+ float(
					actor.tears
				) * 0.10
			),
			"degraded_score": 1.4,
			"tie_rank": 3,
			"payload": {
				"action": ACTION_WARD,
				"ward_target": ZONE_CASTLE,
			},
		})

	return candidates


static func predict_reflex_action(
	game,
	winner_id: int,
	rules: RuleConfig,
	random_source = null,
	policy = null
) -> String:
	var candidates: Array = (
		evaluate_public_guess_candidates(
			game,
			winner_id,
			rules
		)
	)

	if candidates.is_empty():
		return ""

	var selection: Dictionary = (
		BotSelectorData.choose(
			candidates,
			random_source,
			_policy_or_default(
				policy
			)
		)
	)

	var payload: Dictionary = _selection_payload(
		selection
	)

	return String(
		payload.get(
			"guess",
			""
		)
	)


static func evaluate_public_guess_candidates(
	game,
	winner_id: int,
	rules: RuleConfig
) -> Array:
	var winner = game.get_player(
		winner_id
	)

	var target = game.get_opponent(
		winner_id
	)

	assert(
		winner != null,
		"Reflex prediction winner does not exist."
	)

	assert(
		target != null,
		"Reflex prediction target does not exist."
	)

	var raw_profile = BotDoctrineData.LORD_AI.get(
		String(
			winner.lord
		),
		BotDoctrineData.DEFAULT_PROFILE
	)

	var profile: Dictionary = (
		raw_profile
		if typeof(
			raw_profile
		) == TYPE_DICTIONARY
		else BotDoctrineData.DEFAULT_PROFILE
	)

	var aggression: float = float(
		profile.get(
			"aggro",
			1.0
		)
	)

	var control: float = float(
		profile.get(
			"control",
			1.0
		)
	)

	var preferred_action: String = String(
		profile.get(
			"prefer",
			""
		)
	)

	var candidates: Array = []

	if (
		target.alive
		and winner.threat < rules.max_threat
	):
		var hunt_score: float = (
			3.0 * aggression
			+ float(
				target.threat
			) * 0.10
		)

		if preferred_action == ACTION_HUNT:
			hunt_score += 0.25

		candidates.append({
			"id": "guess_hunt",
			"score": hunt_score,
			"degraded_score": 1.0,
			"tie_rank": 1,
			"payload": {
				"guess": ACTION_HUNT,
			},
		})

	if not target.castles.is_empty():
		var siege_score: float = (
			2.0 * aggression
			+ float(
				target.castles.size()
			) * 0.05
		)

		if preferred_action == ACTION_SIEGE:
			siege_score += 0.25

		candidates.append({
			"id": "guess_siege",
			"score": siege_score,
			"degraded_score": 1.0,
			"tie_rank": 2,
			"payload": {
				"guess": ACTION_SIEGE,
			},
		})

	var can_publicly_ward: bool = (
		(
			winner.alive
			and String(
				winner.sigils.get(
					ZONE_LORD,
					""
				)
			).is_empty()
		)
		or (
			not winner.castles.is_empty()
			and String(
				winner.sigils.get(
					ZONE_CASTLE,
					""
				)
			).is_empty()
		)
	)

	if can_publicly_ward:
		var ward_score: float = (
			1.0 * control
			+ float(
				winner.threat
			) * 0.10
		)

		if preferred_action == ACTION_WARD:
			ward_score += 0.25

		candidates.append({
			"id": "guess_ward",
			"score": ward_score,
			"degraded_score": 1.2,
			"tie_rank": 3,
			"payload": {
				"guess": ACTION_WARD,
			},
		})

	return candidates


static func _minimal_hunt_commit(
	game,
	actor,
	opponent,
	rules: RuleConfig
) -> Array:
	var ordered_hand: Array = _stable_sorted_cards(
		actor.hand,
		true
	)

	var selected_cards: Array = []

	var required_defense: int = (
		_lord_base_defense(
			opponent,
			rules
		)
		+ _effective_guard_total(
			actor,
			opponent.lord_guards
		)
		+ _sigil_value(
			game,
			opponent,
			String(
				opponent.sigils.get(
					ZONE_LORD,
					""
				)
			)
		)
	)

	for card in ordered_hand:
		selected_cards.append(
			card
		)

		if (
			_hunt_strength_after_recoil(
				game,
				actor,
				opponent,
				selected_cards,
				rules
			)
			> required_defense
		):
			return selected_cards

	return []


static func _minimal_siege_commit(
	game,
	actor,
	opponent,
	target_castle: String,
	rules: RuleConfig
) -> Array:
	var ordered_hand: Array = _stable_sorted_cards(
		actor.hand,
		true
	)

	var selected_cards: Array = []

	var required_defense: int = (
		_castle_defense(
			game,
			target_castle
		)
		+ _effective_guard_total(
			actor,
			opponent.castle_guards
		)
		+ _sigil_value(
			game,
			opponent,
			String(
				opponent.sigils.get(
					ZONE_CASTLE,
					""
				)
			)
		)
	)

	for card in ordered_hand:
		selected_cards.append(
			card
		)

		if (
			_siege_strength_after_recoil(
				actor,
				opponent,
				selected_cards,
				rules
			)
			> required_defense
		):
			return selected_cards

	return []


static func _hunt_strength_after_recoil(
	game,
	actor,
	opponent,
	selected_cards: Array,
	rules: RuleConfig
) -> int:
	var effective_cards: Array = (
		selected_cards.duplicate()
	)

	var clean_orias_hunt: bool = (
		actor.lord == "Orias"
		and String(
			game.get_meta(
				"orias_marked_lord",
				""
			)
		) == String(
			opponent.lord
		)
	)

	if (
		opponent.lord == "Odradek"
		and opponent.alive
		and not opponent.odradek_recoil_done
		and not clean_orias_hunt
	):
		_apply_recoil_to_cards(
			effective_cards,
			rules
		)

	var strength: int = _card_total(
		effective_cards
	)

	strength += _butcher_bonus(
		effective_cards
	)

	if (
		actor.lord == "Orias"
		and actor.alive
	):
		strength += 1

		if opponent.threat >= 2:
			strength += 1

	return strength


static func _siege_strength_after_recoil(
	actor,
	opponent,
	selected_cards: Array,
	rules: RuleConfig
) -> int:
	var effective_cards: Array = (
		selected_cards.duplicate()
	)

	if (
		opponent.lord == "Odradek"
		and opponent.alive
		and not opponent.odradek_recoil_done
		and not rules.recoil_hunts_only
	):
		_apply_recoil_to_cards(
			effective_cards,
			rules
		)

	var strength: int = _card_total(
		effective_cards
	)

	strength += _butcher_bonus(
		effective_cards
	)

	if (
		actor.lord == "Deimos"
		and actor.alive
		and (
			actor.castles.has(
				"SiegeEngine"
			)
			or rules.deimos_war_machine_free
		)
	):
		var lost_castles: int = (
			actor.ruined_castles.size()
		)

		if not rules.war_machine_ignores_profaned:
			lost_castles += (
				actor.profaned_castles.size()
			)

		strength += max(
			0,
			2 - lost_castles
		)

	if (
		actor.lord == "Kalligan"
		and actor.alive
	):
		strength += (
			2
			if not opponent.ruined_castles.is_empty()
			else 1
		)

	return strength


static func _apply_recoil_to_cards(
	cards: Array,
	rules: RuleConfig
) -> void:
	if cards.is_empty():
		return

	var victim = null

	if rules.recoil_lowest:
		victim = _lowest_card(
			cards
		)
	else:
		var ordered_cards: Array = (
			_stable_sorted_cards(
				cards,
				true
			)
		)

		victim = (
			ordered_cards[1]
			if ordered_cards.size() > 1
			else ordered_cards[0]
		)

	if victim != null:
		cards.erase(
			victim
		)


static func _best_reflex_siege_target(
	game,
	actor,
	opponent,
	rules: RuleConfig
) -> String:
	var selected_castle: String = ""
	var selected_required_strength: int = 1000000
	var selected_tie_rank: int = 1000000

	for castle_name: String in SIEGE_TARGET_ORDER:
		if not opponent.castles.has(
			castle_name
		):
			continue

		var required_strength: int = (
			_castle_defense(
				game,
				castle_name
			)
			+ _effective_guard_total(
				actor,
				opponent.castle_guards
			)
			+ _sigil_value(
				game,
				opponent,
				String(
					opponent.sigils.get(
						ZONE_CASTLE,
						""
					)
				)
			)
		)

		var tie_rank: int = (
			SIEGE_TARGET_ORDER.find(
				castle_name
			)
		)

		if (
			required_strength
			< selected_required_strength
			or (
				required_strength
				== selected_required_strength
				and tie_rank < selected_tie_rank
			)
		):
			selected_castle = castle_name
			selected_required_strength = (
				required_strength
			)
			selected_tie_rank = tie_rank

	return selected_castle


static func _effective_guard_total(
	attacker,
	guards: Array
) -> int:
	if guards.is_empty():
		return 0

	var total: int = _card_total(
		guards
	)

	var ignore_lowest: bool = (
		(
			attacker.lord == "Valak"
			and attacker.alive
			and guards.size() >= 2
		)
		or (
			attacker.lord == "Kanifous"
			and attacker.alive
			and attacker.kanifous_invoked_suit
			== "Butcher"
		)
	)

	if ignore_lowest:
		var lowest_guard = _lowest_card(
			guards
		)

		if lowest_guard != null:
			total -= int(
				lowest_guard.value
			)

	return total


static func _lord_base_defense(
	defender,
	rules: RuleConfig
) -> int:
	if not defender.alive:
		return 0

	if defender.lord == "Humbaba":
		return LordMathData.lord_base_def(
			"Humbaba",
			defender.castles,
			int(
				defender.threat
			),
			rules
		)

	var defense: int = 0

	if defender.lord == "Kroni":
		if defender.kroni_hunger >= 3:
			defense = (
				7
				if rules.kroni_def_soft
				else 8
			)
		elif defender.kroni_hunger >= 1:
			defense = (
				5
				if rules.kroni_def_soft
				else 6
			)
		else:
			defense = 4
	else:
		var lord_data: Dictionary = (
			GameSetupData.LORD_CONTENT.get(
				String(
					defender.lord
				),
				{}
			)
		)

		defense = int(
			lord_data.get(
				"base_defense",
				0
			)
		)

	if defender.threat >= 4:
		defense -= 3
	elif defender.threat >= 3:
		defense -= 2
	elif defender.threat >= 2:
		defense -= 1

	if defender.castles.has(
		"Bastion"
	):
		defense += 2

	return max(
		0,
		defense
	)


static func _castle_defense(
	game,
	castle_name: String
) -> int:
	var defense: int = int(
		CASTLE_DEFENSES.get(
			castle_name,
			0
		)
	)

	if game.breach == "Deimos":
		defense = max(
			0,
			defense - 1
		)

	if game.breach == "Humbaba":
		defense = max(
			1,
			defense - 1
		)

	return defense


static func _sigil_value(
	game,
	player,
	sigil_state: String
) -> int:
	if not sigil_state in [
		SIGIL_FRESH,
		SIGIL_FLIPPED,
	]:
		return 0

	var value: int = (
		2
		if sigil_state == SIGIL_FRESH
		else 1
	)

	if player.castles.has(
		"Keep"
	):
		value += 1

	if (
		game.calculate_veil_total()
		>= OMEN_THRESHOLD
		and player.tears < OMEN_THRESHOLD
	):
		value = max(
			0,
			value - 1
		)

	return value


static func _should_consume(
	game,
	actor,
	opponent,
	rules: RuleConfig
) -> bool:
	var total_after: int = (
		game.calculate_veil_total() + 1
	)

	var personal_after: int = (
		actor.tears + 1
	)

	return (
		total_after >= rules.dominion_track
		and personal_after > opponent.tears
		and personal_after
		>= _dominion_requirement(
			game,
			rules
		)
	)


static func _dominion_requirement(
	game,
	rules: RuleConfig
) -> int:
	var players: Array = []

	for player in game.players:
		players.append({
			"lord": String(
				player.lord
			),
			"alive": bool(
				player.alive
			),
		})

	return LordMathData.dominion_requirement(
		players,
		rules
	)


static func _butcher_bonus(
	cards: Array
) -> int:
	var butcher_count: int = 0

	for card in cards:
		if String(
			card.suit
		) == "Butcher":
			butcher_count += 1

	return (
		1
		if butcher_count >= 2
		else 0
	)


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


static func _lowest_card(
	cards: Array
):
	if cards.is_empty():
		return null

	var selected_card = cards[0]

	for index: int in range(
		1,
		cards.size()
	):
		var candidate = cards[index]

		if int(
			candidate.value
		) < int(
			selected_card.value
		):
			selected_card = candidate

	return selected_card


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


static func _policy_or_default(
	policy
):
	if policy == null:
		return BotPolicyData.competitive()

	return policy
