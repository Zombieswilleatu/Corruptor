extends Node


const LORDS: Array[String] = [
	"Orias",
	"Deimos",
	"Valak",
	"Kroni",
	"Kalligan",
	"Gremory",
	"Odradek",
	"Kanifous",
	"Humbaba",
]

const REPORT_DIRECTORY: String = "user://balance_reports"

const ACTIONS: Array[String] = [
	"Hunt",
	"Siege",
	"Ward",
	"Profane",
	"Pass",
]

const ABILITY_EVENTS: Array[String] = [
	"breach_triggered",
	"lord_banished",
	"castle_lost",
	"cataclysmic_invocation",
	"vessel_used",
	"kalligan_repair",
	"kroni_ravenous",
	"kroni_consume",
	"deimos_claim_the_breach",
	"gremory_inevitable_ruin",
	"gremory_ruinous_harvest",
	"kanifous_invoke",
	"kanifous_high_invoke",
	"odradek_reconfiguration_token",
]

const SeededGameSetupData = preload(
	"res://Scripts/Sim/SeededGameSetup.gd"
)

const PythonRandomData = preload(
	"res://Scripts/Sim/PythonRandom.gd"
)

const BotPolicyData = preload(
	"res://Scripts/Sim/BotPolicy.gd"
)

const BotRoundEngineData = preload(
	"res://Scripts/Sim/BotRoundEngine.gd"
)

const BotGameEngineData = preload(
	"res://Scripts/Sim/BotGameEngine.gd"
)

const ResolutionFinaleEngineData = preload(
	"res://Scripts/Sim/ResolutionFinaleEngine.gd"
)


@export_category("Simulation")
@export var master_seed: int = 20260723
@export_range(1, 100000, 1) var games_per_ordered_matchup: int = 25
@export var include_mirror_matchups: bool = false
@export_multiline var selected_lords_csv: String = ""
@export_enum(
	"Golden deterministic",
	"Competitive",
	"Standard",
	"Easy"
) var policy_profile: String = "Golden deterministic"
@export_range(0, 1000, 1) var max_rounds_override: int = 0

@export_category("Output")
@export_range(1, 100000, 1) var progress_every_games: int = 100
@export_range(1, 10000, 1) var yield_every_games: int = 10
@export var print_each_game: bool = false
@export var write_json_report: bool = true
@export var include_game_records_in_json: bool = true
@export var include_round_history_in_json: bool = true
@export var quit_when_finished: bool = true


func _ready() -> void:
	await _run_balance_simulation()


func _run_balance_simulation() -> void:
	var validation_failure: String = _configuration_failure()

	if not validation_failure.is_empty():
		push_error(validation_failure)
		print("")
		print("BALANCE SIMULATION REFUSED: %s" % validation_failure)
		_finish(1)
		return

	var active_lords: Array[String] = _selected_lords()
	var ordered_matchup_count: int = _ordered_matchup_count(
		active_lords.size()
	)
	var total_games: int = (
		ordered_matchup_count
		* games_per_ordered_matchup
	)
	var rules: RuleConfig = RuleConfig.de_v2()
	var policy = _policy()
	var maximum_rounds: int = int(
		rules.max_rounds
	)

	if max_rounds_override > 0:
		maximum_rounds = max_rounds_override

	var seed_source = PythonRandomData.new(
		master_seed
	)
	var stats: Dictionary = _new_stats(
		active_lords,
		total_games,
		maximum_rounds,
		rules,
		String(
			policy.policy_id
		)
	)
	var started_msec: int = Time.get_ticks_msec()
	var completed_games: int = 0

	print("")
	print("RUNNING GODOT BALANCE SIMULATION")
	print(
		"lords=%d ordered_matchups=%d games_per_order=%d total_games=%d"
		% [
			active_lords.size(),
			ordered_matchup_count,
			games_per_ordered_matchup,
			total_games,
		]
	)
	print(
		"master_seed=%d policy=%s max_rounds=%d mirrors=%s"
		% [
			master_seed,
			String(
				policy.policy_id
			),
			maximum_rounds,
			str(
				include_mirror_matchups
			),
		]
	)
	print(
		"Detailed reports will be written beneath %s"
		% ProjectSettings.globalize_path(
			REPORT_DIRECTORY
		)
	)

	for player_zero_lord: String in active_lords:
		for player_one_lord: String in active_lords:
			if (
				not include_mirror_matchups
				and player_zero_lord == player_one_lord
			):
				continue

			for matchup_game_index: int in range(
				games_per_ordered_matchup
			):
				var game_seed: int = int(
					seed_source.randint(
						0,
						2147483647
					)
				)
				var game_record: Dictionary = _play_game(
					player_zero_lord,
					player_one_lord,
					game_seed,
					matchup_game_index,
					rules,
					policy,
					maximum_rounds
				)

				if not bool(
					game_record.get(
						"ok",
						false
					)
				):
					_print_failure(
						game_record,
						completed_games,
						total_games
					)
					_write_failure_report(
						game_record,
						stats
					)
					_finish(1)
					return

				_record_game(
					stats,
					game_record
				)

				completed_games += 1

				if print_each_game:
					_print_game(
						game_record,
						completed_games,
						total_games
					)

				if (
					completed_games
					% progress_every_games
					== 0
					or completed_games == total_games
				):
					_print_progress(
						stats,
						completed_games,
						total_games,
						started_msec
					)

				if (
					completed_games
					% yield_every_games
					== 0
				):
					await get_tree().process_frame

	var elapsed_seconds: float = (
		float(
			Time.get_ticks_msec()
			- started_msec
		)
		/ 1000.0
	)
	stats["elapsed_seconds"] = elapsed_seconds

	var report_text: String = _format_report(
		stats
	)
	var written_paths: Dictionary = _write_reports(
		stats,
		report_text
	)

	print("")
	print(report_text)
	print("")
	print("GODOT BALANCE SIMULATION PASS")
	print(
		"%d games completed in %.2f seconds (%.1f games/second)."
		% [
			completed_games,
			elapsed_seconds,
			(
				float(
					completed_games
				)
				/ maxf(
					elapsed_seconds,
					0.001
				)
			),
		]
	)
	print(
		"TXT report: %s"
		% String(
			written_paths.get(
				"text",
				"not written"
			)
		)
	)

	if write_json_report:
		print(
			"JSON report: %s"
			% String(
				written_paths.get(
					"json",
					"not written"
				)
			)
		)

	_finish(0)


