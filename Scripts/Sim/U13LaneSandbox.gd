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
var enemy
var last_wave: Dictionary = {}
var totals: Array = []

func _init(seed_text: String = "lane-balance-1") -> void:
	seed_value = seed_text if not seed_text.strip_edges().is_empty() else "lane-balance-1"
	world = {"entities": Ids.new().snapshot(), "data": {"kanifous_losses": [], "kanifous_loss_round": 1}}
	Marching.Ranged.configure(world)
	Monsters.configure(world)
	enemy = Enemy.new(seed_value)
	for pid in [0, 1]: totals.append({"spawned": 0, "defeated": 0, "banished": 0, "escaped": 0})

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

func enemy_wave() -> Dictionary:
	# Leave enough room for five value-five cards plus a Varn swarm.
	if units().size() > LIMIT - 13:
		last_wave = {"summary": "Enemy waits: arena is near capacity."}
		return last_wave
	var wave: Dictionary = enemy.next_wave(round_number, units())
	var ids = Ids.new(); ids.restore(world.entities)
	var cards: Array = []
	var labels: PackedStringArray = []
	for i in range(wave.cards.size()):
		var card: Dictionary = wave.cards[i]
		var made: Dictionary = ids.create("card", "sandbox:commit:%d" % round_number, i, 1, card.attributes)
		cards.append(made.entity.id)
		labels.append("%s %d" % [card.attributes.suit, card.attributes.value])
	world.entities = ids.snapshot()
	if cards.is_empty():
		last_wave = {"summary": "Enemy saves cards; no commitment this interval."}
		return last_wave
	var order: Dictionary = {"action": "Hunt", "lane": "Lord", "card_ids": cards}
	if not wave.monster.is_empty(): order.monster_choice = wave.monster
	var result: Dictionary = Combat._reveal({"world": world, "round": round_number, "seed": seed_value, "player_order": [1], "combat_orders": {1: order}})
	if result.action == "invalid": return result
	world = result.world
	ids.restore(world.entities)
	for id in cards: ids.retire(id)
	world.entities = ids.snapshot()
	var spawned: Array = result.events.filter(func(r): return r.event.type == "MARCHER_SPAWNED")
	totals[1].spawned += spawned.size()
	last_wave = {"cards": wave.cards, "monster": wave.monster, "spawned": spawned.size(), "saved": wave.saved, "summary": "%s\n%d bodies · %s · %d cards saved" % [", ".join(labels), spawned.size(), wave.monster if not wave.monster.is_empty() else "no monster recipe", wave.saved]}
	return last_wave

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
