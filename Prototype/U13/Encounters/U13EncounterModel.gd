extends RefCounted
const Arena = preload("res://Scripts/Sim/U13LaneSandbox.gd")
const Marching = Arena.Marching
const Monsters = Arena.Monsters
const Objectives = preload("res://Prototype/U13/Encounters/U13EncounterObjectives.gd")
const CrossingMonsters = preload("res://Scripts/Sim/U13CrossingMonsters.gd")
const COST: Dictionary = {"Lemek": 6, "Varn": 4, "Fyra": 5, "Kopita": 5, "Tumler": 5,
	"Kurchin": 6, "Muno": 7, "Dotra": 6, "Sooge": 7, "Sinodek": 7}
# Expedition weights preserve the calibrated, seeded opposition when player prices change.
const OPPOSITION_COST: Dictionary = {"Lemek": 5, "Varn": 4, "Fyra": 5, "Kopita": 5, "Tumler": 5,
	"Kurchin": 6, "Muno": 6, "Dotra": 6, "Sooge": 7, "Sinodek": 7}
const WEIGHT: Dictionary = {"Lemek": 3, "Varn": 1, "Fyra": 3, "Kopita": 2, "Tumler": 3,
	"Kurchin": 3, "Muno": 3, "Dotra": 3, "Sooge": 6, "Sinodek": 6}
const SUITS: Array = ["Penitent", "Vulture", "Wright", "Butcher"]
const CAPACITY: int = 7
const DEPLOYMENTS: int = 4
const MAX_ROUNDS: int = 16
const GATE_ROUNDS: int = 24
const REINFORCEMENTS_PER_SUIT: int = 2
const START_POWER: int = 5
# Fixed finite expeditions, calibrated separately for each objective.
const OPPOSITION: Dictionary = {
	"gate": [
		{
			"budget": 59,
			"opening": [
				16,
				13,
				8,
				6
			],
			"pushes": [
				0,
				0,
				0
			],
			"patrols": true,
			"skirmisher_round": -1
		},
		{
			"budget": 70,
			"opening": [
				14,
				10,
				8,
				6
			],
			"pushes": [
				10,
				10,
				12
			],
			"skirmisher_round": 3,
			"patrols": false
		},
		{
			"budget": 80,
			"opening": [
				16,
				12,
				8,
				6
			],
			"pushes": [
				14,
				12,
				12
			],
			"patrols": false,
			"skirmisher_round": 2
		}
	],
	"lamp": [
		{
			"budget": 48,
			"opening": [
				9,
				9,
				8,
				4
			],
			"pushes": [
				6,
				6,
				6
			],
			"skirmisher_round": 3,
			"patrols": false
		},
		{
			"budget": 58,
			"opening": [
				12,
				8,
				6,
				4
			],
			"pushes": [
				10,
				10,
				8
			],
			"patrols": false,
			"skirmisher_round": 2
		},
		{
			"budget": 65,
			"opening": [
				12,
				11,
				6,
				4
			],
			"pushes": [
				12,
				10,
				10
			],
			"patrols": false,
			"skirmisher_round": 2
		}
	]
}
var arena
var ordinary: Dictionary = {}
var reinforcements_received: bool = false
var unlocked: Array = []
var groups: Array = []
var power: int = START_POWER
var income: int = 2
var deployments: int = 0
var threat: int = 1
var phase: String = "planning"
var undo_stack: Array = []
var waves: Array = []
var waiting_enemies: Array = []
var scenario: String = "gate"
var seed_text: String = "crossing-1"
var leader: String = "Penitent"
var metrics: Dictionary = {"rounds": [], "reserve_empty_round": -1, "enemy_cleared_round": -1,
	"first_gate_damage_round": -1, "resolve_ms": 0, "power_spent": 0, "ordinary_deployed": 0}
