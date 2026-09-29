extends RefCounted
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const SECURE_TICKS: int = 40 # Three seconds of uncontested control.
const PICKUP_RADIUS: int = 150
const CONTEST_RADIUS: int = 320

static func create(scenario: String) -> Dictionary:
	return {"scenario": scenario, "gate_hp": [24, 24], "gate_max": 24,
		"carrier": "", "carrier_owner": -1, "lamp_x": 1200, "lamp_y": 300,
		"secure_owner": -1, "secure_ticks": 0, "contested": false,
		"outcome": "", "message": "", "winning_tick": -1}

# Called after combat, before the public tick snapshot. Death/banishment drops
# the lamp at the last live position; charm also drops it instead of stealing it.
static func step(world: Dictionary, entities, number: int, tick: int) -> void:
	var state: Dictionary = world.data.encounter
	if not state.outcome.is_empty(): return
	var rows: Array = entities.marchers()
	if state.scenario == "gate":
		var damage: Array = [0, 0]
		for unit in rows:
			var a: Dictionary = unit.attributes
			if not a.waiting or tick < int(a.get("encounter_gate_tick", 0)): continue
			damage[1 - int(unit.owner)] += maxi(1, int(a.attack))
			a["encounter_gate_tick"] = tick + 27
			entities.update(unit.id, unit.owner, a)
		for side in [0, 1]: state.gate_hp[side] = maxi(0, int(state.gate_hp[side]) - int(damage[side]))
		if state.gate_hp[0] == 0 and state.gate_hp[1] == 0:
			finish(state, "draw", "Both gates fell together.", tick)
		elif state.gate_hp[1] == 0: finish(state, "victory", "The enemy gate is broken.", tick)
		elif state.gate_hp[0] == 0: finish(state, "defeat", "Your gate has fallen.", tick)
		return
	if state.has("ordinary_reserve") and not carrier_possible(state, rows):
		finish(state, "defeat", "No marchers remain who can recover the Lamp.", tick)
		return
	var carrier: Dictionary = entities.get_entity(state.carrier) if not state.carrier.is_empty() else {}
	if not state.carrier.is_empty() and (carrier.is_empty() or carrier.owner != state.carrier_owner):
		if not carrier.is_empty():
			carrier.attributes.erase("encounter_carrier")
			entities.update(carrier.id, carrier.owner, carrier.attributes)
		state.carrier = ""
		state.carrier_owner = -1
		_reset_secure(state)
		state.message = "The lamp was dropped."
		return # Leave a visible loose-lamp tick before another pickup.
	if carrier.is_empty():
		# Only ordinary mobile troops carry. Monsters fight as escorts.
		var present: Array = rows.filter(func(u): return not u.attributes.get("hidden", false) and int(u.attributes.movement_ready_round) <= number and _lamp_distance(u, state) <= CONTEST_RADIUS * CONTEST_RADIUS)
		var candidates: Array = present.filter(func(u): return not u.attributes.has("monster_id") and not u.attributes.waiting and _lamp_distance(u, state) <= PICKUP_RADIUS * PICKUP_RADIUS)
		var contested: bool = present.any(func(u): return u.owner == 0) and present.any(func(u): return u.owner == 1)
		if contested or candidates.is_empty():
			_reset_secure(state)
			state.contested = contested
			state.message = "Lamp contested — clear the defenders." if contested else "Clear the lamp and hold it for 3 seconds."
			return
		candidates.sort_custom(func(a, b):
			var da: float = Vector2(a.attributes.x_fp - state.lamp_x, a.attributes.y_fp - state.lamp_y).length_squared()
			var db: float = Vector2(b.attributes.x_fp - state.lamp_x, b.attributes.y_fp - state.lamp_y).length_squared()
			return a.id < b.id if is_equal_approx(da, db) else da < db)
		carrier = candidates[0]
		state.contested = false
		if state.secure_owner != carrier.owner:
			state.secure_owner = carrier.owner
			state.secure_ticks = 0
		state.secure_ticks += 1
		state.message = ("Your troops are" if carrier.owner == 0 else "The enemy is") + " securing the lamp…"
		if state.secure_ticks < SECURE_TICKS: return
		_reset_secure(state)
		state.carrier = carrier.id
		state.carrier_owner = carrier.owner
		carrier.attributes["encounter_carrier"] = true
		carrier.attributes.waiting = false
		carrier.attributes.waiting_since_round = 0
		carrier.attributes.erase("navigation")
		entities.update(carrier.id, carrier.owner, carrier.attributes)
		state.message = ("Your" if carrier.owner == 0 else "Enemy") + " marcher has the lamp!"
	state.lamp_x = carrier.attributes.x_fp
	state.lamp_y = carrier.attributes.y_fp
	if (carrier.owner == 0 and state.lamp_x <= 70) or (carrier.owner == 1 and state.lamp_x >= 2330):
		finish(state, "victory" if carrier.owner == 0 else "defeat", "The lamp reached your camp." if carrier.owner == 0 else "The enemy escaped with the lamp.", tick)

static func _lamp_distance(unit: Dictionary, state: Dictionary) -> float:
	return Vector2(unit.attributes.x_fp - state.lamp_x, unit.attributes.y_fp - state.lamp_y).length_squared()

static func _reset_secure(state: Dictionary) -> void:
	state.secure_owner = -1
	state.secure_ticks = 0
	state.contested = false

static func finish(state: Dictionary, outcome: String, message: String, tick: int) -> void:
	state.outcome = outcome
	state.message = message
	state.winning_tick = tick

# No resurrection or temporary banishment exists in this isolated arena.
# Charm restores original ownership next round, so it is not permanent loss.
static func carrier_possible(state: Dictionary, rows: Array) -> bool:
	if int(state.get("ordinary_reserve", 1)) > 0: return true
	if int(state.get("ordinary_reinforcements_pending", 0)) > 0: return true
	if rows.any(func(u): return not u.attributes.has("monster_id") and (u.owner == 0 or int(u.attributes.get("charm_owner", -1)) == 0)): return true
	var has_fyra: bool = rows.any(func(u): return u.attributes.get("monster_id", "") == "Fyra" and (u.owner == 0 or int(u.attributes.get("charm_owner", -1)) == 0))
	var enemy_possible: bool = bool(state.get("enemy_ordinary_pending", false)) or rows.any(func(u): return not u.attributes.has("monster_id") and u.owner == 1)
	return enemy_possible and (has_fyra or bool(state.get("future_charm", false)))
