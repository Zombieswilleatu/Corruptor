extends RefCounted
## Non-authoritative, real-time telemetry. Runtime clock origins are never saved.
const VERSION: int = 2
const MAX_MS: int = 9007199254740991
var decision_ms: int = 0
var resolution_ms: int = 0
var history_complete: bool = true
var _last_ms: int = -1
var _mode: String = "excluded"
var _round: int = 0
var _surface: String = "other"
var _rounds: Dictionary = {}
var _breakdown_complete: bool = true

func sample(now_ms: int, mode: String, round_now: int = 0, surface: String = "other") -> void:
	if _last_ms >= 0:
		var elapsed: int = maxi(0, now_ms - _last_ms)
		if _mode == "decision": decision_ms += elapsed
		elif _mode == "resolution": resolution_ms += elapsed
		if elapsed > 0 and _round > 0 and _mode in ["decision", "resolution"]:
			if not _rounds.has(_round):
				_rounds[_round] = {"round": _round, "decision_ms": 0, "resolution_ms": 0, "decision_surfaces_ms": {}}
			var row: Dictionary = _rounds[_round]
			row[_mode + "_ms"] += elapsed
			if _mode == "decision":
				row.decision_surfaces_ms[_surface] = int(row.decision_surfaces_ms.get(_surface, 0)) + elapsed
	_last_ms = now_ms
	_mode = mode
	_round = round_now
	_surface = surface if not surface.is_empty() else "other"

func snapshot() -> Dictionary:
	var rows: Array = []
	var keys: Array = _rounds.keys()
	keys.sort()
	var attributed_decision: int = 0
	var attributed_resolution: int = 0
	for key in keys:
		var row: Dictionary = _rounds[key].duplicate(true)
		row["total_ms"] = row.decision_ms + row.resolution_ms
		rows.append(row)
		attributed_decision += row.decision_ms
		attributed_resolution += row.resolution_ms
	var unattributed: Dictionary = {"decision_ms": decision_ms - attributed_decision, "resolution_ms": resolution_ms - attributed_resolution}
	return {"version": VERSION, "decision_ms": decision_ms,
		"resolution_ms": resolution_ms, "total_ms": decision_ms + resolution_ms,
		"history_complete": history_complete, "rounds": rows, "unattributed": unattributed,
		"breakdown_complete": history_complete and _breakdown_complete and unattributed.decision_ms == 0 and unattributed.resolution_ms == 0}

func restore(raw) -> bool:
	decision_ms = 0
	resolution_ms = 0
	history_complete = false
	_last_ms = -1
	_mode = "excluded"
	_round = 0
	_surface = "other"
	_rounds = {}
	_breakdown_complete = false
	if typeof(raw) != TYPE_DICTIONARY or not _valid_ms(raw.get("version")) or (raw.version != 1 and raw.version != VERSION):
		return false
	for key in ["decision_ms", "resolution_ms", "total_ms"]:
		if not _valid_ms(raw.get(key)): return false
	if typeof(raw.get("history_complete")) != TYPE_BOOL: return false
	if int(raw.total_ms) != int(raw.decision_ms) + int(raw.resolution_ms): return false
	var restored_rounds: Dictionary = {}
	if raw.version == VERSION:
		if typeof(raw.get("rounds")) != TYPE_ARRAY or typeof(raw.get("unattributed")) != TYPE_DICTIONARY or typeof(raw.get("breakdown_complete")) != TYPE_BOOL: return false
		var sums: Dictionary = {"decision_ms": 0, "resolution_ms": 0}
		for entry in raw.rounds:
			if typeof(entry) != TYPE_DICTIONARY or not _valid_ms(entry.get("round")) or int(entry.round) < 1: return false
			var number: int = int(entry.round)
			if restored_rounds.has(number): return false
			for key in ["decision_ms", "resolution_ms", "total_ms"]:
				if not _valid_ms(entry.get(key)): return false
			if int(entry.total_ms) != int(entry.decision_ms) + int(entry.resolution_ms) or typeof(entry.get("decision_surfaces_ms")) != TYPE_DICTIONARY: return false
			var surfaces: Dictionary = {}
			var surface_total: int = 0
			for key in entry.decision_surfaces_ms:
				if typeof(key) != TYPE_STRING or key.is_empty() or not _valid_ms(entry.decision_surfaces_ms[key]): return false
				surfaces[key] = int(entry.decision_surfaces_ms[key])
				surface_total += surfaces[key]
				if surface_total > int(entry.decision_ms): return false
			if surface_total != int(entry.decision_ms): return false
			restored_rounds[number] = {"round": number, "decision_ms": int(entry.decision_ms), "resolution_ms": int(entry.resolution_ms), "decision_surfaces_ms": surfaces}
			for key in sums:
				sums[key] += int(entry[key])
				if sums[key] > int(raw[key]): return false
		for key in sums:
			if not _valid_ms(raw.unattributed.get(key)) or sums[key] + int(raw.unattributed[key]) != int(raw[key]): return false
		if raw.breakdown_complete and (not raw.history_complete or int(raw.unattributed.decision_ms) > 0 or int(raw.unattributed.resolution_ms) > 0): return false
	decision_ms = int(raw.decision_ms)
	resolution_ms = int(raw.resolution_ms)
	history_complete = raw.history_complete
	_rounds = restored_rounds
	_breakdown_complete = bool(raw.get("breakdown_complete", false))
	return true

static func _valid_ms(value) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= 0 and value <= MAX_MS and float(value) == floor(float(value))

static func duration(ms: int) -> String:
	var seconds: int = int(ms / 1000.0)
	return "%02d:%02d:%02d" % [int(seconds / 3600.0), int(seconds / 60.0) % 60, seconds % 60]

func summary() -> String:
	return "%s%s · Decisions/review %s · Resolution %s" % [
		duration(decision_ms + resolution_ms), " (partial)" if not history_complete else "",
		duration(decision_ms), duration(resolution_ms)]
