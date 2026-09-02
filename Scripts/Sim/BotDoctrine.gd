class_name BotDoctrine
extends RefCounted


const OdradekInterlockEngineData = preload(
	"res://Scripts/Sim/OdradekInterlockEngine.gd"
)


const GameSetupData = preload(
	"res://Scripts/Sim/GameSetup.gd"
)

const CastleIntegrityRulesData = preload(
	"res://Scripts/Sim/CastleIntegrityRules.gd"
)

const ActionForecastData = preload(
	"res://Scripts/Sim/ActionForecast.gd"
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
	defender_id: int,
	rules: RuleConfig = null
) -> String:
	assert(game != null, "Bot Siege targeting requires a GameState.")
	var defender = game.get_player(defender_id)
	assert(defender != null, "Bot Siege defender does not exist.")

	if defender.castles.is_empty():
		return ""

	if rules != null:
		var actual_opponent = game.get_opponent(attacker_id)
		if actual_opponent != null and int(actual_opponent.pid) == defender_id:
			# BOT_SIEGE_TARGET_FORECAST_ONLY_V1
			# Target selection consumes only forecast["siege_targets"].
			# forecast_all() also computed a Hunt report that cannot affect which
			# Castle wins this comparison. Build the same Siege reports only.
			var siege_targets: Dictionary = {}
			for castle_value in defender.castles:
				var castle_name: String = String(castle_value)
				if not CastleIntegrityRulesData.standing(
					defender,
					castle_name
				):
					continue
				siege_targets[castle_name] = ActionForecastData.forecast_siege(
					game,
					rules,
					attacker_id,
					castle_name,
					true
				)

			var forecast: Dictionary = {
				"model_version": ActionForecastData.MODEL_VERSION,
				"siege_targets": siege_targets,
			}
			var choice: Dictionary = _best_siege_target_from_forecast(
				defender,
				forecast,
				rules
			)
			var chosen: String = String(choice.get("target_castle", ""))
			if not chosen.is_empty():
				return chosen

	return _fallback_siege_target(defender, rules)


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
	# REFLEX_BID_DEPRECATED_RUNTIME_V1
	# Compatibility stub only. Reflex Bid is retired and may not spend or
	# reserve cards even if a stale historical RuleConfig has reflex_bid=true.
	assert(game != null, "deprecated Reflex evaluator requires a GameState.")
	assert(rules != null, "deprecated Reflex evaluator requires RuleConfig.")
	assert(game.get_player(player_id) != null, "Deprecated Reflex evaluator player does not exist.")
	return [{
		"id": "reflex_bid_deprecated",
		"score": 0.0,
		"degraded_score": 0.0,
		"tie_rank": 0,
		"payload": {
			"pass": true,
			"deprecated": true,
		},
	}]

static func bid_choices(
	game,
	_random_source,
	rules: RuleConfig,
	_policy = null
) -> Dictionary:
	# REFLEX_BID_DEPRECATED_RUNTIME_V1
	# Compatibility stub only. Live round conductors never call this path.
	assert(game != null, "deprecated Reflex Bid doctrine requires a GameState.")
	assert(rules != null, "deprecated Reflex Bid doctrine requires RuleConfig.")
	var decisions: Dictionary = {}
	for player in game.players:
		decisions[int(player.pid)] = {
			"pass": true,
			"deprecated": true,
		}
	return decisions

# DEFENSE_CULPABILITY_COMMITMENT_DRILLDOWN_V1
static var _culp_detail_enabled: bool = false
static var _culp_detail_events: Array[Dictionary] = []


static func culpability_detail_start() -> void:
	_culp_detail_events.clear()
	_culp_detail_enabled = true


static func culpability_detail_stop() -> Array[Dictionary]:
	_culp_detail_enabled = false
	var out: Array[Dictionary] = []
	for row in _culp_detail_events:
		out.append(row.duplicate(true))
	return out


static func _culp_detail_mark(
	label: String,
	started_us: int,
	game,
	player
) -> void:
	if not _culp_detail_enabled:
		return

	var pid: int = -1
	var lord: String = ""
	var hand_size: int = -1

	if player != null:
		pid = int(player.pid)
		lord = String(player.lord)
		hand_size = int(player.hand.size())

	_culp_detail_events.append({
		"round": int(game.round) if game != null else -1,
		"player_id": pid,
		"lord": lord,
		"hand_size": hand_size,
		"phase": label,
		"elapsed_us": Time.get_ticks_usec() - started_us,
	})


static func _culp_detail_plan(
	game,
	player_id: int,
	rules: RuleConfig
) -> String:
	var started_us: int = Time.get_ticks_usec()
	var result: String = plan(game, player_id, rules)
	_culp_detail_mark(
		"plan",
		started_us,
		game,
		game.get_player(player_id)
	)
	return result


