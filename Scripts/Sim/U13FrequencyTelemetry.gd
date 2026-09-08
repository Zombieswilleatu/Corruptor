extends RefCounted

var rounds: Array = []
var _row: Dictionary = {}
var _bases: Dictionary = {}
var _owners: Dictionary = {}
var _souls: Array = []


func begin(round_number: int, view: Dictionary) -> void:
	_row = {
		"round": round_number,
		"marching_start": null,
		"marching_end": null,
		"peak_marchers": 0,
		"peak_by_owner": [0, 0],
		"waiters": {},
		"arrivals": {},
		"spawns_by_owner": [0, 0],
		"powers": {},
		"fizzle_causes": {},
		"tears_by_source": {},
		"passive_triggers": {},
		"souls_gained_by_hook": {},
		"castles_destroyed": 0,
		"ticks_observed": 0,
		"neutral_tears": view.world.neutral_tears,
		"personal_tears": view.world.get("personal_tears", null),
		"artillery_shots": {},
		"artillery_by_instance": {},
		"rout": {},
		"castle_actions": {},
		"activation_integrity": [],
		"personal_tears_by_source": {},
		"both_players_passed": false
	}
	for player_id in [0, 1]:
		for lane in ["Lord", "Castle"]:
			var key: String = "%d:%s" % [player_id, lane]
			_row.waiters[key] = {"peak": 0, "ticks_present": 0, "ticks_at_least_five": 0}
			_row.arrivals[key] = 0
	_bases = {}
	_owners = {}
	_souls = view.world.souls.duplicate()
	_observe(view.world.entities, false)


func observe_hook(view: Dictionary, hook: String) -> void:
	_observe(view.world.entities, false)
	var gains: Array = [0, 0]
	for player_id in [0, 1]:
		gains[player_id] = maxi(0, int(view.world.souls[player_id]) - int(_souls[player_id]))
	if gains != [0, 0]:
		_row.souls_gained_by_hook[hook] = gains
	_souls = view.world.souls.duplicate()
	_row.neutral_tears = view.world.neutral_tears
	_row.personal_tears = view.world.get("personal_tears", null)


func consume(events: Array) -> void:
	for event in events:
		var data: Dictionary = event.data
		match event.type:
			"MARCHER_SPAWNED":
				_row.spawns_by_owner[int(data.owner)] += 1
				_owners[data.id] = data.owner
			"MARCHING_STARTED":
				_bases = {}
				for unit in data.units:
					_bases[unit.id] = unit.duplicate(true)
				_row.marching_start = _observe(data.units, false)
			"MARCHING_TICK":
				var units: Array = []
				for unit in data.units:
					if data.get("unit_format", "") == "attribute_delta_v1" and _bases.has(unit.id):
						var restored: Dictionary = _bases[unit.id].duplicate(true)
						restored.owner = unit.owner
						restored.attributes.merge(unit.attributes, true)
						units.append(restored)
					else:
						units.append(unit)
				_observe(units, true)
				_row.ticks_observed += 1
			"MARCHING_FINISHED":
				_row.marching_end = _observe(data.units, false)
			"MARCHER_WAITING":
				var key: String = "%d:%s" % [int(_owners[data.entity_id]), data.lane]
				_row.arrivals[key] += 1
			"POWER_DECLARED", "POWER_RESOLVED", "FIZZLE_INVALID_TARGET":
				var key: String = "%d:%s" % [int(data.player_id), data.power_id]
				if not _row.powers.has(key):
					_row.powers[key] = {"declared": 0, "resolved": 0, "fizzled": 0}
				var counter: String = {
					"POWER_DECLARED": "declared",
					"POWER_RESOLVED": "resolved",
					"FIZZLE_INVALID_TARGET": "fizzled"
				}[event.type]
				_row.powers[key][counter] += 1
				if counter == "fizzled":
					_increment(
						_row.fizzle_causes,
						key + ":" + String(data.get("result", {}).get("reason", "unspecified"))
					)
			"CONSTRUCTION_PROGRESS", "CASTLE_REPAIRED", "CASTLE_ACTIVATED", "CASTLE_ACTION_FIZZLED":
				var key: String = "%d:%s" % [int(data.player_id), event.type]
				_increment(_row.castle_actions, key)
				if event.type == "CASTLE_ACTIVATED":
					_row.activation_integrity.append(data.after)
				if data.get("reconstruction", false):
					_increment(_row.castle_actions, str(data.player_id) + ":reconstructions")
				if event.type == "CONSTRUCTION_PROGRESS" and data.complete:
					_increment(_row.castle_actions, str(data.player_id) + ":builds_completed")
			"ROUT_APPLIED":
				_increment(_row.rout, "activations")
				_increment(_row.rout, "affected_units", data.affected_ids.size())
				_increment(_row.rout, "empty_activations", 1 if data.affected_ids.is_empty() else 0)
			"ROUT_RECOVERING", "ROUT_ENDED":
				_increment(_row.rout, event.type)
			"ARTILLERY_FIRED":
				_increment(_row.artillery_by_instance, data.engine_id)

				_increment(
					_row.artillery_shots,
					(
						"%d:%s"
						% [int(data.player_id), "normal" if data.shot == "normal" else "WarMachine"]
					)
				)
			"PERSONAL_TEAR_CREATED":
				_increment(
					_row.personal_tears_by_source,
					"%d:%s" % [int(data.player_id), data.source],
					int(data.amount)
				)
			"NEUTRAL_TEAR_CREATED":
				_increment(_row.tears_by_source, String(data.source), int(data.amount))
			"PICKING_THE_BONES", "SIFTING_THE_RUINS", "GEM_DAGGER", "FEAR_AURA":
				_increment(_row.passive_triggers, "%d:%s" % [int(data.player_id), event.type])
			"CASTLE_DESTROYED":
				_row.castles_destroyed += 1


