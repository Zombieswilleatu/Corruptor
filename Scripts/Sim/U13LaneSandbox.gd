extends RefCounted

const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Monsters = preload("res://Scripts/Sim/U13MonsterRules.gd")
const Effects = preload("res://Scripts/Sim/U13MonsterEffects.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")
const Enemy = preload("res://Scripts/Sim/U13SandboxEnemy.gd")
const Staging = preload("res://Scripts/Sim/U13LaneStaging.gd")
const Ids = Marching.Ids
const LIMIT: int = 64
var world: Dictionary
var seed_value: String
var round_number: int = 1
var serial: int = 0
var spawners: Array = []
var last_waves: Array = [{}, {}]
var totals: Array = []
var goal_ids: Array = [{}, {}]
var seats_swapped: bool = false

func _init(seed_text: String = "lane-balance-1", balance_preview: bool = false, goal_advance: bool = true, swapped: bool = false, staging_capacity: int = 0) -> void:
	seats_swapped = swapped
	seed_value = seed_text if not seed_text.strip_edges().is_empty() else "lane-balance-1"
	world = {"entities": Ids.new().snapshot(), "data": {"kanifous_losses": [], "kanifous_loss_round": 1}}
	Marching.Ranged.configure(world)
	if balance_preview:
		world.data["lane_balance_preview"] = {"version": Marching.Ranged.PREVIEW_VERSION, "goal_advance": goal_advance}
	Monsters.configure(world)
	if staging_capacity > 0: Staging.configure(world, staging_capacity)
	for pid in [0, 1]:
		spawners.append(Enemy.new(seed_value, pid))
		totals.append({"spawned": 0, "defeated": 0, "banished": 0, "escaped": 0, "reached_goal": 0})

func fork():
	# A worker owns its whole arena, including the two mutable card streams.
	var copy = get_script().new()
	copy.world = world.duplicate(true)
	copy.seed_value = seed_value
	copy.round_number = round_number
	copy.serial = serial
	copy.spawners = spawners.map(func(spawner): return spawner.fork())
	copy.last_waves = last_waves.duplicate(true)
	copy.totals = totals.duplicate(true)
	copy.goal_ids = goal_ids.duplicate(true)
	copy.seats_swapped = seats_swapped
	return copy

func units() -> Array:
	return world.entities.entities.filter(func(r): return r.kind == "marcher")

func staged_units() -> Array:
	return Staging.rows(world)

func prepare_releases(modes: Array = ["Auto", "Auto"]) -> Array:
	if not seats_swapped: return Staging.prepare(world, round_number, modes, LIMIT)
	_flip_spawn_frame()
	Staging.prepare(world, round_number, [modes[1], modes[0]], LIMIT)
	_flip_spawn_frame()
	return world.data.get("marcher_staging", {}).get("decisions", [])

func spawn(name: String, pid: int, near_center: bool = false, turret: bool = false) -> Dictionary:
	if not seats_swapped: return _spawn(name, pid, near_center, turret)
	_flip_spawn_frame()
	var outcome: Dictionary = _spawn(name, 1 - pid, near_center, turret)
	_flip_spawn_frame()
	return outcome

func _spawn(name: String, pid: int, near_center: bool = false, turret: bool = false) -> Dictionary:
	if pid not in [0, 1] or (name not in Marching.SUITS and name not in Monsters.NAMES):
		return {"action": "invalid", "reason": "Unknown unit or side."}
	if Monsters.limited(name) and Monsters.living(units() + staged_units(), pid, name):
		return {"action": "invalid", "reason": "Only one living %s per side." % name}
	var count: int = 3 + Effects.Lamp.draw(seed_value, "manual:%d" % serial, "SWARM_COUNT", 3) if name == "Varn" else 1
	if Staging.enabled(world) and Staging.rows(world, pid).size() + count > int(world.data.marcher_staging.capacity):
		return {"action": "invalid", "reason": "Staging is full. Run an interval to release an older group."}
	if not Staging.enabled(world) and units().size() + count > LIMIT:
		return {"action": "invalid", "reason": "Arena limit: %d active units. Let this wave finish or reset." % LIMIT}
	var ids = Ids.new(); ids.restore(world.entities)
	var created: Array = []
	for i in range(count):
		# Manual units are already deployed. AI commitments retain the birth hold.
		var a: Dictionary = Monsters.profile(name, "Lord", pid, round_number - 1, round_number, turret and name == "Sooge") if name in Monsters.NAMES else Marching.profile(name, "Lord", pid, round_number - 1, round_number, true)
		var made: Dictionary = ids.create("marcher", "sandbox:manual:%d" % serial, i, pid, a)
		if made.action == "invalid": return made
		Marching.place_spawn(ids, made.entity.id, seed_value)
		if near_center:
			var unit: Dictionary = ids.get_entity(made.entity.id)
			unit.attributes.x_fp += 800 if pid == 0 else -800
			ids.update(unit.id, pid, unit.attributes)
		created.append(made.entity.id)
	serial += 1
	world.entities = ids.snapshot()
	Staging.store_units(world, created, round_number)
	totals[pid].spawned += count
	return {"action": "spawned", "count": count, "ids": created, "reason": "%s staged; eligible from round %d." % [name, round_number + 1] if Staging.enabled(world) else "%s spawned." % name}

