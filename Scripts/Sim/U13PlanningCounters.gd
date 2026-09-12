extends RefCounted

# Read-only instrumentation facade, usable by both policies with identical
# authority underneath. Counts payloads entering validation, not imagined grids.
var owner
var calls: Array = []

func _init(source) -> void:
	owner = source

func player_view(pid: int, history_limit: int = -1) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = owner.player_view(pid, history_limit)
	record("player_view", 0, 0, started)
	return result

func snapshot() -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = owner.snapshot()
	record("snapshot", 0, 0, started)
	return result

func round_number() -> int:
	return owner.round_number()

func rng_seed() -> String:
	return owner.rng_seed()

func legal_power_candidates(pid: int, candidates: Array) -> Array:
	var started: int = Time.get_ticks_usec()
	var result: Array = owner.legal_power_candidates(pid, candidates)
	record("power", candidates.size(), result.size(), started)
	return result

func legal_order_candidates(pid: int, powers: Array, candidates: Array) -> Array:
	var started: int = Time.get_ticks_usec()
	var result: Array = owner.legal_order_candidates(pid, powers, candidates)
	record("order", candidates.size(), result.size(), started)
	return result

func preview_submission(pid: int, powers: Array, order: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = owner.preview_submission(pid, powers, order)
	record("complete_preview", 1, 0 if result.action == "invalid" else 1, started)
	return result

func record(kind: String, generated: int, legal: int, started: int) -> void:
	calls.append({"kind": kind, "candidates": generated, "legal": legal, "ms": (Time.get_ticks_usec() - started) / 1000.0})

func summary(elapsed: float) -> Dictionary:
	var count: int = 0
	var ms: float = 0.0
	var projection_ms: float = 0.0
	for row in calls:
		count += row.candidates
		if row.kind in ["player_view", "snapshot"]:
			projection_ms += row.ms
		else:
			ms += row.ms
	return {"calls": calls, "candidates_validated": count, "validation_ms": ms, "projection_snapshot_ms": projection_ms, "planning_ms": elapsed, "outside_validation_ms": elapsed - ms}
