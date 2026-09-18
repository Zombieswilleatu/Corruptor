extends RefCounted

const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Monsters = preload("res://Scripts/Sim/U13MonsterRules.gd")
const Effects = preload("res://Scripts/Sim/U13MonsterEffects.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")
const Enemy = preload("res://Scripts/Sim/U13SandboxEnemy.gd")
const Ids = Marching.Ids
const LIMIT: int = 64
var world: Dictionary
var seed_value: String
var round_number: int = 1
var serial: int = 0
var spawners: Array = []
var last_waves: Array = [{}, {}]
var totals: Array = []

func _init(seed_text: String = "lane-balance-1") -> void:
	seed_value = seed_text if not seed_text.strip_edges().is_empty() else "lane-balance-1"
	world = {"entities": Ids.new().snapshot(), "data": {"kanifous_losses": [], "kanifous_loss_round": 1}}
	Marching.Ranged.configure(world)
	Monsters.configure(world)
	for pid in [0, 1]:
		spawners.append(Enemy.new(seed_value, pid))
		totals.append({"spawned": 0, "defeated": 0, "banished": 0, "escaped": 0})

func units() -> Array:
	return world.entities.entities.filter(func(r): return r.kind == "marcher")

func spawn(name: String, pid: int, near_center: bool = false, turret: bool = false) -> Dictionary:
	if pid not in [0, 1] or (name not in Marching.SUITS and name not in Monsters.NAMES):
		return {"action": "invalid", "reason": "Unknown unit or side."}
	if Monsters.limited(name) and Monsters.living(units(), pid, name):
		return {"action": "invalid", "reason": "Only one living %s per side." % name}
	var count: int = 3 + Effects.Lamp.draw(seed_value, "manual:%d" % serial, "SWARM_COUNT", 3) if name == "Varn" else 1
	if units().size() + count > LIMIT:
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
	totals[pid].spawned += count
	return {"action": "spawned", "count": count, "ids": created}

func random_waves(owners: Array) -> Dictionary:
	if owners.is_empty(): return {"action": "spawned", "spawned": 0}
	if owners.any(func(pid): return pid not in [0, 1]):
		return {"action": "invalid", "reason": "Unknown random-spawn side."}
	if world.data.get("combat_reveal_round", 0) >= round_number:
		return {"action": "invalid", "reason": "Random commitments already deployed this interval."}
	var ids = Ids.new(); ids.restore(world.entities)
	var orders: Dictionary = {}
	var cards_to_retire: Array = []
	var available_space: int = LIMIT - units().size()
	# Reserve five value-five cards plus a Varn swarm per side. Alternate
	# priority when the field only has room for one new commitment.
	for pid in [round_number % 2, 1 - round_number % 2]:
		if pid not in owners: continue
		var side: String = "Your side" if pid == 0 else "Enemy"
		if available_space < 13:
			last_waves[pid] = {"summary": side + " waits: arena is near capacity."}
			continue
		var wave: Dictionary = spawners[pid].next_wave(round_number, units())
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
	# Reveal both sides together: the production engine seals the whole round.
	var result: Dictionary = Combat._reveal({"world": staged, "round": round_number, "seed": seed_value, "player_order": [0, 1].filter(func(pid): return orders.has(pid)), "combat_orders": orders})
	if result.action == "invalid": return result
	world = result.world
	ids.restore(world.entities)
	for id in cards_to_retire: ids.retire(id)
	world.entities = ids.snapshot()
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
	return {"action": "spawned", "spawned": spawned.size()}

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

func finish(result: Dictionary) -> void:
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
	round_number += 1
