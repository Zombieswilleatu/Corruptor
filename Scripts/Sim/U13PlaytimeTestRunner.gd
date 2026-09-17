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
	breakdown_checks()
	check(Playtime.duration(3661000) == "01:01:01", "duration renders hours minutes seconds")
	print("U13 playtime failures: ", failures)
	quit(1 if failures else 0)

func breakdown_checks() -> void:
	var timer = Playtime.new()
	timer.sample(0, "decision", 1, "slaver")
	timer.sample(5000, "decision", 1, "work_target")
	timer.sample(17000, "decision", 1, "combat_commitment")
	timer.sample(27000, "decision", 1, "work_target")
	timer.sample(30000, "resolution", 1)
	timer.sample(33000, "decision", 1, "aftermath")
	timer.sample(35000, "excluded", 1)
	timer.sample(95000, "resolution", 2)
	timer.sample(96000, "decision", 2, "slaver")
	timer.sample(99000, "excluded", 2)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(timer.snapshot()))
	check(saved.breakdown_complete and saved.total_ms == 39000 and saved.rounds.size() == 2, "round breakdown excludes a minute paused and partitions total time")
	check(saved.rounds[0].decision_ms == 32000 and saved.rounds[0].resolution_ms == 3000 and saved.rounds[1].decision_ms == 3000 and saved.rounds[1].resolution_ms == 1000, "round transitions attribute the preceding interval to the preceding round")
	check(saved.rounds[0].decision_surfaces_ms == {"slaver": 5000.0, "work_target": 15000.0, "combat_commitment": 10000.0, "aftermath": 2000.0}, "revisiting Work Target accumulates separately from combat and Aftermath")
	var loaded = Playtime.new()
	check(loaded.restore(saved) and loaded.snapshot() == timer.snapshot(), "round and screen breakdown round-trips through JSON exactly")
	loaded.sample(900000, "decision", 2, "slaver")
	loaded.sample(902000, "excluded", 2)
	check(loaded.snapshot().rounds[1].decision_surfaces_ms.slaver == 5000 and loaded.snapshot().total_ms == 41000, "resuming a partial round adds to that screen without counting offline time")
	var legacy: Dictionary = {"version": 1, "decision_ms": 10000, "resolution_ms": 2000, "total_ms": 12000, "history_complete": true}
	check(loaded.restore(legacy) and loaded.history_complete and not loaded.snapshot().breakdown_complete, "version-one totals remain valid with explicitly incomplete breakdown")
	loaded.sample(0, "decision", 9, "combat_commitment")
	loaded.sample(4000, "excluded", 9)
	var migrated: Dictionary = loaded.snapshot()
	check(migrated.unattributed == {"decision_ms": 10000, "resolution_ms": 2000} and migrated.rounds.size() == 1 and migrated.rounds[0].round == 9 and migrated.rounds[0].decision_ms == 4000, "old totals are unattributed; no invented earlier-round measurements")
	for bad in ["duplicate_round", "negative_surface", "surface_mismatch", "round_mismatch", "bad_unattributed"]:
		var corrupt: Dictionary = saved.duplicate(true)
		match bad:
			"duplicate_round": corrupt.rounds.append(corrupt.rounds[0].duplicate(true))
			"negative_surface": corrupt.rounds[0].decision_surfaces_ms.slaver = -1
			"surface_mismatch": corrupt.rounds[0].decision_surfaces_ms.slaver = 1
			"round_mismatch": corrupt.rounds[0].total_ms = 1
			"bad_unattributed": corrupt.unattributed.resolution_ms = 9999
		check(not loaded.restore(corrupt) and loaded.snapshot().total_ms == 0 and loaded.snapshot().rounds.is_empty(), "corrupt breakdown rejects atomically: " + bad)