func random_waves(owners: Array) -> Dictionary:
	if not seats_swapped: return _random_waves(owners)
	if owners.any(func(pid): return pid not in [0, 1]): return {"action": "invalid", "reason": "Unknown random-spawn side."}
	_flip_spawn_frame()
	var outcome: Dictionary = _random_waves(owners.map(func(pid): return 1 - int(pid)))
	_flip_spawn_frame()
	return outcome

func _random_waves(owners: Array) -> Dictionary:
	if owners.is_empty(): return {"action": "spawned", "spawned": 0}
	if owners.any(func(pid): return pid not in [0, 1]):
		return {"action": "invalid", "reason": "Unknown random-spawn side."}
	if world.data.get("combat_reveal_round", 0) >= round_number:
		return {"action": "invalid", "reason": "Random commitments already deployed this interval."}
	var ids = Ids.new(); ids.restore(world.entities)
	var orders: Dictionary = {}
	var cards_to_retire: Array = []
	var available_space: int = LIMIT - units().size()
	var protected: bool = Staging.enabled(world)
	# Reserve five value-five cards plus a Varn swarm per side. Alternate
	# priority when the field only has room for one new commitment.
	for pid in [round_number % 2, 1 - round_number % 2]:
		if pid not in owners: continue
		var side: String = "Your side" if pid == 0 else "Enemy"
		if (not protected and available_space < 13) or (protected and Staging.rows(world, pid).size() > int(world.data.marcher_staging.capacity)):
			last_waves[pid] = {"summary": side + " waits: arena is near capacity."}
			continue
		var wave: Dictionary = spawners[pid].next_wave(round_number, units() + staged_units())
		last_waves[pid] = wave.duplicate(true)
		if wave.cards.is_empty():
			last_waves[pid]["summary"] = side + " saves cards; no commitment this interval."
			continue
		var cards: Array = []
		for i in range(wave.cards.size()):
			var made: Dictionary = ids.create("card", "sandbox:commit:%d:%d" % [round_number, pid], i, pid, wave.cards[i].attributes)
			if made.action == "invalid": return made
			cards.append(made.entity.id)
		cards_to_retire.append_array(cards)
		orders[pid] = {"action": "Hunt", "lane": "Lord", "card_ids": cards}
		if not wave.monster.is_empty(): orders[pid]["monster_choice"] = wave.monster
		available_space -= 13
	if orders.is_empty(): return {"action": "spawned", "spawned": 0}
	var staged: Dictionary = world.duplicate(true)
	staged.entities = ids.snapshot()
	var existing: Array = units().map(func(u): return u.id)
	# Reveal both sides together: the production engine seals the whole round.
	var result: Dictionary = Combat._reveal({"world": staged, "round": round_number, "seed": seed_value, "player_order": [0, 1].filter(func(pid): return orders.has(pid)), "combat_orders": orders})
	if result.action == "invalid": return result
	world = result.world
	ids.restore(world.entities)
	for id in cards_to_retire: ids.retire(id)
	world.entities = ids.snapshot()
	Staging.store_units(world, units().filter(func(u): return u.id not in existing).map(func(u): return u.id), round_number)
	var spawned: Array = result.events.filter(func(r): return r.event.type == "MARCHER_SPAWNED")
	for pid in orders:
		var wave: Dictionary = last_waves[pid]
		var count: int = spawned.filter(func(r): return r.event.data.owner == pid).size()
		totals[pid].spawned += count
		var labels: PackedStringArray = []
		for card in wave.cards: labels.append("%s %d" % [card.attributes.suit, card.attributes.value])
		wave["spawned"] = count
		wave["summary"] = "%s\n%d %s · %s · %d cards saved" % [", ".join(labels), count, "body" if count == 1 else "bodies", wave.monster if not wave.monster.is_empty() else "no monster recipe", wave.saved]
		if count == 0: wave.summary += "\nNo suit total reaches 3 this interval."
		elif protected: wave.summary += "\nProtected until round %d or later." % (round_number + 1)
	return {"action": "spawned", "spawned": spawned.size()}

