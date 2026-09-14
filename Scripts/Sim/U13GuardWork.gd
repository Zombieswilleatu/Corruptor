extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const VERSION: String = "U13_GUARD_WORK_V2"

static func enabled(world: Dictionary) -> bool:
	var state = world.data.get("guard_work")
	return state is Dictionary and state.get("version") == VERSION

static func configure(world: Dictionary) -> void:
	world.data["guard_work"] = {"version": VERSION, "targets": ["", ""], "pairs": [], "developed_round": 0, "draw_round": 0}
	for player in world.players: player.resources.repair_tokens = 0

static func valid(world: Dictionary) -> bool:
	if not enabled(world): return false
	var state: Dictionary = world.data.guard_work
	if state.keys().size() != 5 or not state.get("targets") is Array or state.targets.size() != 2 or not state.get("pairs") is Array: return false
	for key in ["developed_round", "draw_round"]:
		if not Data.is_integer(state.get(key)) or state[key] < 0: return false
	var ids = Ids.new()
	if ids.restore(world.entities).action == "invalid": return false
	for pid in [0, 1]:
		if not state.targets[pid] is String or world.players[pid].resources.repair_tokens != 0: return false
		if not state.targets[pid].is_empty():
			var target: Dictionary = ids.get_entity(state.targets[pid])
			if target.is_empty() or target.kind != "castle" or target.owner != pid: return false
	var used: Dictionary = {}
	for pair in state.pairs:
		if not pair is Dictionary or pair.keys().size() != 7 or not Data.is_integer(pair.get("player_id")) or pair.get("player_id") not in [0, 1] or pair.get("lane") not in ["Lord", "Castle"] or pair.get("suit") not in ["Butcher", "Penitent", "Wright", "Vulture"]: return false
		if not pair.get("ids") is Array or pair.ids.size() != 2 or not pair.get("slots") is Array or pair.slots.size() != 2: return false
		if not Data.is_integer(pair.get("round")) or pair.round < 1 or not pair.get("active") is bool: return false
		for index in range(2):
			if not pair.ids[index] is String or pair.ids[index].is_empty() or not Data.is_integer(pair.slots[index]) or pair.slots[index] not in [0, 1, 2]: return false
		if pair.ids[0] == pair.ids[1] or pair.slots[0] >= pair.slots[1]: return false
		for id in pair.ids:
			if id not in world.entities.used_ids: return false
		if pair.round > state.developed_round: return false
		if pair.active:
			if not intact(world, pair): return false
			for id in pair.ids:
				if used.has(id): return false
				used[id] = true
	return true

static func choice(target: String) -> Dictionary:
	return {"action": "Work", "target_id": target, "card_ids": [], "use_repair_token": false}

static func eligible(world: Dictionary, pid: int, target: Dictionary) -> bool:
	if target.is_empty() or target.kind != "castle" or target.owner != pid: return false
	var a: Dictionary = target.attributes
	if a.status == "profaned": return false
	if a.status == "ruined": return Structures.reconstruction_eligibility(world, pid, target.id).action != "invalid"
	return a.integrity < a.max_integrity or a.construction_state != "active"

static func validate_choice(world: Dictionary, pid: int, selected: Dictionary) -> Dictionary:
	if selected.is_empty(): return {"action": "legal", "paid_value": 0, "reconstruction": false}
	if selected.get("action") != "Work" or selected.get("card_ids") != [] or selected.get("use_repair_token") != false: return Data.invalid("choose_work_target_without_payment")
	if selected.target_id.is_empty(): return {"action": "legal", "paid_value": 0, "reconstruction": false}
	var ids = Ids.new()
	ids.restore(world.entities)
	var target: Dictionary = ids.get_entity(selected.target_id)
	if not eligible(world, pid, target): return Data.invalid("work_target_unavailable")
	return {"action": "legal", "paid_value": 0, "reconstruction": target.attributes.status == "ruined"}

static func intact(world: Dictionary, pair: Dictionary) -> bool:
	if not pair.active: return false
	for index in range(2):
		var found: bool = false
		for entity in world.entities.entities:
			if entity.id == pair.ids[index]:
				found = entity.owner == pair.player_id and entity.attributes.get("role") == "guard" and entity.attributes.get("lane") == pair.lane and entity.attributes.get("slot") == pair.slots[index] and entity.attributes.get("suit") == pair.suit
		if not found: return false
	return true

static func reconcile(world: Dictionary) -> void:
	if not enabled(world): return
	for pair in world.data.guard_work.pairs:
		if pair.active and not intact(world, pair): pair.active = false

