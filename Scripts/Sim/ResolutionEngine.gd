class_name ResolutionEngine
extends RefCounted


const ResolutionPreludeEngineData = preload(
	"res://Scripts/Sim/ResolutionPreludeEngine.gd"
)

const HuntResolutionEngineData = preload(
	"res://Scripts/Sim/HuntResolutionEngine.gd"
)

const SiegeResolutionEngineData = preload(
	"res://Scripts/Sim/SiegeResolutionEngine.gd"
)

const ProfaneResolutionEngineData = preload(
	"res://Scripts/Sim/ProfaneResolutionEngine.gd"
)

const ResolutionActionAftermathEngineData = preload(
	"res://Scripts/Sim/ResolutionActionAftermathEngine.gd"
)

const ReflexActionEngineData = preload(
	"res://Scripts/Sim/ReflexActionEngine.gd"
)

const ResolutionFinaleEngineData = preload(
	"res://Scripts/Sim/ResolutionFinaleEngine.gd"
)

const ResolutionCleanupEngineData = preload(
	"res://Scripts/Sim/ResolutionCleanupEngine.gd"
)


const ACTION_HUNT: String = "Hunt"
const ACTION_SIEGE: String = "Siege"
const ACTION_WARD: String = "Ward"
const ACTION_PROFANE: String = "Profane"

const ZONE_LORD: String = "Lord"
const ZONE_CASTLE: String = "Castle"


static func resolve(
	game,
	rules: RuleConfig,
	decisions: Dictionary = {}
) -> Dictionary:
	assert(
		game != null,
		"Resolution requires a GameState."
	)

	assert(
		rules != null,
		"Resolution requires RuleConfig."
	)

	assert(
		game.players.size() == 2,
		"Resolution currently requires two players."
	)

	if int(
		game.winner
	) >= 0:
		return _finish_result(
			game,
			{},
			[],
			{},
			{},
			{},
			"before_resolution"
		)

	var action_choices: Dictionary = (
		_nested_dictionary(
			decisions,
			"actions"
		)
	)

	var vessel_choices: Dictionary = (
		_nested_dictionary(
			decisions,
			"vessels"
		)
	)

	var reflex_decision: Dictionary = (
		_nested_dictionary(
			decisions,
			"reflex"
		)
	)

	var odradek_breach_decision: Dictionary = (
		_nested_dictionary(
			decisions,
			"odradek_breach"
		)
	)

	var gremory_choices: Dictionary = (
		_nested_dictionary(
			decisions,
			"gremory"
		)
	)

	var tie_first_player: int = int(
		decisions.get(
			"tie_first_player",
			-1
		)
	)

	var prelude_result: Dictionary = (
		ResolutionPreludeEngineData.resolve(
			game,
			rules,
			tie_first_player
		)
	)

	if String(
		prelude_result.get(
			"action",
			""
		)
	) == "invalid":
		return _invalid_result(
			game,
			"prelude",
			String(
				prelude_result.get(
					"reason",
					"invalid_resolution_prelude"
				)
			),
			prelude_result,
			[],
			{},
			{},
			{}
		)

	var raw_order = prelude_result.get(
		"order",
		[]
	)

	if typeof(
		raw_order
	) != TYPE_ARRAY:
		return _invalid_result(
			game,
			"prelude",
			"resolution_order_not_array",
			prelude_result,
			[],
			{},
			{},
			{}
		)

	var order: Array = raw_order

	if order.size() != game.players.size():
		return _invalid_result(
			game,
			"prelude",
			"resolution_order_wrong_size",
			prelude_result,
			[],
			{},
			{},
			{}
		)

	var action_events: Array[Dictionary] = []

	for raw_player_id in order:
		var player_id: int = int(
			raw_player_id
		)

		var player = game.get_player(
			player_id
		)

		if player == null:
			return _invalid_result(
				game,
				"actions",
				"resolution_player_missing_%d"
				% player_id,
				prelude_result,
				action_events,
				{},
				{},
				{}
			)

		var committed_action: String = String(
			player.action
		)

		var action_options: Dictionary = (
			_decision_for_player(
				action_choices,
				player_id
			)
		)

		var action_result: Dictionary = (
			_resolve_committed_action(
				game,
				rules,
				player,
				action_options
			)
		)

		if String(
			action_result.get(
				"action",
				""
			)
		) == "invalid":
			return _invalid_result(
				game,
				"actions",
				String(
					action_result.get(
						"reason",
						"invalid_committed_action"
					)
				),
				prelude_result,
				action_events,
				{},
				{},
				{}
			)

		var vessel_decision: Dictionary = (
			_decision_for_player(
				vessel_choices,
				player_id
			)
		)

		var aftermath_result: Dictionary = (
			ResolutionActionAftermathEngineData.resolve(
				game,
				rules,
				player_id,
				action_result,
				vessel_decision
			)
		)

		action_events.append({
			"player_id": player_id,
			"committed_action": committed_action,
			"action_result": action_result,
			"aftermath_result": aftermath_result,
		})

		if String(
			aftermath_result.get(
				"action",
				""
			)
		) == "invalid":
			return _invalid_result(
				game,
				"aftermath",
				String(
					aftermath_result.get(
						"reason",
						"invalid_action_aftermath"
					)
				),
				prelude_result,
				action_events,
				{},
				{},
				{}
			)

		if (
			int(
				game.winner
			) >= 0
			or bool(
				aftermath_result.get(
					"stopped_on_win",
					false
				)
			)
		):
			return _finish_result(
				game,
				prelude_result,
				action_events,
				{},
				{},
				{},
				"actions"
			)

	var reflex_result: Dictionary = (
		ReflexActionEngineData.resolve(
			game,
			rules,
			reflex_decision,
			odradek_breach_decision
		)
	)

	if String(
		reflex_result.get(
			"action",
			""
		)
	) == "invalid":
		return _invalid_result(
			game,
			"reflex",
			String(
				reflex_result.get(
					"reason",
					"invalid_reflex_action"
				)
			),
			prelude_result,
			action_events,
			reflex_result,
			{},
			{}
		)

	if int(
		game.winner
	) >= 0:
		return _finish_result(
			game,
			prelude_result,
			action_events,
			reflex_result,
			{},
			{},
			"reflex"
		)

	var finale_result: Dictionary = (
		ResolutionFinaleEngineData.resolve(
			game,
			rules
		)
	)

	if bool(
		finale_result.get(
			"stopped_on_win",
			false
		)
	):
		return _finish_result(
			game,
			prelude_result,
			action_events,
			reflex_result,
			finale_result,
			{},
			"finale"
		)

	var cleanup_result: Dictionary = (
		ResolutionCleanupEngineData.resolve(
			game,
			rules,
			gremory_choices
		)
	)

	var stopped_stage: String = ""

	if bool(
		cleanup_result.get(
			"stopped_on_win",
			false
		)
	):
		stopped_stage = "cleanup"

	game.refresh_derived_values()

	return _finish_result(
		game,
		prelude_result,
		action_events,
		reflex_result,
		finale_result,
		cleanup_result,
		stopped_stage
	)