func _play_game(
	player_zero_lord: String,
	player_one_lord: String,
	game_seed: int,
	matchup_game_index: int,
	rules: RuleConfig,
	policy,
	maximum_rounds: int
) -> Dictionary:
	var setup: Dictionary = (
		SeededGameSetupData.setup_locked_game(
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
			"Seeded setup returned no game or RNG."
		)

	var round_history: Array[Dictionary] = []
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
			BotRoundEngineData.resolve_round(
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
				"Round engine did not advance to the requested round."
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

		previous_breach = String(
			game.breach
		)

		round_history.append(
			_round_snapshot(
				game
			)
		)

		# Fallback Consume can create a victory that is intentionally
		# evaluated after the completed-round state. Apply that checkpoint
		# before beginning another round.
		if int(
			game.winner
		) < 0:
			ResolutionFinaleEngineData.check_win(
				game,
				rules
			)

	var timeout_result: Dictionary = {}

	if int(
		game.winner
	) < 0:
		var game_result: Dictionary = (
			BotGameEngineData.resolve_game(
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
			"Game finished without a winner."
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
		"timeout": timeout_result,
	}


func _record_round_activity(
	game,
	action_counts: Dictionary,
	actions_by_player: Array[Dictionary],
	ability_counts: Dictionary,
	previous_alive: Array[bool],
	previous_castle_counts: Array[int],
	previous_persistent_flags: Array[Dictionary],
	previous_breach: String
) -> void:
	if (
		not String(
			game.breach
		).is_empty()
		and String(
			game.breach
		) != previous_breach
	):
		_increment(
			ability_counts,
			"breach_triggered"
		)

	for player_id: int in range(
		game.players.size()
	):
		var player = game.players[
			player_id
		]
		var action_name: String = String(
			player.action
		)

		if action_name.is_empty():
			action_name = "Pass"

		_increment(
			action_counts,
			action_name
		)
		_increment(
			actions_by_player[player_id],
			action_name
		)

		if (
			previous_alive[player_id]
			and not bool(
				player.alive
			)
		):
			_increment(
				ability_counts,
				"lord_banished"
			)

		previous_alive[player_id] = bool(
			player.alive
		)

		var lost_castles: int = maxi(
			0,
			previous_castle_counts[player_id]
			- player.castles.size()
		)

		_increment_by(
			ability_counts,
			"castle_lost",
			lost_castles
		)

		previous_castle_counts[player_id] = (
			player.castles.size()
		)

		if bool(
			player.gremory_inevitable_ruin_done
		):
			_increment(
				ability_counts,
				"gremory_inevitable_ruin"
			)

		if bool(
			player.gremory_ruin_done
		):
			_increment(
				ability_counts,
				"gremory_ruinous_harvest"
			)

		_increment_by(
			ability_counts,
			"kanifous_invoke",
			int(
				player.kanifous_invokes_this_round
			)
		)

		if bool(
			player.kanifous_invoked_high
		):
			_increment(
				ability_counts,
				"kanifous_high_invoke"
			)

		if bool(
			player.kroni_consume_done
		):
			_increment(
				ability_counts,
				"kroni_consume"
			)

		var previous_flags: Dictionary = (
			previous_persistent_flags[
				player_id
			]
		)
		var current_flags: Dictionary = (
			_persistent_flags(
				player
			)
		)

		for flag_name: String in [
			"cataclysmic_invocation",
			"vessel_used",
			"kalligan_repair",
			"kroni_ravenous",
			"deimos_claim_the_breach",
		]:
			if (
				not bool(
					previous_flags.get(
						flag_name,
						false
					)
				)
				and bool(
					current_flags.get(
						flag_name,
						false
					)
				)
			):
				_increment(
					ability_counts,
					flag_name
				)

		var previous_tokens: int = int(
			previous_flags.get(
				"odradek_reconfiguration_token",
				0
			)
		)
		var current_tokens: int = int(
			current_flags.get(
				"odradek_reconfiguration_token",
				0
			)
		)

		_increment_by(
			ability_counts,
			"odradek_reconfiguration_token",
			maxi(
				0,
				current_tokens
				- previous_tokens
			)
		)

		previous_persistent_flags[
			player_id
		] = current_flags


func _persistent_flags(
	player
) -> Dictionary:
	return {
		"cataclysmic_invocation": bool(
			player.cataclysmic_used
		),
		"vessel_used": bool(
			player.vessel_used
		),
		"kalligan_repair": bool(
			player.kalligan_repair_used
		),
		"kroni_ravenous": bool(
			player.kroni_ravenous_used
		),
		"deimos_claim_the_breach": bool(
			player.deimos_breach_claimed
		),
		"odradek_reconfiguration_token": int(
			player.odradek_reconfig_tokens
		),
	}


func _round_snapshot(
	game
) -> Dictionary:
	return {
		"round": int(
			game.round
		),
		"souls": [
			int(
				game.players[0].souls
			),
			int(
				game.players[1].souls
			),
		],
		"tears": [
			int(
				game.players[0].tears
			),
			int(
				game.players[1].tears
			),
		],
		"threat": [
			int(
				game.players[0].threat
			),
			int(
				game.players[1].threat
			),
		],
		"alive": [
			bool(
				game.players[0].alive
			),
			bool(
				game.players[1].alive
			),
		],
		"castles": [
			game.players[0].castles.size(),
			game.players[1].castles.size(),
		],
		"actions": [
			String(
				game.players[0].action
			),
			String(
				game.players[1].action
			),
		],
		"breach": String(
			game.breach
		),
		"breach_owner": int(
			game.breach_owner
		),
		"veil_total": int(
			game.calculate_veil_total()
		),
	}


func _tension_metrics(
	round_history: Array[Dictionary],
	winner_id: int,
	soul_margin: int
) -> Dictionary:
	var previous_leader: int = -1
	var lead_changes: int = 0
	var comeback: bool = false
	var loser_id: int = (
		1
		if winner_id == 0
		else 0
	)

	for snapshot: Dictionary in round_history:
		var souls: Array = snapshot.get(
			"souls",
			[
				0,
				0,
			]
		)
		var leader: int = -1

		if int(
			souls[0]
		) > int(
			souls[1]
		):
			leader = 0
		elif int(
			souls[1]
		) > int(
			souls[0]
		):
			leader = 1

		if (
			leader >= 0
			and previous_leader >= 0
			and leader != previous_leader
		):
			lead_changes += 1

		if leader >= 0:
			previous_leader = leader

		if (
			int(
				snapshot.get(
					"round",
					0
				)
			) >= 2
			and int(
				souls[winner_id]
			) < int(
				souls[loser_id]
			)
		):
			comeback = true

	return {
		"close": soul_margin <= 1,
		"comeback": comeback,
		"lead_changes": lead_changes,
	}


func _new_stats(
	active_lords: Array[String],
	total_games: int,
	maximum_rounds: int,
	rules: RuleConfig,
	policy_id: String
) -> Dictionary:
	var lord_stats: Dictionary = {}

	for lord_name: String in active_lords:
		lord_stats[lord_name] = {
			"games": 0,
			"wins": 0,
			"seat0_games": 0,
			"seat0_wins": 0,
			"seat1_games": 0,
			"seat1_wins": 0,
			"rounds_total": 0,
			"souls_total": 0,
			"tears_total": 0,
			"threat_total": 0,
			"castles_total": 0,
			"alive_finishes": 0,
			"actions": _zero_counts(
				ACTIONS
			),
			"wins_by": {},
		}

	return {
		"schema": "corruptor.godot.balance.v1",
		"project_version": String(
			ProjectSettings.get_setting(
				"application/config/version",
				""
			)
		),
		"master_seed": master_seed,
		"policy": policy_id,
		"rules": _rule_snapshot(
			rules
		),
		"selected_lords": active_lords,
		"games_per_ordered_matchup": (
			games_per_ordered_matchup
		),
		"include_mirror_matchups": (
			include_mirror_matchups
		),
		"max_rounds": maximum_rounds,
		"expected_games": total_games,
		"games": 0,
		"elapsed_seconds": 0.0,
		"seat_wins": [
			0,
			0,
		],
		"first_player_wins": 0,
		"timeouts": 0,
		"win_conditions": {},
		"rounds": [],
		"soul_margins": [],
		"close_games": 0,
		"comeback_games": 0,
		"lead_changes_total": 0,
		"neutral_tears_total": 0,
		"veil_total": 0,
		"actions": _zero_counts(
			ACTIONS
		),
		"ability_events": _zero_counts(
			ABILITY_EVENTS
		),
		"lords": lord_stats,
		"ordered_matchups": {},
		"head_to_head": {},
		"longest_games": [],
		"largest_margins": [],
		"game_records": [],
	}


func _rule_snapshot(
	rules: RuleConfig
) -> Dictionary:
	return {
		"win_souls": int(
			rules.win_souls
		),
		"dominion_track": int(
			rules.dominion_track
		),
		"dominion_requirement": int(
			rules.dominion_requirement
		),
		"final_collapse_threshold": int(
			rules.final_collapse_threshold
		),
		"hand_limit": int(
			rules.hand_limit
		),
		"garrison_max": int(
			rules.garrison_max
		),
		"max_threat": int(
			rules.max_threat
		),
		"market_size": int(
			rules.market_size
		),
		"max_rounds": int(
			rules.max_rounds
		),
		"invocation_gate": int(
			rules.invocation_gate
		),
		"profane_ruins_req": int(
			rules.profane_ruins_req
		),
		"reconfig_tokens_needed": int(
			rules.reconfig_tokens_needed
		),
		"deimos_claims_breach": int(
			rules.deimos_claims_breach
		),
		"deimos_summon_cost": int(
			rules.deimos_summon_cost
		),
		"gremory_summon_cost": int(
			rules.gremory_summon_cost
		),
		"recoil_hunts_only": bool(
			rules.recoil_hunts_only
		),
		"sigil_soul_fresh_only": bool(
			rules.sigil_soul_fresh_only
		),
		"ai_dominion_drive": bool(
			rules.ai_dominion_drive
		),
		"no_backwash": bool(
			rules.no_backwash
		),
		"reconfig_strict": bool(
			rules.reconfig_strict
		),
		"kroni_def_soft": bool(
			rules.kroni_def_soft
		),
		"kroni_hunger_decay": bool(
			rules.kroni_hunger_decay
		),
		"deimos_war_machine_free": bool(
			rules.deimos_war_machine_free
		),
		"recoil_lowest": bool(
			rules.recoil_lowest
		),
		"neutral_tear_on_banish": bool(
			rules.neutral_tear_on_banish
		),
		"castle_tear_uncapped": bool(
			rules.castle_tear_uncapped
		),
		"veil_drift": int(
			rules.veil_drift
		),
		"invocation_repeatable": bool(
			rules.invocation_repeatable
		),
		"reconfig_neutral": bool(
			rules.reconfig_neutral
		),
		"consume_the_siege": bool(
			rules.consume_the_siege
		),
		"war_machine_ignores_profaned": bool(
			rules.war_machine_ignores_profaned
		),
		"humbaba_seal": bool(
			rules.humbaba_seal
		),
		"humbaba_toll": bool(
			rules.humbaba_toll
		),
		"humbaba_gate4": bool(
			rules.humbaba_gate4
		),
		"humbaba_patient": bool(
			rules.humbaba_patient
		),
	}


func _record_game(
	stats: Dictionary,
	record: Dictionary
) -> void:
	stats["games"] = int(
		stats.get(
			"games",
			0
		)
	) + 1

	var winner_id: int = int(
		record.get(
			"winner",
			-1
		)
	)
	var seat_wins: Array = stats.get(
		"seat_wins",
		[
			0,
			0,
		]
	)

	seat_wins[winner_id] = int(
		seat_wins[winner_id]
	) + 1
	stats["seat_wins"] = seat_wins

	if winner_id == int(
		record.get(
			"first_player",
			-1
		)
	):
		stats["first_player_wins"] = int(
			stats.get(
				"first_player_wins",
				0
			)
		) + 1

	var win_by: String = String(
		record.get(
			"win_by",
			"Unknown"
		)
	)

	_increment(
		stats["win_conditions"],
		win_by
	)

	if win_by == "Timeout":
		stats["timeouts"] = int(
			stats.get(
				"timeouts",
				0
			)
		) + 1

	stats["rounds"].append(
		int(
			record.get(
				"rounds",
				0
			)
		)
	)
	stats["soul_margins"].append(
		int(
			record.get(
				"soul_margin",
				0
			)
		)
	)

	if bool(
		record.get(
			"close",
			false
		)
	):
		stats["close_games"] = int(
			stats.get(
				"close_games",
				0
			)
		) + 1

	if bool(
		record.get(
			"comeback",
			false
		)
	):
		stats["comeback_games"] = int(
			stats.get(
				"comeback_games",
				0
			)
		) + 1

	stats["lead_changes_total"] = int(
		stats.get(
			"lead_changes_total",
			0
		)
	) + int(
		record.get(
			"lead_changes",
			0
		)
	)
	stats["neutral_tears_total"] = int(
		stats.get(
			"neutral_tears_total",
			0
		)
	) + int(
		record.get(
			"neutral_tears",
			0
		)
	)
	stats["veil_total"] = int(
		stats.get(
			"veil_total",
			0
		)
	) + int(
		record.get(
			"veil_total",
			0
		)
	)

	_merge_counts(
		stats["actions"],
		_dictionary(
			record.get(
				"actions",
				{}
			)
		)
	)
	_merge_counts(
		stats["ability_events"],
		_dictionary(
			record.get(
				"ability_events",
				{}
			)
		)
	)

	var players: Array = record.get(
		"players",
		[]
	)
	var lords: Dictionary = stats.get(
		"lords",
		{}
	)
	var actions_by_player: Array = record.get(
		"actions_by_player",
		[]
	)
	var record_actions: Dictionary = _dictionary(
		record.get(
			"actions",
			{}
		)
	)

	for player_data_raw in players:
		if typeof(
			player_data_raw
		) != TYPE_DICTIONARY:
			continue

		var player_data: Dictionary = (
			player_data_raw
		)
		var lord_name: String = String(
			player_data.get(
				"lord",
				""
			)
		)
		var pid: int = int(
			player_data.get(
				"pid",
				-1
			)
		)
		var player_actions: Dictionary = {}

		if (
			pid >= 0
			and pid < actions_by_player.size()
		):
			player_actions = _dictionary(
				actions_by_player[pid]
			)

		var lord_stat: Dictionary = _dictionary(
			lords.get(
				lord_name,
				{}
			)
		)

		lord_stat["games"] = int(
			lord_stat.get(
				"games",
				0
			)
		) + 1
		lord_stat["rounds_total"] = int(
			lord_stat.get(
				"rounds_total",
				0
			)
		) + int(
			record.get(
				"rounds",
				0
			)
		)
		lord_stat["souls_total"] = int(
			lord_stat.get(
				"souls_total",
				0
			)
		) + int(
			player_data.get(
				"souls",
				0
			)
		)
		lord_stat["tears_total"] = int(
			lord_stat.get(
				"tears_total",
				0
			)
		) + int(
			player_data.get(
				"tears",
				0
			)
		)
		lord_stat["threat_total"] = int(
			lord_stat.get(
				"threat_total",
				0
			)
		) + int(
			player_data.get(
				"threat",
				0
			)
		)
		lord_stat["castles_total"] = int(
			lord_stat.get(
				"castles_total",
				0
			)
		) + int(
			player_data.get(
				"castles",
				0
			)
		)

		if bool(
			player_data.get(
				"alive",
				false
			)
		):
			lord_stat["alive_finishes"] = int(
				lord_stat.get(
					"alive_finishes",
					0
				)
			) + 1

		if pid == 0:
			lord_stat["seat0_games"] = int(
				lord_stat.get(
					"seat0_games",
					0
				)
			) + 1
		else:
			lord_stat["seat1_games"] = int(
				lord_stat.get(
					"seat1_games",
					0
				)
			) + 1

		if pid == winner_id:
			lord_stat["wins"] = int(
				lord_stat.get(
					"wins",
					0
				)
			) + 1

			if pid == 0:
				lord_stat["seat0_wins"] = int(
					lord_stat.get(
						"seat0_wins",
						0
					)
				) + 1
			else:
				lord_stat["seat1_wins"] = int(
					lord_stat.get(
						"seat1_wins",
						0
					)
				) + 1

			_increment(
				lord_stat["wins_by"],
				win_by
			)

		# Each round records one action for each seat. In a locked game,
		# the seat's Lord owns every one of those choices.
		for action_name: String in ACTIONS:
			var action_count: int = int(
				player_actions.get(
					action_name,
					0
				)
			)

			if player_actions.is_empty():
				action_count = int(
					record_actions.get(
						action_name,
						0
					)
				) / maxi(
					1,
					players.size()
				)

			_increment_by(
				lord_stat["actions"],
				action_name,
				action_count
			)

		lords[lord_name] = lord_stat

	stats["lords"] = lords

	_record_matchup(
		stats,
		record
	)
	_insert_top(
		stats["longest_games"],
		record,
		"rounds",
		10
	)
	_insert_top(
		stats["largest_margins"],
		record,
		"soul_margin",
		10
	)

	if include_game_records_in_json:
		stats["game_records"].append(
			record
		)


func _record_matchup(
	stats: Dictionary,
	record: Dictionary
) -> void:
	var lord0: String = String(
		record.get(
			"lord0",
			""
		)
	)
	var lord1: String = String(
		record.get(
			"lord1",
			""
		)
	)
	var winner_id: int = int(
		record.get(
			"winner",
			-1
		)
	)
	var ordered_key: String = "%s vs %s" % [
		lord0,
		lord1,
	]
	var ordered: Dictionary = _dictionary(
		stats["ordered_matchups"].get(
			ordered_key,
			_new_matchup_stat(
				lord0,
				lord1
			)
		)
	)

	_accumulate_matchup(
		ordered,
		record,
		winner_id
	)
	stats["ordered_matchups"][
		ordered_key
	] = ordered

	var first_lord: String = lord0
	var second_lord: String = lord1
	var winner_is_first: bool = (
		winner_id == 0
	)

	if _lord_index(
		second_lord
	) < _lord_index(
		first_lord
	):
		first_lord = lord1
		second_lord = lord0
		winner_is_first = (
			winner_id == 1
		)

	var head_key: String = "%s vs %s" % [
		first_lord,
		second_lord,
	]
	var head_stat: Dictionary = _dictionary(
		stats["head_to_head"].get(
			head_key,
			{
				"lord_a": first_lord,
				"lord_b": second_lord,
				"games": 0,
				"wins_a": 0,
				"wins_b": 0,
				"rounds_total": 0,
				"close_games": 0,
				"win_conditions": {},
			}
		)
	)

	head_stat["games"] = int(
		head_stat.get(
			"games",
			0
		)
	) + 1
	head_stat["rounds_total"] = int(
		head_stat.get(
			"rounds_total",
			0
		)
	) + int(
		record.get(
			"rounds",
			0
		)
	)

	if winner_is_first:
		head_stat["wins_a"] = int(
			head_stat.get(
				"wins_a",
				0
			)
		) + 1
	else:
		head_stat["wins_b"] = int(
			head_stat.get(
				"wins_b",
				0
			)
		) + 1

	if bool(
		record.get(
			"close",
			false
		)
	):
		head_stat["close_games"] = int(
			head_stat.get(
				"close_games",
				0
			)
		) + 1

	_increment(
		head_stat["win_conditions"],
		String(
			record.get(
				"win_by",
				"Unknown"
			)
		)
	)
	stats["head_to_head"][
		head_key
	] = head_stat


func _new_matchup_stat(
	lord0: String,
	lord1: String
) -> Dictionary:
	return {
		"lord0": lord0,
		"lord1": lord1,
		"games": 0,
		"wins0": 0,
		"wins1": 0,
		"rounds_total": 0,
		"souls0_total": 0,
		"souls1_total": 0,
		"tears0_total": 0,
		"tears1_total": 0,
		"castles0_total": 0,
		"castles1_total": 0,
		"close_games": 0,
		"comeback_games": 0,
		"win_conditions": {},
	}


func _accumulate_matchup(
	matchup: Dictionary,
	record: Dictionary,
	winner_id: int
) -> void:
	matchup["games"] = int(
		matchup.get(
			"games",
			0
		)
	) + 1
	matchup[
		"wins%d" % winner_id
	] = int(
		matchup.get(
			"wins%d" % winner_id,
			0
		)
	) + 1
	matchup["rounds_total"] = int(
		matchup.get(
			"rounds_total",
			0
		)
	) + int(
		record.get(
			"rounds",
			0
		)
	)

	var players: Array = record.get(
		"players",
		[]
	)

	for pid: int in range(
		mini(
			2,
			players.size()
		)
	):
		var player_data: Dictionary = _dictionary(
			players[pid]
		)

		for field_name: String in [
			"souls",
			"tears",
			"castles",
		]:
			var total_key: String = (
				"%s%d_total"
				% [
					field_name,
					pid,
				]
			)
			matchup[total_key] = int(
				matchup.get(
					total_key,
					0
				)
			) + int(
				player_data.get(
					field_name,
					0
				)
			)

	if bool(
		record.get(
			"close",
			false
		)
	):
		matchup["close_games"] = int(
			matchup.get(
				"close_games",
				0
			)
		) + 1

	if bool(
		record.get(
			"comeback",
			false
		)
	):
		matchup["comeback_games"] = int(
			matchup.get(
				"comeback_games",
				0
			)
		) + 1

	_increment(
		matchup["win_conditions"],
		String(
			record.get(
				"win_by",
				"Unknown"
			)
		)
	)


func _format_report(
	stats: Dictionary
) -> String:
	var lines: Array[String] = []
	var game_count: int = int(
		stats.get(
			"games",
			0
		)
	)
	var rounds: Array = stats.get(
		"rounds",
		[]
	)
	var soul_margins: Array = stats.get(
		"soul_margins",
		[]
	)

	lines.append(
		"CORRUPTOR GODOT BALANCE REPORT"
	)
	lines.append(
		"========================================"
	)
	lines.append(
		"Engine: Godot simulation (not parity validation)"
	)
	lines.append(
		"Master seed: %d"
		% int(
			stats.get(
				"master_seed",
				0
			)
		)
	)
	lines.append(
		"Policy: %s"
		% String(
			stats.get(
				"policy",
				""
			)
		)
	)
	lines.append(
		"Games: %d | ordered samples/matchup: %d | mirrors: %s"
		% [
			game_count,
			int(
				stats.get(
					"games_per_ordered_matchup",
					0
				)
			),
			str(
				stats.get(
					"include_mirror_matchups",
					false
				)
			),
		]
	)
	lines.append(
		"Lords: %s"
		% ", ".join(
			stats.get(
				"selected_lords",
				[]
			)
		)
	)

	lines.append("")
	lines.append("OVERALL")
	lines.append("----------------------------------------")
	lines.append(
		"Average rounds: %.2f | median: %.0f | p90: %.0f | min/max: %d/%d"
		% [
			_average(
				rounds
			),
			_percentile(
				rounds,
				0.50
			),
			_percentile(
				rounds,
				0.90
			),
			_minimum(
				rounds
			),
			_maximum(
				rounds
			),
		]
	)
	lines.append(
		"Average final Soul margin: %.2f | close (0-1): %s | comeback: %s"
		% [
			_average(
				soul_margins
			),
			_percent_text(
				int(
					stats.get(
						"close_games",
						0
					)
				),
				game_count
			),
			_percent_text(
				int(
					stats.get(
						"comeback_games",
						0
					)
				),
				game_count
			),
		]
	)
	lines.append(
		"Average lead changes/game: %.2f | average final Veil: %.2f"
		% [
			_ratio(
				int(
					stats.get(
						"lead_changes_total",
						0
					)
				),
				game_count
			),
			_ratio(
				int(
					stats.get(
						"veil_total",
						0
					)
				),
				game_count
			),
		]
	)

	lines.append("")
	lines.append("LORD STANDINGS")
	lines.append("----------------------------------------")
	lines.append(
		"%s %s %s %s %s %s %s %s"
		% [
			"Lord".rpad(11),
			"Games".lpad(7),
			"Wins".lpad(7),
			"Win%".lpad(8),
			"S0%".lpad(8),
			"S1%".lpad(8),
			"Souls".lpad(8),
			"Castles".lpad(8),
		]
	)

	var lords: Dictionary = stats.get(
		"lords",
		{}
	)

	for lord_name: String in stats.get(
		"selected_lords",
		[]
	):
		var lord_stat: Dictionary = _dictionary(
			lords.get(
				lord_name,
				{}
			)
		)
		var lord_games: int = int(
			lord_stat.get(
				"games",
				0
			)
		)

		lines.append(
			"%s %s %s %s %s %s %s %s"
			% [
				lord_name.rpad(
					11
				),
				str(
					lord_games
				).lpad(
					7
				),
				str(
					lord_stat.get(
						"wins",
						0
					)
				).lpad(
					7
				),
				_percent_cell(
					int(
						lord_stat.get(
							"wins",
							0
						)
					),
					lord_games
				),
				_percent_cell(
					int(
						lord_stat.get(
							"seat0_wins",
							0
						)
					),
					int(
						lord_stat.get(
							"seat0_games",
							0
						)
					)
				),
				_percent_cell(
					int(
						lord_stat.get(
							"seat1_wins",
							0
						)
					),
					int(
						lord_stat.get(
							"seat1_games",
							0
						)
					)
				),
				("%.2f" % _ratio(
					int(
						lord_stat.get(
							"souls_total",
							0
						)
					),
					lord_games
				)).lpad(
					8
				),
				("%.2f" % _ratio(
					int(
						lord_stat.get(
							"castles_total",
							0
						)
					),
					lord_games
				)).lpad(
					8
				),
			]
		)

	lines.append("")
	lines.append("LORD FINAL ECONOMY")
	lines.append("----------------------------------------")
	lines.append(
		"%s %s %s %s %s %s"
		% [
			"Lord".rpad(11),
			"Souls".lpad(8),
			"Tears".lpad(8),
			"Threat".lpad(8),
			"Castles".lpad(8),
			"Alive".lpad(8),
		]
	)

	for lord_name: String in stats.get(
		"selected_lords",
		[]
	):
		var lord_stat: Dictionary = _dictionary(
			lords.get(
				lord_name,
				{}
			)
		)
		var lord_games: int = int(
			lord_stat.get(
				"games",
				0
			)
		)

		lines.append(
			"%s %s %s %s %s %s"
			% [
				lord_name.rpad(
					11
				),
				("%.2f" % _ratio(
					int(
						lord_stat.get(
							"souls_total",
							0
						)
					),
					lord_games
				)).lpad(
					8
				),
				("%.2f" % _ratio(
					int(
						lord_stat.get(
							"tears_total",
							0
						)
					),
					lord_games
				)).lpad(
					8
				),
				("%.2f" % _ratio(
					int(
						lord_stat.get(
							"threat_total",
							0
						)
					),
					lord_games
				)).lpad(
					8
				),
				("%.2f" % _ratio(
					int(
						lord_stat.get(
							"castles_total",
							0
						)
					),
					lord_games
				)).lpad(
					8
				),
				_percent_cell(
					int(
						lord_stat.get(
							"alive_finishes",
							0
						)
					),
					lord_games
				),
			]
		)

	lines.append("")
	lines.append("SEAT AND INITIATIVE")
	lines.append("----------------------------------------")
	var seat_wins: Array = stats.get(
		"seat_wins",
		[
			0,
			0,
		]
	)
	lines.append(
		"Seat 0 wins: %s | Seat 1 wins: %s | First-player wins: %s"
		% [
			_percent_text(
				int(
					seat_wins[0]
				),
				game_count
			),
			_percent_text(
				int(
					seat_wins[1]
				),
				game_count
			),
			_percent_text(
				int(
					stats.get(
						"first_player_wins",
						0
					)
				),
				game_count
			),
		]
	)

	lines.append("")
	lines.append("WIN CONDITIONS")
	lines.append("----------------------------------------")
	var win_conditions: Dictionary = stats.get(
		"win_conditions",
		{}
	)

	for condition_name: String in [
		"Ritual",
		"Dominion",
		"FinalCollapse",
		"Timeout",
	]:
		lines.append(
			"%s %s"
			% [
				condition_name.rpad(
					16
				),
				_count_and_percent(
					int(
						win_conditions.get(
							condition_name,
							0
						)
					),
					game_count
				),
			]
		)

	lines.append("")
	lines.append("HEAD TO HEAD (seat-balanced)")
	lines.append("----------------------------------------")
	lines.append(
		"%s %s %s %s %s"
		% [
			"Matchup".rpad(24),
			"Games".lpad(7),
			"A win%".lpad(8),
			"AvgRnd".lpad(8),
			"Close".lpad(8),
		]
	)
	var head_to_head: Dictionary = stats.get(
		"head_to_head",
		{}
	)

	for head_key: String in _sorted_keys(
		head_to_head
	):
		var head_stat: Dictionary = _dictionary(
			head_to_head[head_key]
		)
		var head_games: int = int(
			head_stat.get(
				"games",
				0
			)
		)

		lines.append(
			"%s %s %s %s %s"
			% [
				head_key.rpad(
					24
				),
				str(
					head_games
				).lpad(
					7
				),
				_percent_cell(
					int(
						head_stat.get(
							"wins_a",
							0
						)
					),
					head_games
				),
				("%.2f" % _ratio(
					int(
						head_stat.get(
							"rounds_total",
							0
						)
					),
					head_games
				)).lpad(
					8
				),
				_percent_cell(
					int(
						head_stat.get(
							"close_games",
							0
						)
					),
					head_games
				),
			]
		)

	lines.append("")
	lines.append("ORDERED MATCHUPS (seat-specific)")
	lines.append("----------------------------------------")
	lines.append(
		"%s %s %s %s %s %s %s"
		% [
			"Player 0 vs Player 1".rpad(
				24
			),
			"Games".lpad(7),
			"P0 win%".lpad(8),
			"AvgRnd".lpad(8),
			"Soul0".lpad(8),
			"Soul1".lpad(8),
			"Close".lpad(8),
		]
	)
	var ordered_matchups: Dictionary = stats.get(
		"ordered_matchups",
		{}
	)

	for ordered_key: String in _sorted_keys(
		ordered_matchups
	):
		var ordered_stat: Dictionary = _dictionary(
			ordered_matchups[ordered_key]
		)
		var ordered_games: int = int(
			ordered_stat.get(
				"games",
				0
			)
		)

		lines.append(
			"%s %s %s %s %s %s %s"
			% [
				ordered_key.rpad(
					24
				),
				str(
					ordered_games
				).lpad(
					7
				),
				_percent_cell(
					int(
						ordered_stat.get(
							"wins0",
							0
						)
					),
					ordered_games
				),
				("%.2f" % _ratio(
					int(
						ordered_stat.get(
							"rounds_total",
							0
						)
					),
					ordered_games
				)).lpad(
					8
				),
				("%.2f" % _ratio(
					int(
						ordered_stat.get(
							"souls0_total",
							0
						)
					),
					ordered_games
				)).lpad(
					8
				),
				("%.2f" % _ratio(
					int(
						ordered_stat.get(
							"souls1_total",
							0
						)
					),
					ordered_games
				)).lpad(
					8
				),
				_percent_cell(
					int(
						ordered_stat.get(
							"close_games",
							0
						)
					),
					ordered_games
				),
			]
		)

	lines.append("")
	lines.append("ACTION MIX")
	lines.append("----------------------------------------")
	var actions: Dictionary = stats.get(
		"actions",
		{}
	)
	var total_actions: int = _count_total(
		actions
	)

	for action_name: String in ACTIONS:
		lines.append(
			"%s %s"
			% [
				action_name.rpad(
					16
				),
				_count_and_percent(
					int(
						actions.get(
							action_name,
							0
						)
					),
					total_actions
				),
			]
		)

	lines.append("")
	lines.append("ACTION MIX BY LORD")
	lines.append("----------------------------------------")
	lines.append(
		"%s %s %s %s %s %s"
		% [
			"Lord".rpad(11),
			"Hunt".lpad(8),
			"Siege".lpad(8),
			"Ward".lpad(8),
			"Profane".lpad(8),
			"Pass".lpad(8),
		]
	)

	for lord_name: String in stats.get(
		"selected_lords",
		[]
	):
		var lord_stat: Dictionary = _dictionary(
			lords.get(
				lord_name,
				{}
			)
		)
		var lord_actions: Dictionary = _dictionary(
			lord_stat.get(
				"actions",
				{}
			)
		)
		var lord_action_total: int = _count_total(
			lord_actions
		)

		lines.append(
			"%s %s %s %s %s %s"
			% [
				lord_name.rpad(
					11
				),
				_percent_cell(
					int(
						lord_actions.get(
							"Hunt",
							0
						)
					),
					lord_action_total
				),
				_percent_cell(
					int(
						lord_actions.get(
							"Siege",
							0
						)
					),
					lord_action_total
				),
				_percent_cell(
					int(
						lord_actions.get(
							"Ward",
							0
						)
					),
					lord_action_total
				),
				_percent_cell(
					int(
						lord_actions.get(
							"Profane",
							0
						)
					),
					lord_action_total
				),
				_percent_cell(
					int(
						lord_actions.get(
							"Pass",
							0
						)
					),
					lord_action_total
				),
			]
		)

	lines.append("")
	lines.append("ABILITY AND STATE ACTIVITY")
	lines.append("----------------------------------------")
	var ability_events: Dictionary = stats.get(
		"ability_events",
		{}
	)

	for event_name: String in ABILITY_EVENTS:
		lines.append(
			"%s %s"
			% [
				event_name.rpad(
					34
				),
				str(
					ability_events.get(
						event_name,
						0
					)
				).lpad(
					8
				),
			]
		)

	lines.append("")
	lines.append("LONGEST GAMES")
	lines.append("----------------------------------------")

	for outlier_raw in stats.get(
		"longest_games",
		[]
	):
		var outlier: Dictionary = _dictionary(
			outlier_raw
		)
		lines.append(
			"%s vs %s seed=%d rounds=%d winner=%s by %s margin=%d"
			% [
				String(
					outlier.get(
						"lord0",
						""
					)
				),
				String(
					outlier.get(
						"lord1",
						""
					)
				),
				int(
					outlier.get(
						"seed",
						0
					)
				),
				int(
					outlier.get(
						"rounds",
						0
					)
				),
				String(
					outlier.get(
						"winner_lord",
						""
					)
				),
				String(
					outlier.get(
						"win_by",
						""
					)
				),
				int(
					outlier.get(
						"soul_margin",
						0
					)
				),
			]
		)

	lines.append("")
	lines.append("BALANCE FLAGS")
	lines.append("----------------------------------------")
	var flags: Array[String] = _balance_flags(
		stats
	)

	if flags.is_empty():
		lines.append(
			"No automatic threshold flags."
		)
	else:
		for flag_text: String in flags:
			lines.append(
				"- %s" % flag_text
			)

	return "\n".join(
		lines
	)


func _balance_flags(
	stats: Dictionary
) -> Array[String]:
	var flags: Array[String] = []
	var game_count: int = int(
		stats.get(
			"games",
			0
		)
	)
	var lords: Dictionary = stats.get(
		"lords",
		{}
	)

	for lord_name: String in stats.get(
		"selected_lords",
		[]
	):
		var lord_stat: Dictionary = _dictionary(
			lords.get(
				lord_name,
				{}
			)
		)
		var lord_games: int = int(
			lord_stat.get(
				"games",
				0
			)
		)
		var win_rate: float = _ratio(
			int(
				lord_stat.get(
					"wins",
					0
				)
			),
			lord_games
		)

		if win_rate > 0.56:
			flags.append(
				"%s overall win rate is high (%.1f%%)."
				% [
					lord_name,
					win_rate * 100.0,
				]
			)
		elif win_rate < 0.44:
			flags.append(
				"%s overall win rate is low (%.1f%%)."
				% [
					lord_name,
					win_rate * 100.0,
				]
			)

	var head_to_head: Dictionary = stats.get(
		"head_to_head",
		{}
	)

	for head_key: String in _sorted_keys(
		head_to_head
	):
		var head_stat: Dictionary = _dictionary(
			head_to_head[head_key]
		)
		var head_games: int = int(
			head_stat.get(
				"games",
				0
			)
		)
		var a_rate: float = _ratio(
			int(
				head_stat.get(
					"wins_a",
					0
				)
			),
			head_games
		)

		if (
			a_rate > 0.60
			or a_rate < 0.40
		):
			flags.append(
				"%s is lopsided (A wins %.1f%%)."
				% [
					head_key,
					a_rate * 100.0,
				]
			)

	var seat_wins: Array = stats.get(
		"seat_wins",
		[
			0,
			0,
		]
	)
	var seat_zero_rate: float = _ratio(
		int(
			seat_wins[0]
		),
		game_count
	)

	if absf(
		seat_zero_rate - 0.50
	) > 0.03:
		flags.append(
			"Seat 0 win rate is %.1f%%."
			% (
				seat_zero_rate
				* 100.0
			)
		)

	var first_player_rate: float = _ratio(
		int(
			stats.get(
				"first_player_wins",
				0
			)
		),
		game_count
	)

	if absf(
		first_player_rate - 0.50
	) > 0.03:
		flags.append(
			"First-player win rate is %.1f%%."
			% (
				first_player_rate
				* 100.0
			)
		)

	var timeout_rate: float = _ratio(
		int(
			stats.get(
				"timeouts",
				0
			)
		),
		game_count
	)

	if timeout_rate > 0.15:
		flags.append(
			"Timeout rate is high (%.1f%%)."
			% (
				timeout_rate
				* 100.0
			)
		)

	return flags


func _write_reports(
	stats: Dictionary,
	report_text: String
) -> Dictionary:
	var absolute_directory: String = (
		ProjectSettings.globalize_path(
			REPORT_DIRECTORY
		)
	)
	var directory_error: Error = (
		DirAccess.make_dir_recursive_absolute(
			absolute_directory
		)
	)

	if directory_error != OK:
		push_error(
			"Unable to create balance report directory: %s"
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
		"balance_%s_seed%d_games%d"
		% [
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
		REPORT_DIRECTORY,
		stem,
	]
	var json_path: String = "%s/%s.json" % [
		REPORT_DIRECTORY,
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
			REPORT_DIRECTORY
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
		"%s/balance_failure_seed%d.json"
		% [
			REPORT_DIRECTORY,
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
				"failure": failure,
				"partial_stats": stats,
			},
			"\t",
			true
		)
	)
	failure_file.close()

	print(
		"Retained failure report: %s"
		% ProjectSettings.globalize_path(
			failure_path
		)
	)


func _print_progress(
	stats: Dictionary,
	completed_games: int,
	total_games: int,
	started_msec: int
) -> void:
	var elapsed_seconds: float = maxf(
		0.001,
		float(
			Time.get_ticks_msec()
			- started_msec
		)
		/ 1000.0
	)
	var games_per_second: float = (
		float(
			completed_games
		)
		/ elapsed_seconds
	)
	var remaining_games: int = (
		total_games
		- completed_games
	)
	var eta_seconds: float = (
		float(
			remaining_games
		)
		/ maxf(
			games_per_second,
			0.001
		)
	)

	print(
		"PROGRESS %d/%d (%.1f%%) %.1f games/s ETA %.1fs | avg rounds %.2f"
		% [
			completed_games,
			total_games,
			(
				100.0
				* float(
					completed_games
				)
				/ float(
					total_games
				)
			),
			games_per_second,
			eta_seconds,
			_average(
				stats.get(
					"rounds",
					[]
				)
			),
		]
	)


func _print_game(
	record: Dictionary,
	completed_games: int,
	total_games: int
) -> void:
	print(
		"GAME %d/%d seed=%d %s vs %s -> %s by %s r%d margin=%d"
		% [
			completed_games,
			total_games,
			int(
				record.get(
					"seed",
					0
				)
			),
			String(
				record.get(
					"lord0",
					""
				)
			),
			String(
				record.get(
					"lord1",
					""
				)
			),
			String(
				record.get(
					"winner_lord",
					""
				)
			),
			String(
				record.get(
					"win_by",
					""
				)
			),
			int(
				record.get(
					"rounds",
					0
				)
			),
			int(
				record.get(
					"soul_margin",
					0
				)
			),
		]
	)


func _print_failure(
	record: Dictionary,
	completed_games: int,
	total_games: int
) -> void:
	print("")
	print("BALANCE SIMULATION STOPPED ON INVALID GAME")
	print(
		"completed=%d/%d matchup=%s vs %s seed=%d round=%d phase=%s"
		% [
			completed_games,
			total_games,
			String(
				record.get(
					"lord0",
					""
				)
			),
			String(
				record.get(
					"lord1",
					""
				)
			),
			int(
				record.get(
					"seed",
					0
				)
			),
			int(
				record.get(
					"round",
					0
				)
			),
			String(
				record.get(
					"phase",
					""
				)
			),
		]
	)
	print(
		"reason=%s"
		% String(
			record.get(
				"reason",
				"unknown_failure"
			)
		)
	)


func _failed_game(
	lord0: String,
	lord1: String,
	game_seed: int,
	round_number: int,
	phase_name: String,
	reason: String
) -> Dictionary:
	return {
		"ok": false,
		"lord0": lord0,
		"lord1": lord1,
		"seed": game_seed,
		"round": round_number,
		"phase": phase_name,
		"reason": reason,
	}


func _configuration_failure() -> String:
	if games_per_ordered_matchup <= 0:
		return "games_per_ordered_matchup must be positive."

	if progress_every_games <= 0:
		return "progress_every_games must be positive."

	if yield_every_games <= 0:
		return "yield_every_games must be positive."

	var active_lords: Array[String] = _selected_lords()

	if active_lords.size() < 2:
		return "Select at least two valid Lords."

	return ""


func _selected_lords() -> Array[String]:
	if selected_lords_csv.strip_edges().is_empty():
		return LORDS.duplicate()

	var result: Array[String] = []
	var requested: PackedStringArray = (
		selected_lords_csv.split(
			",",
			false
		)
	)

	for raw_name: String in requested:
		var lord_name: String = raw_name.strip_edges()

		if (
			LORDS.has(
				lord_name
			)
			and not result.has(
				lord_name
			)
		):
			result.append(
				lord_name
			)

	return result


func _ordered_matchup_count(
	lord_count: int
) -> int:
	if include_mirror_matchups:
		return lord_count * lord_count

	return lord_count * (
		lord_count - 1
	)


func _policy():
	if policy_profile == "Competitive":
		return BotPolicyData.competitive()

	if policy_profile == "Standard":
		return BotPolicyData.standard()

	if policy_profile == "Easy":
		return BotPolicyData.easy()

	return BotPolicyData.golden_core()


func _increment(
	counts: Dictionary,
	key_name: String
) -> void:
	_increment_by(
		counts,
		key_name,
		1
	)


func _increment_by(
	counts: Dictionary,
	key_name: String,
amount: int
) -> void:
	if amount <= 0:
		return

	counts[key_name] = int(
		counts.get(
			key_name,
			0
		)
	) + amount


func _merge_counts(
	target: Dictionary,
source: Dictionary
) -> void:
	for key_raw in source.keys():
		var key_name: String = String(
			key_raw
		)

		_increment_by(
			target,
			key_name,
			int(
				source.get(
					key_raw,
					0
				)
			)
		)


func _zero_counts(
	names: Array[String]
) -> Dictionary:
	var counts: Dictionary = {}

	for key_name: String in names:
		counts[key_name] = 0

	return counts


func _count_total(
	counts: Dictionary
) -> int:
	var total: int = 0

	for value_raw in counts.values():
		total += int(
			value_raw
		)

	return total


func _insert_top(
	target: Array,
	record: Dictionary,
field_name: String,
limit: int
) -> void:
	var summary: Dictionary = {
		"seed": int(
			record.get(
				"seed",
				0
			)
		),
		"lord0": String(
			record.get(
				"lord0",
				""
			)
		),
		"lord1": String(
			record.get(
				"lord1",
				""
			)
		),
		"winner_lord": String(
			record.get(
				"winner_lord",
				""
			)
		),
		"win_by": String(
			record.get(
				"win_by",
				""
			)
		),
		"rounds": int(
			record.get(
				"rounds",
				0
			)
		),
		"soul_margin": int(
			record.get(
				"soul_margin",
				0
			)
		),
	}
	var insert_at: int = target.size()
	var summary_value: int = int(
		summary.get(
			field_name,
			0
		)
	)

	for index: int in range(
		target.size()
	):
		var current: Dictionary = _dictionary(
			target[index]
		)

		if summary_value > int(
			current.get(
				field_name,
				0
			)
		):
			insert_at = index
			break

	target.insert(
		insert_at,
		summary
	)

	while target.size() > limit:
		target.pop_back()


func _average(
	values: Array
) -> float:
	if values.is_empty():
		return 0.0

	var total: float = 0.0

	for value_raw in values:
		total += float(
			value_raw
		)

	return total / float(
		values.size()
	)


func _percentile(
	values: Array,
fraction: float
) -> float:
	if values.is_empty():
		return 0.0

	var sorted_values: Array = values.duplicate()
	sorted_values.sort()

	var index: int = clampi(
		int(
			ceil(
				fraction
				* float(
					sorted_values.size()
				)
			)
		) - 1,
		0,
		sorted_values.size() - 1
	)

	return float(
		sorted_values[index]
	)


func _minimum(
	values: Array
) -> int:
	if values.is_empty():
		return 0

	var result: int = int(
		values[0]
	)

	for value_raw in values:
		result = mini(
			result,
			int(
				value_raw
			)
		)

	return result


func _maximum(
	values: Array
) -> int:
	if values.is_empty():
		return 0

	var result: int = int(
		values[0]
	)

	for value_raw in values:
		result = maxi(
			result,
			int(
				value_raw
			)
		)

	return result


func _ratio(
	numerator: int,
	denominator: int
) -> float:
	if denominator <= 0:
		return 0.0

	return float(
		numerator
	) / float(
		denominator
	)


func _percent_text(
	count: int,
	total: int
) -> String:
	return "%d (%.1f%%)" % [
		count,
		100.0 * _ratio(
			count,
			total
		),
	]


func _percent_cell(
	count: int,
	total: int
) -> String:
	return (
		"%.1f%%"
		% (
			100.0
			* _ratio(
				count,
				total
			)
		)
	).lpad(
		8
	)


func _count_and_percent(
	count: int,
	total: int
) -> String:
	return (
		"%8d %7.1f%%"
		% [
			count,
			100.0 * _ratio(
				count,
				total
			),
		]
	)


func _sorted_keys(
	dictionary: Dictionary
) -> Array[String]:
	var result: Array[String] = []

	for key_raw in dictionary.keys():
		result.append(
			String(
				key_raw
			)
		)

	result.sort()

	return result


func _lord_index(
	lord_name: String
) -> int:
	var index: int = LORDS.find(
		lord_name
	)

	if index < 0:
		return LORDS.size()

	return index


func _dictionary(
	value
) -> Dictionary:
	if typeof(
		value
	) == TYPE_DICTIONARY:
		return value

	return {}


func _finish(
	exit_code: int
) -> void:
	if quit_when_finished:
		get_tree().quit(
			exit_code
		)
