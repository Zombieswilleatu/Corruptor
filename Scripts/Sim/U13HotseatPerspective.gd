extends RefCounted

# Only detached views and commands are transformed. Entity IDs and the match's
# canonical seats never change, including tie-breaks and seeded randomness.
const Match = preload("res://Scripts/Sim/U13Match.gd")
const Space = preload("res://Scripts/Sim/U13SpatialSpace.gd")
const SEAT_FIELDS: Array = ["owner", "player_id", "viewer_id", "winner", "seat", "first_player", "attacker_id", "defender_id", "target_player_id", "source_player_id", "previous_owner", "new_owner", "old_owner", "original_owner", "pid", "birth_owner", "charm_owner", "displaced_owner", "other_owner", "target_owner", "tumler_charge_owner", "tumler_engaged_owner", "muster_owner", "wright_owner"]
const SEAT_ARRAYS: Array = ["souls", "personal_tears", "lord_ids", "lord_stats", "castle_loadouts", "sigils", "accelerate", "summon_counts", "guard_placement_limits", "snare_rounds", "interlock_rounds", "reconfiguration", "hunger", "life_essence", "breach_wish_access", "relentless_pursuit", "invocation_rounds", "unlocked", "results", "active_castle_count", "active_castle_ids", "summons", "absent_rounds", "orias_marks", "march_round"]
var canonical
var seat: int = 0

static func pid(value: int, perspective: int) -> int:
	return 1 - value if perspective == 1 and value in [0, 1] else value

static func orient(value, perspective: int, key: String = ""):
	if perspective == 0:
		return value.duplicate(true) if value is Dictionary or value is Array else value
	if value is Dictionary:
		var result: Dictionary = {}
		for name in value: result[name] = orient(value[name], perspective, str(name))
		if key == "vacant_throne":
			for field in ["prior_counts", "counts", "present"]:
				if result.has(field): result[field].reverse()
		if key == "embolden_guard_history" and result.has("slots"): result.slots.reverse()
		return result
	if value is Array:
		var result: Array = []
		for entry in value: result.append(orient(entry, perspective))
		if key in SEAT_ARRAYS and result.size() == 2: result.reverse()
		return result
	if typeof(value) == TYPE_INT:
		if key in SEAT_FIELDS: return pid(value, perspective)
		if key == "x_fp": return Space.LANE_FP - value
		if key == "vx_fp": return -value
	if typeof(value) == TYPE_STRING and value in ["castle_zone:0", "castle_zone:1"]:
		return "castle_zone:%d" % (1 - int(value.right(1)))
	return value

func powers_to_match(powers: Array, relative_pid: int = 0) -> Array:
	var result: Array = orient(powers, seat)
	for index in range(result.size()):
		result[index].declaration_id = Match.declaration_id(pid(relative_pid, seat), canonical.round_number(), index)
	return result

func player_view(relative_pid: int, limit: int = -1) -> Dictionary:
	return orient(canonical.player_view(pid(relative_pid, seat), limit), seat)
func preview_submission(relative_pid: int, powers: Array, order: Dictionary = {}) -> Dictionary:
	if powers.any(func(source): return typeof(source) != TYPE_DICTIONARY): return Match.Data.invalid("declaration_shape_invalid")
	return orient(canonical.preview_submission(pid(relative_pid, seat), powers_to_match(powers, relative_pid), orient(order, seat)), seat)
func planning_session(_relative_pid: int): return null
func revision() -> int: return canonical.revision()
func next_hook() -> String: return canonical.next_hook()
func round_number() -> int: return canonical.round_number()
func rng_seed() -> String: return canonical.rng_seed()
func is_finished() -> bool: return canonical.is_finished()
func run_next_hook() -> Dictionary: return orient(canonical.run_next_hook(), seat)
func _event_cursor() -> int: return canonical._event_cursor()
func _player_events_since(relative_pid: int, cursor: int) -> Array:
	return orient(canonical._player_events_since(pid(relative_pid, seat), cursor), seat)
func _player_selected_events_since(relative_pid: int, cursor: int, types: Array, hook: String = "") -> Array:
	return orient(canonical._player_selected_events_since(pid(relative_pid, seat), cursor, types, hook), seat)
func _retire_completed_visual_samples() -> int: return canonical._retire_completed_visual_samples()
func _clone():
	var result = get_script().new()
	result.canonical = canonical._clone()
	result.seat = seat
	return result if result.canonical != null else null