static func _culp_detail_score_hunt(
	game,
	player,
	opponent,
	current_plan: String,
	rules: RuleConfig
) -> float:
	var started_us: int = Time.get_ticks_usec()
	var result: float = _score_hunt(
		game,
		player,
		opponent,
		current_plan,
		rules
	)
	_culp_detail_mark("score_hunt", started_us, game, player)
	return result


static func _culp_detail_score_siege(
	game,
	player,
	opponent,
	current_plan: String,
	rules: RuleConfig
) -> float:
	var started_us: int = Time.get_ticks_usec()
	var result: float = _score_siege(
		player,
		opponent,
		current_plan,
		rules
	)
	_culp_detail_mark("score_siege", started_us, game, player)
	return result


static func _culp_detail_score_ward(
	game,
	player,
	opponent,
	current_plan: String,
	rules: RuleConfig
) -> float:
	var started_us: int = Time.get_ticks_usec()
	var result: float = _score_ward(
		game,
		player,
		opponent,
		current_plan,
		rules
	)
	_culp_detail_mark("score_ward", started_us, game, player)
	return result


static func _culp_detail_doctrine_delta(
	game,
	player,
	rules: RuleConfig
) -> Vector3:
	var started_us: int = Time.get_ticks_usec()
	var result: Vector3 = OdradekInterlockEngineData.doctrine_delta(
		player,
		rules
	)
	_culp_detail_mark("doctrine_delta", started_us, game, player)
	return result


static func _culp_detail_profanable(
	game,
	player,
	rules: RuleConfig
) -> Array[String]:
	var started_us: int = Time.get_ticks_usec()
	var result: Array[String] = _profanable_castles(player, rules)
	_culp_detail_mark("profanable", started_us, game, player)
	return result


static func _culp_detail_dominion_requirement(
	game,
	player,
	rules: RuleConfig
) -> int:
	var started_us: int = Time.get_ticks_usec()
	var result: int = _dominion_requirement(game, rules)
	_culp_detail_mark(
		"dominion_requirement",
		started_us,
		game,
		player
	)
	return result


static func _culp_detail_pick_siege_target(
	game,
	attacker_id: int,
	defender_id: int,
	rules: RuleConfig
) -> String:
	var started_us: int = Time.get_ticks_usec()
	var result: String = pick_siege_target(
		game,
		attacker_id,
		defender_id,
		rules
	)
	_culp_detail_mark(
		"pick_siege_target",
		started_us,
		game,
		game.get_player(attacker_id)
	)
	return result


static func _culp_detail_commit_attack(
	game,
	player,
	opponent,
	target_type: String,
	current_plan: String,
	chip: bool,
	rules: RuleConfig,
	target_castle_override: String = ""
) -> Array:
	var started_us: int = Time.get_ticks_usec()
	var result: Array = _commit_for_attack(
		game,
		player,
		opponent,
		target_type,
		current_plan,
		chip,
		rules,
		target_castle_override
	)
	_culp_detail_mark("commit_attack", started_us, game, player)
	return result


static func _culp_detail_ward_read(
	game,
	player,
	opponent,
	rules: RuleConfig
) -> String:
	var started_us: int = Time.get_ticks_usec()
	var result: String = _ward_read_zone(
		game,
		player,
		opponent,
		rules
	)
	_culp_detail_mark("ward_read", started_us, game, player)
	return result


static func _culp_detail_commit_ward(
	game,
	player,
	opponent,
	current_plan: String,
	rules: RuleConfig
) -> Array:
	var started_us: int = Time.get_ticks_usec()
	var result: Array = _commit_for_ward(
		game,
		player,
		opponent,
		current_plan,
		rules
	)
	_culp_detail_mark("commit_ward", started_us, game, player)
	return result


