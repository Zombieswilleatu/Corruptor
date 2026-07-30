extends "res://Scripts/Sim/BalanceSimulationRunner.gd"


# This file is a disposable overlay. Canonical simulation scripts never
# preload or reference it. Delete Experiments/BalanceLab and the normal game,
# golden tests, parity soak, and canonical balance runner remain unchanged.

const EXPERIMENTAL_RULE_OVERRIDES: Dictionary = {
	# Stage temporary tuning changes here.
	#
	# Examples:
	# "win_souls": 8,
	# "dominion_requirement": 3,
	# "final_collapse_threshold": 16,
	# "invocation_gate": 6,
	# "kroni_hunger_decay": false,
}

const EXPERIMENT_REPORT_DIRECTORY: String = (
	"user://balance_reports/experiments"
)

const ExperimentalSeededGameSetupData = preload(
	"res://Experiments/BalanceLab/Runtime/ExperimentalSeededGameSetup.gd"
)

const ExperimentalBotRoundEngineData = preload(
	"res://Experiments/BalanceLab/Runtime/ExperimentalBotRoundEngine.gd"
)

const ExperimentalBotPolicyData = preload(
	"res://Scripts/Sim/BotPolicy.gd"
)

const ExperimentalBotGameEngineData = preload(
	"res://Scripts/Sim/BotGameEngine.gd"
)

const ExperimentalResolutionFinaleEngineData = preload(
	"res://Scripts/Sim/ResolutionFinaleEngine.gd"
)

const ALLOWED_RULE_OVERRIDES: Array[String] = [
	"win_souls",
	"dominion_track",
	"dominion_requirement",
	"final_collapse_threshold",
	"hand_limit",
	"garrison_max",
	"max_threat",
	"market_size",
	"recoil_hunts_only",
	"sigil_soul_fresh_only",
	"invocation_gate",
	"profane_ruins_req",
	"ai_dominion_drive",
	"no_backwash",
	"reconfig_strict",
	"kroni_def_soft",
	"kroni_hunger_decay",
	"deimos_war_machine_free",
	"deimos_summon_cost",
	"recoil_lowest",
	"neutral_tear_on_banish",
	"castle_tear_uncapped",
	"veil_drift",
	"invocation_repeatable",
	"reconfig_tokens_needed",
	"reconfig_neutral",
	"deimos_claims_breach",
	"consume_the_siege",
	"war_machine_ignores_profaned",
	"gremory_summon_cost",
	"humbaba_seal",
	"humbaba_toll",
	"humbaba_gate4",
	"humbaba_patient",
]


@export_category("Experiment Identity")
@export var experiment_name: String = "Untitled balance experiment"

@export_category("Documented Structural Testbed")
@export_enum(
	"Canonical roster",
	"Vanilla mirror"
) var testbed: String = "Vanilla mirror"
@export var enable_fix_a_doctrine: bool = false
@export var enable_fix_b_profane: bool = false

@export_category("Mixed Strategy")
@export var use_custom_softmax: bool = false
@export_range(0.0, 5.0, 0.01) var softmax_temperature: float = 0.70
@export_range(0.0, 1.0, 0.01) var softmax_error_rate: float = 0.0

@export_category("Pure Strategy Seats")
@export_enum(
	"Doctrine",
	"Hunt",
	"Siege",
	"Ward",
	"Profane"
) var forced_action_seat_0: String = "Doctrine"
@export_enum(
	"Doctrine",
	"Hunt",
	"Siege",
	"Ward",
	"Profane"
) var forced_action_seat_1: String = "Doctrine"

@export_category("Temporary Rule Overrides")
@export var inspector_rule_overrides: Dictionary = {}


