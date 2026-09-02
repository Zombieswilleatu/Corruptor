# DEFENSE_REWARD_AUDIT_V0
extends SceneTree

const Harness = preload(
	"res://Scripts/Sim/Experiments/DefenseRewardAuditHarness.gd"
)

var _started_us: int = 0


func _initialize() -> void:
	var seeds: int = 2
	var seed: int = 799685594
	var panel: String = "smoke"

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = maxi(1, int(arg.trim_prefix("--seeds=")))
		elif arg.begins_with("--seed="):
			seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--panel="):
			panel = String(arg.trim_prefix("--panel="))

	if panel not in ["smoke", "all"]:
		push_error("--panel must be smoke or all")
		quit(2)
		return

	_started_us = Time.get_ticks_usec()

	print("")
	print("CORRUPTOR - DEFENSE REWARD / BOT STRATEGY AUDIT V0")
	print(
		"Panel %s | seeds %d | base seed %d"
		% [panel, seeds, seed]
	)
	print("")

	var result: Dictionary = Harness.run(
		RuleConfig.lab_v6_5(),
		seeds,
		seed,
		panel,
		Callable(self, "_on_progress")
	)

	var text: String = Harness.report_text(result)

	print("")
	print(text)
	print("")

	var downloads: String = (
		OS.get_environment("USERPROFILE").replace("\\", "/")
		+ "/Downloads"
	)

	var text_path: String = (
		downloads + "/DEFENSE_REWARD_AUDIT_V0_REPORT.txt"
	)
	var json_path: String = (
		downloads + "/DEFENSE_REWARD_AUDIT_V0_REPORT.json"
	)

	var tf = FileAccess.open(text_path, FileAccess.WRITE)
	if tf != null:
		tf.store_string(text)
		tf.close()

	var jf = FileAccess.open(json_path, FileAccess.WRITE)
	if jf != null:
		jf.store_string(JSON.stringify(result, "\t"))
		jf.close()

	print("Completed in %s" % _elapsed_text())
	print("Text report: " + text_path)
	print("JSON report: " + json_path)
	quit(0)


func _on_progress(event: Dictionary) -> void:
	var completed: int = int(event.get("completed", 0))
	var total: int = int(event.get("total", 1))

	if (
		completed != 1
		and completed % 10 != 0
		and completed != total
	):
		return

	print(
		"  %d/%d  %s vs %s  seed=%d c%d r%d  elapsed %s"
		% [
			completed,
			total,
			String(event.get("a", "")),
			String(event.get("b", "")),
			int(event.get("seed", 0)),
			int(event.get("cross", 0)),
			int(event.get("round", -1)),
			_elapsed_text(),
		]
	)


func _elapsed_text() -> String:
	var elapsed_seconds: int = int(
		(Time.get_ticks_usec() - _started_us) / 1000000
	)

	return "%02d:%02d" % [
		elapsed_seconds / 60,
		elapsed_seconds % 60,
	]