func _flip_spawn_frame() -> void:
	# Generate cards, immutable unit IDs and keyed spawn positions in their
	# original seats, then exchange the actual combat world. Combat itself runs
	# in the swapped seats; this is not merely a flipped view of the old fight.
	world = mirror(world)
	totals.reverse()
	last_waves.reverse()

static func mirror(value: Variant) -> Variant:
	if value is Array: return value.map(mirror)
	if value is Dictionary:
		var reflected: Dictionary = {}
		for key in value:
			if key in ["owner", "charm_owner", "wright_owner", "player_id", "source_owner", "target_owner"] and value[key] in [0, 1]: reflected[key] = 1 - int(value[key])
			elif key == "x_fp": reflected[key] = Marching.LANE_FP - int(value[key])
			elif key == "direction": reflected[key] = -int(value[key])
			else: reflected[key] = mirror(value[key])
		return reflected
	return value

static func reaction(raw: Dictionary, _fact: Dictionary, _seed: String, _order: Array) -> Dictionary:
	# No Lord passives, rewards, castles or Veil in this arena. Marching itself
	# records monster deaths and applies pools, poison, charm and other abilities.
	return {"action": "resolved", "world": raw, "events": []}

static func resolve_round(raw: Dictionary, seed_text: String, number: int) -> Dictionary:
	var context: Dictionary = {"world": raw.duplicate(true), "round": number, "hook": Marching.Timeline.ROUND_START_AUTOMATIC, "seed": seed_text, "player_order": [0, 1], "persistent_effects": [], "full_roster": true}
	Effects.end_round(context.world, number - 1)
	context.world.data.kanifous_losses = []
	context.world.data.kanifous_loss_round = number
	var regenerated: Dictionary = Marching.regenerate(context)
	if regenerated.action == "invalid": return regenerated
	context.world = regenerated.world
	context.hook = Marching.Timeline.MARCHING
	return Marching.resolve(context, Callable(reaction))

func goal_arrivals(events: Array) -> Array:
	var arrivals: Array = []
	var seen: Array = goal_ids.duplicate(true)
	for row in events:
		if row.event.type != "MARCHER_WAITING": continue
		var data: Dictionary = row.event.data
		# Use the gate actually reached, including a temporarily charmed unit.
		var pid: int = 0 if int(data.x_fp) == Marching.LANE_FP else 1
		if seen[pid].has(data.entity_id): continue
		seen[pid][data.entity_id] = true
		arrivals.append({"id": data.entity_id, "owner": pid, "tick": int(data.tick)})
	return arrivals

func finish(result: Dictionary) -> void:
	for arrival in goal_arrivals(result.events):
		goal_ids[arrival.owner][arrival.id] = true
		totals[arrival.owner].reached_goal += 1
	world = result.world
	var seen: Dictionary = {}
	for row in result.events:
		var fact: Dictionary = row.event
		var unit: Dictionary = {}
		var bucket: String = ""
		if fact.type == "MARCHER_DEFEATED": unit = fact.data.victim; bucket = "defeated"
		elif fact.type == "MONSTER_BANISHED": unit = fact.data.unit; bucket = "banished"
		if not unit.is_empty() and not seen.has(unit.id):
			seen[unit.id] = true
			totals[unit.owner][bucket] += 1
	var ids = Ids.new(); ids.restore(world.entities)
	for unit in units():
		if unit.attributes.waiting:
			totals[unit.owner].escaped += 1
			ids.retire(unit.id)
	world.entities = ids.snapshot()
	# Keep ongoing fights across intervals, retiring only escaped participants.
	for lane in world.data.get("marching_duels", {}).keys():
		if world.data.marching_duels[lane].units.any(func(u): return ids.get_entity(u.id).is_empty()):
			world.data.marching_duels.erase(lane)
	world.data.kanifous_losses = []
	world.data.monsters.death_ids = []
	# Restore temporary control before the next draw and staging decisions.
	# Score/retire arrivals first: a charmed unit may have reached our goal.
	Effects.end_round(world, round_number)
	round_number += 1