static func _resolve_committed_action(
	game,
	rules: RuleConfig,
	player,
	options: Dictionary
) -> Dictionary:
	var player_id: int = int(
		player.pid
	)

	var action: String = String(
		player.action
	)

	if action == ACTION_HUNT:
		return HuntResolutionEngineData.resolve(
			game,
			rules,
			player_id,
			options
		)

	if action == ACTION_SIEGE:
		return SiegeResolutionEngineData.resolve(
			game,
			rules,
			player_id,
			options
		)

	if action == ACTION_PROFANE:
		return ProfaneResolutionEngineData.resolve(
			game,
			rules,
			player_id,
			options
		)

	if action == ACTION_WARD:
		var ward_target: String = String(
			player.ward_target
		)

		if not [
			ZONE_LORD,
			ZONE_CASTLE,
		].has(
			ward_target
		):
			return {
				"action": "invalid",
				"reason": "ward_target_invalid",
				"player_id": player_id,
				"won": false,
			}

		return {
			"action": "ward",
			"reason": "",
			"player_id": player_id,
			"ward_target": ward_target,
			"sigil_state": String(
				player.sigils.get(
					ward_target,
					""
				)
			),
			"guards_defeated": [],
			"destroyed": false,
			"won": false,
		}

	if action.is_empty():
		return {
			"action": "pass",
			"reason": "no_committed_action",
			"player_id": player_id,
			"guards_defeated": [],
			"destroyed": false,
			"won": false,
		}

	return {
		"action": "invalid",
		"reason": (
			"unknown_committed_action_%s"
			% action
		),
		"player_id": player_id,
		"won": false,
	}


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


static func _finish_result(
	game,
	prelude_result: Dictionary,
	action_events: Array[Dictionary],
	reflex_result: Dictionary,
	finale_result: Dictionary,
	cleanup_result: Dictionary,
	stopped_stage: String
) -> Dictionary:
	return {
		"action": "resolution",
		"reason": "",
		"prelude_result": prelude_result,
		"action_events": action_events,
		"reflex_result": reflex_result,
		"finale_result": finale_result,
		"cleanup_result": cleanup_result,
		"stopped_stage": stopped_stage,
		"winner": int(
			game.winner
		),
		"win_by": String(
			game.win_by
		),
		"veil_total": int(
			game.calculate_veil_total()
		),
	}


static func _invalid_result(
	game,
	stage: String,
	reason: String,
	prelude_result: Dictionary,
	action_events: Array[Dictionary],
	reflex_result: Dictionary,
	finale_result: Dictionary,
	cleanup_result: Dictionary
) -> Dictionary:
	return {
		"action": "invalid",
		"reason": reason,
		"invalid_stage": stage,
		"prelude_result": prelude_result,
		"action_events": action_events,
		"reflex_result": reflex_result,
		"finale_result": finale_result,
		"cleanup_result": cleanup_result,
		"stopped_stage": "",
		"winner": int(
			game.winner
		),
		"win_by": String(
			game.win_by
		),
		"veil_total": int(
			game.calculate_veil_total()
		),
	}
