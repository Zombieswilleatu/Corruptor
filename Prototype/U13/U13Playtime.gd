extends RefCounted
## Non-authoritative, real-time telemetry. Runtime clock origins are never saved.
const VERSION: int = 1
const MAX_MS: int = 9007199254740991
var decision_ms: int = 0
var resolution_ms: int = 0
var history_complete: bool = true
var _last_ms: int = -1
var _mode: String = "excluded"

func sample(now_ms: int, mode: String) -> void:
	if _last_ms >= 0:
		var elapsed: int = maxi(0, now_ms - _last_ms)
		if _mode == "decision": decision_ms += elapsed
		elif _mode == "resolution": resolution_ms += elapsed
	_last_ms = now_ms
	_mode = mode

func snapshot() -> Dictionary:
	return {"version": VERSION, "decision_ms": decision_ms,
		"resolution_ms": resolution_ms, "total_ms": decision_ms + resolution_ms,
		"history_complete": history_complete}

func restore(raw) -> bool:
	decision_ms = 0
	resolution_ms = 0
	history_complete = false
	_last_ms = -1
	_mode = "excluded"
	if typeof(raw) != TYPE_DICTIONARY or raw.get("version") != VERSION:
		return false
	for key in ["decision_ms", "resolution_ms", "total_ms"]:
		var value = raw.get(key)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]: return false
		if not is_finite(float(value)) or value < 0 or value > MAX_MS or float(value) != floor(float(value)): return false
	if typeof(raw.get("history_complete")) != TYPE_BOOL: return false
	if int(raw.total_ms) != int(raw.decision_ms) + int(raw.resolution_ms): return false
	decision_ms = int(raw.decision_ms)
	resolution_ms = int(raw.resolution_ms)
	history_complete = raw.history_complete
	return true

static func duration(ms: int) -> String:
	var seconds: int = int(ms / 1000.0)
	return "%02d:%02d:%02d" % [int(seconds / 3600.0), int(seconds / 60.0) % 60, seconds % 60]

func summary() -> String:
	return "%s%s · Decisions/review %s · Resolution %s" % [
		duration(decision_ms + resolution_ms), " (partial)" if not history_complete else "",
		duration(decision_ms), duration(resolution_ms)]
