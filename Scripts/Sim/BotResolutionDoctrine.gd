class_name BotResolutionDoctrine
extends RefCounted


const LordMathData = preload(
	"res://Scripts/Sim/LordMath.gd"
)

const ResolutionEngineData = preload(
	"res://Scripts/Sim/ResolutionEngine.gd"
)

const BotDoctrineData = preload(
	"res://Scripts/Sim/BotDoctrine.gd"
)

const BotPolicyData = preload(
	"res://Scripts/Sim/BotPolicy.gd"
)

const BotReflexDoctrineData = preload(
	"res://Scripts/Sim/BotReflexDoctrine.gd"
)


const ACTION_HUNT: String = "Hunt"
const ACTION_SIEGE: String = "Siege"
const ACTION_WARD: String = "Ward"
const ACTION_PROFANE: String = "Profane"


static func build_decisions(
	game,
	rules: RuleConfig,
	commitment_choices: Dictionary = {},
	random_source = null,
	policy = null
) -> Dictionary:
	assert(
		game != null,
		"Bot Resolution doctrine requires a GameState."
	)

	assert(
		rules != null,
		"Bot Resolution doctrine requires RuleConfig."
	)

	var effective_policy = _policy_or_default(
		policy
	)

	var reflex_provider: Callable = Callable(
		BotReflexDoctrineData,
		"build_decisions"
	).bind(
		random_source,
		effective_policy
	)

	var decisions: Dictionary = {
		"actions": action_choices(
			game,
			rules,
			commitment_choices
		),
		"vessels": vessel_choices(
			game,
			rules
		),
		"reflex": {
			"pass": true,
		},
		"odradek_breach": {},
		"reflex_provider": reflex_provider,
		"gremory": {},
		"tie_first_player": int(
			game.first_player
		),
	}

	decisions["gremory"] = (
		_preview_gremory_choices(
			game,
			rules,
			decisions,
			random_source
		)
	)

	# The preview remains useful for inspection, but its payment can be
	# stale after Resolution mutates Gremory's hand. Bot games therefore
	# reevaluate at the exact pre-Cleanup boundary.
	# Static functions have no self in Godot 4.2. Bind the Callable to
	# this cached script resource instead of an unqualified method member.
	decisions["gremory_provider"] = Callable(
		load("res://Scripts/Sim/BotResolutionDoctrine.gd"),
		"current_gremory_choices"
	)

	return decisions


static func action_choices(
	game,
	rules: RuleConfig,
	commitment_choices: Dictionary = {}
) -> Dictionary:
	var decisions: Dictionary = {}

	for player in game.players:
		var player_id: int = int(
			player.pid
		)

		var action_name: String = String(
			player.action
		)

		var options: Dictionary = {}

		if action_name == ACTION_HUNT:
			options["consume_hunt"] = (
				_should_consume(
					game,
					player_id,
					rules
				)
			)

		elif action_name == ACTION_SIEGE:
			var opponent = game.get_opponent(
				player_id
			)

			var requested_target: String = (
				_commitment_target_castle(
					commitment_choices,
					player_id
				)
			)

			var target_castle: String = ""

			if (
				opponent != null
				and opponent.castles.has(
					requested_target
				)
			):
				target_castle = requested_target
			elif opponent != null:
				target_castle = (
					BotDoctrineData
					.pick_siege_target(
						game,
						player_id,
						int(
							opponent.pid
						)
					)
				)

			options = {
				"target_castle": target_castle,
				"consume_siege": (
					rules.consume_the_siege
					and _should_consume(
						game,
						player_id,
						rules
					)
				),
				"use_inferno": true,
			}

		elif action_name == ACTION_PROFANE:
			var requested_profane: String = (
				_commitment_target_castle(
					commitment_choices,
					player_id
				)
			)

			var target_profane: String = ""

			if player.castles.has(
				requested_profane
			):
				target_profane = requested_profane
			else:
				target_profane = (
					_lowest_priority_active_castle(
						player
					)
				)

			options = {
				"target_castle": target_profane,
			}

		decisions[player_id] = options

	return decisions


