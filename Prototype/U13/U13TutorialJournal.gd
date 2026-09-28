extends RefCounted

# Presentation state only: never stored in a simulation world or a declaration.
const VERSION: String = "U13_CONTEXT_HELP_V1"
const NORMAL_LIMIT: int = 5
const HARD_LIMIT: int = 6
var seen: Dictionary = {}
var counts: Dictionary = {}
var last_opportunity: String = ""

func reset() -> void:
	seen.clear()
	counts.clear()
	last_opportunity = ""

func choose(candidates: Array, number: int, opportunity: String, preferences, early_limit: int = NORMAL_LIMIT) -> Dictionary:
	if opportunity == last_opportunity: return {}
	last_opportunity = opportunity
	var ranked: Array = candidates.duplicate()
	ranked.sort_custom(func(a, b): return a.id < b.id if a.priority == b.priority else a.priority > b.priority)
	var used: int = int(counts.get(str(number), 0))
	for lesson in ranked:
		if seen.has(lesson.id) or not preferences.should_show(lesson.id): continue
		var limit: int = HARD_LIMIT if lesson.get("urgent", false) else mini(NORMAL_LIMIT, early_limit)
		if used >= limit: continue
		seen[lesson.id] = true
		for concept in lesson.get("concepts", []): seen[concept] = true
		counts[str(number)] = used + 1
		return lesson.duplicate(true)
	return {}

func snapshot() -> Dictionary:
	return {"version": VERSION, "seen": seen.duplicate(), "counts": counts.duplicate(), "last_opportunity": last_opportunity}

func restore(raw) -> void:
	reset()
	if typeof(raw) != TYPE_DICTIONARY or raw.get("version") != VERSION: return
	if typeof(raw.get("seen")) == TYPE_DICTIONARY:
		for key in raw.seen:
			if typeof(key) == TYPE_STRING and raw.seen[key] == true: seen[key] = true
	if typeof(raw.get("counts")) == TYPE_DICTIONARY:
		for key in raw.counts:
			if str(key).is_valid_int() and typeof(raw.counts[key]) in [TYPE_INT, TYPE_FLOAT]: counts[str(key)] = clampi(int(raw.counts[key]), 0, HARD_LIMIT)
	if typeof(raw.get("last_opportunity")) == TYPE_STRING: last_opportunity = raw.last_opportunity
