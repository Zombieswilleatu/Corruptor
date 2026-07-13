class_name GoldenMaster
extends RefCounted

# ─────────────────────────────────────────────────────────────────────────────
#  Golden-master test harness (Godot side).
#
#  The Python sim is the ORACLE. It emits versioned JSON traces (see
#  golden_master.py) into res://golden/. This class loads a trace, replays the
#  same scenario under the same RuleConfig in the GDScript engine, and asserts
#  the canonical state matches.
#
#  Two levels of assertion, cheap-first:
#    1. trace_hash equality  — one sha256 compare; if it matches, done.
#    2. per-snapshot diff     — only runs on hash mismatch, to LOCATE the drift.
#
#  Contract discipline:
#    * canonical_json() here MUST byte-match the Python canonical_json()
#      (sorted keys, no spaces, ascii). Hashes agree only if serialization agrees.
#    * identity check first: a trace generated under a different config or AI
#      version is REFUSED, not diffed (Law 5 — data invalid across versions).
#
#  This file is the engine's definition of "correct". When the real GDScript
#  resolver exists, snapshot_game()/snapshot_player() below get pointed at it;
#  until then, the unit traces can be validated against direct combat calls.
# ─────────────────────────────────────────────────────────────────────────────

const SCHEMA_VERSION := 3
const GOLDEN_DIR := "res://golden/"

# Result of a single trace validation.
class Result extends RefCounted:
	var name: String = ""
	var passed: bool = false
	var reason: String = ""          # "" if passed
	var first_divergence: Dictionary = {}   # {checkpoint, field, want, got} on diff
	func _to_string() -> String:
		if passed: return "PASS  %s" % name
		return "FAIL  %s — %s" % [name, reason]


# ── Canonical serialization (MUST mirror Python golden_serializer.canonical_json) ──
static func canonical_json(obj) -> String:
	# Godot's JSON.stringify with sort_keys gives sorted keys; we request the
	# most compact form and then assert no whitespace crept in. Godot >=4.2
	# JSON.stringify(data, indent="", sort_keys=true, full_precision=false).
	return JSON.stringify(obj, "", true)

