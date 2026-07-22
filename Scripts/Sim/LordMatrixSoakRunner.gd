extends Node


const AI_POLICY: String = "softmax-2026.07-v1-golden"
const MATCHUPS_PER_SEED: int = 81
const GENERATOR_PATH: String = "res://lord_matrix_soak_master.py"
const BATCH_PATH: String = "user://lord_matrix_soak_batch.json"

const GoldenMasterData = preload(
		"res://Scripts/Sim/GoldenMaster.gd"
)

const LordMatrixTestsData = preload(
		"res://Scripts/Sim/LordMatrixTests.gd"
)


@export var master_seed: int = 20260719
@export_range(0, 1000000, 1) var seed_start: int = 0
@export_range(1, 1000000, 1) var seed_count: int = 100
@export_range(1, 1000, 1) var batch_seed_count: int = 5
@export var python_command: String = "py"


func _ready() -> void:
		print("")
		print("RUNNING LORD MATRIX PARITY SOAK")
		print(
				"master_seed=%d seed_indexes=%d..%d batch_size=%d"
				% [
						master_seed,
						seed_start,
						seed_start + seed_count - 1,
						batch_seed_count,
				]
		)

		var passed: bool = _run_soak()

		if passed:
				print("")
				print("LORD MATRIX PARITY SOAK PASS")
				print(
						"%d seeds x %d ordered matchups = %d games passed."
						% [
								seed_count,
								MATCHUPS_PER_SEED,
								seed_count * MATCHUPS_PER_SEED,
						]
				)
		else:
				print("")
				print("LORD MATRIX PARITY SOAK FAILED")

		get_tree().quit(
				0 if passed else 1
		)


func _run_soak() -> bool:
		if seed_start < 0:
				return _configuration_failure(
						"seed_start must be at least zero."
				)

		if seed_count <= 0:
				return _configuration_failure(
						"seed_count must be positive."
				)

		if batch_seed_count <= 0:
				return _configuration_failure(
						"batch_seed_count must be positive."
				)

		if python_command.is_empty():
				return _configuration_failure(
						"python_command is empty."
				)

		var rules: RuleConfig = RuleConfig.de_v2()
		var batch_path: String = ProjectSettings.globalize_path(
				BATCH_PATH
		)
		var completed_seeds: int = 0
		var completed_games: int = 0

		while completed_seeds < seed_count:
				var current_start: int = (
						seed_start + completed_seeds
				)
				var current_count: int = mini(
						batch_seed_count,
						seed_count - completed_seeds
				)

				print("")
				print(
						"Generating oracle batch for seed indexes %d..%d..."
						% [
								current_start,
								current_start + current_count - 1,
						]
				)

				if not _generate_batch(
						current_start,
						current_count,
						batch_path
				):
						return false

				var batch: Dictionary = _load_batch(
						batch_path
				)

				if batch.has("_error"):
						print(
								"BATCH LOAD FAILURE: %s"
								% String(
										batch.get(
												"_error",
												"unknown_batch_load_failure"
										)
								)
						)
						print(
								"Retained batch: %s"
								% batch_path
						)
						return false

				var batch_failure: String = _batch_failure(
						batch,
						rules,
						current_start,
						current_count
				)

				if not batch_failure.is_empty():
						print(
								"BATCH VALIDATION FAILURE: %s"
								% batch_failure
						)
						print(
								"Retained batch: %s"
								% batch_path
						)
						return false

				var scenarios: Array = batch.get(
						"scenarios",
						[]
				)
				var games_in_batch: int = 0

				for raw_scenario in scenarios:
						if typeof(raw_scenario) != TYPE_DICTIONARY:
								print(
										"SOAK DIVERGENCE: batch contains a non-Dictionary scenario."
								)
								print(
										"Retained batch: %s"
										% batch_path
								)
								return false

						var scenario: Dictionary = raw_scenario
						var result: Dictionary = (
								LordMatrixTestsData._run_scenario(
										scenario,
										rules
								)
						)

						if not bool(
								result.get(
										"passed",
										false
								)
						):
								_report_divergence(
										scenario,
										result,
										batch_path
								)
								return false

						games_in_batch += 1
						completed_games += 1

						if (
								games_in_batch
								% MATCHUPS_PER_SEED
								== 0
						):
								print(
										"PASS seed index %d (%d/%d total seeds; %d games)"
										% [
												current_start
												+ int(
														games_in_batch
														/ MATCHUPS_PER_SEED
												)
												- 1,
												completed_seeds
												+ int(
														games_in_batch
														/ MATCHUPS_PER_SEED
												),
												seed_count,
												completed_games,
										]
								)

				completed_seeds += current_count

				var remove_error: int = (
						DirAccess.remove_absolute(
								batch_path
						)
				)

				if (
						remove_error != OK
						and remove_error != ERR_FILE_NOT_FOUND
				):
						print(
								"WARNING: passed batch could not be removed: %s"
								% batch_path
						)

		return true


