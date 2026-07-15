class_name BotDoctrine
extends RefCounted


const GameSetupData = preload(
	"res://Scripts/Sim/GameSetup.gd"
)

const LordMathData = preload(
	"res://Scripts/Sim/LordMath.gd"
)

const BotPolicyData = preload(
	"res://Scripts/Sim/BotPolicy.gd"
)

const BotSelectorData = preload(
	"res://Scripts/Sim/BotSelector.gd"
)


const ACTION_HUNT: String = "Hunt"
const ACTION_SIEGE: String = "Siege"
const ACTION_WARD: String = "Ward"
const ACTION_PROFANE: String = "Profane"

const TARGET_LORD: String = "Lord"
const TARGET_CASTLE: String = "Castle"

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


const DEFAULT_PROFILE: Dictionary = {
	"aggro": 1.0,
	"control": 1.0,
	"risk": 1.0,
	"prefer": "",
}


const LORD_AI: Dictionary = {
	"Orias": {
		"aggro": 1.30,
		"control": 0.65,
		"risk": 1.20,
		"prefer": ACTION_HUNT,
	},
	"Deimos": {
		"aggro": 1.15,
		"control": 0.85,
		"risk": 1.00,
		"prefer": ACTION_SIEGE,
	},
	"Valak": {
		"aggro": 1.15,
		"control": 0.85,
		"risk": 0.85,
		"prefer": ACTION_HUNT,
	},
	"Kroni": {
		"aggro": 0.95,
		"control": 1.00,
		"risk": 0.75,
		"prefer": ACTION_HUNT,
	},
	"Kalligan": {
		"aggro": 0.95,
		"control": 1.25,
		"risk": 0.95,
		"prefer": ACTION_SIEGE,
	},
	"Gremory": {
		"aggro": 1.20,
		"control": 0.85,
		"risk": 1.05,
		"prefer": ACTION_SIEGE,
	},
	"Odradek": {
		"aggro": 0.75,
		"control": 1.25,
		"risk": 0.65,
		"prefer": ACTION_WARD,
	},
	"Kanifous": {
		"aggro": 1.00,
		"control": 1.10,
		"risk": 1.25,
		"prefer": ACTION_WARD,
	},
	"Humbaba": {
		"aggro": 0.65,
		"control": 1.35,
		"risk": 0.60,
		"prefer": ACTION_WARD,
	},
}


const DEFAULT_CASTLE_PRIORITY: Array[String] = [
	"Keep",
	"Bastion",
	"SummoningCircle",
	"Stockpile",
	"SiegeEngine",
]


const SIEGE_TARGET_ORDER: Array[String] = [
	"Stockpile",
	"SummoningCircle",
	"SiegeEngine",
	"Bastion",
	"Keep",
]


const CASTLE_PRIORITIES: Dictionary = {
	"Orias": [
		"SiegeEngine",
		"Bastion",
		"Stockpile",
		"SummoningCircle",
		"Keep",
	],
	"Deimos": [
		"SiegeEngine",
		"Bastion",
		"Stockpile",
		"Keep",
		"SummoningCircle",
	],
	"Valak": [
		"SiegeEngine",
		"Keep",
		"Bastion",
		"Stockpile",
		"SummoningCircle",
	],
	"Kroni": [
		"Keep",
		"Bastion",
		"Stockpile",
		"SummoningCircle",
		"SiegeEngine",
	],
	"Kalligan": [
		"SiegeEngine",
		"Stockpile",
		"SummoningCircle",
		"Bastion",
		"Keep",
	],
	"Gremory": [
		"SiegeEngine",
		"Stockpile",
		"SummoningCircle",
		"Bastion",
		"Keep",
	],
	"Odradek": [
		"Keep",
		"Bastion",
		"SummoningCircle",
		"Stockpile",
		"SiegeEngine",
	],
	"Kanifous": [
		"Keep",
		"Bastion",
		"SummoningCircle",
		"Stockpile",
		"SiegeEngine",
	],
	"Humbaba": [
		"Keep",
		"Bastion",
		"Stockpile",
		"SummoningCircle",
		"SiegeEngine",
	],
}