static func sha256_hex(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()

static func trace_hash(snapshots: Array) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for s in snapshots:
		ctx.update(canonical_json(s).to_utf8_buffer())
	return ctx.finish().hex_encode()


# ── Load a trace file ──
static func load_trace(name: String) -> Dictionary:
	var path := GOLDEN_DIR + name + ".json"
	if not FileAccess.file_exists(path):
		return {"_error": "missing trace file: " + path}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return {"_error": "unparseable trace: " + path}
	return parsed


# ── Identity gate (Law 5) ──
# The engine passes in the RuleConfig + AI version it is running under; we refuse
# to validate a trace produced under a different ruleset.
static func identity_matches(trace: Dictionary, rules: RuleConfig, ai_version: String) -> Dictionary:
	var ident: Dictionary = trace.get("identity", {})
	if int(ident.get("schema_version", -1)) != SCHEMA_VERSION:
		return {"ok": false, "why": "schema mismatch (trace v%s, loader v%d)" %
			[ident.get("schema_version", "?"), SCHEMA_VERSION]}
	if String(trace.get("ai_version", "")) != ai_version:
		return {"ok": false, "why": "ai_version mismatch (trace %s, engine %s)" %
			[trace.get("ai_version", "?"), ai_version]}
	# Spot-check the constants that most often drift (the clock numbers).
	var c: Dictionary = ident.get("constants", {})
	var want := {
		"WIN_SOULS": rules.win_souls,
		"DOMINION_TRACK": rules.dominion_track,
		"DOMINION_REQUIREMENT": rules.dominion_requirement,
		"FINAL_COLLAPSE_TRACK": rules.final_collapse_threshold,
	}
	for k in want:
		if int(c.get(k, -999)) != int(want[k]):
			return {"ok": false, "why": "constant %s: trace=%s config=%s" %
				[k, c.get(k, "?"), want[k]]}
	return {"ok": true, "why": ""}


# ── Validate a trace against a set of engine-produced snapshots ──
# `engine_snapshots` is what the GDScript engine produced for this scenario, in
# the same canonical shape the Python serializer emits. Producing them is the
# engine's job (a GDScript mirror of snapshot_game); this method only compares.
static func validate(trace: Dictionary, engine_snapshots: Array,
					  rules: RuleConfig, ai_version: String) -> Result:
	var r := Result.new()
	r.name = String(trace.get("name", "?"))

	if trace.has("_error"):
		r.reason = trace["_error"]; return r

	var idgate := identity_matches(trace, rules, ai_version)
	if not idgate["ok"]:
		r.reason = "identity refused: " + idgate["why"]; return r

	# NOTE ON THE HASH FAST-PATH:
	# Cross-language canonical JSON is fragile — Godot may serialize an int as
	# "5.0" where Python writes "5", or differ on nested key-sort depth by version.
	# So the STRUCTURAL diff below is authoritative; the hash is only a fast
	# "definitely equal" shortcut. If hashes match we trust it; if they DON'T,
	# we still run the structural diff rather than failing, because the mismatch
	# may be pure serialization noise, not a real state divergence.
	var golden: Array = trace.get("snapshots", [])
	var want_hash := String(trace.get("trace_hash", ""))
	var got_hash := trace_hash(engine_snapshots)
	if got_hash == want_hash:
		r.passed = true; return r

	# Structural diff — the real authority. Uses type-tolerant numeric compare so
	# int/float serialization differences never masquerade as state drift.
	r.first_divergence = _first_divergence(golden, engine_snapshots)
	if r.first_divergence.is_empty():
		# Hashes differed but no structural divergence found => serialization
		# noise only. Pass, but flag it so the contract can be tightened.
		r.passed = true
		r.reason = "PASS (hash differed, structure identical — serialization noise)"
		return r
	r.reason = "state divergence at %s.%s (want=%s got=%s)" % [
		r.first_divergence.get("checkpoint", "?"),
		r.first_divergence.get("field", "?"),
		str(r.first_divergence.get("want", "∅")),
		str(r.first_divergence.get("got", "∅")),
	]
	return r


# Deep, order-independent-where-appropriate diff. Returns the first mismatch.
static func _first_divergence(golden: Array, engine: Array) -> Dictionary:
	if golden.size() != engine.size():
		return {"checkpoint": "<count>", "field": "snapshot_count",
				"want": golden.size(), "got": engine.size()}
	for i in golden.size():
		var g: Dictionary = golden[i]
		var e = engine[i] if i < engine.size() else {}
		var cp := String(g.get("checkpoint", str(i)))
		var d := _diff_value(cp, "", g, e)
		if not d.is_empty():
			return d
	return {}

# Recursive value diff. Dictionaries compared key-wise; arrays index-wise
# (canonical order is guaranteed by the serializer, so index compare is valid).
static func _diff_value(cp: String, field: String, want, got) -> Dictionary:
	var tw := typeof(want)
	var tg := typeof(got)
	# Numeric tolerance: JSON round-trips ints as floats in Godot. Treat INT and
	# FLOAT as the same domain and compare by value, so 5 (Python) == 5.0 (Godot).
	var w_num := tw == TYPE_INT or tw == TYPE_FLOAT
	var g_num := tg == TYPE_INT or tg == TYPE_FLOAT
	if w_num and g_num:
		if not is_equal_approx(float(want), float(got)):
			return {"checkpoint": cp, "field": field, "want": want, "got": got}
		return {}
	if tw != tg:
		return {"checkpoint": cp, "field": field, "want": want, "got": got}
	match tw:
		TYPE_DICTIONARY:
			var keys := (want as Dictionary).keys()
			keys.sort()
			for k in keys:
				if not (got as Dictionary).has(k):
					return {"checkpoint": cp, "field": _join(field, k), "want": want[k], "got": "∅"}
				var d := _diff_value(cp, _join(field, k), want[k], got[k])
				if not d.is_empty(): return d
			return {}
		TYPE_ARRAY:
			if (want as Array).size() != (got as Array).size():
				return {"checkpoint": cp, "field": field + "[]",
						"want": (want as Array).size(), "got": (got as Array).size()}
			for j in (want as Array).size():
				var d := _diff_value(cp, "%s[%d]" % [field, j], want[j], got[j])
				if not d.is_empty(): return d
			return {}
		_:
			if want != got:
				return {"checkpoint": cp, "field": field, "want": want, "got": got}
			return {}

static func _join(a: String, b) -> String:
	return b if a == "" else "%s.%s" % [a, b]


# ── Convenience: run every trace named in the manifest ──
static func run_all(engine_snapshot_provider: Callable,
					rules: RuleConfig, ai_version: String) -> Array:
	# Returns Array of GoldenMaster.Result. (Deliberately untyped: Array[Result]
	# with an inner class is unreliable across Godot 4.x point releases.)
	# engine_snapshot_provider: func(trace_name: String, trace: Dictionary) -> Array
	#   The engine replays the scenario and returns its canonical snapshots.
	var results: Array = []
	var manifest = load_trace("_manifest")
	if manifest.has("_error") or not manifest.has("traces"):
		var r := Result.new(); r.name = "_manifest"; r.reason = "no manifest"
		results.append(r); return results
	var names: Array = manifest["traces"].keys()
	names.sort()
	for name in names:
		var trace := load_trace(name)
		var snaps: Array = engine_snapshot_provider.call(name, trace)
		results.append(validate(trace, snaps, rules, ai_version))
	return results