func _generate_batch(
		current_start: int,
		current_count: int,
		batch_path: String
) -> bool:
		var generator_path: String = (
				ProjectSettings.globalize_path(
						GENERATOR_PATH
				)
		)
		var output: Array = []
		var arguments := PackedStringArray([
				"-3",
				"-B",
				generator_path,
				"--master-seed",
				str(master_seed),
				"--seed-start",
				str(current_start),
				"--seed-count",
				str(current_count),
				"--output",
				batch_path,
		])
		var exit_code: int = OS.execute(
				python_command,
				arguments,
				output,
				true,
				false
		)

		if not output.is_empty():
				print(
						String(output[0]).strip_edges()
				)

		if exit_code != 0:
				print(
						"PYTHON ORACLE FAILURE: command=%s exit_code=%d"
						% [
								python_command,
								exit_code,
						]
				)
				print(
						"Generator: %s"
						% generator_path
				)
				return false

		return true


func _load_batch(
		batch_path: String
) -> Dictionary:
		var file_handle := FileAccess.open(
				batch_path,
				FileAccess.READ
		)

		if file_handle == null:
				return {
						"_error": (
								"unable_to_open_batch error=%d"
								% FileAccess.get_open_error()
						),
				}

		var parsed = JSON.parse_string(
				file_handle.get_as_text()
		)
		file_handle.close()

		if typeof(parsed) != TYPE_DICTIONARY:
				return {
						"_error": "batch_root_is_not_a_dictionary",
				}

		return parsed


func _batch_failure(
		batch: Dictionary,
		rules: RuleConfig,
		expected_start: int,
		expected_count: int
) -> String:
		var identity_gate: Dictionary = (
				GoldenMasterData.identity_matches(
						batch,
						rules,
						AI_POLICY
				)
		)

		if not bool(
				identity_gate.get(
						"ok",
						false
				)
		):
				return (
						"identity refused: %s"
						% String(
								identity_gate.get(
										"why",
										"unknown_identity_mismatch"
								)
						)
				)

		if int(batch.get("master_seed", -1)) != master_seed:
				return "master seed mismatch"

		if int(batch.get("seed_start", -1)) != expected_start:
				return "seed start mismatch"

		if int(batch.get("seed_count", -1)) != expected_count:
				return "seed count mismatch"

		var scenarios_raw = batch.get(
				"scenarios",
				[]
		)

		if typeof(scenarios_raw) != TYPE_ARRAY:
				return "scenarios are not an Array"

		var expected_scenario_count: int = (
				expected_count * MATCHUPS_PER_SEED
		)

		if scenarios_raw.size() != expected_scenario_count:
				return (
						"scenario count mismatch: want=%d got=%d"
						% [
								expected_scenario_count,
								scenarios_raw.size(),
						]
				)

		return ""


func _report_divergence(
		scenario: Dictionary,
		result: Dictionary,
		batch_path: String
) -> void:
		print("")
		print("SOAK DIVERGENCE — STOPPED ON FIRST FAILURE")
		print(
				"matchup: %s vs %s"
				% [
						String(
								scenario.get(
										"player_zero_lord",
										""
								)
						),
						String(
								scenario.get(
										"player_one_lord",
										""
								)
						),
				]
		)
		print(
				"seed: %d"
				% int(
						scenario.get(
								"seed",
								-1
						)
				)
		)
		print(
				"seed_index: %d"
				% int(
						scenario.get(
								"seed_index",
								-1
						)
				)
		)
		print(
				"failure: %s"
				% String(
						result.get(
								"text",
								"unknown_failure"
						)
				)
		)
		var expected_terminal_raw = scenario.get(
				"terminal_snapshot",
				{}
		)
		var actual_snapshot_raw = result.get(
				"actual_snapshot",
				{}
		)

		if (
				typeof(expected_terminal_raw) == TYPE_DICTIONARY
				and typeof(actual_snapshot_raw) == TYPE_DICTIONARY
		):
				var expected_terminal: Dictionary = expected_terminal_raw
				var actual_snapshot: Dictionary = actual_snapshot_raw

				if (
						int(actual_snapshot.get("round", -1))
						== int(scenario.get("round", -2))
				):
						var expected_checkpoint: Dictionary = expected_terminal.duplicate(true)
						expected_checkpoint["checkpoint"] = String(
								actual_snapshot.get("checkpoint", "")
						)

						var divergences: Array[Dictionary] = (
								GoldenMasterData._all_divergences(
										[expected_checkpoint],
										[actual_snapshot],
										32
								)
						)

						print("terminal-round structural differences:")

						if divergences.is_empty():
								print("  none (hash-only serialization difference)")
						else:
								for divergence: Dictionary in divergences:
										print(
												"  %s expected=%s actual=%s"
												% [
														String(divergence.get("field", "?")),
														str(divergence.get("want", "<missing>")),
														str(divergence.get("got", "<missing>")),
												]
										)
				else:
						print(
								"actual checkpoint snapshot: %s"
								% JSON.stringify(actual_snapshot, "", true)
						)

		print(
				"expected terminal snapshot: %s"
				% JSON.stringify(expected_terminal_raw, "", true)
		)
		print(
				"Retained failed batch: %s"
				% batch_path
		)


func _configuration_failure(
		reason: String
) -> bool:
		print(
				"SOAK CONFIGURATION FAILURE: %s"
				% reason
		)
		return false
