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
	var reason: String = ""
	var first_divergence: Dictionary = {}

	func _to_string() -> String:
		if passed:
			return "PASS  %s" % name

		return "FAIL  %s — %s" % [
			name,
			reason,
		]


# ── Canonical serialization (MUST mirror Python golden_serializer.canonical_json) ──
static func canonical_json(
	obj
) -> String:
	# Godot's JSON.stringify with sort_keys gives sorted keys; request the most
	# compact form. Structural comparison remains authoritative.
	return JSON.stringify(
		obj,
		"",
		true
	)


static func sha256_hex(
	text: String
) -> String:
	var context := HashingContext.new()

	context.start(
		HashingContext.HASH_SHA256
	)

	context.update(
		text.to_utf8_buffer()
	)

	return context.finish().hex_encode()


static func trace_hash(
	snapshots: Array
) -> String:
	var context := HashingContext.new()

	context.start(
		HashingContext.HASH_SHA256
	)

	for snapshot in snapshots:
		context.update(
			canonical_json(
				snapshot
			).to_utf8_buffer()
		)

	return context.finish().hex_encode()


# ── Load a trace file ──
static func load_trace(
	name: String
) -> Dictionary:
	var path := (
		GOLDEN_DIR
		+ name
		+ ".json"
	)

	if not FileAccess.file_exists(
		path
	):
		return {
			"_error": (
				"missing trace file: "
				+ path
			),
		}

	var text := FileAccess.get_file_as_string(
		path
	)

	var parsed = JSON.parse_string(
		text
	)

	if (
		parsed == null
		or typeof(
			parsed
		) != TYPE_DICTIONARY
	):
		return {
			"_error": (
				"unparseable trace: "
				+ path
			),
		}

	return parsed


# ── Identity gate (Law 5) ──
static func identity_matches(
	trace: Dictionary,
	rules: RuleConfig,
	ai_version: String
) -> Dictionary:
	var identity: Dictionary = trace.get(
		"identity",
		{}
	)

	if int(
		identity.get(
			"schema_version",
			-1
		)
	) != SCHEMA_VERSION:
		return {
			"ok": false,
			"why": (
				"schema mismatch (trace v%s, loader v%d)"
				% [
					identity.get(
						"schema_version",
						"?"
					),
					SCHEMA_VERSION,
				]
			),
		}

	if String(
		trace.get(
			"ai_version",
			""
		)
	) != ai_version:
		return {
			"ok": false,
			"why": (
				"ai_version mismatch (trace %s, engine %s)"
				% [
					trace.get(
						"ai_version",
						"?"
					),
					ai_version,
				]
			),
		}

	var constants: Dictionary = identity.get(
		"constants",
		{}
	)

	var expected := {
		"WIN_SOULS": rules.win_souls,
		"DOMINION_TRACK": rules.dominion_track,
		"DOMINION_REQUIREMENT": (
			rules.dominion_requirement
		),
		"FINAL_COLLAPSE_TRACK": (
			rules.final_collapse_threshold
		),
	}

	for key in expected:
		if int(
			constants.get(
				key,
				-999
			)
		) != int(
			expected[key]
		):
			return {
				"ok": false,
				"why": (
					"constant %s: trace=%s config=%s"
					% [
						key,
						constants.get(
							key,
							"?"
						),
						expected[key],
					]
				),
			}

	return {
		"ok": true,
		"why": "",
	}


# ── Validate a trace against engine-produced snapshots ──
static func validate(
	trace: Dictionary,
	engine_snapshots: Array,
	rules: RuleConfig,
	ai_version: String
) -> Result:
	var result := Result.new()

	result.name = String(
		trace.get(
			"name",
			"?"
		)
	)

	if trace.has(
		"_error"
	):
		result.reason = String(
			trace["_error"]
		)

		return result

	var identity_gate := identity_matches(
		trace,
		rules,
		ai_version
	)

	if not bool(
		identity_gate.get(
			"ok",
			false
		)
	):
		result.reason = (
			"identity refused: "
			+ String(
				identity_gate.get(
					"why",
					"unknown identity mismatch"
				)
			)
		)

		return result

	# Cross-language canonical JSON can differ cosmetically, so hash equality is
	# only a fast pass. Structural comparison is authoritative.
	var golden_snapshots: Array = trace.get(
		"snapshots",
		[]
	)

	var wanted_hash := String(
		trace.get(
			"trace_hash",
			""
		)
	)

	var received_hash := trace_hash(
		engine_snapshots
	)

	if received_hash == wanted_hash:
		result.passed = true

		return result

	var divergences: Array[Dictionary] = _all_divergences(
		golden_snapshots,
		engine_snapshots,
		16
	)

	if divergences.is_empty():
		result.passed = true
		result.reason = (
			"PASS (hash differed, structure identical — serialization noise)"
		)

		return result

	result.first_divergence = divergences[0]
	result.reason = _divergence_summary(
		divergences
	)

	return result