static func _culp_detail_profane_target(
	game,
	player,
	rules: RuleConfig
) -> String:
	var started_us: int = Time.get_ticks_usec()
	var result: String = _profane_target(player, rules)
	_culp_detail_mark("profane_target", started_us, game, player)
	return result


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

	var current_plan: String = _culp_detail_plan(
		game,
		player_id,
		rules
	)

	var action_forecast: Dictionary = ActionForecastData.forecast_all(
		game,
		rules,
		player_id,
		true
	)
	var hunt_reach: float = _hunt_forecast_reach(action_forecast.get("hunt", {}))
	var siege_choice: Dictionary = _best_siege_target_from_forecast(
		opponent,
		action_forecast,
		rules
	)
	var siege_reach: float = float(siege_choice.get("reach", -1.0))
	var siege_target_value: float = float(siege_choice.get("strategic_value", 0.0))

	var hunt_score: float = (
		_culp_detail_score_hunt(
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
		_culp_detail_score_siege(
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

	var ward_score: float = (
		_culp_detail_score_ward(
			game,
			player,
			opponent,
			current_plan,
			rules
		)
		* float(
			profile.get(
				"control",
				1.0
			)
		)
	)


	if hunt_reach >= 0.0:
		hunt_score += _forecast_score_adjustment(hunt_reach)

	if siege_reach >= 0.0:
		siege_score += _forecast_score_adjustment(siege_reach)
		siege_score += minf(
			0.60,
			siege_target_value * maxf(0.0, siege_reach) * 0.25
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

	var doctrine_delta: Vector3 = _culp_detail_doctrine_delta(
		game,
		player,
		rules
	)
	hunt_score += doctrine_delta.x
	siege_score += doctrine_delta.y
	ward_score += doctrine_delta.z

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
	var profanable: Array[String] = _culp_detail_profanable(game, player, rules)
	var can_profane: bool = (
		not profanable.is_empty()
		and (
			rules.profane_no_castle_gate
			or player.castles.size() >= 3
		)
	)

	if can_profane:
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
			"forecast_reach": hunt_reach,
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
			"forecast_reach": siege_reach,
			"forecast_target": String(siege_choice.get("target_castle", "")),
			"forecast_target_value": siege_target_value,
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

	if can_profane:
		candidates.append({
			"id": ACTION_PROFANE,
			"action": ACTION_PROFANE,
			"score": profane_score,
			"degraded_score": 0.4,
			"tie_rank": 1,
			"chip_siege": false,
		})

	return candidates


# DEFENSE_CULPABILITY_COMMITMENT_PROFILER_V1
static var _culpability_commit_profile_enabled: bool = false
static var _culpability_commit_profile_events: Array[Dictionary] = []


static func culpability_commit_profile_start() -> void:
	_culpability_commit_profile_events.clear()
	_culpability_commit_profile_enabled = true


static func culpability_commit_profile_stop() -> Array[Dictionary]:
	_culpability_commit_profile_enabled = false
	var out: Array[Dictionary] = []
	for row in _culpability_commit_profile_events:
		out.append(row.duplicate(true))
	return out


static func _culp_commit_now() -> int:
	return Time.get_ticks_usec()


static func _culp_commit_mark(
	label: String,
	started_us: int,
	game,
	player_id: int
) -> void:
	if not _culpability_commit_profile_enabled:
		return

	_culpability_commit_profile_events.append({
		"round": int(game.round),
		"player_id": player_id,
		"phase": label,
		"elapsed_us": Time.get_ticks_usec() - started_us,
	})


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

		var _culp_candidates_us: int = _culp_commit_now()
		var candidates: Array = (
			evaluate_action_candidates(
				game,
				player_id,
				rules
			)
		)

		_culp_commit_mark(
			"candidate_evaluation",
			_culp_candidates_us,
			game,
			player_id
		)

		var _culp_selector_us: int = _culp_commit_now()
		var selection: Dictionary = (
			BotSelectorData.choose(
				candidates,
				random_source,
				effective_policy
			)
		)

		_culp_commit_mark(
			"selector",
			_culp_selector_us,
			game,
			player_id
		)

		var selected_candidate: Dictionary = (
			selection.get(
				"candidate",
				{}
			)
		)

		var _culp_decision_us: int = _culp_commit_now()
		decisions[player_id] = (
			_commitment_decision_from_candidate(
				game,
				player_id,
				selected_candidate,
				rules
			)
		)
		_culp_commit_mark(
			"decision_construction",
			_culp_decision_us,
			game,
			player_id
		)

	return decisions


static func commitment_choice(
	game,
	player_id: int,
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
			_policy_or_default(policy)
		)
	)

	var selected_candidate: Dictionary = (
		selection.get(
			"candidate",
			{}
		)
	)

	return _commitment_decision_from_candidate(
		game,
		player_id,
		selected_candidate,
		rules
	)


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

	var current_plan: String = _culp_detail_plan(
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
				_culp_detail_commit_attack(
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

		# BOT_SIEGE_TARGET_REUSE_V1
		# Forecast target once, then use that same Castle for payload and
		# commitment sizing.
		var selected_target: String = _culp_detail_pick_siege_target(
			game,
			player_id,
			int(opponent.pid),
			rules
		)

		return {
			"action": ACTION_SIEGE,
			"target_pid": int(
				opponent.pid
			),
			"target_castle": selected_target,
			"cards": _card_ids(
				_culp_detail_commit_attack(
					game,
					player,
					opponent,
					TARGET_CASTLE,
					current_plan,
					chip_siege,
					rules,
					selected_target
				)
			),
		}

	if action_name == ACTION_PROFANE:
		return {
			"action": ACTION_PROFANE,
			"target_pid": player_id,
			"target_castle": _culp_detail_profane_target(
				game,
				player, rules
			),
			"cards": [],
		}

	var ward_target: String = ""

	if not player.alive:
		ward_target = TARGET_CASTLE
	elif rules.ward_read:
		ward_target = _culp_detail_ward_read(
			game,
			player,
			opponent,
			rules
		)
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

		if (
			rules.ward_anti_repeat
			and ward_target == player.prev_ward_target
		):
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
			_culp_detail_commit_ward(
				game,
				player,
				opponent,
				current_plan,
				rules
			)
		),
	}


# BOT_DOCTRINE_ACTION_FORECAST_V1
# Personality/plan supplies intent. ActionForecast supplies public-information
# feasibility. Castle strategic value supplies payoff.
static func _forecast_objective_reach(objective) -> float:
	if typeof(objective) != TYPE_DICTIONARY:
		return -1.0

	var report: Dictionary = objective
	var open_value = report.get("open", {})
	if typeof(open_value) != TYPE_DICTIONARY:
		return -1.0

	var open_probability: float = clampf(
		float(open_value.get("probability", 0.0)),
		0.0,
		1.0
	)
	var warded_range = report.get("warded_range", {})

	if (
		typeof(warded_range) != TYPE_DICTIONARY
		or not bool(warded_range.get("available", false))
	):
		return open_probability

	# Forecast intentionally does not predict whether Ward will be chosen.
	# This is a robustness score: mostly open reach, plus some weight on the
	# worst modeled Ward branch. It is not claimed expected win probability.
	var ward_floor: float = clampf(
		float(warded_range.get("min_probability", open_probability)),
		0.0,
		1.0
	)
	return open_probability * 0.75 + ward_floor * 0.25


static func _hunt_forecast_reach(report) -> float:
	if (
		typeof(report) != TYPE_DICTIONARY
		or not bool(report.get("available", false))
	):
		return -1.0

	var pressure: float = _forecast_objective_reach(report.get("pressure", {}))
	var banish: float = _forecast_objective_reach(report.get("banish", {}))
	if pressure < 0.0 or banish < 0.0:
		return -1.0
	return clampf(pressure * 0.35 + banish * 0.65, 0.0, 1.0)


static func _siege_forecast_reach(report) -> float:
	if (
		typeof(report) != TYPE_DICTIONARY
		or not bool(report.get("available", false))
	):
		return -1.0

	var damage: float = _forecast_objective_reach(report.get("damage", {}))
	var ruin: float = _forecast_objective_reach(report.get("ruin", {}))
	if damage < 0.0 or ruin < 0.0:
		return -1.0
	return clampf(damage * 0.40 + ruin * 0.60, 0.0, 1.0)


static func _forecast_score_adjustment(reach: float) -> float:
	if reach < 0.0:
		return 0.0

	# 35% is ActionForecast's RISKY/FAVORABLE boundary, so make it neutral.
	return clampf((reach - 0.35) * 2.0, -0.70, 1.30)


static func _castle_strategic_value(owner, castle_name: String, rules: RuleConfig) -> float:
	if (
		owner == null
		or rules == null
		or not CastleIntegrityRulesData.power_active(owner, castle_name, rules)
	):
		return 0.0

	var value: float = 0.25

	match castle_name:
		"Keep":
			if rules.keep_sanctuary and owner.alive:
				value += 1.00 + float(owner.souls) / float(maxi(1, rules.win_souls)) * 0.35
			if rules.keep_ignores_ward_tax:
				value += 0.85
		"Bastion":
			if owner.alive:
				value += 0.75
			if rules.bastion_wall and owner.castles.size() > 1:
				value += 1.00
		"Stockpile":
			if rules.stockpile_filter:
				value += 0.55
		"SummoningCircle":
			if rules.circle_blood_summon and not owner.alive:
				value += 0.75
			if rules.circle_blood_conduit and owner.threat >= 1:
				value += 0.35
		"SiegeEngine":
			if rules.attack_offsuit_penalty > 0:
				value += 0.85
			if rules.siege_engine_bypass:
				value += 0.35
			if owner.lord == "Deimos" and owner.alive:
				value += 0.75

	return value


static func _fallback_siege_target(defender, rules: RuleConfig) -> String:
	if defender == null or defender.castles.is_empty():
		return ""

	for castle_name: String in SIEGE_TARGET_ORDER:
		if not defender.castles.has(castle_name):
			continue
		if (
			castle_name == "Bastion"
			and rules != null
			and rules.bastion_wall
			and CastleIntegrityRulesData.standing(defender, "Bastion")
			and defender.castles.size() > 1
		):
			continue
		return castle_name

	return String(defender.castles[0])


static func _best_siege_target_from_forecast(
	defender,
	forecast: Dictionary,
	rules: RuleConfig
) -> Dictionary:
	var raw_targets = forecast.get("siege_targets", {})
	if typeof(raw_targets) != TYPE_DICTIONARY:
		return {}

	var siege_targets: Dictionary = raw_targets
	var names: Array[String] = []

	for castle_value in defender.castles:
		var castle_name: String = String(castle_value)
		if not CastleIntegrityRulesData.standing(defender, castle_name):
			continue
		# With a standing Bastion wall, naming a rear Castle preserves overflow and
		# dominates directly naming Bastion while something remains behind it.
		if (
			castle_name == "Bastion"
			and rules.bastion_wall
			and CastleIntegrityRulesData.standing(defender, "Bastion")
			and defender.castles.size() > 1
		):
			continue
		names.append(castle_name)

	names.sort()
	var best: Dictionary = {}
	var best_utility: float = -999.0
	var best_tie_rank: int = -999

	for castle_name: String in names:
		var raw_report = siege_targets.get(castle_name, {})
		if typeof(raw_report) != TYPE_DICTIONARY:
			continue
		var report: Dictionary = raw_report
		var reach: float = _siege_forecast_reach(report)
		if reach < 0.0:
			continue

		var strategic: float = _castle_strategic_value(defender, castle_name, rules)
		var maximum: int = maxi(1, CastleIntegrityRulesData.max_integrity(castle_name))
		var current: int = int(defender.castle_integrity.get(castle_name, maximum))
		var wounded: float = clampf(float(maximum - current) / float(maximum), 0.0, 1.0)

		# Reach is dominant. Strategic value can justify a somewhat harder but more
		# consequential engine; wounded state mildly rewards finishing work.
		var utility: float = (
			reach * (1.0 + strategic * 0.50)
			+ strategic * 0.15
			+ wounded * 0.15
		)
		var order_index: int = SIEGE_TARGET_ORDER.find(castle_name)
		var tie_rank: int = SIEGE_TARGET_ORDER.size() - order_index if order_index >= 0 else 0

		if (
			utility > best_utility + 0.0001
			or (is_equal_approx(utility, best_utility) and tie_rank > best_tie_rank)
		):
			best_utility = utility
			best_tie_rank = tie_rank
			best = {
				"target_castle": castle_name,
				"reach": reach,
				"strategic_value": strategic,
				"utility": utility,
			}

	return best



static func _score_hunt(
	game,
	player,
	opponent,
	current_plan: String,
	rules: RuleConfig
) -> float:
	if not opponent.alive:
		return -5.0

	var score: float = 0.90 if rules.fix_a else 1.8

	# Opponent Threat is not a generic Hunt beacon. Actual defensive
	# consequences are priced by ActionForecast in candidate evaluation.
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

	if (
		rules.ward_threshold
		and opponent.prev_ward_target != TARGET_LORD
	):
		score -= 0.40

	return score


static func _score_siege(
	player,
	opponent,
	current_plan: String,
	rules: RuleConfig
) -> float:
	if opponent.castles.is_empty():
		return -5.0

	var score: float = 0.333 if rules.fix_a else 1.0

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

	if (
		rules.ward_threshold
		and opponent.prev_ward_target != TARGET_CASTLE
	):
		score -= 0.40

	return score


static func _score_ward(
	_game,
	player,
	opponent,
	current_plan: String,
	rules: RuleConfig
) -> float:
	var score: float = 0.6

	if rules.fix_a:
		score = 0.333
		score += player.souls * 0.12
		score += (float(player.castles.size()) / 5.0) * 0.40
		score += player.threat * 0.20
	else:
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

	# Canonical Penitent Ward tax must affect action selection, not only the
	# resolver, or the bot keeps choosing Ward as if every suit were efficient.
	if rules.ward_offsuit_penalty > 0 and not player.hand.is_empty():
		var raw_hand: int = _card_total(player.hand)
		var effective_hand: int = 0
		for card in player.hand:
			effective_hand += int(player.ward_card_value(card, rules))
		if raw_hand > 0:
			score *= float(effective_hand) / float(raw_hand)

	if rules.ward_threshold:
		var incoming: float = 0.0
		if opponent.alive:
			incoming += 0.5
		if not player.castles.is_empty():
			incoming += 0.4
		if player.souls >= rules.win_souls - 2:
			incoming += 0.6
		if player.threat >= 2:
			incoming += 0.5
		if _card_total(player.hand) < 4:
			incoming *= 0.3
		score += incoming * 0.30

	return score


static func _degraded_hunt_score(
	player,
	opponent
) -> float:
	if not opponent.alive:
		return -5.0

	return (
		1.3
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


static func _ward_read_zone(
	_game,
	player,
	opponent,
	rules: RuleConfig
) -> String:
	var lord_score: float = 0.0
	var castle_score: float = 0.0
	var opponent_profile: Dictionary = _profile_for(String(opponent.lord))
	var preference: String = String(opponent_profile.get("prefer", ""))

	if preference == ACTION_HUNT:
		lord_score += 0.90
	elif preference == ACTION_SIEGE:
		castle_score += 0.90

	if not player.alive:
		castle_score += 2.0
	else:
		# Threat 1 has no defensive consequence. Only actual Threat breakpoints
		# soften the public Lord door.
		if player.threat >= 2:
			lord_score += float(player.threat - 1) * 0.50
		if player.souls >= rules.win_souls - 2:
			lord_score += 0.30

	if not player.castles.is_empty():
		castle_score += (float(player.castles.size()) / 5.0) * 0.75
	else:
		lord_score += 2.0

	lord_score += float(opponent_profile.get("aggro", 1.0)) * 0.30

	if player.was_lord_attacked_prev:
		lord_score += 0.50
	if player.was_castle_attacked_prev:
		castle_score += 0.50

	return TARGET_LORD if lord_score >= castle_score else TARGET_CASTLE


static func _estimated_guard_total(
	guards: Array,
	rules: RuleConfig
) -> int:
	if guards.is_empty():
		return 0

	if not rules.fog_of_war:
		return _card_total(guards)

	# Reconnaissance makes revealed Guards exact while unrevealed cards retain
	# the deterministic deck-mean Fog estimate.
	var known_total: int = 0
	var unknown_count: int = 0
	for card in guards:
		if bool(card.guard_revealed):
			known_total += int(card.value)
		else:
			unknown_count += 1
	if unknown_count <= 0:
		return known_total
	return known_total + max(
		unknown_count,
		int(round(float(unknown_count) * 2.83))
	)


static func _estimated_guard_total_ignoring_lowest(
	guards: Array,
	rules: RuleConfig
) -> int:
	var estimated_total: int = _estimated_guard_total(
		guards,
		rules
	)

	# Valak's Crushing Presence only turns on when the attacked zone
	# contains at least two Guards.
	if guards.size() < 2:
		return estimated_total

	# In open-information profiles, exact values are legal knowledge.
	if not rules.fog_of_war:
		var lowest_value: int = int(
			guards[0].value
		)

		for index: int in range(
			1,
			guards.size()
		):
			lowest_value = mini(
				lowest_value,
				int(
					guards[index].value
				)
			)

		return maxi(
			0,
			estimated_total - lowest_value
		)

	# Under Fog, revealed Guards remain exact. Face-down Guards must stay
	# statistical: one unknown Guard is represented by the same rounded
	# 2.83 deck-mean estimate used by _estimated_guard_total().
	var lowest_estimate: int = 0
	var have_estimate: bool = false
	var unknown_count: int = 0

	for card in guards:
		if bool(
			card.guard_revealed
		):
			var known_value: int = int(
				card.value
			)

			if (
				not have_estimate
				or known_value < lowest_estimate
			):
				lowest_estimate = known_value
				have_estimate = true
		else:
			unknown_count += 1

	if unknown_count > 0:
		var hidden_guard_estimate: int = maxi(
			1,
			int(round(2.83))
		)

		if (
			not have_estimate
			or hidden_guard_estimate < lowest_estimate
		):
			lowest_estimate = hidden_guard_estimate
			have_estimate = true

	if not have_estimate:
		return estimated_total

	return maxi(
		0,
		estimated_total - lowest_estimate
	)


static func _commit_for_attack(
	game,
	player,
	opponent,
	target_type: String,
	current_plan: String,
	chip: bool,
	rules: RuleConfig,
	target_castle_override: String = ""
) -> Array:
	if chip:
		var chip_guards: Array = (
			opponent.castle_guards
			if target_type == TARGET_CASTLE
			else opponent.lord_guards
		)

		if not chip_guards.is_empty():
			# Chip attacks still need to respect Fog of War.  The old doctrine
			# inspected the highest face-down guard here even after the normal
			# attack estimator had been made fog-safe.  A player can see the
			# number of Guards, not their individual values, so use the same
			# deterministic estimate as every other attack calculation.
			var needed_strength: int = (
				_estimated_guard_total(chip_guards, rules)
				if rules.fog_of_war
				else int(_highest_card(chip_guards).value)
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

				picked_total += player.attack_card_value(
					card, rules, target_type == TARGET_CASTLE
				)

			if picked_total > needed_strength:
				return picked_cards

	var estimated_defense: int = 0

	if target_type == TARGET_LORD:
		estimated_defense = _lord_base_defense(
			opponent,
			rules
		)

		estimated_defense += _estimated_guard_total(
			opponent.lord_guards,
			rules
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
				),
				rules
			)
		)
	else:
		# BOT_SIEGE_TARGET_REUSE_V1
		# Reuse an already-selected forecast target when supplied.
		var target_castle: String = target_castle_override
		if target_castle.is_empty():
			target_castle = pick_siege_target(
				game,
				int(player.pid),
				int(opponent.pid),
				rules
			)

		# Bastion may screen a strategically chosen rear Castle, but the bot's
		# immediate commitment objective is only to destroy the wall. Overflow
		# into the rear Castle is upside; it is not required commitment strength.
		var commitment_castle: String = target_castle
		if (
			rules.bastion_wall
			and target_castle != "Bastion"
			and CastleIntegrityRulesData.standing(
				opponent,
				"Bastion"
			)
		):
			commitment_castle = "Bastion"

		estimated_defense = _castle_defense(
			game,
			commitment_castle,
			opponent,
			rules
		)

		if not (rules.siege_engine_bypass and player.castles.has("SiegeEngine")):
			var castle_guard_estimate: int = (
				_estimated_guard_total(
					opponent.castle_guards,
					rules
				)
			)

			if (
				player.lord == "Valak"
				and player.alive
				and opponent.castle_guards.size() >= 2
			):
				castle_guard_estimate = (
					_estimated_guard_total_ignoring_lowest(
						opponent.castle_guards,
						rules
					)
				)

			estimated_defense += castle_guard_estimate

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
				),
				rules
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

	if rules.momentum:
		padding = min(padding, 1)

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
		not rules.momentum
	)

	other_cards = _stable_sorted_cards(
		other_cards,
		not rules.momentum
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

		committed_total += player.attack_card_value(
			card, rules, target_type == TARGET_CASTLE
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
		- player.attack_card_value(
			committed[committed.size() - 1],
			rules,
			target_type == TARGET_CASTLE
		)
		> target_strength
		+ trim_allowance
	):
		var removed_card = committed.pop_back()

		committed_total -= player.attack_card_value(
			removed_card, rules, target_type == TARGET_CASTLE
		)

	# Crushing Presence lowers Valak's required defensive breakpoint.
	# His normal momentum-oriented greedy ordering can still overcommit
	# when a smaller subset reaches that breakpoint, so compact only
	# Valak's proposed commitment here. Odradek recoil handling below
	# remains authoritative and may add cards back if necessary.
	if (
		player.lord == "Valak"
		and player.alive
		and target_type == TARGET_CASTLE
	):
		var compact_commitment: Array = (
			_minimum_threshold_attack_subset(
				player,
				player.hand,
				rules,
				target_type == TARGET_CASTLE,
				target_strength
			)
		)

		if (
			not compact_commitment.is_empty()
			and compact_commitment.size()
			< committed.size()
		):
			committed = compact_commitment

			committed_total = 0
			for compact_card in committed:
				committed_total += (
					player.attack_card_value(
						compact_card,
						rules,
						target_type == TARGET_CASTLE
					)
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
				player, committed, rules, target_type == TARGET_CASTLE
			) >= target_strength:
				break

			committed.append(
				card
			)

	return committed


static func _minimum_threshold_attack_subset(
	player,
	cards: Array,
	rules: RuleConfig,
	siege: bool,
	target_strength: int
) -> Array:
	if cards.is_empty():
		return []

	# Normal hands are tiny. This is only a defensive ceiling against some
	# future mode accidentally feeding a huge collection into the doctrine.
	if cards.size() > 12:
		return []

	var best_subset: Array = []
	var best_count: int = 999999
	var best_total: int = 999999
	var best_printed_total: int = 999999
	var best_mask: int = 999999

	var combination_count: int = (
		1 << cards.size()
	)

	for mask: int in range(
		1,
		combination_count
	):
		var subset: Array = []
		var effective_total: int = 0
		var printed_total: int = 0

		for index: int in range(
			cards.size()
		):
			if (
				mask
				& (1 << index)
			) == 0:
				continue

			var card = cards[index]

			subset.append(
				card
			)

			effective_total += (
				player.attack_card_value(
					card,
					rules,
					siege
				)
			)

			printed_total += int(
				card.value
			)

		if effective_total < target_strength:
			continue

		var subset_count: int = (
			subset.size()
		)

		var better: bool = false

		if subset_count < best_count:
			better = true
		elif (
			subset_count == best_count
			and effective_total < best_total
		):
			better = true
		elif (
			subset_count == best_count
			and effective_total == best_total
			and printed_total < best_printed_total
		):
			better = true
		elif (
			subset_count == best_count
			and effective_total == best_total
			and printed_total == best_printed_total
			and mask < best_mask
		):
			better = true

		if not better:
			continue

		best_subset = subset
		best_count = subset_count
		best_total = effective_total
		best_printed_total = printed_total
		best_mask = mask

	return best_subset


static func _commit_for_ward(
	_game,
	player,
	opponent,
	current_plan: String,
	rules: RuleConfig
) -> Array:
	if rules.ward_commit_any:
		var expected: float = float(
			_card_total(opponent.hand)
			+ _card_total(opponent.garrison)
		) * 0.60

		if current_plan in ["protect_souls", "deny_ritual"]:
			expected *= 1.15
		elif current_plan in ["race_dominion", "pressure_souls"]:
			expected *= 0.75

		expected *= float(
			_profile_for(String(player.lord)).get("control", 1.0)
		)

		var budget: float = min(
			expected,
			float(_card_total(player.hand)) * 0.70
		)
		var any_suit_commitment: Array = []
		var any_suit_total: int = 0

		# BOT_WARD_COMMIT_SORT_OPT_V1
		# Preserve the old exact ordering:
		#   1. effective Ward value descending
		#   2. printed value descending
		#   3. suit name ascending
		#   4. original hand order for exact ties
		# The previous repeated best-card scan was O(n^2) and recalculated
		# ward_card_value for the same cards many times.
		var ward_entries: Array[Dictionary] = []
		for hand_index: int in range(player.hand.size()):
			var hand_card = player.hand[hand_index]
			ward_entries.append({
				"card": hand_card,
				"ward_value": int(player.ward_card_value(hand_card, rules)),
				"printed_value": int(hand_card.value),
				"suit": String(hand_card.suit),
				"index": hand_index,
			})

		ward_entries.sort_custom(
			func(
				entry_a: Dictionary,
				entry_b: Dictionary
			) -> bool:
				var ward_a: int = int(entry_a["ward_value"])
				var ward_b: int = int(entry_b["ward_value"])
				if ward_a != ward_b:
					return ward_a > ward_b

				var printed_a: int = int(entry_a["printed_value"])
				var printed_b: int = int(entry_b["printed_value"])
				if printed_a != printed_b:
					return printed_a > printed_b

				var suit_a: String = String(entry_a["suit"])
				var suit_b: String = String(entry_b["suit"])
				if suit_a != suit_b:
					return suit_a < suit_b

				return int(entry_a["index"]) < int(entry_b["index"])
		)

		var ward_cards: Array = []
		for ward_entry: Dictionary in ward_entries:
			ward_cards.append(ward_entry["card"])

		for card in ward_cards:
			if float(any_suit_total) >= budget:
				break
			any_suit_commitment.append(card)
			any_suit_total += int(player.ward_card_value(card, rules))

		return any_suit_commitment

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
	player,
	cards: Array,
	rules: RuleConfig,
	siege: bool
) -> int:
	if cards.size() <= 1:
		var unopposed_total: int = 0
		for card in cards:
			unopposed_total += player.attack_card_value(
				card,
				rules,
				siege
			)
		return unopposed_total
	var ordered: Array = cards.duplicate()
	ordered.sort_custom(func(a, b): return int(a.value) > int(b.value))
	var removed = ordered[ordered.size() - 1] if rules.recoil_lowest else ordered[1]
	var total: int = 0
	for card in cards:
		total += player.attack_card_value(card, rules, siege)
	return total - player.attack_card_value(removed, rules, siege)


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

	if defender.castles.has("Bastion"):
		defense += maxi(0, int(rules.bastion_lord_def_bonus))

	return max(
		0,
		defense
	)


static func _castle_defense(
	game,
	castle_name: String,
	defender = null,
	rules: RuleConfig = null
) -> int:
	if rules != null and rules.castle_integrity and defender != null:
		var integrity_defense: int = int(
			defender.castle_integrity.get(
				castle_name,
				CastleIntegrityRulesData.max_integrity(castle_name)
			)
		)
		if (
			rules.bastion_wall
			and castle_name != "Bastion"
			and CastleIntegrityRulesData.standing(defender, "Bastion")
		):
			integrity_defense += int(defender.castle_integrity.get(
				"Bastion", CastleIntegrityRulesData.max_integrity("Bastion")
			))
		if game.breach == "Deimos":
			integrity_defense = maxi(0, integrity_defense - 1)
		elif game.breach == "Humbaba":
			integrity_defense = maxi(1, integrity_defense - 1)
		return integrity_defense

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

	if (
		rules != null
		and rules.castle_scarring
		and defender != null
	):
		defense = max(
			1,
			defense - (
				int(defender.castle_scars.get(castle_name, 0))
				* rules.castle_scar_def
			)
		)

	return defense


static func _sigil_value(
	game,
	player,
	sigil_state: String,
	rules: RuleConfig = null
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

	if rules != null and rules.sigil_flat:
		return value

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


static func _profanable_castles(player, rules: RuleConfig) -> Array[String]:
	var result: Array[String] = []
	for castle_value in player.castles:
		var castle_name: String = String(castle_value)
		if not rules.profane_requires_full_integrity:
			result.append(castle_name)
			continue
		var maximum: int = CastleIntegrityRulesData.max_integrity(castle_name)
		if int(player.castle_integrity.get(castle_name, maximum)) >= maximum:
			result.append(castle_name)
	return result


static func _profane_target(player, rules: RuleConfig) -> String:
	var eligible: Array[String] = _profanable_castles(player, rules)
	if eligible.is_empty():
		return ""
	var raw_priority = CASTLE_PRIORITIES.get(
		String(player.lord),
		DEFAULT_CASTLE_PRIORITY
	)
	var priority: Array = raw_priority
	for index: int in range(priority.size() - 1, -1, -1):
		var castle_name: String = String(priority[index])
		if eligible.has(castle_name):
			return castle_name
	return eligible[0]


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