static func vessel_choices(
	game,
	rules: RuleConfig
) -> Dictionary:
	var decisions: Dictionary = {}

	for player in game.players:
		var player_id: int = int(
			player.pid
		)

		if _should_offer_vessel(
			game,
			player_id,
			rules
		):
			decisions[player_id] = {
				"offer": true,
				"reevaluate_after_action": true,
			}
		else:
			decisions[player_id] = {
				"pass": true,
				"reevaluate_after_action": true,
			}

	return decisions


static func current_gremory_choices(
	game,
	rules: RuleConfig
) -> Dictionary:
	assert(
		game != null,
		"Current Gremory doctrine requires a GameState."
	)

	assert(
		rules != null,
		"Current Gremory doctrine requires RuleConfig."
	)

	var choices: Dictionary = {}

	if int(
		game.winner
	) >= 0:
		return choices

	for player in game.players:
		var player_id: int = int(
			player.pid
		)

		if (
			player.lord != "Gremory"
			or not player.alive
			or player.gremory_inevitable_ruin_done
		):
			continue

		var opponent = game.get_opponent(
			player_id
		)

		if opponent == null:
			continue

		var target_castle: String = String(
			opponent.last_sieged_castle
		)

		if (
			not opponent.was_sieged
			or target_castle.is_empty()
			or not opponent.castles.has(
				target_castle
			)
		):
			continue

		# Inevitable Ruin must retain two cards after payment.
		if (
			player.hand.size()
			+ player.garrison.size()
			< 4
		):
			continue

		# Committed and Reflex cards have already left these zones at
		# this boundary, so no prediction-time exclusions are needed.
		var payment: Array = (
			_select_gremory_payment(
				player,
				[]
			)
		)

		if payment.size() != 2:
			continue

		choices[player_id] = {
			"payment": payment,
		}

	return choices


static func _preview_gremory_choices(
	game,
	rules: RuleConfig,
	base_decisions: Dictionary,
	random_source = null
) -> Dictionary:
	var shadow = game.duplicate_state()

	var preview_decisions: Dictionary = (
		base_decisions.duplicate(
			true
		)
	)

	preview_decisions["gremory"] = {}

	var preview_random_source = null

	if random_source != null:
		assert(
			random_source.has_method(
				"duplicate_state"
			),
			"Gremory preview requires a cloneable deterministic random source."
		)

		preview_random_source = (
			random_source.duplicate_state()
		)

	var preview_result: Dictionary = (
		ResolutionEngineData.resolve(
			shadow,
			rules,
			preview_decisions,
			preview_random_source
		)
	)

	if String(
		preview_result.get(
			"action",
			""
		)
	) == "invalid":
		return {}

	if int(
		preview_result.get(
			"winner",
			-1
		)
	) >= 0:
		return {}

	var excluded_cards: Dictionary = (
		_reflex_card_exclusions(
			game,
			base_decisions
		)
	)

	var choices: Dictionary = {}

	for preview_player in shadow.players:
		var player_id: int = int(
			preview_player.pid
		)

		if (
			preview_player.lord != "Gremory"
			or not preview_player.alive
			or preview_player
				.gremory_inevitable_ruin_done
		):
			continue

		var preview_opponent = (
			shadow.get_opponent(
				player_id
			)
		)

		if preview_opponent == null:
			continue

		var target_castle: String = String(
			preview_opponent.last_sieged_castle
		)

		if (
			not preview_opponent.was_sieged
			or target_castle.is_empty()
			or not preview_opponent.castles.has(
				target_castle
			)
		):
			continue

		# Inevitable Ruin must retain two cards after payment.
		if (
			preview_player.hand.size()
			+ preview_player.garrison.size()
			< 4
		):
			continue

		var original_player = game.get_player(
			player_id
		)

		if original_player == null:
			continue

		var excluded_for_player: Array = (
			_array_for_player(
				excluded_cards,
				player_id
			)
		)

		var payment: Array = (
			_select_gremory_payment(
				original_player,
				excluded_for_player
			)
		)

		if payment.size() != 2:
			continue

		choices[player_id] = {
			"payment": payment,
		}

	return choices