static func plan(
	game,
	player_id: int,
	rules: RuleConfig
) -> String:
	assert(
		game != null,
		"Bot plan detection requires a GameState."
	)

	assert(
		rules != null,
		"Bot plan detection requires RuleConfig."
	)

	var player = game.get_player(
		player_id
	)

	var opponent = game.get_opponent(
		player_id
	)

	assert(
		player != null,
		"Bot plan player does not exist."
	)

	assert(
		opponent != null,
		"Bot plan opponent does not exist."
	)

	var opponent_ritual_gap: int = (
		rules.win_souls
		- int(
			opponent.souls
		)
	)

	var veil_total: int = int(
		game.calculate_veil_total()
	)

	if (
		opponent.alive
		and opponent_ritual_gap <= 1
	):
		return "deny_ritual"

	if (
		veil_total >= rules.dominion_track - 1
		and opponent.tears > player.tears
	):
		return "deny_dominion"

	if player.souls > opponent.souls:
		return "protect_souls"

	if player.souls < opponent.souls:
		return "pressure_souls"

	if (
		player.lord == "Kroni"
		and player.kroni_hunger >= 3
		and player.tears >= 1
	):
		return "race_dominion"

	if (
		player.lord == "Kroni"
		and opponent.lord == "Humbaba"
		and player.tears >= 1
	):
		return "race_dominion"

	if (
		rules.ai_dominion_drive
		and player.tears >= 1
		and veil_total >= 5
		and player.tears >= opponent.tears
	):
		return "race_dominion"

	if (
		player.lord == "Odradek"
		and player.alive
		and player.tears >= 1
	):
		return "race_dominion"

	if (
		player.tears >= 2
		and player.tears > opponent.tears
	):
		return "race_dominion"

	return "neutral"


static func pick_siege_target(
	game,
	attacker_id: int,
	defender_id: int
) -> String:
	assert(
		game != null,
		"Bot Siege targeting requires a GameState."
	)

	var attacker = game.get_player(
		attacker_id
	)

	var defender = game.get_player(
		defender_id
	)

	assert(
		attacker != null,
		"Bot Siege attacker does not exist."
	)

	assert(
		defender != null,
		"Bot Siege defender does not exist."
	)

	if defender.castles.is_empty():
		return ""

	if (
		defender.lord == "Deimos"
		and defender.alive
		and defender.castles.has(
			"SiegeEngine"
		)
	):
		return "SiegeEngine"

	for castle_name: String in SIEGE_TARGET_ORDER:
		if defender.castles.has(
			castle_name
		):
			return castle_name

	return String(
		defender.castles[0]
	)


static func evaluate_market_candidates(
	game,
	player_id: int
) -> Array:
	var player = game.get_player(
		player_id
	)

	assert(
		player != null,
		"Market evaluator player does not exist."
	)

	var candidates: Array = [
		{
			"id": "pass",
			"score": 0.0,
			"tie_rank": 0,
			"payload": {
				"pass": true,
			},
		},
	]

	if (
		game.market.is_empty()
		or player.hand.is_empty()
	):
		return candidates

	var best_market = _highest_card(
		game.market
	)

	var worst_hand = _lowest_card(
		player.hand
	)

	if (
		best_market == null
		or worst_hand == null
	):
		return candidates

	var improvement: int = (
		int(
			best_market.value
		)
		- int(
			worst_hand.value
		)
	)

	if improvement <= 0:
		return candidates

	candidates.append({
		"id": "swap",
		"score": float(
			improvement
		),
		"tie_rank": 1,
		"payload": {
			"take": _card_id(
				best_market
			),
			"give": _card_id(
				worst_hand
			),
		},
	})

	return candidates