var aftermath: Dictionary = {}
var round_started_power: int = START_POWER
var enemy_budget: int = 0
var enemy_spent: int = 0
var enemy_plan: String = ""
var plan_note: String = ""
var enemy_line: int = 300
var _accepted_round: int = 0
var start_metrics: Dictionary = {}
var _spawned_round: int = 0

func _init(seed_value: String = "crossing-1", objective: String = "gate", regeneration: int = 2, difficulty: int = 1, monster_list: Array = Monsters.NAMES, retinue_suit: String = "Penitent") -> void:
	seed_text = seed_value if not seed_value.is_empty() else "crossing-1"
	scenario = objective if objective in ["gate", "lamp"] else "gate"
	income = clampi(regeneration, 1, 4)
	threat = clampi(difficulty, 0, 2)
	leader = retinue_suit if retinue_suit in SUITS else ""
	for suit in SUITS: ordinary[suit] = 3 + (2 if suit == leader else 0)
	for name in monster_list:
		if name in Monsters.NAMES and name not in unlocked: unlocked.append(name)
	arena = Arena.new(seed_text)
	arena.world.data["encounter"] = Objectives.create(scenario)
	arena.world.data.encounter["monster_profile"] = CrossingMonsters.PROFILE
	arena.world.data.encounter["slow_construction"] = true
	_build_waves()
	_sync_objective_inputs()
	start_metrics = planning_metrics()

func round_limit() -> int:
	return GATE_ROUNDS if scenario == "gate" else MAX_ROUNDS

func reinforcement_round() -> int:
	return 15 if scenario == "gate" else 10

func pending_reinforcements() -> int:
	return 0 if reinforcements_received else REINFORCEMENTS_PER_SUIT * SUITS.size()

func reinforcement_text() -> String:
	if reinforcements_received:
		return "REINFORCEMENTS ARRIVED · round %d · +2 of each troop (one-time)" % reinforcement_round()
	return "YOUR REINFORCEMENTS · round %d · +2 of each troop (one-time)" % reinforcement_round()

func _grant_reinforcements() -> void:
	if reinforcements_received or arena.round_number != reinforcement_round(): return
	for suit in SUITS: ordinary[suit] += REINFORCEMENTS_PER_SUIT
	reinforcements_received = true
	metrics["player_reinforcement_round"] = arena.round_number
	metrics["player_reinforcement_bodies"] = REINFORCEMENTS_PER_SUIT * SUITS.size()