static func _should_offer_vessel(
	game,
	player_id: int,
	rules: RuleConfig
) -> bool:
	var player = game.get_player(
		player_id
	)

	var opponent = game.get_opponent(
		player_id
	)

	if (
		player == null
		or opponent == null
	):
		return false

	if (
		player.vessel_used
		or not player.alive
		or int(
			game.winner
		) >= 0
	):
		return false

	# Vessel gives the opponent one Soul before victory is checked.
	if opponent.souls + 1 >= rules.win_souls:
		return false

	var veil_after: int = (
		game.calculate_veil_total()
		+ 1
	)

	# Final Collapse is checked before Dominion.
	if veil_after >= rules.final_collapse_threshold:
		return false

	if veil_after < rules.dominion_track:
		return false

	var personal_after: int = (
		player.tears + 1
	)

	if personal_after <= opponent.tears:
		return false

	var requirement: int = (
		_dominion_requirement_after_vessel(
			game,
			player_id,
			rules
		)
	)

	return personal_after >= requirement


static func _should_consume(
	game,
	player_id: int,
	rules: RuleConfig
) -> bool:
	var player = game.get_player(
		player_id
	)

	var opponent = game.get_opponent(
		player_id
	)

	if (
		player == null
		or opponent == null
	):
		return false

	var veil_after: int = (
		game.calculate_veil_total()
		+ 1
	)

	# Python still takes Consume when it triggers Final Collapse; the normal
	# win-priority check then selects the actual winner.
	if veil_after < rules.dominion_track:
		return false

	var personal_after: int = (
		player.tears + 1
	)

	if personal_after <= opponent.tears:
		return false

	return personal_after >= (
		_current_dominion_requirement(
			game,
			rules
		)
	)


static func _current_dominion_requirement(
	game,
	rules: RuleConfig
) -> int:
	var player_summaries: Array = []

	for player in game.players:
		player_summaries.append({
			"lord": String(
				player.lord
			),
			"alive": bool(
				player.alive
			),
		})

	return LordMathData.dominion_requirement(
		player_summaries,
		rules
	)


static func _dominion_requirement_after_vessel(
	game,
	vessel_player_id: int,
	rules: RuleConfig
) -> int:
	var player_summaries: Array = []

	for player in game.players:
		player_summaries.append({
			"lord": String(
				player.lord
			),
			"alive": (
				false
				if int(
					player.pid
				) == vessel_player_id
				else bool(
					player.alive
				)
			),
		})

	return LordMathData.dominion_requirement(
		player_summaries,
		rules
	)