static func market_choices(
	game,
	_random_source = null
) -> Dictionary:
	assert(
		game != null,
		"Bot Market doctrine requires a GameState."
	)

	assert(
		game.first_player >= 0
		and game.first_player < game.players.size(),
		"Bot Market doctrine requires a valid first player."
	)

	var shadow = game.duplicate_state()
	var decisions: Dictionary = {}
	var consistent_policy = BotPolicyData.golden_core()

	for offset: int in range(
		shadow.players.size()
	):
		var player_id: int = (
			shadow.first_player + offset
		) % shadow.players.size()

		var candidates: Array = (
			evaluate_market_candidates(
				shadow,
				player_id
			)
		)

		var selection: Dictionary = (
			BotSelectorData.choose(
				candidates,
				null,
				consistent_policy
			)
		)

		var payload: Dictionary = selection.get(
			"payload",
			{
				"pass": true,
			}
		)

		decisions[player_id] = payload.duplicate(
			true
		)

		if bool(
			payload.get(
				"pass",
				false
			)
		):
			continue

		var player = shadow.get_player(
			player_id
		)

		var take_card = _find_card(
			shadow.market,
			String(
				payload.get(
					"take",
					""
				)
			)
		)

		var give_card = _find_card(
			player.hand,
			String(
				payload.get(
					"give",
					""
				)
			)
		)

		assert(
			take_card != null,
			"Shadow Market card disappeared."
		)

		assert(
			give_card != null,
			"Shadow hand card disappeared."
		)

		shadow.market.erase(
			take_card
		)

		player.hand.erase(
			give_card
		)

		player.hand.append(
			take_card
		)

		shadow.market.append(
			give_card
		)

	return decisions


static func evaluate_bid_candidates(
	game,
	player_id: int,
	rules: RuleConfig
) -> Array:
	var player = game.get_player(
		player_id
	)

	assert(
		player != null,
		"Reflex Bid evaluator player does not exist."
	)

	if player.hand.is_empty():
		return [
			{
				"id": "bid_0",
				"score": 0.0,
				"degraded_score": 0.0,
				"tie_rank": 0,
				"payload": {
					"pass": true,
				},
			},
		]

	var profile: Dictionary = _profile_for(
		String(
			player.lord
		)
	)

	var current_plan: String = plan(
		game,
		player_id,
		rules
	)

	var desired_count: int = 1

	if current_plan in [
		"deny_ritual",
		"deny_dominion",
	]:
		desired_count = 2

	if float(
		profile.get(
			"control",
			1.0
		)
	) >= 1.25:
		desired_count = max(
			desired_count,
			2
		)

	if (
		player.alive
		and player.souls >= rules.win_souls - 1
	):
		desired_count = max(
			desired_count,
			2
		)

	var ordered_hand: Array = _stable_sorted_cards(
		player.hand,
		false
	)

	var maximum_count: int = min(
		3,
		ordered_hand.size()
	)

	var candidates: Array = []

	for bid_count: int in range(
		maximum_count + 1
	):
		var bid_cards: Array = []

		for index: int in range(
			bid_count
		):
			bid_cards.append(
				ordered_hand[index]
			)

		var bid_total: int = _card_total(
			bid_cards
		)

		var score: float = (
			-float(
				abs(
					bid_count - desired_count
				)
			) * 2.0
			- float(
				bid_total
			) * 0.05
		)

		if (
			bid_count == 0
			and desired_count > 0
		):
			score -= 0.75

		var degraded_score: float = (
			-float(
				abs(
					bid_count - 1
				)
			) * 1.5
			- float(
				bid_total
			) * 0.05
		)

		var payload: Dictionary = {}

		if bid_count == 0:
			payload = {
				"pass": true,
			}
		else:
			payload = {
				"bid": _card_ids(
					bid_cards
				),
			}

		candidates.append({
			"id": "bid_%d" % bid_count,
			"score": score,
			"degraded_score": degraded_score,
			"tie_rank": -bid_count,
			"payload": payload,
		})

	return candidates