func _build_waves() -> void:
	# Plan, complete order list, and order IDs are fixed before player choices.
	var plan_rng := RandomNumberGenerator.new()
	plan_rng.seed = (seed_text + ":plan").hash()
	var plan: int = plan_rng.randi_range(0, 2)
	enemy_line = [180, 300, 420][plan_rng.randi_range(0, 2)]
	enemy_plan = ["Shield column", "Volley company", "Raiding party"][plan]
	plan_note = ["Penitent screen; few archers.", "Vulture-heavy; a thin melee screen.", "Butcher-heavy; Tumler hunts ranged and support units."][plan]
	var patterns: Array = [["Penitent", "Penitent", "Vulture", "Butcher"],
		["Vulture", "Vulture", "Penitent", "Butcher"], ["Butcher", "Butcher", "Vulture", "Penitent"]]
	var monsters: Array = [["Lemek", "Kopita"], ["Kurchin", "Fyra"], ["Tumler", "Varn"]][plan].duplicate()
	var settings: Dictionary = OPPOSITION[scenario][threat]
	var opening: Array = settings.opening
	enemy_budget = int(settings.budget)
	var push_rounds: Array = [6,9,12]
	var push_funds: Array = settings.pushes
	var reserve_monsters: Array = [["Sooge", "Kopita", "Lemek"], ["Muno", "Kurchin", "Fyra"], ["Dotra", "Tumler", "Varn"]][plan]
	var remaining: int = enemy_budget
	var bank: int = 0
	var serial: int = 100000
	var ordinary_index: int = 0
	for number in range(1, round_limit() + 1):
		var wave: Array = []
		var push_index: int = push_rounds.find(number)
		var release: int = 0
		if number <= 4: release = int(opening[number - 1])
		elif bool(settings.patrols): release = 2 if number % 2 == 0 else 0
		elif push_index >= 0: release = int(push_funds[push_index])
		var grant: int = mini(remaining, release)
		bank += grant
		remaining -= grant
		var purchases: Array = []
		if number == 1: purchases = monsters
		elif number == int(settings.skirmisher_round): purchases = ["Muno"]
		elif threat > 0 and push_index >= 0: purchases = [reserve_monsters[push_index]]
		for name in purchases:
			if int(OPPOSITION_COST[name]) > bank: continue
			wave.append(_enemy_order(name, serial)); serial += 1
			bank -= int(OPPOSITION_COST[name])
		while bank >= 2:
			var name: String = patterns[plan][ordinary_index % 4]
			if number == 4 and wave.is_empty(): name = "Wright"
			wave.append(_enemy_order(name, serial)); serial += 1
			ordinary_index += 1
			bank -= 2
		waves.append(wave)
	enemy_spent = enemy_budget - remaining - bank
	if int(settings.skirmisher_round) > 0:
		plan_note += " Muno arrives round %d." % int(settings.skirmisher_round)
	plan_note += " Finite patrols every other round after round 4." if bool(settings.patrols) else " Reinforcements on rounds 6, 9, 12; gaps between pushes."

func _enemy_order(name: String, serial: int) -> Dictionary:
	var count: int = 3 + Arena.Effects.Lamp.draw(seed_text + ":enemy", "manual:%d" % serial, "SWARM_COUNT", 3) if name == "Varn" else 1
	var rear: bool = name in ["Vulture", "Wright", "Kopita", "Fyra", "Sooge", "Sinodek"]
	return {"name": name, "serial": serial, "bodies": count,
		"x": 2160 if rear else 1980, "y": enemy_line + (serial % 3 - 1) * 55}

func forecast(offset: int = 0) -> Array:
	var index: int = arena.round_number - 1 + offset
	return waves[index].duplicate(true) if index >= 0 and index < waves.size() else []

func remaining_enemy_orders() -> Array:
	var rows: Array = waiting_enemies.duplicate(true)
	for index in range(arena.round_number if _spawned_round == arena.round_number else arena.round_number - 1, waves.size()): rows.append_array(waves[index])
	return rows

func remaining_enemy_bodies() -> int:
	var count: int = 0
	for order in remaining_enemy_orders(): count += int(order.bodies)
	return count

func capacity_used() -> int:
	var live: Dictionary = {}
	for unit in arena.units(): live[unit.id] = true
	var used: int = 0
	for group in groups:
		if group.ids.any(func(id): return live.has(id)): used += int(group.weight)
	return used

func ordinary_remaining() -> int:
	var count: int = 0
	for value in ordinary.values(): count += int(value)
	return count

func unavailable(name: String) -> String:
	if phase != "planning": return "Wait for the next planning phase."
	if deployments >= DEPLOYMENTS: return "All four deployments used this round."
	if name in SUITS: return "No %s recruits remain." % name if ordinary[name] <= 0 else ""
	if name not in unlocked: return "That monster is locked."
	if power < int(COST[name]): return "Not enough summoning power."
	if capacity_used() + int(WEIGHT[name]) > CAPACITY: return "Not enough monster capacity."
	if Monsters.limited(name) and Monsters.living(arena.units(), 0, name): return "That monster already lives on the field."
	return ""

func _snapshot() -> Dictionary:
	return {"world": arena.world.duplicate(true), "serial": arena.serial, "totals": arena.totals.duplicate(true),
		"ordinary": ordinary.duplicate(), "groups": groups.duplicate(true), "power": power, "deployments": deployments,
		"metrics": metrics.duplicate(true)}