# Collect several independent mismatches from the earliest shared checkpoint.
# Array count mismatches are recorded without index-walking that array, preventing
# one missing card from producing a useless cascade of shifted-card differences.
static func _all_divergences(
	golden: Array,
	engine: Array,
	limit: int
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	var shared_count: int = min(
		golden.size(),
		engine.size()
	)

	for index: int in range(
		shared_count
	):
		var golden_snapshot = golden[
			index
		]

		var engine_snapshot = engine[
			index
		]

		var checkpoint: String = str(
			index
		)

		if typeof(
			golden_snapshot
		) == TYPE_DICTIONARY:
			checkpoint = String(
				golden_snapshot.get(
					"checkpoint",
					checkpoint
				)
			)

		_collect_divergences(
			checkpoint,
			"",
			golden_snapshot,
			engine_snapshot,
			results,
			limit
		)

		if not results.is_empty():
			break

	if (
		results.is_empty()
		and golden.size() != engine.size()
	):
		results.append({
			"checkpoint": "<count>",
			"field": "snapshot_count",
			"want": golden.size(),
			"got": engine.size(),
		})

	return results


static func _collect_divergences(
	checkpoint: String,
	field: String,
	want,
	got,
	results: Array[Dictionary],
	limit: int
) -> void:
	if results.size() >= limit:
		return

	var want_type: int = typeof(
		want
	)

	var got_type: int = typeof(
		got
	)

	var want_is_number: bool = (
		want_type == TYPE_INT
		or want_type == TYPE_FLOAT
	)

	var got_is_number: bool = (
		got_type == TYPE_INT
		or got_type == TYPE_FLOAT
	)

	if (
		want_is_number
		and got_is_number
	):
		if not is_equal_approx(
			float(
				want
			),
			float(
				got
			)
		):
			results.append({
				"checkpoint": checkpoint,
				"field": field,
				"want": want,
				"got": got,
			})

		return

	if want_type != got_type:
		results.append({
			"checkpoint": checkpoint,
			"field": field,
			"want": want,
			"got": got,
		})

		return

	match want_type:
		TYPE_DICTIONARY:
			var want_dictionary: Dictionary = want
			var got_dictionary: Dictionary = got
			var keys: Array = want_dictionary.keys()

			keys.sort()

			for key in keys:
				if results.size() >= limit:
					return

				if not got_dictionary.has(
					key
				):
					results.append({
						"checkpoint": checkpoint,
						"field": _join(
							field,
							key
						),
						"want": want_dictionary[
							key
						],
						"got": "∅",
					})

					continue

				_collect_divergences(
					checkpoint,
					_join(
						field,
						key
					),
					want_dictionary[
						key
					],
					got_dictionary[
						key
					],
					results,
					limit
				)

		TYPE_ARRAY:
			var want_array: Array = want
			var got_array: Array = got

			if want_array.size() != got_array.size():
				results.append({
					"checkpoint": checkpoint,
					"field": (
						field
						+ "[]"
					),
					"want": want_array.size(),
					"got": got_array.size(),
				})

				return

			for index: int in range(
				want_array.size()
			):
				if results.size() >= limit:
					return

				_collect_divergences(
					checkpoint,
					"%s[%d]"
					% [
						field,
						index,
					],
					want_array[
						index
					],
					got_array[
						index
					],
					results,
					limit
				)

		_:
			if want != got:
				results.append({
					"checkpoint": checkpoint,
					"field": field,
					"want": want,
					"got": got,
				})


static func _divergence_summary(
	divergences: Array[Dictionary]
) -> String:
	var parts: Array[String] = []

	for divergence: Dictionary in divergences:
		parts.append(
			"%s.%s (want=%s got=%s)"
			% [
				String(
					divergence.get(
						"checkpoint",
						"?"
					)
				),
				String(
					divergence.get(
						"field",
						"?"
					)
				),
				str(
					divergence.get(
						"want",
						"∅"
					)
				),
				str(
					divergence.get(
						"got",
						"∅"
					)
				),
			]
		)

	return (
		"state divergences: "
		+ "; ".join(
			parts
		)
	)


# Deep, order-independent-where-appropriate diff.
#
# IMPORTANT: compare all shared checkpoints before reporting snapshot-count
# differences. This lets a game that ends in a different round reveal the first
# real state divergence instead of stopping at "<count>.snapshot_count".
static func _first_divergence(
	golden: Array,
	engine: Array
) -> Dictionary:
	var shared_count: int = min(
		golden.size(),
		engine.size()
	)

	for index: int in range(
		shared_count
	):
		var golden_snapshot = golden[
			index
		]

		var engine_snapshot = engine[
			index
		]

		if typeof(
			golden_snapshot
		) != TYPE_DICTIONARY:
			return {
				"checkpoint": str(
					index
				),
				"field": "<snapshot_type>",
				"want": typeof(
					golden_snapshot
				),
				"got": typeof(
					engine_snapshot
				),
			}

		var golden_dictionary: Dictionary = (
			golden_snapshot
		)

		var checkpoint := String(
			golden_dictionary.get(
				"checkpoint",
				str(
					index
				)
			)
		)

		var divergence := _diff_value(
			checkpoint,
			"",
			golden_snapshot,
			engine_snapshot
		)

		if not divergence.is_empty():
			return divergence

	if golden.size() != engine.size():
		return {
			"checkpoint": "<count>",
			"field": "snapshot_count",
			"want": golden.size(),
			"got": engine.size(),
		}

	return {}


# Recursive value diff. Dictionaries compare key-wise; arrays compare index-wise.
static func _diff_value(
	checkpoint: String,
	field: String,
	want,
	got
) -> Dictionary:
	var want_type := typeof(
		want
	)

	var got_type := typeof(
		got
	)

	var want_is_number := (
		want_type == TYPE_INT
		or want_type == TYPE_FLOAT
	)

	var got_is_number := (
		got_type == TYPE_INT
		or got_type == TYPE_FLOAT
	)

	if (
		want_is_number
		and got_is_number
	):
		if not is_equal_approx(
			float(
				want
			),
			float(
				got
			)
		):
			return {
				"checkpoint": checkpoint,
				"field": field,
				"want": want,
				"got": got,
			}

		return {}

	if want_type != got_type:
		return {
			"checkpoint": checkpoint,
			"field": field,
			"want": want,
			"got": got,
		}

	match want_type:
		TYPE_DICTIONARY:
			var want_dictionary: Dictionary = want
			var got_dictionary: Dictionary = got

			var keys := want_dictionary.keys()

			keys.sort()

			for key in keys:
				if not got_dictionary.has(
					key
				):
					return {
						"checkpoint": checkpoint,
						"field": _join(
							field,
							key
						),
						"want": want_dictionary[
							key
						],
						"got": "∅",
					}

				var divergence := _diff_value(
					checkpoint,
					_join(
						field,
						key
					),
					want_dictionary[
						key
					],
					got_dictionary[
						key
					]
				)

				if not divergence.is_empty():
					return divergence

			return {}

		TYPE_ARRAY:
			var want_array: Array = want
			var got_array: Array = got

			if want_array.size() != got_array.size():
				return {
					"checkpoint": checkpoint,
					"field": (
						field
						+ "[]"
					),
					"want": want_array.size(),
					"got": got_array.size(),
				}

			for index: int in range(
				want_array.size()
			):
				var divergence := _diff_value(
					checkpoint,
					"%s[%d]"
					% [
						field,
						index,
					],
					want_array[
						index
					],
					got_array[
						index
					]
				)

				if not divergence.is_empty():
					return divergence

			return {}

		_:
			if want != got:
				return {
					"checkpoint": checkpoint,
					"field": field,
					"want": want,
					"got": got,
				}

			return {}


static func _join(
	left: String,
	right
) -> String:
	if left.is_empty():
		return String(
			right
		)

	return "%s.%s" % [
		left,
		right,
	]


# ── Convenience: run every trace named in the manifest ──
static func run_all(
	engine_snapshot_provider: Callable,
	rules: RuleConfig,
	ai_version: String
) -> Array:
	var results: Array = []

	var manifest = load_trace(
		"_manifest"
	)

	if (
		manifest.has(
			"_error"
		)
		or not manifest.has(
			"traces"
		)
	):
		var result := Result.new()

		result.name = "_manifest"
		result.reason = "no manifest"

		results.append(
			result
		)

		return results

	var names: Array = manifest[
		"traces"
	].keys()

	names.sort()

	for name in names:
		var trace := load_trace(
			name
		)

		var snapshots: Array = (
			engine_snapshot_provider.call(
				name,
				trace
			)
		)

		results.append(
			validate(
				trace,
				snapshots,
				rules,
				ai_version
			)
		)

	return results