static func bid_choices(
	game,
	random_source,
	rules: RuleConfig,
	policy = null
) -> Dictionary:
	assert(
		game != null,
		"Bot Reflex Bid doctrine requires a GameState."
	)

	assert(
		rules != null,
		"Bot Reflex Bid doctrine requires RuleConfig."
	)

	var effective_policy = _policy_or_default(
		policy
	)

	var decisions: Dictionary = {}

	for player in game.players:
		var player_id: int = int(
			player.pid
		)

		var candidates: Array = (
			evaluate_bid_candidates(
				game,
				player_id,
				rules
			)
		)

		var selection: Dictionary = (
			BotSelectorData.choose(
				candidates,
				random_source,
				effective_policy
			)
		)

		var payload: Dictionary = selection.get(
			"payload",
			{
				"pass": true,
			}
		)

		decisions[player_id] = payload.duplicate(
			true
		)

	return decisions


static func evaluate_action_candidates(
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
		"Commitment evaluator player does not exist."
	)

	assert(
		opponent != null,
		"Commitment evaluator opponent does not exist."
	)

	if not player.alive:
		return [
			{
				"id": ACTION_WARD,
				"action": ACTION_WARD,
				"score": 0.0,
				"degraded_score": 0.0,
				"tie_rank": 3,
				"chip_siege": false,
			},
		]

	var profile: Dictionary = _profile_for(
		String(
			player.lord
		)
	)

	var current_plan: String = plan(
		game,
		player_id,
		rules
	)

	var hunt_score: float = (
		_score_hunt(
			game,
			player,
			opponent,
			current_plan,
			rules
		)
		* float(
			profile.get(
				"aggro",
				1.0
			)
		)
	)

	var siege_score: float = (
		_score_siege(
			player,
			opponent,
			current_plan
		)
		* float(
			profile.get(
				"aggro",
				1.0
			)
		)
	)

	var ward_score: float = (
		_score_ward(
			player,
			current_plan
		)
		* float(
			profile.get(
				"control",
				1.0
			)
		)
	)

	var caution: float = max(
		0.0,
		1.0 - float(
			profile.get(
				"risk",
				1.0
			)
		)
	)

	hunt_score -= (
		player.threat
		* caution
		* 0.9
	)

	siege_score -= (
		player.threat
		* caution
		* 0.5
	)

	var preferred_action: String = String(
		profile.get(
			"prefer",
			""
		)
	)

	if preferred_action == ACTION_HUNT:
		hunt_score += 0.25

	if preferred_action == ACTION_SIEGE:
		siege_score += 0.25

	if preferred_action == ACTION_WARD:
		ward_score += 0.25

	var profane_score: float = -5.0

	if player.castles.size() >= 3:
		var soul_deficit: int = (
			opponent.souls
			- player.souls
		)

		var tear_lead: int = (
			player.tears
			- opponent.tears
		)

		profane_score = 0.0

		if soul_deficit >= 2:
			profane_score += 1.6

		if (
			player.tears >= 2
			and tear_lead >= 1
		):
			profane_score += 1.8

		if current_plan == "race_dominion":
			profane_score += 1.2

		if current_plan == "deny_dominion":
			profane_score -= 1.0

		if current_plan == "deny_ritual":
			profane_score -= 2.0

		if player.lord == "Humbaba":
			profane_score -= 2.5

		if rules.ai_dominion_drive:
			profane_score += 0.9

			if player.castles.size() >= 4:
				profane_score += 0.5

			if (
				opponent.alive
				and opponent.lord == "Odradek"
			):
				profane_score += 0.8

	var chip_siege: bool = false

	if (
		opponent.alive
		and not opponent.castles.is_empty()
		and not opponent.castle_guards.is_empty()
	):
		if (
			opponent.lord == "Odradek"
			and rules.reconfig_strict
			and player.lord == "Humbaba"
		):
			chip_siege = true

			var sigils_standing: bool = (
				player.sigils.values().has(
					SIGIL_FRESH
				)
				or player.sigils.values().has(
					SIGIL_FLIPPED
				)
			)

			if (
				sigils_standing
				and opponent.tears + 1
				>= _dominion_requirement(
					game,
					rules
				) - 1
			):
				siege_score += 4.0
			elif sigils_standing:
				siege_score += 2.2
			else:
				siege_score -= 0.5

		if (
			player.lord == "Kroni"
			and opponent.lord == "Humbaba"
		):
			siege_score += 1.2
			chip_siege = true

	var candidates: Array = []

	if opponent.alive:
		candidates.append({
			"id": ACTION_HUNT,
			"action": ACTION_HUNT,
			"score": hunt_score,
			"degraded_score": _degraded_hunt_score(
				player,
				opponent
			),
			"tie_rank": 0,
			"chip_siege": false,
		})

	if not opponent.castles.is_empty():
		candidates.append({
			"id": ACTION_SIEGE,
			"action": ACTION_SIEGE,
			"score": siege_score,
			"degraded_score": _degraded_siege_score(
				opponent
			),
			"tie_rank": 2,
			"chip_siege": chip_siege,
		})

	candidates.append({
		"id": ACTION_WARD,
		"action": ACTION_WARD,
		"score": ward_score,
		"degraded_score": _degraded_ward_score(
			player
		),
		"tie_rank": 3,
		"chip_siege": false,
	})

	if player.castles.size() >= 3:
		candidates.append({
			"id": ACTION_PROFANE,
			"action": ACTION_PROFANE,
			"score": profane_score,
			"degraded_score": 0.4,
			"tie_rank": 1,
			"chip_siege": false,
		})

	return candidates