func _restore(snap: Dictionary) -> void:
	arena.world = snap.world; arena.serial = snap.serial; arena.totals = snap.totals
	ordinary = snap.ordinary; groups = snap.groups; power = snap.power; deployments = snap.deployments
	metrics = snap.metrics

func deploy(name: String, point: Vector2, _unused: int = -1) -> Dictionary:
	var reason: String = unavailable(name)
	if not reason.is_empty(): return {"error": reason}
	if point.x < 60 or point.x > 420 or point.y < 60 or point.y > 540: return {"error": "Place troops in the blue deployment area."}
	var snap: Dictionary = _snapshot()
	var made: Dictionary = arena.spawn(name, 0)
	if made.action == "invalid":
		_restore(snap)
		return {"error": made.reason}
	var ids = Marching.Ids.new()
	ids.restore(arena.world.entities)
	var occupied: Array = arena.units().filter(func(u): return u.id not in made.ids)
	for id in made.ids:
		var unit: Dictionary = ids.get_entity(id)
		var found: bool = false
		for attempt in range(90):
			var angle: float = float(attempt) * 2.399963
			var distance: float = 11.0 * sqrt(float(attempt))
			var p := Vector2(clampf(point.x + cos(angle) * distance, 60, 420), clampf(point.y + sin(angle) * distance, 60, 540))
			if occupied.any(func(u): return Vector2(u.attributes.x_fp, u.attributes.y_fp).distance_to(p) < 43): continue
			unit.attributes.x_fp = roundi(p.x)
			unit.attributes.y_fp = roundi(p.y)
			ids.update(id, 0, unit.attributes)
			occupied.append(unit)
			found = true
			break
		if not found:
			_restore(snap)
			return {"error": "That area is crowded. Choose another spot."}
	arena.world.entities = ids.snapshot()
	undo_stack.append(snap)
	deployments += 1
	if name in SUITS:
		ordinary[name] -= 1
		metrics.ordinary_deployed += 1
	else:
		power -= int(COST[name])
		metrics.power_spent += int(COST[name])
		groups.append({"name": name, "weight": WEIGHT[name], "ids": made.ids.duplicate()})
	_sync_objective_inputs()
	return {"ok": true, "count": made.count}

func undo() -> bool:
	if phase != "planning" or undo_stack.is_empty(): return false
	_restore(undo_stack.pop_back())
	return true

func _sync_objective_inputs() -> void:
	var state: Dictionary = arena.world.data.encounter
	state["ordinary_reserve"] = ordinary_remaining()
	state["ordinary_reinforcements_pending"] = pending_reinforcements()
	state["enemy_ordinary_pending"] = remaining_enemy_orders().any(func(order): return order.name in SUITS)
	# Conservative reachability: a future Fyra may acquire an enemy carrier.
	state["future_charm"] = "Fyra" in unlocked and power + income * maxi(0, round_limit() - arena.round_number) >= int(COST.Fyra)
	state["round_limit"] = round_limit()

func planning_metrics() -> Dictionary:
	var power_only: Array = []
	var cap_only: Array = []
	var both: Array = []
	var legal: Array = []
	var used: int = capacity_used()
	for name in unlocked:
		var needs_power: bool = power < int(COST[name])
		var needs_cap: bool = used + int(WEIGHT[name]) > CAPACITY
		if needs_power and needs_cap: both.append(name)
		elif needs_power: power_only.append(name)
		elif needs_cap: cap_only.append(name)
		elif unavailable(name).is_empty(): legal.append(name)
	return {"round": arena.round_number, "power_start": round_started_power, "power_end": power,
		"capacity_used": used, "ordinary_left": ordinary_remaining(), "reinforcements_pending": pending_reinforcements(), "deployments": deployments,
		"power_only": power_only, "capacity_only": cap_only, "both": both, "legal": legal,
		"enemy_reserve_bodies": remaining_enemy_bodies(), "gate_hp": arena.world.data.encounter.gate_hp.duplicate()}

