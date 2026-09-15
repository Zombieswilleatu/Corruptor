extends SceneTree
const Playtime = preload("res://Prototype/U13/U13Playtime.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + message)
func _initialize() -> void:
	var timer = Playtime.new()
	timer.sample(0, "excluded")
	timer.sample(5000, "decision")
	timer.sample(7000, "resolution")
	timer.sample(10000, "excluded")
	timer.sample(20000, "decision")
	timer.sample(21000, "excluded")
	check(timer.decision_ms == 3000 and timer.resolution_ms == 3000 and timer.snapshot().total_ms == 6000, "setup and paused intervals excluded; decision and resolution partition total")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(timer.snapshot()))
	var restored = Playtime.new()
	check(restored.restore(saved) and restored.history_complete, "JSON metadata round trip preserves complete history")
	restored.sample(999999, "decision")
	restored.sample(1000999, "excluded")
	check(restored.decision_ms == 4000 and restored.resolution_ms == 3000, "loading rebases clock without counting time closed")
	restored.sample(2000000, "excluded")
	check(restored.snapshot().total_ms == 7000, "completed match does not keep accumulating")
	check(not restored.restore(null) and not restored.history_complete and restored.snapshot().total_ms == 0, "legacy save starts explicitly partial history")
	restored.sample(4, "decision")
	restored.sample(1004, "excluded")
	var partial = Playtime.new()
	check(partial.restore(restored.snapshot()) and not partial.history_complete and partial.decision_ms == 1000, "partial marker survives subsequent saves")
	for bad in [-1, 1.5, "1000", true, INF, NAN]:
		var corrupt: Dictionary = saved.duplicate(true)
		corrupt.decision_ms = bad
		check(not restored.restore(corrupt) and restored.snapshot().total_ms == 0, "bad timing rejected without partial state: " + str(bad))
	var inconsistent: Dictionary = saved.duplicate(true)
	inconsistent.total_ms = 1
	check(not restored.restore(inconsistent), "inconsistent total rejected")
	check(Playtime.duration(3661000) == "01:01:01", "duration renders hours minutes seconds")
	print("U13 playtime failures: ", failures)
	quit(1 if failures else 0)