static func commitment_choices(
	game,
	random_source,
	rules: RuleConfig,
	policy = null
) -> Dictionary:
	assert(
		game != null,
		"Bot Commitment doctrine requires a GameState."
	)

	assert(
		rules != null,
		"Bot Commitment doctrine requires RuleConfig."
	)

	var effective_policy = _policy_or_default(
		policy
	)

	var decisions: Dictionary = {}

	for player in game.players:
		var player_id: int = int(
			player.pid
		)

		var candidates: Array = (
			evaluate_action_candidates(
				game,
				player_id,
				rules
			)
		)

		var selection: Dictionary = (
			BotSelectorData.choose(
				candidates,
				random_source,
				effective_policy
			)
		)

		var selected_candidate: Dictionary = (
			selection.get(
				"candidate",
				{}
			)
		)

		decisions[player_id] = (
			_commitment_decision_from_candidate(
				game,
				player_id,
				selected_candidate,
				rules
			)
		)

	return decisions


static func _commitment_decision_from_candidate(
	game,
	player_id: int,
	candidate: Dictionary,
	rules: RuleConfig
) -> Dictionary:
	var player = game.get_player(
		player_id
	)

	var opponent = game.get_opponent(
		player_id
	)

	assert(
		player != null,
		"Selected Commitment player does not exist."
	)

	assert(
		opponent != null,
		"Selected Commitment opponent does not exist."
	)

	var action_name: String = String(
		candidate.get(
			"action",
			ACTION_WARD
		)
	)

	var current_plan: String = plan(
		game,
		player_id,
		rules
	)

	if not player.alive:
		action_name = ACTION_WARD

	if action_name == ACTION_HUNT:
		return {
			"action": ACTION_HUNT,
			"target_pid": int(
				opponent.pid
			),
			"cards": _card_ids(
				_commit_for_attack(
					game,
					player,
					opponent,
					TARGET_LORD,
					current_plan,
					false,
					rules
				)
			),
		}

	if action_name == ACTION_SIEGE:
		var chip_siege: bool = bool(
			candidate.get(
				"chip_siege",
				false
			)
		)

		return {
			"action": ACTION_SIEGE,
			"target_pid": int(
				opponent.pid
			),
			"target_castle": pick_siege_target(
				game,
				player_id,
				int(
					opponent.pid
				)
			),
			"cards": _card_ids(
				_commit_for_attack(
					game,
					player,
					opponent,
					TARGET_CASTLE,
					current_plan,
					chip_siege,
					rules
				)
			),
		}

	if action_name == ACTION_PROFANE:
		return {
			"action": ACTION_PROFANE,
			"target_pid": player_id,
			"target_castle": _profane_target(
				player
			),
			"cards": [],
		}

	var ward_target: String = ""

	if not player.alive:
		ward_target = TARGET_CASTLE
	elif (
		current_plan == "deny_ritual"
		and player.prev_ward_target != TARGET_LORD
	):
		ward_target = TARGET_LORD
	else:
		var wants_lord: bool = (
			player.souls >= 2
			or player.threat >= 2
		)

		ward_target = (
			TARGET_LORD
			if wants_lord
			else TARGET_CASTLE
		)

		if ward_target == player.prev_ward_target:
			ward_target = (
				TARGET_CASTLE
				if ward_target == TARGET_LORD
				else TARGET_LORD
			)

	return {
		"action": ACTION_WARD,
		"target_pid": player_id,
		"target_type": ward_target,
		"cards": _card_ids(
			_commit_for_ward(
				player
			)
		),
	}