func _configuration_failure() -> String:
	if games_per_ordered_matchup <= 0:
		return "games_per_ordered_matchup must be positive."

	if progress_every_games <= 0:
		return "progress_every_games must be positive."

	if yield_every_games <= 0:
		return "yield_every_games must be positive."

	var active_lords: Array[String] = _selected_lords()

	if (
		testbed == "Vanilla mirror"
		and not include_mirror_matchups
	):
		return (
			"Vanilla mirror requires include_mirror_matchups=true."
		)

	if (
		testbed != "Vanilla mirror"
		and active_lords.size() < 2
	):
		return "Select at least two valid Lords."

	if experiment_name.strip_edges().is_empty():
		return "experiment_name cannot be empty."

	var rules: RuleConfig = RuleConfig.de_v2()
	var overrides: Dictionary = _combined_rule_overrides()

	for property_raw in overrides.keys():
		var property_name: String = String(
			property_raw
		)

		if property_name == "max_rounds":
			return (
				"Use the inherited max_rounds_override field instead of "
				+ "overriding RuleConfig.max_rounds."
			)

		if not ALLOWED_RULE_OVERRIDES.has(
			property_name
		):
			return (
				"Unknown experimental RuleConfig property: %s"
				% property_name
			)

		var core_value = rules.get(
			property_name
		)
		var experimental_value = overrides.get(
			property_raw
		)

		if typeof(
			core_value
		) != typeof(
			experimental_value
		):
			return (
				"Experimental override %s has type %s; core type is %s."
				% [
					property_name,
					type_string(
						typeof(
							experimental_value
						)
					),
					type_string(
						typeof(
							core_value
						)
					),
				]
			)

	return ""


func _selected_lords() -> Array[String]:
	if testbed == "Vanilla mirror":
		return [
			"Vanilla",
		]

	return super._selected_lords()


func _policy():
	if use_custom_softmax:
		return ExperimentalBotPolicyData.new(
			"balance-lab-softmax-t%.2f-e%.2f"
			% [
				softmax_temperature,
				softmax_error_rate,
			],
			softmax_temperature,
			softmax_error_rate
		)

	return super._policy()


func _uses_experimental_runtime() -> bool:
	return (
		testbed == "Vanilla mirror"
		or enable_fix_a_doctrine
		or enable_fix_b_profane
		or forced_action_seat_0 != "Doctrine"
		or forced_action_seat_1 != "Doctrine"
	)