func finish(both_passed: bool) -> Dictionary:
	_row.both_players_passed = both_passed
	var result: Dictionary = _row.duplicate(true)
	rounds.append(result)
	return result.duplicate(true)


func _observe(units: Array, tick: bool) -> Dictionary:
	var counts: Array = [0, 0]
	var waiters: Dictionary = {"0:Lord": 0, "0:Castle": 0, "1:Lord": 0, "1:Castle": 0}
	for unit in units:
		if unit.get("kind", "marcher") != "marcher":
			continue
		counts[int(unit.owner)] += 1
		_owners[unit.id] = unit.owner
		if unit.attributes.get("waiting", false):
			waiters["%d:%s" % [int(unit.owner), unit.attributes.lane]] += 1
	for key in waiters:
		var metric: Dictionary = _row.waiters[key]
		metric.peak = maxi(metric.peak, waiters[key])
		if tick:
			metric.ticks_present += 1 if waiters[key] > 0 else 0
			metric.ticks_at_least_five += 1 if waiters[key] >= 5 else 0
	_row.peak_marchers = maxi(_row.peak_marchers, counts[0] + counts[1])
	for player_id in [0, 1]:
		_row.peak_by_owner[player_id] = maxi(_row.peak_by_owner[player_id], counts[player_id])
	return {"total": counts[0] + counts[1], "by_owner": counts}