static func _score_hunt(
	game,
	player,
	opponent,
	current_plan: String,
	rules: RuleConfig
) -> float:
	if not opponent.alive:
		return -5.0

	var score: float = 1.8

	score += opponent.threat * 0.55
	score -= player.threat * 0.20

	if player.threat >= 3:
		score -= 2.5
	elif player.threat == 2:
		score -= 0.9

	if (
		opponent.lord == "Orias"
		and opponent.alive
		and player.threat >= 1
	):
		score -= 1.5

	if current_plan == "deny_ritual":
		score += 2.8

	if current_plan == "protect_souls":
		score -= 0.6

	if current_plan == "pressure_souls":
		score += 0.8

	if player.lord == "Orias":
		score += 1.1

		if (
			opponent.alive
			and opponent.threat >= 2
		):
			score += 0.5

	if player.lord == "Gremory":
		score += 0.4

	if (
		player.lord == "Valak"
		and player.souls < 2
	):
		score += 0.7

	if player.lord == "Kroni":
		score += min(
			1.2,
			player.kroni_hunger * 0.4
		)

	if opponent.lord == "Odradek":
		var harsh_recoil: bool = not (
			rules.recoil_hunts_only
			and rules.recoil_lowest
		)

		if harsh_recoil:
			score -= 0.9
		else:
			score -= 0.3

		if (
			rules.ai_dominion_drive
			and harsh_recoil
		):
			score -= 0.9

	var marked_lord: String = String(
		game.get_meta(
			"orias_marked_lord",
			""
		)
	)

	if (
		player.lord == "Orias"
		and marked_lord == opponent.lord
	):
		score += 0.5

	if player.lord == "Odradek":
		score -= 0.1

	return score


static func _score_siege(
	player,
	opponent,
	current_plan: String
) -> float:
	if opponent.castles.is_empty():
		return -5.0

	var score: float = 1.0

	score += opponent.castles.size() * 0.25

	if current_plan == "deny_dominion":
		score += 3.0

	if current_plan == "race_dominion":
		score += 1.2

	if (
		opponent.lord == "Orias"
		and opponent.alive
		and player.threat >= 1
	):
		score += 1.2

	if player.threat >= 2:
		score += 0.5

	if player.threat >= 3:
		score += 0.6

	if player.lord == "Deimos":
		score += 1.0

	if player.lord == "Kalligan":
		score += 0.8

	if player.lord == "Gremory":
		score += 0.7

	if (
		player.lord == "Kalligan"
		and player.alive
		and not opponent.ruined_castles.is_empty()
	):
		score += 0.5

	if player.tears > opponent.tears:
		score += 0.3

	return score


