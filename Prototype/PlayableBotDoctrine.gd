class_name PlayableBotDoctrine
extends RefCounted


const BotDoctrineData = preload(
	"res://Scripts/Sim/BotDoctrine.gd"
)


static func commitment_choices(
	game,
	random_source,
	rules: RuleConfig,
	policy = null
) -> Dictionary:
	assert(
		game != null,
		"Playable bot doctrine requires a GameState."
	)
	assert(
		rules != null,
		"Playable bot doctrine requires RuleConfig."
	)

	var effective_policy = BotDoctrineData._policy_or_default(policy)
	var decisions: Dictionary = {}
	for player in game.players:
		var player_id: int = int(player.pid)
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
		"Playable bot doctrine requires a GameState."
	)
	assert(
		rules != null,
		"Playable bot doctrine requires RuleConfig."
	)

	# Profile behavior, including FIX A, belongs to the shared doctrine. Keeping
	# this wrapper thin prevents the human-vs-bot scene from scoring choices twice.
	return BotDoctrineData.commitment_choice(
		game,
		player_id,
		random_source,
		rules,
		policy
	)