func _play_game(
	player_zero_lord: String,
	player_one_lord: String,
	game_seed: int,
	matchup_game_index: int,
	rules: RuleConfig,
	policy,
	maximum_rounds: int
) -> Dictionary:
	if not _uses_experimental_runtime():
		return super._play_game(
			player_zero_lord,
			player_one_lord,
			game_seed,
			matchup_game_index,
			rules,
			policy,
			maximum_rounds
		)

	var setup: Dictionary = (
		ExperimentalSeededGameSetupData.setup_locked_game(
			player_zero_lord,
			player_one_lord,
			game_seed,
			rules
		)
	)
	var game = setup.get(
		"game"
	)
	var random_source = setup.get(
		"rng"
	)

	if (
		game == null
		or random_source == null
	):
		return _failed_game(
			player_zero_lord,
			player_one_lord,
			game_seed,
			0,
			"setup",
			"Experimental seeded setup returned no game or RNG."
		)

	game.set_meta(
		"balance_lab_fix_a",
		enable_fix_a_doctrine
	)
	game.set_meta(
		"balance_lab_fix_b",
		enable_fix_b_profane
	)
	_set_forced_action_meta(
		game,
		0,
		forced_action_seat_0
	)
	_set_forced_action_meta(
		game,
		1,
		forced_action_seat_1
	)

	var round_history: Array[Dictionary] = []
	var action_outcomes: Array[Dictionary] = []
	var action_counts: Dictionary = _zero_counts(
		ACTIONS
	)
	var actions_by_player: Array[Dictionary] = [
		_zero_counts(
			ACTIONS
		),
		_zero_counts(
			ACTIONS
		),
	]
	var ability_counts: Dictionary = _zero_counts(
		ABILITY_EVENTS
	)
	var previous_alive: Array[bool] = [
		bool(
			game.players[0].alive
		),
		bool(
			game.players[1].alive
		),
	]
	var previous_castle_counts: Array[int] = [
		game.players[0].castles.size(),
		game.players[1].castles.size(),
	]
	var previous_breach: String = String(
		game.breach
	)
	var previous_persistent_flags: Array[Dictionary] = [
		_persistent_flags(
			game.players[0]
		),
		_persistent_flags(
			game.players[1]
		),
	]

	while (
		int(
			game.winner
		) < 0
		and int(
			game.round
		) < maximum_rounds
	):
		var next_round: int = int(
			game.round
		) + 1
		var round_result: Dictionary = (
			ExperimentalBotRoundEngineData.resolve_round(
				game,
				rules,
				random_source,
				next_round,
				policy
			)
		)

		if String(
			round_result.get(
				"action",
				""
			)
		) == "invalid":
			return _failed_game(
				player_zero_lord,
				player_one_lord,
				game_seed,
				next_round,
				String(
					round_result.get(
						"stopped_phase",
						"round"
					)
				),
				String(
					round_result.get(
						"reason",
						"invalid_round"
					)
				)
			)

		if int(
			game.round
		) != next_round:
			return _failed_game(
				player_zero_lord,
				player_one_lord,
				game_seed,
				next_round,
				"round",
				"Experimental round engine did not advance."
			)

		_record_round_activity(
			game,
			action_counts,
			actions_by_player,
			ability_counts,
			previous_alive,
			previous_castle_counts,
			previous_persistent_flags,
			previous_breach
		)
		_append_action_outcomes(
			action_outcomes,
			round_result,
			next_round
		)

		previous_breach = String(
			game.breach
		)

		round_history.append(
			_round_snapshot(
				game
			)
		)

		if int(
			game.winner
		) < 0:
			ExperimentalResolutionFinaleEngineData.check_win(
				game,
				rules
			)

	var timeout_result: Dictionary = {}

	if int(
		game.winner
	) < 0:
		var game_result: Dictionary = (
			ExperimentalBotGameEngineData.resolve_game(
				game,
				rules,
				random_source,
				policy,
				int(
					game.round
				)
			)
		)

		if String(
			game_result.get(
				"action",
				""
			)
		) == "invalid":
			return _failed_game(
				player_zero_lord,
				player_one_lord,
				game_seed,
				int(
					game.round
				),
				String(
					game_result.get(
						"stopped_phase",
						"timeout"
					)
				),
				String(
					game_result.get(
						"reason",
						"invalid_timeout"
					)
				)
			)

		timeout_result = _dictionary(
			game_result.get(
				"timeout",
				{}
			)
		)

	if int(
		game.winner
	) < 0:
		return _failed_game(
			player_zero_lord,
			player_one_lord,
			game_seed,
			int(
				game.round
			),
			"terminal",
			"Experimental game finished without a winner."
		)

	var winner_id: int = int(
		game.winner
	)
	var loser_id: int = (
		1
		if winner_id == 0
		else 0
	)
	var soul_margin: int = absi(
		int(
			game.players[0].souls
		)
		- int(
			game.players[1].souls
		)
	)
	var tension: Dictionary = _tension_metrics(
		round_history,
		winner_id,
		soul_margin
	)
	var players: Array[Dictionary] = []

	for player in game.players:
		players.append(
			{
				"pid": int(
					player.pid
				),
				"lord": String(
					player.lord
				),
				"alive": bool(
					player.alive
				),
				"souls": int(
					player.souls
				),
				"tears": int(
					player.tears
				),
				"threat": int(
					player.threat
				),
				"castles": player.castles.size(),
				"ruined_castles": (
					player.ruined_castles.size()
				),
				"profaned_castles": (
					player.profaned_castles.size()
				),
			}
		)

	return {
		"ok": true,
		"experimental_runtime": true,
		"seed": game_seed,
		"matchup_game_index": matchup_game_index,
		"lord0": player_zero_lord,
		"lord1": player_one_lord,
		"first_player": int(
			game.first_player
		),
		"winner": winner_id,
		"winner_lord": String(
			game.players[winner_id].lord
		),
		"loser_lord": String(
			game.players[loser_id].lord
		),
		"win_by": String(
			game.win_by
		),
		"rounds": int(
			game.round
		),
		"veil_total": int(
			game.calculate_veil_total()
		),
		"neutral_tears": int(
			game.neutral_tears
		),
		"breach": String(
			game.breach
		),
		"breach_owner": int(
			game.breach_owner
		),
		"soul_margin": soul_margin,
		"close": bool(
			tension.get(
				"close",
				false
			)
		),
		"comeback": bool(
			tension.get(
				"comeback",
				false
			)
		),
		"lead_changes": int(
			tension.get(
				"lead_changes",
				0
			)
		),
		"round_history": (
			round_history
			if include_round_history_in_json
			else []
		),
		"players": players,
		"actions": action_counts,
		"actions_by_player": actions_by_player,
		"ability_events": ability_counts,
		"action_outcomes": action_outcomes,
		"timeout": timeout_result,
	}