static func _score_ward(
	player,
	current_plan: String
) -> float:
	var score: float = 0.6

	score += player.souls * 0.55
	score += player.castles.size() * 0.30
	score += player.threat * 0.35

	if player.threat >= 2:
		score += 0.6

	if player.threat >= 3:
		score += 0.8

	if current_plan == "protect_souls":
		score += 1.0

	if current_plan == "deny_ritual":
		score += 0.7

	if current_plan in [
		"deny_dominion",
		"race_dominion",
	]:
		score += 0.4

	if player.lord == "Kroni":
		score += 0.5

	if player.lord == "Odradek":
		score += 0.8

	return score


static func _degraded_hunt_score(
	player,
	opponent
) -> float:
	if not opponent.alive:
		return -5.0

	return (
		1.3
		+ opponent.threat * 0.25
		- player.threat * 0.25
	)


static func _degraded_siege_score(
	opponent
) -> float:
	if opponent.castles.is_empty():
		return -5.0

	return (
		1.0
		+ opponent.castles.size() * 0.15
	)


static func _degraded_ward_score(
	player
) -> float:
	return (
		0.8
		+ player.souls * 0.25
		+ player.threat * 0.20
	)


static func _commit_for_attack(
	game,
	player,
	opponent,
	target_type: String,
	current_plan: String,
	chip: bool,
	rules: RuleConfig
) -> Array:
	if chip:
		var chip_guards: Array = (
			opponent.castle_guards
			if target_type == TARGET_CASTLE
			else opponent.lord_guards
		)

		if not chip_guards.is_empty():
			var highest_guard = _highest_card(
				chip_guards
			)

			var needed_strength: int = int(
				highest_guard.value
			)

			var picked_cards: Array = []
			var picked_total: int = 0

			for card in _stable_sorted_cards(
				player.hand,
				false
			):
				if picked_total > needed_strength:
					break

				picked_cards.append(
					card
				)

				picked_total += int(
					card.value
				)

			if picked_total > needed_strength:
				return picked_cards

	var estimated_defense: int = 0

	if target_type == TARGET_LORD:
		estimated_defense = _lord_base_defense(
			opponent,
			rules
		)

		estimated_defense += _card_total(
			opponent.lord_guards
		)

		estimated_defense += max(
			2,
			_sigil_value(
				game,
				opponent,
				String(
					opponent.sigils.get(
						TARGET_LORD,
						""
					)
				)
			)
		)
	else:
		var target_castle: String = pick_siege_target(
			game,
			int(
				player.pid
			),
			int(
				opponent.pid
			)
		)

		estimated_defense = _castle_defense(
			game,
			target_castle
		)

		if not player.castles.has(
			"SiegeEngine"
		):
			estimated_defense += _card_total(
				opponent.castle_guards
			)

		estimated_defense += max(
			1,
			_sigil_value(
				game,
				opponent,
				String(
					opponent.sigils.get(
						TARGET_CASTLE,
						""
					)
				)
			)
		)

	var padding: int = 1

	if current_plan in [
		"deny_ritual",
		"deny_dominion",
	]:
		padding = 2
	elif current_plan == "protect_souls":
		padding = 0

	var target_strength: int = (
		estimated_defense
		+ padding
	)

	var butchers: Array = []
	var other_cards: Array = []

	for card in player.hand:
		if String(
			card.suit
		) == "Butcher":
			butchers.append(
				card
			)
		else:
			other_cards.append(
				card
			)

	butchers = _stable_sorted_cards(
		butchers,
		true
	)

	other_cards = _stable_sorted_cards(
		other_cards,
		true
	)

	var committed: Array = []
	var committed_total: int = 0

	var wants_bonus: bool = (
		player.lord in [
			"Deimos",
			"Orias",
			"Gremory",
		]
		or current_plan.begins_with(
			"deny"
		)
	)

	if wants_bonus:
		for index: int in range(
			min(
				2,
				butchers.size()
			)
		):
			var butcher = butchers[
				index
			]

			committed.append(
				butcher
			)

			committed_total += int(
				butcher.value
			)

		if butchers.size() > 2:
			butchers = butchers.slice(
				2
			)
		else:
			butchers = []

	var remaining_candidates: Array = []

	remaining_candidates.append_array(
		butchers
	)

	remaining_candidates.append_array(
		other_cards
	)

	for card in remaining_candidates:
		if committed_total >= target_strength:
			break

		committed.append(
			card
		)

		committed_total += int(
			card.value
		)

	var trim_allowance: int = (
		3
		if current_plan.begins_with(
			"deny"
		)
		else 2
	)

	while (
		committed.size() > 1
		and committed_total
		- int(
			committed[
				committed.size() - 1
			].value
		)
		> target_strength
		+ trim_allowance
	):
		var removed_card = committed.pop_back()

		committed_total -= int(
			removed_card.value
		)

	var marked_lord: String = String(
		game.get_meta(
			"orias_marked_lord",
			""
		)
	)

	var recoil_applies: bool = (
		opponent.lord == "Odradek"
		and opponent.alive
		and not (
			player.lord == "Orias"
			and marked_lord == opponent.lord
		)
		and (
			target_type == TARGET_LORD
			or not rules.recoil_hunts_only
		)
	)

	if (
		recoil_applies
		and not committed.is_empty()
	):
		var remaining_hand: Array = (
			player.hand.duplicate()
		)

		for card in committed:
			remaining_hand.erase(
				card
			)

		remaining_hand = _stable_sorted_cards(
			remaining_hand,
			true
		)

		for card in remaining_hand:
			if _effective_recoil_total(
				committed,
				rules
			) >= target_strength:
				break

			committed.append(
				card
			)

	return committed


