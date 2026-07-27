class_name PlayableBotDoctrine
extends RefCounted


const BotDoctrineData = preload(
	"res://Scripts/Sim/BotDoctrine.gd"
)

const BotSelectorData = preload(
	"res://Scripts/Sim/BotSelector.gd"
)


const ACTION_HUNT: String = "Hunt"
const ACTION_SIEGE: String = "Siege"
const ACTION_WARD: String = "Ward"

const FIX_A_BASE_SCORE: float = 0.333
const CANONICAL_HUNT_BASE: float = 1.8
const CANONICAL_SIEGE_BASE: float = 1.0
const CANONICAL_WARD_BASE: float = 0.6

const FIX_A_WARD_SOUL_WEIGHT: float = 0.12
const FIX_A_WARD_CASTLE_WEIGHT: float = 0.08
const FIX_A_WARD_THREAT_WEIGHT: float = 0.20

const CANONICAL_WARD_SOUL_WEIGHT: float = 0.55
const CANONICAL_WARD_CASTLE_WEIGHT: float = 0.30
const CANONICAL_WARD_THREAT_WEIGHT: float = 0.35


static func commitment_choices(
	game,
	random_source,
	rules: RuleConfig,
	policy = null
) -> Dictionary:
	assert(
		game != null,
		"Playable FIX A doctrine requires a GameState."
	)

	assert(
		rules != null,
		"Playable FIX A doctrine requires RuleConfig."
	)

	var effective_policy = (
		BotDoctrineData._policy_or_default(
			policy
		)
	)
	var decisions: Dictionary = {}

	for player in game.players:
		var player_id: int = int(
			player.pid
		)
		decisions[player_id] = commitment_choice(
			game,
			player_id,
			random_source,
			rules,
			effective_policy
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
		"Playable FIX A doctrine requires a GameState."
	)

	assert(
		rules != null,
		"Playable FIX A doctrine requires RuleConfig."
	)

	var player = game.get_player(player_id)
	assert(
		player != null,
		"Playable FIX A player %d does not exist."
		% player_id
	)

	var candidates: Array = BotDoctrineData.evaluate_action_candidates(
		game,
		player_id,
		rules
	)
	_apply_fix_a_scores(player, candidates)

	var selection: Dictionary = BotSelectorData.choose(
		candidates,
		random_source,
		BotDoctrineData._policy_or_default(policy)
	)
	var selected_candidate: Dictionary = selection.get("candidate", {})
	return BotDoctrineData._commitment_decision_from_candidate(
		game,
		player_id,
		selected_candidate,
		rules
	)


static func _apply_fix_a_scores(
	player,
	candidates: Array
) -> void:
	# Canonical dead-player behavior is a forced zero-score Ward. FIX A does
	# not alter that legality fallback.
	if not player.alive:
		return

	var profile: Dictionary = (
		BotDoctrineData._profile_for(
			String(
				player.lord
			)
		)
	)
	var aggro: float = float(
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
	var ward_delta: float = (
		(
			FIX_A_BASE_SCORE
			- CANONICAL_WARD_BASE
		)
		+ float(
			player.souls
		) * (
			FIX_A_WARD_SOUL_WEIGHT
			- CANONICAL_WARD_SOUL_WEIGHT
		)
		+ float(
			player.castles.size()
		) * (
			FIX_A_WARD_CASTLE_WEIGHT
			- CANONICAL_WARD_CASTLE_WEIGHT
		)
		+ float(
			player.threat
		) * (
			FIX_A_WARD_THREAT_WEIGHT
			- CANONICAL_WARD_THREAT_WEIGHT
		)
	)

	for raw_candidate in candidates:
		if typeof(
			raw_candidate
		) != TYPE_DICTIONARY:
			continue

		var candidate: Dictionary = raw_candidate
		var action_name: String = String(
			candidate.get(
				"action",
				""
			)
		)
		var score: float = float(
			candidate.get(
				"score",
				0.0
			)
		)

		if action_name == ACTION_HUNT:
			score += (
				FIX_A_BASE_SCORE
				- CANONICAL_HUNT_BASE
			) * aggro
		elif action_name == ACTION_SIEGE:
			score += (
				FIX_A_BASE_SCORE
				- CANONICAL_SIEGE_BASE
			) * aggro
		elif action_name == ACTION_WARD:
			score += ward_delta * control

		candidate["score"] = score