func _place_enemy_group(order: Dictionary, made_ids: Array) -> bool:
	var ids = Marching.Ids.new()
	ids.restore(arena.world.entities)
	var occupied: Array = arena.units().filter(func(u): return u.id not in made_ids)
	var center := Vector2(int(order.get("x", 1980)), int(order.get("y", enemy_line)))
	for id in made_ids:
		var unit: Dictionary = ids.get_entity(id)
		var found: bool = false
		for attempt in range(180):
			var angle: float = float(attempt) * 2.399963
			var distance: float = 13.0 * sqrt(float(attempt))
			var point := Vector2(clampf(center.x + cos(angle) * distance, 1980, 2340), clampf(center.y + sin(angle) * distance, 60, 540))
			if occupied.any(func(u): return Vector2(u.attributes.x_fp, u.attributes.y_fp).distance_to(point) < 43): continue
			unit.attributes.x_fp = roundi(point.x)
			unit.attributes.y_fp = roundi(point.y)
			found = true
			break
		if not found: return false
		ids.update(id, 1, unit.attributes)
		occupied.append(unit)
	arena.world.entities = ids.snapshot()
	return true

func begin() -> Dictionary:
	if phase != "planning": return {"error": "Already running."}
	_sync_objective_inputs()
	var row: Dictionary = planning_metrics()
	row["before_choices"] = start_metrics.duplicate(true)
	var before: Dictionary = _snapshot()
	var old_waiting: Array = waiting_enemies.duplicate(true)
	var orders: Array = waiting_enemies + forecast()
	waiting_enemies = []
	for order in orders:
		var spawn_world: Dictionary = arena.world.duplicate(true)
		var spawn_totals: Array = arena.totals.duplicate(true)
		var player_serial: int = arena.serial
		arena.serial = int(order.serial)
		arena.seed_value = seed_text + ":enemy"
		var made: Dictionary = arena.spawn(order.name, 1)
		arena.serial = player_serial
		arena.seed_value = seed_text
		if made.action == "invalid":
			if str(made.reason).begins_with("Arena limit") or (Monsters.limited(order.name) and Monsters.living(arena.units(), 1, order.name)):
				waiting_enemies.append(order)
				continue
			_restore(before); waiting_enemies = old_waiting
			return {"error": made.reason}
		if not _place_enemy_group(order, made.ids):
			arena.world = spawn_world
			arena.totals = spawn_totals
			waiting_enemies.append(order)
			continue
		metrics["last_reinforcement_round"] = arena.round_number
	# Current scheduled orders have now been handled. Only deferred and later
	# waves count as reserves while combat is resolving.
	var future: Array = waiting_enemies.duplicate(true)
	for i in range(arena.round_number, waves.size()): future.append_array(waves[i])
	arena.world.data.encounter.enemy_ordinary_pending = future.any(func(order): return order.name in SUITS)
	if future.is_empty() and metrics.reserve_empty_round < 0: metrics.reserve_empty_round = arena.round_number
	_spawned_round = arena.round_number
	row["enemy_after_spawn"] = future.size()
	metrics.rounds.append(row)
	phase = "resolving"
	return {"world": arena.world.duplicate(true), "seed": seed_text, "round": arena.round_number}

