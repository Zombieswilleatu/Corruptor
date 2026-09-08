extends SceneTree

const Reference = preload("res://Scripts/Sim/Reference/U13MarchingBeforeOptimization.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")
var failures: int = 0


func _init() -> void:
	_spawn_spread()
	_contact_and_steering()
	_join_queue()
	_round_boundary()
	_spatial_query_edges()
	_reference_equivalence()
	print("U13 spatial Marching failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _world() -> Dictionary:
	return {"entities": Ids.new().snapshot(), "data": {}}


func _add(world: Dictionary, name: String, owner: int, changes: Dictionary = {}) -> String:
	var ids = Ids.new()
	ids.restore(world.entities)
	var attributes: Dictionary = Marching.profile("Vulture", "Castle", owner, 0, 1)
	attributes.merge(changes, true)
	var row: Dictionary = ids.create("marcher", name, 0, owner, attributes)
	world.entities = ids.snapshot()
	return row.entity.id


static func _reaction(
	world: Dictionary, _fact: Dictionary, _seed: String, _order: Array
) -> Dictionary:
	return {"action": "resolved", "world": world, "events": []}


func _run(world: Dictionary, round_number: int = 1) -> Dictionary:
	return Marching.resolve(
		{
			"world": world,
			"round": round_number,
			"hook": Timeline.MARCHING,
			"seed": "spatial_fixture",
			"player_order": [0, 1]
		},
		Callable(self, "_reaction")
	)


func _events(result: Dictionary, kind: String) -> Array:
	var found: Array = []
	for row in result.events:
		if row.event.type == kind:
			found.append(row.event.data)
	return found


func _unit(rows: Array, id: String) -> Dictionary:
	for unit in rows:
		if unit.id == id:
			return unit
	return {}


func _spawn_spread() -> void:
	var ids = Ids.new()
	for index in range(3):
		var row: Dictionary = ids.create(
			"marcher", "spawn", index, 0, Marching.profile("Vulture", "Castle", 0, 1, 2)
		)
		_check(
			(
				Marching.place_spawn(ids, row.entity.id, "spatial_fixture").action
				== "spawn_positioned"
			),
			"spawn_position_accepted"
		)
	var first: Dictionary = ids.snapshot()
	var replay = Ids.new()
	for index in range(3):
		var row: Dictionary = replay.create(
			"marcher", "spawn", index, 0, Marching.profile("Vulture", "Castle", 0, 1, 2)
		)
		Marching.place_spawn(replay, row.entity.id, "spatial_fixture")
	_check(first == replay.snapshot(), "spawn_keyed_replay_exact")
	var xs: Dictionary = {}
	var ys: Dictionary = {}
	for left in first.entities:
		xs[left.attributes.x_fp] = true
		ys[left.attributes.y_fp] = true
		for right in first.entities:
			if left.id != right.id:
				_check(
					(
						Marching._distance(left.attributes, right.attributes)
						>= Marching.CENTER_GAP_FP * Marching.CENTER_GAP_FP
					),
					"spawn_centers_have_clearance"
				)
	_check(xs.size() > 1 and ys.size() > 1, "spawn_varies_both_actual_coordinates")
	var result: Dictionary = _run({"entities": first, "data": {}})
	if not _check(result.action == "resolved", "birth_hold_resolves"):
		return
	_check(result.world.entities == first, "birth_hold_preserves_real_spawn_coordinates")


func _contact_and_steering() -> void:
	var world: Dictionary = _world()
	_add(world, "left", 0, {"x_fp": 1200, "y_fp": 50, "step_fp": 0})
	_add(world, "right", 1, {"x_fp": 1200, "y_fp": 550, "step_fp": 0})
	var result: Dictionary = _run(world)
	if not _check(result.action == "resolved", "separated_fixture_resolves"):
		return
	_check(_events(result, "MARCHER_CONTACT").is_empty(), "same_forward_position_is_not_contact")
	world = _world()
	var left: String = _add(world, "left", 0, {"x_fp": 900, "y_fp": 100})
	_add(world, "right", 1, {"x_fp": 1500, "y_fp": 500})
	var before: Dictionary = world.duplicate(true)
	result = _run(world)
	if not _check(result.action == "resolved", "steering_fixture_resolves"):
		return
	_check(world == before, "movement_does_not_mutate_input")
	var ticks: Array = _events(result, "MARCHING_TICK")
	_check(
		_unit(ticks[0].units, left).attributes.y_fp > 100,
		"steering_changes_authoritative_lateral_position"
	)
	var contacts: Array = _events(result, "MARCHER_CONTACT")
	_check(contacts.size() == 1, "steering_reaches_enemy_contact")
	for contact in contacts:
		_check(
			(
				Marching._distance(contact.units[0].attributes, contact.units[1].attributes)
				<= Marching.CONTACT_FP * Marching.CONTACT_FP
			),
			"combat_requires_actual_intersection"
		)
	_check(_events(result, "MARCHER_DEFEATED").size() == 2, "contact_resolves_simultaneous_combat")
	var reversed: Dictionary = before.duplicate(true)
	reversed.entities.entities.reverse()
	_check(_run(reversed) == result, "movement_and_contacts_ignore_registry_order")
	var playback = Playback.new()
	var tape: Array = []
	for row in result.events:
		tape.append(row.event)
	if not _check(playback.build(tape), "spatial_playback_builds"):
		return
	_check(ticks[0].unit_format == "attribute_delta_v1", "tick_uses_compact_attribute_format")
	_check(not ticks[0].units[0].has("origin"), "tick_does_not_repeat_immutable_identity_metadata")
	var full_tape: Array = tape.duplicate(true)
	var bases: Dictionary = {}
	for unit in before.entities.entities:
		bases[unit.id] = unit
	for event in full_tape:
		if event.type != "MARCHING_TICK":
			continue
		var rows: Array = []
		for delta in event.data.units:
			var unit: Dictionary = bases[delta.id].duplicate(true)
			unit.owner = delta.owner
			unit.attributes.merge(delta.attributes, true)
			rows.append(unit)
		event.data.units = rows
		event.data.erase("unit_format")
	var full_playback = Playback.new()
	_check(full_playback.build(full_tape), "full_tick_tapes_remain_readable")
	for at in [0.0, 0.015, 0.24, 1.125, 3.0, 6.0]:
		_check(
			playback.sample(at) == full_playback.sample(at),
			"compact_and_full_tick_playback_identical"
		)
	var unchanged: Array = tape.duplicate(true)
	for tick in [0, 7, 20, 70, 199]:
		var sampled: Dictionary = playback.sample(6.0 * float(tick + 1) / 200.0)
		_check(
			sampled.units.size() == ticks[tick].units.size(), "tick_playback_preserves_population"
		)
		for unit in sampled.units:
			var recorded: Dictionary = _unit(ticks[tick].units, unit.id)
			_check(
				(
					is_equal_approx(unit.attributes.visual_x, float(recorded.attributes.x_fp))
					and is_equal_approx(unit.attributes.visual_y, float(recorded.attributes.y_fp))
				),
				"tick_playback_uses_both_real_coordinates"
			)
	_check(tape == unchanged, "playback_cannot_mutate_recorded_positions")
	world = _world()
	_add(world, "one", 0, {"x_fp": 1200, "step_fp": 0})
	_add(world, "other_lane", 1, {"x_fp": 1200, "step_fp": 0, "lane": "Lord"})
	_check(_events(_run(world), "MARCHER_CONTACT").is_empty(), "separate_lanes_never_contact")


func _join_queue() -> void:
	var world: Dictionary = _world()
	_add(
		world,
		"anchor",
		0,
		{"x_fp": 1200, "hp": 100, "max_hp": 100, "attack": 1, "armor": 0, "step_fp": 0}
	)
	_add(
		world,
		"first",
		1,
		{"x_fp": 1300, "hp": 10, "max_hp": 10, "attack": 1, "armor": 0, "step_fp": 0}
	)
	var incoming: String = _add(world, "incoming", 1, {"x_fp": 1430, "y_fp": 450})
	var result: Dictionary = _run(world)
	if not _check(result.action == "resolved", "contact_queue_resolves"):
		return
	var at: Dictionary = _unit(_events(result, "MARCHING_TICK")[40].units, incoming)
	_check(
		not at.is_empty() and at.attributes.x_fp < 1430 and at.attributes.hp == 5,
		"incoming_moves_and_waits_without_receiving_duel_damage"
	)
	var contacts: Array = _events(result, "MARCHER_CONTACT")
	var clashes: Array = _events(result, "MARCHER_CLASH")
	if _check(contacts.size() == 2 and clashes.size() == 2, "joined_chit_gets_second_duel"):
		_check(contacts[1].tick > clashes[0].end_tick, "lane_duels_resolve_sequentially")
		_check(contacts[1].units[1].id == incoming, "waiting_joiner_enters_next_duel")


func _round_boundary() -> void:
	var world: Dictionary = _world()
	for owner in [0, 1]:
		_add(
			world,
			"long_" + str(owner),
			owner,
			{"x_fp": 1200, "hp": 40, "max_hp": 40, "attack": 1, "armor": 0, "step_fp": 0}
		)
	var first: Dictionary = _run(world)
	if not _check(first.action == "resolved", "long_duel_first_round"):
		return
	_check(
		first.world.data.marching_duels.size() == 1, "unfinished_duel_persists_at_round_boundary"
	)
	var decoded: Dictionary = Data.copy_data(JSON.parse_string(JSON.stringify(first.world)))
	_check(Marching.valid(decoded), "unfinished_duel_json_valid")
	var second: Dictionary = _run(first.world, 2)
	var replay: Dictionary = _run(decoded, 2)
	_check(second == replay and second.action == "resolved", "unfinished_duel_json_replay_exact")
	if second.action == "resolved":
		_check(
			(
				_events(second, "MARCHER_DEFEATED").size() == 2
				and second.world.data.marching_duels.is_empty()
			),
			"unfinished_duel_finishes_once_next_round"
		)
	var bad: Dictionary = decoded.duplicate(true)
	bad.entities.entities[0].attributes.y_fp = 100.5
	_check(not Marching.valid(bad), "fractional_lateral_position_rejected")
	bad = decoded.duplicate(true)
	bad.data.marching_duels.Castle.units[0].id = "invented"
	_check(not Marching.valid(bad), "unknown_duel_participant_rejected")
	bad = decoded.duplicate(true)
	bad.data.marching_duels.Castle.next_tick += 1
	_check(not Marching.valid(bad), "forged_duel_clock_rejected")


func _spatial_query_edges() -> void:
	var rows: Array = []
	for x in [0, 127, 128, 255, 256, 511, 600]:
		for y in [0, 127, 128, 255, 256, 511, 600]:
			rows.append({"id": "%d:%d" % [x, y], "attributes": {"x_fp": x, "y_fp": y}})
	for shift in [7, 8]:
		var radius: int = 84 if shift == 7 else 180
		var grid: Dictionary = Marching._spatial_grid(rows, shift)
		var complete: bool = true
		for center in rows:
			var candidates: Array = Marching._near_rows(center.attributes, grid, shift)
			for other in rows:
				if Marching._distance(center.attributes, other.attributes) <= radius * radius:
					complete = complete and other in candidates
		_check(complete, "spatial_query_keeps_all_contacts_across_cell_edges_%d" % radius)


func _reference_equivalence() -> void:
	for count in [6, 24, 48]:
		for mode in ["travel", "contact"]:
			var ids = Ids.new()
			ids.create("card", "unrelated", 0, 0, {"nested": {"values": [1, 2, 3]}})
			for index in range(count):
				var owner: int = index % 2
				var lane: String = "Lord" if mode == "travel" and owner == 0 else "Castle"
				var attributes: Dictionary = Marching.profile(
					Marching.SUITS[index % 4], lane, owner, 0, 1
				)
				var created: Dictionary = ids.create(
					"marcher", "equivalence", index, owner, attributes
				)
				Marching.place_spawn(ids, created.entity.id, "spatial_fixture")
				if mode == "contact":
					var unit: Dictionary = ids.get_entity(created.entity.id)
					unit.attributes.x_fp += 900 if owner == 0 else -900
					ids.update(unit.id, owner, unit.attributes)
			var world: Dictionary = {"entities": ids.snapshot(), "data": {}}
			# Include an unordered import; both implementations canonicalize IDs.
			world.entities.entities.reverse()
			for round_number in [1, 2]:
				var before: Dictionary = world.duplicate(true)
				var expected: Dictionary = Reference.resolve(
					{
						"world": world,
						"round": round_number,
						"hook": Timeline.MARCHING,
						"seed": "spatial_fixture",
						"player_order": [0, 1]
					},
					Callable(self, "_reaction")
				)
				var actual: Dictionary = _run(world, round_number)
				if not _check(
					expected.action == "resolved" and actual.action == "resolved",
					"optimized_reference_fixture_resolves"
				):
					return
				_check(
					actual == expected,
					"optimized_exact_reference_%s_n%d_r%d" % [mode, count, round_number]
				)
				_check(world == before, "optimized_phase_leaves_input_untouched")
				world = actual.world


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok
