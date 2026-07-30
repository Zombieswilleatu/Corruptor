class_name ExperimentalPureStrategyMatrixRunner
extends Node


const ExperimentalBalanceRunnerData = preload(
	"res://Experiments/BalanceLab/ExperimentalBalanceRunner.gd"
)

const PythonRandomData = preload(
	"res://Scripts/Sim/PythonRandom.gd"
)

const ACTIONS: Array[String] = [
	"Hunt",
	"Siege",
	"Ward",
	"Profane",
]

const REPORT_DIRECTORY: String = (
	"user://balance_reports/experiments"
)


@export_category("Matrix")
@export var master_seed: int = 20260724
@export_range(1, 100000, 1) var games_per_cell: int = 100
@export_range(1, 1000, 1) var max_rounds: int = 60

@export_category("Documented Fixes")
@export var enable_fix_a_doctrine: bool = true
@export var enable_fix_b_profane: bool = true

@export_category("Non-Commitment Decisions")
@export_range(0.0, 5.0, 0.01) var softmax_temperature: float = 0.70
@export_range(0.0, 1.0, 0.01) var softmax_error_rate: float = 0.0

@export_category("Output")
@export_range(1, 10000, 1) var progress_every_games: int = 100
@export_range(1, 1000, 1) var yield_every_games: int = 10
@export var include_game_records: bool = false
@export var quit_when_finished: bool = true


func _ready() -> void:
	await _run_matrix()


func _run_matrix() -> void:
	if games_per_cell <= 0:
		_refuse(
			"games_per_cell must be positive."
		)
		return

	if max_rounds <= 0:
		_refuse(
			"max_rounds must be positive."
		)
		return

	var worker = ExperimentalBalanceRunnerData.new()
	worker.testbed = "Vanilla mirror"
	worker.include_mirror_matchups = true
	worker.enable_fix_a_doctrine = enable_fix_a_doctrine
	worker.enable_fix_b_profane = enable_fix_b_profane
	worker.use_custom_softmax = true
	worker.softmax_temperature = softmax_temperature
	worker.softmax_error_rate = softmax_error_rate
	worker.include_round_history_in_json = false

	var rules: RuleConfig = RuleConfig.de_v2()
	var policy = worker._policy()
	var seed_source = PythonRandomData.new(
		master_seed
	)
	var total_games: int = (
		ACTIONS.size()
		* ACTIONS.size()
		* games_per_cell
	)
	var completed_games: int = 0
	var started_msec: int = Time.get_ticks_msec()
	var cells: Dictionary = {}
	var records: Array[Dictionary] = []

	print("")
	print("RUNNING EXPERIMENTAL VANILLA PURE-STRATEGY MATRIX")
	print(
		"games_per_cell=%d total_games=%d FIX_A=%s FIX_B=%s"
		% [
			games_per_cell,
			total_games,
			str(
				enable_fix_a_doctrine
			),
			str(
				enable_fix_b_profane
			),
		]
	)

	for seat_zero_action: String in ACTIONS:
		for seat_one_action: String in ACTIONS:
			var cell_key: String = "%s_vs_%s" % [
				seat_zero_action,
				seat_one_action,
			]
			var cell: Dictionary = _new_cell(
				seat_zero_action,
				seat_one_action
			)

			worker.forced_action_seat_0 = (
				seat_zero_action
			)
			worker.forced_action_seat_1 = (
				seat_one_action
			)

			for game_index: int in range(
				games_per_cell
			):
				var game_seed: int = int(
					seed_source.randint(
						0,
						2147483647
					)
				)
				var record: Dictionary = worker._play_game(
					"Vanilla",
					"Vanilla",
					game_seed,
					game_index,
					rules,
					policy,
					max_rounds
				)

				if not bool(
					record.get(
						"ok",
						false
					)
				):
					push_error(
						"Pure matrix failed in %s: %s"
						% [
							cell_key,
							str(
								record
							),
						]
					)
					_finish(
						1
					)
					return

				_record_cell_game(
					cell,
					record
				)

				if include_game_records:
					records.append(
						record
					)

				completed_games += 1

				if (
					completed_games
					% progress_every_games
					== 0
					or completed_games == total_games
				):
					print(
						"PASS %d/%d games"
						% [
							completed_games,
							total_games,
						]
					)

				if (
					completed_games
					% yield_every_games
					== 0
				):
					await get_tree().process_frame

			cells[cell_key] = cell

	var elapsed_seconds: float = (
		float(
			Time.get_ticks_msec()
			- started_msec
		)
		/ 1000.0
	)
	var result: Dictionary = {
		"schema": "corruptor.balance_lab.pure_matrix.v1",
		"experimental": true,
		"canonical_files_modified": false,
		"testbed": "Vanilla mirror",
		"vanilla_stats": {
			"summon_cost": 6,
			"base_defense": 5,
			"return_threat": 1,
			"abilities": 0,
		},
		"master_seed": master_seed,
		"games_per_cell": games_per_cell,
		"games": total_games,
		"max_rounds": max_rounds,
		"fix_a_doctrine": enable_fix_a_doctrine,
		"fix_b_profane_denial_removed": (
			enable_fix_b_profane
		),
		"softmax_temperature": softmax_temperature,
		"softmax_error_rate": softmax_error_rate,
		"elapsed_seconds": elapsed_seconds,
		"cells": cells,
		"game_records": records,
	}
	var report_text: String = _format_report(
		result
	)
	var paths: Dictionary = _write_reports(
		result,
		report_text
	)

	print("")
	print(report_text)
	print("")
	print(
		"Pure matrix JSON: %s"
		% String(
			paths.get(
				"json",
				"not written"
			)
		)
	)
	print(
		"Pure matrix text: %s"
		% String(
			paths.get(
				"text",
				"not written"
			)
		)
	)

	_finish(
		0
	)