static func summarize(rows: Array) -> Dictionary:
	var start: Array = []
	var end: Array = []
	var peaks: Array = []
	var spawns: Array = [0, 0]
	var powers: Dictionary = {}
	var tears: Dictionary = {}
	var both_spawned: int = 0
	var all_pass: int = 0
	var castles: int = 0
	var arrivals: Dictionary = {}
	var waiters: Dictionary = {}
	var fizzles: Dictionary = {}
	var triggers: Dictionary = {}
	var souls: Dictionary = {}
	var artillery: Dictionary = {}
	var castle_actions: Dictionary = {}
	var instance_shots: Dictionary = {}
	var rout: Dictionary = {}
	var activation_integrity: Array = []
	var personal: Dictionary = {}
	for row in rows:
		for key in row.get("artillery_by_instance", {}):
			_increment(instance_shots, key, row.artillery_by_instance[key])
		for key in row.get("rout", {}):
			_increment(rout, key, row.rout[key])
		activation_integrity.append_array(row.get("activation_integrity", []))
		for key in row.get("castle_actions", {}):
			_increment(castle_actions, key, row.castle_actions[key])
		for key in row.artillery_shots:
			_increment(artillery, key, row.artillery_shots[key])
		for key in row.personal_tears_by_source:
			_increment(personal, key, row.personal_tears_by_source[key])
		all_pass += 1 if row.both_players_passed else 0
		castles += int(row.castles_destroyed)
		for key in row.arrivals:
			_increment(arrivals, key, row.arrivals[key])
		for key in row.fizzle_causes:
			_increment(fizzles, key, row.fizzle_causes[key])
		for key in row.passive_triggers:
			_increment(triggers, key, row.passive_triggers[key])
		for key in row.souls_gained_by_hook:
			if not souls.has(key):
				souls[key] = [0, 0]
			for player_id in [0, 1]:
				souls[key][player_id] += row.souls_gained_by_hook[key][player_id]
		for key in row.waiters:
			if not waiters.has(key):
				waiters[key] = {
					"peak": 0,
					"ticks_present": 0,
					"ticks_at_least_five": 0,
					"rounds_at_least_five": 0
				}
			waiters[key].peak = maxi(waiters[key].peak, row.waiters[key].peak)
			waiters[key].ticks_present += row.waiters[key].ticks_present
			waiters[key].ticks_at_least_five += row.waiters[key].ticks_at_least_five
			waiters[key].rounds_at_least_five += 1 if row.waiters[key].peak >= 5 else 0
		start.append(row.marching_start.total)
		end.append(row.marching_end.total)
		peaks.append(row.peak_marchers)
		for player_id in [0, 1]:
			spawns[player_id] += row.spawns_by_owner[player_id]
		if row.spawns_by_owner[0] > 0 and row.spawns_by_owner[1] > 0:
			both_spawned += 1
		for key in row.powers:
			if not powers.has(key):
				powers[key] = {"declared": 0, "resolved": 0, "fizzled": 0}
			for counter in row.powers[key]:
				powers[key][counter] += row.powers[key][counter]
		for key in row.tears_by_source:
			_increment(tears, key, row.tears_by_source[key])
	return {
		"round_samples": rows.size(),
		"artillery_shots": artillery,
		"artillery_by_instance": instance_shots,
		"rout": rout,
		"castle_actions": castle_actions,
		"activation_integrity": distribution(activation_integrity),
		"personal_tears_by_source": personal,
		"both_players_passed_rounds": all_pass,
		"castles_destroyed": castles,
		"arrivals": arrivals,
		"waiters": waiters,
		"fizzle_causes": fizzles,
		"passive_triggers": triggers,
		"souls_gained_by_hook": souls,
		"marching_start": distribution(start),
		"marching_end": distribution(end),
		"round_peak": distribution(peaks),
		"spawns_by_owner": spawns,
		"rounds_both_sides_spawned": both_spawned,
		"powers": powers,
		"tears_by_source": tears,
		"threshold_power_ratios": null,
		"threshold_note":
		"No active power in this slice has a counted Marcher threshold. Future Lord thresholds are not measured."
	}


static func distribution(values: Array) -> Dictionary:
	if values.is_empty():
		return {"n": 0, "min": null, "max": null, "mean": null, "histogram": {}}
	var ordered: Array = values.duplicate()
	ordered.sort()
	var histogram: Dictionary = {}
	var total: int = 0
	for value in ordered:
		_increment(histogram, str(value))
		total += int(value)
	return {
		"n": ordered.size(),
		"min": ordered.front(),
		"max": ordered.back(),
		"mean": float(total) / float(ordered.size()),
		"histogram": histogram
	}


static func _increment(target: Dictionary, key: String, amount: int = 1) -> void:
	target[key] = int(target.get(key, 0)) + amount