func accept(result: Dictionary) -> bool:
	if phase not in ["resolving", "playback"] or _accepted_round == arena.round_number: return false
	if result.get("action", "") != "resolved": return false
	_accepted_round = arena.round_number
	arena.world = result.world
	undo_stack.clear()
	metrics.resolve_ms += int(result.get("resolve_ms", 0))
	if metrics.first_gate_damage_round < 0 and int(arena.world.data.encounter.gate_hp[1]) < 24: metrics.first_gate_damage_round = arena.round_number
	if metrics.reserve_empty_round >= 0 and metrics.enemy_cleared_round < 0 and not arena.units().any(func(u): return int(u.attributes.get("charm_owner", u.owner)) == 1): metrics.enemy_cleared_round = arena.round_number
	if not arena.world.data.encounter.outcome.is_empty():
		_finish(); return true
	if arena.round_number >= round_limit():
		Objectives.finish(arena.world.data.encounter, "defeat", "Time ran out. The objective remains in enemy hands.", -1)
		_finish(); return true
	arena.round_number += 1
	_grant_reinforcements()
	power += income
	round_started_power = power
	deployments = 0
	phase = "planning"
	_sync_objective_inputs()
	start_metrics = planning_metrics()
	return true

func withdraw() -> bool:
	if phase != "planning": return false
	Objectives.finish(arena.world.data.encounter, "defeat", "You withdrew from the mission.", -1)
	_finish()
	aftermath["withdrawn"] = true
	aftermath["grade_ceiling"] = "worst" # Withdrawal can never preserve a better margin.
	return true

func _finish() -> void:
	phase = "finished"
	metrics["mission_end_round"] = arena.round_number
	metrics["mission_end_tick"] = arena.world.data.encounter.winning_tick
	undo_stack.clear()
	var victory: bool = arena.world.data.encounter.outcome == "victory"
	aftermath = {"preview_only": true, "run_continues": true, "leader": leader, "withdrawn": false, "grade_ceiling": "ungraded",
		"reward_eligible": victory, "promotion_eligible": victory and not leader.is_empty(),
		"marring_eligible": not victory and not leader.is_empty(), "outcome": arena.world.data.encounter.outcome,
		"round": arena.round_number, "reason": arena.world.data.encounter.message}

func aftermath_text() -> String:
	if aftermath.is_empty(): return ""
	var consequence: String = "Reward eligible." if aftermath.reward_eligible else "No reward."
	if not leader.is_empty(): consequence += " Promotion eligible." if aftermath.reward_eligible else " Marring eligible."
	return "LOCAL PREVIEW · %s · %s Run continues. No campaign changes." % [leader if not leader.is_empty() else "No retinue", consequence]

# Worker owns the copied world. No UI, global random calls, or scene access.
static func resolve(raw: Dictionary, seed_value: String, number: int) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var context: Dictionary = {"world": raw.duplicate(true), "round": number,
		"hook": Marching.Timeline.ROUND_START_AUTOMATIC, "seed": seed_value,
		"player_order": [0, 1], "persistent_effects": [], "full_roster": true}
	Arena.Effects.end_round(context.world, number - 1)
	context.world.data.kanifous_losses = []
	context.world.data.kanifous_loss_round = number
	for unit in context.world.entities.entities:
		unit.attributes.erase("encounter_gate_tick")
	var regenerated: Dictionary = Marching.regenerate(context)
	if regenerated.action == "invalid": return regenerated
	context.world = regenerated.world
	context.hook = Marching.Timeline.MARCHING
	context["encounter_tick"] = Callable(Objectives, "step")
	var result: Dictionary = Marching.resolve(context, Callable(Arena, "reaction"))
	if result.action == "resolved":
		var ticks: int = Marching.TICKS
		if not str(result.world.data.encounter.outcome).is_empty():
			ticks = int(result.world.data.encounter.winning_tick) + 1
		for row in result.events:
			if row.event.type in ["MARCHING_STARTED", "MARCHING_FINISHED"]:
				row.event.data["ticks"] = ticks
				row.event.data["seconds"] = float(ticks) * 15.0 / float(Marching.TICKS)
	result["resolve_ms"] = Time.get_ticks_msec() - started
	return result


static func monster_ability(name: String) -> String:
	return CrossingMonsters.DESCRIPTIONS.get(name, Monsters.ROSTER[name].ability)