func _new_cell(
	seat_zero_action: String,
	seat_one_action: String
) -> Dictionary:
	return {
		"seat_zero_action": seat_zero_action,
		"seat_one_action": seat_one_action,
		"games": 0,
		"seat_zero_wins": 0,
		"seat_one_wins": 0,
		"first_player_wins": 0,
		"rounds_total": 0,
		"win_conditions": {},
		"actual_actions_seat_0": {},
		"actual_actions_seat_1": {},
	}


func _record_cell_game(
	cell: Dictionary,
	record: Dictionary
) -> void:
	cell["games"] = int(
		cell.get(
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

	if winner_id == 0:
		cell["seat_zero_wins"] = int(
			cell.get(
				"seat_zero_wins",
				0
			)
		) + 1
	else:
		cell["seat_one_wins"] = int(
			cell.get(
				"seat_one_wins",
				0
			)
		) + 1

	if winner_id == int(
		record.get(
			"first_player",
			-1
		)
	):
		cell["first_player_wins"] = int(
			cell.get(
				"first_player_wins",
				0
			)
		) + 1

	cell["rounds_total"] = int(
		cell.get(
			"rounds_total",
			0
		)
	) + int(
		record.get(
			"rounds",
			0
		)
	)

	var win_conditions: Dictionary = cell.get(
		"win_conditions",
		{}
	)

	_increment(
		win_conditions,
		String(
			record.get(
				"win_by",
				"Unknown"
			)
		)
	)
	cell["win_conditions"] = win_conditions

	var actions_by_player = record.get(
		"actions_by_player",
		[]
	)

	if (
		typeof(
			actions_by_player
		) == TYPE_ARRAY
		and actions_by_player.size() >= 2
	):
		var seat_zero_counts: Dictionary = cell.get(
			"actual_actions_seat_0",
			{}
		)
		var seat_one_counts: Dictionary = cell.get(
			"actual_actions_seat_1",
			{}
		)
		_add_counts(
			seat_zero_counts,
			actions_by_player[0]
		)
		_add_counts(
			seat_one_counts,
			actions_by_player[1]
		)
		cell["actual_actions_seat_0"] = (
			seat_zero_counts
		)
		cell["actual_actions_seat_1"] = (
			seat_one_counts
		)


func _format_report(
	result: Dictionary
) -> String:
	var lines: Array[String] = [
		"EXPERIMENTAL VANILLA PURE-STRATEGY MATRIX",
		"========================================",
		"Vanilla: summon 6 / defense 5 / return threat 1 / zero abilities",
		"FIX A: %s | FIX B: %s | temperature: %.2f"
		% [
			str(
				enable_fix_a_doctrine
			),
			str(
				enable_fix_b_profane
			),
			softmax_temperature,
		],
		"Each cell is seat 0's win rate against seat 1.",
		"",
	]
	var cells: Dictionary = result.get(
		"cells",
		{}
	)
	var header: String = "S0 \\ S1".rpad(
		12
	)

	for seat_one_action: String in ACTIONS:
		header += seat_one_action.lpad(
			10
		)

	lines.append(
		header
	)

	for seat_zero_action: String in ACTIONS:
		var row: String = seat_zero_action.rpad(
			12
		)

		for seat_one_action: String in ACTIONS:
			var cell: Dictionary = cells.get(
				"%s_vs_%s"
				% [
					seat_zero_action,
					seat_one_action,
				],
				{}
			)
			var games: int = int(
				cell.get(
					"games",
					0
				)
			)
			var wins: int = int(
				cell.get(
					"seat_zero_wins",
					0
				)
			)
			var win_rate: float = (
				100.0
				* float(
					wins
				)
				/ float(
					maxi(
						1,
						games
					)
				)
			)
			row += (
				"%.1f"
				% win_rate
			).lpad(
				10
			)

		lines.append(
			row
		)

	lines.append("")
	lines.append("CELL DETAIL")
	lines.append("----------------------------------------")

	for seat_zero_action: String in ACTIONS:
		for seat_one_action: String in ACTIONS:
			var cell_key: String = "%s_vs_%s" % [
				seat_zero_action,
				seat_one_action,
			]
			var cell: Dictionary = cells.get(
				cell_key,
				{}
			)
			var games: int = int(
				cell.get(
					"games",
					0
				)
			)

			lines.append(
				"%s: S0 %.1f%% | avg rounds %.2f | wins %s"
				% [
					cell_key,
					(
						100.0
						* float(
							cell.get(
								"seat_zero_wins",
								0
							)
						)
						/ float(
							maxi(
								1,
								games
							)
						)
					),
					(
						float(
							cell.get(
								"rounds_total",
								0
							)
						)
						/ float(
							maxi(
								1,
								games
							)
						)
					),
					str(
						cell.get(
							"win_conditions",
							{}
						)
					),
				]
			)

	return "\n".join(
		lines
	)


func _write_reports(
	result: Dictionary,
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
			"Unable to create matrix report directory: %s"
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
	var stem: String = "pure_matrix_%s_seed%d_games%d" % [
		timestamp,
		master_seed,
		int(
			result.get(
				"games",
				0
			)
		),
	]
	var text_path: String = "%s/%s.txt" % [
		REPORT_DIRECTORY,
		stem,
	]
	var json_path: String = "%s/%s.json" % [
		REPORT_DIRECTORY,
		stem,
	]
	var text_file = FileAccess.open(
		text_path,
		FileAccess.WRITE
	)
	var json_file = FileAccess.open(
		json_path,
		FileAccess.WRITE
	)
	var paths: Dictionary = {}

	if text_file != null:
		text_file.store_string(
			report_text
		)
		text_file.close()
		paths["text"] = ProjectSettings.globalize_path(
			text_path
		)

	if json_file != null:
		json_file.store_string(
			JSON.stringify(
				result,
				"\t",
				true
			)
		)
		json_file.close()
		paths["json"] = ProjectSettings.globalize_path(
			json_path
		)

	return paths


func _increment(
	counts: Dictionary,
	key_name: String
) -> void:
	counts[key_name] = int(
		counts.get(
			key_name,
			0
		)
	) + 1


func _add_counts(
	target: Dictionary,
	source_raw
) -> void:
	if typeof(
		source_raw
	) != TYPE_DICTIONARY:
		return

	var source: Dictionary = source_raw

	for key_raw in source.keys():
		var key_name: String = String(
			key_raw
		)
		target[key_name] = int(
			target.get(
				key_name,
				0
			)
		) + int(
			source.get(
				key_raw,
				0
			)
		)


func _refuse(
	reason: String
) -> void:
	push_error(
		reason
	)
	print(
		"PURE-STRATEGY MATRIX REFUSED: %s"
		% reason
	)
	_finish(
		1
	)


func _finish(
	exit_code: int
) -> void:
	if quit_when_finished:
		get_tree().quit(
			exit_code
		)