static func develop(world: Dictionary, round_number: int, player_order: Array) -> Array:
	reconcile(world)
	var state: Dictionary = world.data.guard_work
	var events: Array = []
	if state.developed_round >= round_number: return events
	var ids = Ids.new()
	ids.restore(world.entities)
	for pid in player_order:
		var moves: Array = world.data.guard_orders[pid].moves
		var work: int = moves.size()
		for lane in ["Lord", "Castle"]:
			for suit in ["Butcher", "Penitent", "Wright", "Vulture"]:
				var fresh: Array = []
				for move in moves:
					if move.lane == lane and ids.get_entity(move.card_id).attributes.suit == suit: fresh.append(move)
				fresh.sort_custom(func(a, b): return a.slot < b.slot)
				if fresh.size() < 2: continue
				var pair: Dictionary = {"player_id": pid, "lane": lane, "suit": suit, "ids": [fresh[0].card_id, fresh[1].card_id], "slots": [fresh[0].slot, fresh[1].slot], "round": round_number, "active": true}
				state.pairs.append(pair)
				if suit == "Wright": work += 5
				var formed: Dictionary = Structures.public_event("GUARD_PAIR_FORMED", {"player_id": pid, "round": round_number, "lane": lane, "suit": suit, "card_ids": pair.ids})
				formed.views[1 - pid] = null # Unrevealed Guard suits remain private.
				events.append(formed)
		var selected: Dictionary = world.data.castle_orders[pid].choice
		if not selected.is_empty(): state.targets[pid] = selected.target_id
		if state.targets[pid].is_empty(): continue
		var castle: Dictionary = ids.get_entity(state.targets[pid])
		if not eligible(world, pid, castle):
			state.targets[pid] = ""
			continue
		var a: Dictionary = castle.attributes
		var build: bool = a.construction_state != "active"
		var reconstruction: bool = a.status == "ruined"
		# Deimos alone can rebuild a ruined Engine; it resumes protected construction.
		if reconstruction: build = true
		var passive: int = 3 if build else 0
		var gain: int = work + passive
		if not build and int(a.get("repair_lock_until_round", 0)) >= round_number: gain = 0
		var before: int = int(a.integrity)
		a.integrity = mini(int(a.max_integrity), before + gain)
		if build:
			a.construction_state = "active" if a.integrity >= a.max_integrity else "building"
			a.erase("repair_lock_until_round")
			a.artillery_target = ""
		if a.integrity > 0: a.status = "standing"
		ids.update(castle.id, pid, a)
		var details: Dictionary = {"player_id": pid, "round": round_number, "castle_id": castle.id, "before": before, "after": a.integrity, "work": work, "passive": passive, "reconstruction": reconstruction}
		events.append(Structures.public_event("WORK_RESOLVED", details))
		if build and a.construction_state == "active": events.append(Structures.public_event("CASTLE_ACTIVATED", details))
		if a.integrity >= a.max_integrity: state.targets[pid] = ""
	world.entities = ids.snapshot()
	state.developed_round = round_number
	return events

static func draw_pairs(world: Dictionary, round_number: int, seed_value: String) -> Array:
	reconcile(world)
	var state: Dictionary = world.data.guard_work
	var events: Array = []
	if state.draw_round >= round_number: return events
	for pair in state.pairs:
		if not pair.active or pair.suit != "Vulture" or pair.round >= round_number: continue
		var draw: Dictionary = Cards.draw(world, pair.player_id, seed_value, Data.instance_id("guard_draw", str(round_number), JSON.stringify(pair.ids)))
		if draw.get("drawn", false): events.append(Structures.public_event("GUARD_PAIR_DRAW", {"player_id": pair.player_id, "round": round_number, "amount": 1, "lane": pair.lane}))
	state.draw_round = round_number
	return events

static func defend(world: Dictionary, pid: int, lane: String, context: Dictionary, reaction: Callable) -> Dictionary:
	reconcile(world)
	var events: Array = []
	var screen: int = 0
	for pair in world.data.guard_work.pairs:
		if not pair.active or pair.player_id != pid or pair.lane != lane: continue
		if pair.suit == "Penitent":
			screen += 5
			events.append(Structures.public_event("GUARD_PAIR_SCREEN", {"player_id": pid, "round": context.round, "lane": lane, "amount": 5}))
		elif pair.suit == "Butcher":
			var targets: Array = []
			for entity in world.entities.entities:
				if entity.kind == "marcher" and entity.owner == 1 - pid and entity.attributes.lane == lane: targets.append(entity)
			targets.sort_custom(func(a, b): return a.id < b.id)
			if targets.is_empty(): continue
			var key: String = Data.instance_id("butcher_guard", str(context.round) + lane, JSON.stringify(pair.ids))
			var roll: Dictionary = Rng.draw(context.seed, key, "victim", 0, targets.size())
			var target: Dictionary = targets[roll.value]
			var killed: Dictionary = Battle.apply(world, {"kind": "marcher_damage", "command_id": key, "target_id": target.id, "damage": target.attributes.hp, "cause": "hazard"}, context.round, context.hook)
			if killed.action == "invalid": return killed
			world = killed.world
			events.append(Structures.public_event("GUARD_PAIR_STRIKE", {"player_id": pid, "round": context.round, "lane": lane, "target_id": target.id}))
			events.append({"event": killed.event, "views": [killed.event, killed.event]})
			var reacted: Dictionary = reaction.call(world, killed.event, context.seed, context.player_order)
			if reacted.action == "invalid": return reacted
			world = reacted.world
			events.append_array(reacted.events)
	return {"action": "resolved", "world": world, "events": events, "screen": screen}