static func _commit_for_ward(
	player
) -> Array:
	var penitents: Array = []

	for card in player.hand:
		if String(
			card.suit
		) == "Penitent":
			penitents.append(
				card
			)

	penitents = _stable_sorted_cards(
		penitents,
		true
	)

	var committed: Array = []

	for index: int in range(
		min(
			2,
			penitents.size()
		)
	):
		committed.append(
			penitents[index]
		)

	return committed


static func _effective_recoil_total(
	cards: Array,
	rules: RuleConfig
) -> int:
	if cards.size() <= 1:
		return 0

	var values: Array[int] = []

	for card in cards:
		values.append(
			int(
				card.value
			)
		)

	values.sort()
	values.reverse()

	var loss: int = 0

	if rules.recoil_lowest:
		loss = values[
			values.size() - 1
		]
	else:
		loss = values[1]

	var total: int = 0

	for value: int in values:
		total += value

	return total - loss


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


static func _profane_target(
	player
) -> String:
	var raw_priority = CASTLE_PRIORITIES.get(
		String(
			player.lord
		),
		DEFAULT_CASTLE_PRIORITY
	)

	var priority: Array = raw_priority

	for index: int in range(
		priority.size() - 1,
		-1,
		-1
	):
		var castle_name: String = String(
			priority[index]
		)

		if player.castles.has(
			castle_name
		):
			return castle_name

	if player.castles.is_empty():
		return ""

	return String(
		player.castles[0]
	)


static func _profile_for(
	lord_name: String
) -> Dictionary:
	var raw_profile = LORD_AI.get(
		lord_name,
		DEFAULT_PROFILE
	)

	if typeof(
		raw_profile
	) != TYPE_DICTIONARY:
		return DEFAULT_PROFILE

	return raw_profile


static func _policy_or_default(
	policy
):
	if policy == null:
		return BotPolicyData.competitive()

	return policy


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


static func _highest_card(
	cards: Array
):
	if cards.is_empty():
		return null

	var selected = cards[0]

	for index: int in range(
		1,
		cards.size()
	):
		var candidate = cards[index]

		if int(
			candidate.value
		) > int(
			selected.value
		):
			selected = candidate

	return selected


static func _lowest_card(
	cards: Array
):
	if cards.is_empty():
		return null

	var selected = cards[0]

	for index: int in range(
		1,
		cards.size()
	):
		var candidate = cards[index]

		if int(
			candidate.value
		) < int(
			selected.value
		):
			selected = candidate

	return selected


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