func _set_forced_action_meta(
	game,
	player_id: int,
	action_name: String
) -> void:
	if action_name == "Doctrine":
		return

	game.set_meta(
		"balance_lab_forced_action_%d" % player_id,
		action_name
	)


func _append_action_outcomes(
	output: Array[Dictionary],
	round_result: Dictionary,
	round_number: int
) -> void:
	var phases: Dictionary = _dictionary(
		round_result.get(
			"phases",
			{}
		)
	)
	var resolution_phase: Dictionary = _dictionary(
		phases.get(
			"resolution",
			{}
		)
	)
	var resolution_result: Dictionary = _dictionary(
		resolution_phase.get(
			"result",
			{}
		)
	)
	var events_raw = resolution_result.get(
		"action_events",
		[]
	)

	if typeof(
		events_raw
	) != TYPE_ARRAY:
		return

	for event_raw in events_raw:
		if typeof(
			event_raw
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = event_raw
		var action_result: Dictionary = _dictionary(
			event.get(
				"action_result",
				{}
			)
		)
		var action_name: String = String(
			event.get(
				"committed_action",
				action_result.get(
					"action",
					""
				)
			)
		)

		output.append({
			"round": round_number,
			"player_id": int(
				event.get(
					"player_id",
					-1
				)
			),
			"action": action_name,
			"reason": String(
				action_result.get(
					"reason",
					""
				)
			),
			"destroyed": bool(
				action_result.get(
					"destroyed",
					false
				)
			),
			"blocked": bool(
				action_result.get(
					"blocked",
					false
				)
			),
			"profaned": bool(
				action_result.get(
					"profaned",
					false
				)
			),
			"target_reevaluated": bool(
				action_result.get(
					"target_reevaluated",
					false
				)
			),
			"strength": int(
				action_result.get(
					"strength",
					0
				)
			),
			"defense": int(
				action_result.get(
					"lord_defense",
					action_result.get(
						"structural_defense",
						0
					)
				)
			),
			"excess": int(
				action_result.get(
					"excess",
					0
				)
			),
			"failure_gap": int(
				action_result.get(
					"failure_gap",
					-1
				)
			),
			"stopped_at": String(
				action_result.get(
					"stopped_at",
					""
				)
			),
		})


func _new_stats(
	active_lords: Array[String],
	total_games: int,
	maximum_rounds: int,
	rules: RuleConfig,
	policy_id: String
) -> Dictionary:
	var overrides: Dictionary = _combined_rule_overrides()

	for property_raw in overrides.keys():
		var property_name: String = String(
			property_raw
		)

		rules.set(
			property_name,
			overrides.get(
				property_raw
			)
		)

	var stats: Dictionary = super._new_stats(
		active_lords,
		total_games,
		maximum_rounds,
		rules,
		policy_id
	)

	stats["experimental"] = true
	stats["experiment_name"] = experiment_name
	stats["experimental_features"] = {
		"testbed": testbed,
		"vanilla_lord": testbed == "Vanilla mirror",
		"fix_a_doctrine": enable_fix_a_doctrine,
		"fix_b_profane_denial_removed": (
			enable_fix_b_profane
		),
		"custom_softmax": use_custom_softmax,
		"softmax_temperature": (
			_effective_policy_temperature()
		),
		"softmax_error_rate": (
			_effective_policy_error_rate()
		),
		"forced_action_seat_0": (
			forced_action_seat_0
		),
		"forced_action_seat_1": (
			forced_action_seat_1
		),
		"isolated_runtime": _uses_experimental_runtime(),
	}
	stats["experimental_rule_overrides"] = (
		overrides.duplicate(
			true
		)
	)
	stats["experimental_action_outcomes"] = {
		"Hunt": _empty_outcome_totals(),
		"Siege": _empty_outcome_totals(),
		"Ward": _empty_outcome_totals(),
		"Profane": _empty_outcome_totals(),
	}

	return stats


func _effective_policy_temperature() -> float:
	if use_custom_softmax:
		return softmax_temperature

	if policy_profile == "Competitive":
		return 0.35

	if policy_profile == "Standard":
		return 0.70

	if policy_profile == "Easy":
		return 1.25

	return 0.0


func _effective_policy_error_rate() -> float:
	if use_custom_softmax:
		return softmax_error_rate

	if policy_profile == "Easy":
		return 0.12

	return 0.0


func _record_game(
	stats: Dictionary,
	record: Dictionary
) -> void:
	super._record_game(
		stats,
		record
	)

	var totals_by_action: Dictionary = _dictionary(
		stats.get(
			"experimental_action_outcomes",
			{}
		)
	)
	var outcomes_raw = record.get(
		"action_outcomes",
		[]
	)

	if typeof(
		outcomes_raw
	) != TYPE_ARRAY:
		return

	for outcome_raw in outcomes_raw:
		if typeof(
			outcome_raw
		) != TYPE_DICTIONARY:
			continue

		var outcome: Dictionary = outcome_raw
		var action_name: String = String(
			outcome.get(
				"action",
				""
			)
		)

		if not totals_by_action.has(
			action_name
		):
			continue

		var totals: Dictionary = _dictionary(
			totals_by_action.get(
				action_name,
				{}
			)
		)
		totals["attempts"] = int(
			totals.get(
				"attempts",
				0
			)
		) + 1

		var succeeded: bool = bool(
			outcome.get(
				"destroyed",
				false
			)
		) or bool(
			outcome.get(
				"profaned",
				false
			)
		) or (
			action_name == "Ward"
			and String(
				outcome.get(
					"reason",
					""
				)
			).is_empty()
		)

		if succeeded:
			totals["successes"] = int(
				totals.get(
					"successes",
					0
				)
			) + 1
		else:
			totals["failures"] = int(
				totals.get(
					"failures",
					0
				)
			) + 1

		if bool(
			outcome.get(
				"blocked",
				false
			)
		):
			totals["blocked"] = int(
				totals.get(
					"blocked",
					0
				)
			) + 1

		if bool(
			outcome.get(
				"target_reevaluated",
				false
			)
		):
			totals["target_reevaluations"] = int(
				totals.get(
					"target_reevaluations",
					0
				)
			) + 1

		var failure_gap: int = int(
			outcome.get(
				"failure_gap",
				-1
			)
		)

		if (
			not succeeded
			and
			failure_gap >= 0
			and failure_gap <= 1
		):
			totals["near_misses"] = int(
				totals.get(
					"near_misses",
					0
				)
			) + 1

		if succeeded:
			totals["excess_total"] = int(
				totals.get(
					"excess_total",
					0
				)
			) + int(
				outcome.get(
					"excess",
					0
				)
			)

		totals_by_action[action_name] = totals

	stats["experimental_action_outcomes"] = (
		totals_by_action
	)


func _empty_outcome_totals() -> Dictionary:
	return {
		"attempts": 0,
		"successes": 0,
		"failures": 0,
		"blocked": 0,
		"near_misses": 0,
		"excess_total": 0,
		"target_reevaluations": 0,
	}


func _format_report(
	stats: Dictionary
) -> String:
	var overrides: Dictionary = _dictionary(
		stats.get(
			"experimental_rule_overrides",
			{}
		)
	)
	var experimental_header: Array[String] = [
		"EXPERIMENTAL BALANCE LAB — NOT CANONICAL",
		"Experiment: %s"
		% String(
			stats.get(
				"experiment_name",
				experiment_name
			)
		),
		"Rule overrides: %s"
		% (
			str(
				overrides
			)
			if not overrides.is_empty()
			else "none (control run)"
		),
		"Testbed: %s" % testbed,
		"FIX A doctrine: %s"
		% str(
			enable_fix_a_doctrine
		),
		"FIX B Profane denial removed: %s"
		% str(
			enable_fix_b_profane
		),
		"Policy temperature/error: %.2f / %.2f"
		% [
			float(
				stats.get(
					"experimental_features",
					{}
				).get(
					"softmax_temperature",
					0.0
				)
			),
			float(
				stats.get(
					"experimental_features",
					{}
				).get(
					"softmax_error_rate",
					0.0
				)
			),
		],
		"Forced actions seat 0 / seat 1: %s / %s"
		% [
			forced_action_seat_0,
			forced_action_seat_1,
		],
		"Execution path: %s"
		% (
			"isolated experimental runtime"
			if _uses_experimental_runtime()
			else "canonical control"
		),
		"Canonical files modified: no",
		"",
	]

	var result: String = (
		"\n".join(
			experimental_header
		)
		+ super._format_report(
			stats
		)
	)
	var totals_by_action: Dictionary = _dictionary(
		stats.get(
			"experimental_action_outcomes",
			{}
		)
	)

	if not totals_by_action.is_empty():
		var lines: Array[String] = [
			"",
			"EXPERIMENTAL ACTION OUTCOMES",
			"----------------------------------------",
			(
				"%s %s %s %s %s %s %s"
				% [
					"Action".rpad(10),
					"Attempts".lpad(9),
					"Success".lpad(9),
					"Blocked".lpad(9),
					"Retarget".lpad(9),
					"Near<=1".lpad(9),
					"AvgExcess".lpad(10),
				]
			),
		]

		for action_name: String in [
			"Hunt",
			"Siege",
			"Ward",
			"Profane",
		]:
			var totals: Dictionary = _dictionary(
				totals_by_action.get(
					action_name,
					{}
				)
			)
			var attempts: int = int(
				totals.get(
					"attempts",
					0
				)
			)
			var successes: int = int(
				totals.get(
					"successes",
					0
				)
			)

			lines.append(
				"%s %s %s %s %s %s %s"
				% [
					action_name.rpad(
						10
					),
					str(
						attempts
					).lpad(
						9
					),
					(
						"%.1f%%"
						% (
							100.0
							* float(
								successes
							)
							/ float(
								maxi(
									1,
									attempts
								)
							)
						)
					).lpad(
						9
					),
					str(
						totals.get(
							"blocked",
							0
						)
					).lpad(
						9
					),
					str(
						totals.get(
							"target_reevaluations",
							0
						)
					).lpad(
						9
					),
					str(
						totals.get(
							"near_misses",
							0
						)
					).lpad(
						9
					),
					(
						"%.2f"
						% (
							float(
								totals.get(
									"excess_total",
									0
								)
							)
							/ float(
								maxi(
									1,
									successes
								)
							)
						)
					).lpad(
						10
					),
				]
			)

		result += "\n" + "\n".join(
			lines
		)

	return result


func _write_reports(
	stats: Dictionary,
	report_text: String
) -> Dictionary:
	var absolute_directory: String = (
		ProjectSettings.globalize_path(
			EXPERIMENT_REPORT_DIRECTORY
		)
	)
	var directory_error: Error = (
		DirAccess.make_dir_recursive_absolute(
			absolute_directory
		)
	)

	if directory_error != OK:
		push_error(
			"Unable to create experimental report directory: %s"
			% error_string(
				directory_error
			)
		)
		return {}

	var timestamp: String = (
		Time.get_datetime_string_from_system()
		.replace(
			"-",
			""
		)
		.replace(
			":",
			""
		)
		.replace(
			"T",
			"_"
		)
	)
	var stem: String = (
		"experiment_%s_%s_seed%d_games%d"
		% [
			_experiment_slug(),
			timestamp,
			master_seed,
			int(
				stats.get(
					"games",
					0
				)
			),
		]
	)
	var text_path: String = "%s/%s.txt" % [
		EXPERIMENT_REPORT_DIRECTORY,
		stem,
	]
	var json_path: String = "%s/%s.json" % [
		EXPERIMENT_REPORT_DIRECTORY,
		stem,
	]
	var written: Dictionary = {}
	var text_file = FileAccess.open(
		text_path,
		FileAccess.WRITE
	)

	if text_file == null:
		push_error(
			"Unable to write %s: %s"
			% [
				text_path,
				error_string(
					FileAccess.get_open_error()
				),
			]
		)
	else:
		text_file.store_string(
			report_text
		)
		text_file.close()
		written["text"] = (
			ProjectSettings.globalize_path(
				text_path
			)
		)

	if write_json_report:
		var json_file = FileAccess.open(
			json_path,
			FileAccess.WRITE
		)

		if json_file == null:
			push_error(
				"Unable to write %s: %s"
				% [
					json_path,
					error_string(
						FileAccess.get_open_error()
					),
				]
			)
		else:
			json_file.store_string(
				JSON.stringify(
					stats,
					"\t",
					true
				)
			)
			json_file.close()
			written["json"] = (
				ProjectSettings.globalize_path(
					json_path
				)
			)

	return written


func _write_failure_report(
	failure: Dictionary,
	stats: Dictionary
) -> void:
	var absolute_directory: String = (
		ProjectSettings.globalize_path(
			EXPERIMENT_REPORT_DIRECTORY
		)
	)
	var directory_error: Error = (
		DirAccess.make_dir_recursive_absolute(
			absolute_directory
		)
	)

	if directory_error != OK:
		return

	var failure_path: String = (
		"%s/experiment_%s_failure_seed%d.json"
		% [
			EXPERIMENT_REPORT_DIRECTORY,
			_experiment_slug(),
			master_seed,
		]
	)
	var failure_file = FileAccess.open(
		failure_path,
		FileAccess.WRITE
	)

	if failure_file == null:
		return

	failure_file.store_string(
		JSON.stringify(
			{
				"experimental": true,
				"experiment_name": experiment_name,
				"experimental_features": {
					"testbed": testbed,
					"fix_a_doctrine": (
						enable_fix_a_doctrine
					),
					"fix_b_profane_denial_removed": (
						enable_fix_b_profane
					),
					"forced_action_seat_0": (
						forced_action_seat_0
					),
					"forced_action_seat_1": (
						forced_action_seat_1
					),
				},
				"experimental_rule_overrides": (
					_combined_rule_overrides()
				),
				"failure": failure,
				"partial_stats": stats,
			},
			"\t",
			true
		)
	)
	failure_file.close()

	print(
		"Retained experimental failure report: %s"
		% ProjectSettings.globalize_path(
			failure_path
		)
	)


func _combined_rule_overrides() -> Dictionary:
	var result: Dictionary = (
		EXPERIMENTAL_RULE_OVERRIDES.duplicate(
			true
		)
	)

	for property_raw in inspector_rule_overrides.keys():
		result[String(
			property_raw
		)] = inspector_rule_overrides.get(
			property_raw
		)

	return result


func _experiment_slug() -> String:
	var result: String = (
		experiment_name.strip_edges().to_lower()
	)

	for character: String in [
		" ",
		"/",
		"\\",
		":",
		";",
		".",
		",",
	]:
		result = result.replace(
			character,
			"_"
		)

	return result