static func _select_gremory_payment(
	player,
	excluded_card_ids: Array
) -> Array:
	var exclusion_counts: Dictionary = {}

	for raw_card_id in excluded_card_ids:
		var card_identifier: String = String(
			raw_card_id
		)

		exclusion_counts[card_identifier] = int(
			exclusion_counts.get(
				card_identifier,
				0
			)
		) + 1

	var entries: Array[Dictionary] = []

	for index: int in range(
		player.garrison.size()
	):
		var card = player.garrison[index]

		entries.append({
			"source": "Garrison",
			"card": card,
			"card_id": _card_id(
				card
			),
			"value": int(
				card.value
			),
			"source_rank": 0,
			"index": index,
		})

	for index: int in range(
		player.hand.size()
	):
		var card = player.hand[index]

		entries.append({
			"source": "Hand",
			"card": card,
			"card_id": _card_id(
				card
			),
			"value": int(
				card.value
			),
			"source_rank": 1,
			"index": index,
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
				return value_a < value_b

			var source_rank_a: int = int(
				entry_a.get(
					"source_rank",
					0
				)
			)

			var source_rank_b: int = int(
				entry_b.get(
					"source_rank",
					0
				)
			)

			if source_rank_a != source_rank_b:
				return source_rank_a < source_rank_b

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

	var selected: Array = []

	for entry: Dictionary in entries:
		var card_identifier: String = String(
			entry.get(
				"card_id",
				""
			)
		)

		var exclusion_count: int = int(
			exclusion_counts.get(
				card_identifier,
				0
			)
		)

		if exclusion_count > 0:
			exclusion_counts[card_identifier] = (
				exclusion_count - 1
			)

			continue

		selected.append({
			"source": String(
				entry.get(
					"source",
					""
				)
			),
			"card": card_identifier,
		})

		if selected.size() >= 2:
			break

	return selected


static func _reflex_card_exclusions(
	game,
	decisions: Dictionary
) -> Dictionary:
	var result: Dictionary = {}

	var winner_id: int = int(
		game.reflex_winner
	)

	if winner_id < 0:
		return result

	var winner_decision: Dictionary = (
		_nested_dictionary(
			decisions,
			"reflex"
		)
	)

	_append_player_cards(
		result,
		winner_id,
		winner_decision.get(
			"cards",
			[]
		)
	)

	if game.breach != "Odradek":
		return result

	var breach_owner_id: int = int(
		game.breach_owner
	)

	if (
		breach_owner_id < 0
		or breach_owner_id == winner_id
	):
		return result

	var breach_decision: Dictionary = (
		_nested_dictionary(
			decisions,
			"odradek_breach"
		)
	)

	var guessed_action: String = _canonical_action(
		String(
			breach_decision.get(
				"guess",
				""
			)
		)
	)

	var requested_action: String = _canonical_action(
		String(
			winner_decision.get(
				"action",
				"Pass"
			)
		)
	)

	if guessed_action != requested_action:
		return result

	var stolen_action: Dictionary = (
		_nested_dictionary(
			breach_decision,
			"stolen_action"
		)
	)

	_append_player_cards(
		result,
		breach_owner_id,
		stolen_action.get(
			"cards",
			[]
		)
	)

	return result


static func _append_player_cards(
	target: Dictionary,
	player_id: int,
	raw_cards
) -> void:
	if typeof(
		raw_cards
	) != TYPE_ARRAY:
		return

	var cards: Array = _array_for_player(
		target,
		player_id
	)

	for raw_card in raw_cards:
		cards.append(
			String(
				raw_card
			)
		)

	target[player_id] = cards


static func _array_for_player(
	source: Dictionary,
	player_id: int
) -> Array:
	var raw_value = source.get(
		player_id,
		null
	)

	if raw_value == null:
		raw_value = source.get(
			str(
				player_id
			),
			[]
		)

	if typeof(
		raw_value
	) != TYPE_ARRAY:
		return []

	return raw_value.duplicate()


static func _commitment_target_castle(
	commitment_choices: Dictionary,
	player_id: int
) -> String:
	var decision: Dictionary = (
		_decision_for_player(
			commitment_choices,
			player_id
		)
	)

	return String(
		decision.get(
			"target_castle",
			""
		)
	)


static func _lowest_priority_active_castle(
	player
) -> String:
	var raw_priority = (
		BotDoctrineData.CASTLE_PRIORITIES.get(
			String(
				player.lord
			),
			BotDoctrineData.DEFAULT_CASTLE_PRIORITY
		)
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


static func _canonical_action(
	raw_action: String
) -> String:
	var normalized: String = (
		raw_action.strip_edges().to_lower()
	)

	if normalized == "hunt":
		return ACTION_HUNT

	if normalized == "siege":
		return ACTION_SIEGE

	if normalized == "ward":
		return ACTION_WARD

	if normalized == "profane":
		return ACTION_PROFANE

	return "Pass"


static func _decision_for_player(
	decisions: Dictionary,
	player_id: int
) -> Dictionary:
	var raw_decision = decisions.get(
		player_id,
		null
	)

	if raw_decision == null:
		raw_decision = decisions.get(
			str(
				player_id
			),
			{}
		)

	if typeof(
		raw_decision
	) != TYPE_DICTIONARY:
		return {}

	return raw_decision


static func _nested_dictionary(
	source: Dictionary,
	key: String
) -> Dictionary:
	var raw_value = source.get(
		key,
		{}
	)

	if typeof(
		raw_value
	) != TYPE_DICTIONARY:
		return {}

	return raw_value


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


static func _policy_or_default(
	policy
):
	if policy == null:
		return BotPolicyData.golden_core()

	return policy
