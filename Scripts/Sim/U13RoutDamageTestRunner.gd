extends SceneTree

# Short mechanics checks, with complete native packets for verify_exposure.py.
const Game = preload("res://Scripts/Sim/U13GameConductor.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Monsters = preload("res://Scripts/Sim/U13MonsterRules.gd")
const Effects = preload("res://Scripts/Sim/U13MonsterEffects.gd")
const Incoming = preload("res://Scripts/Sim/U13IncomingDamage.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
var failures: int = 0
var cases: int = 0
var output

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func world() -> Dictionary:
	var w: Dictionary = Game.Economy.initialize(Game.Scenario.loadout_world(["Deimos", "Gremory"], [Game.Slots.TYPES, Game.Slots.TYPES]), "rout-damage").world
	w.data["marching_round"] = 1
	w.data["marching_regen_round"] = 2
	w.data.kanifous_loss_round = 2
	w.data.monsters.phase_round = 1
	return w

func put(w: Dictionary, name: String, owner: int, x: int, extra: Dictionary = {}) -> Dictionary:
	var ids = Ids.new(); ids.restore(w.entities)
	var a: Dictionary = Monsters.profile(name, "Lord", owner, 0, 1) if name in Monsters.NAMES else Marching.profile(name, "Lord", owner, 0, 1, true)
	a.x_fp = x
	a.merge(extra, true)
	var made: Dictionary = ids.create("marcher", "rout-damage:" + name + ":" + str(owner), 0, owner, a)
	w.entities = ids.snapshot()
	return made.entity

func target_attributes(applied: int, extra: Dictionary = {}) -> Dictionary:
	var a: Dictionary = {"hp": 100, "max_hp": 100, "armor": 0, "step_fp": 0}
	if applied > 0: a.merge({"rout_round": applied, "rout_effect_id": "rout-damage-effect"})
	return a.merged(extra, true)

func context(w: Dictionary, seed_value: String) -> Dictionary:
	return {"world": w, "round": 2, "hook": "marching", "seed": seed_value, "player_order": [0, 1], "persistent_effects": [], "full_roster": true}

func direct(label: String, operation: String, w: Dictionary, options: Dictionary = {}) -> Dictionary:
	var c: Dictionary = context(w, options.get("seed", "rout-damage"))
	var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
	var content = Game.Content.new()
	var react: Callable = Callable(content, "react")
	var tick: int = int(options.get("tick", 0))
	var result: Dictionary
	match operation:
		"melee": result = Marching.FieldMelee.resolve(w.duplicate(true), buffer, c, tick, {}, react)
		"ranged": result = Marching.Ranged.volley(w.duplicate(true), buffer, c, {}, tick, {}, react)
		"packet": result = Effects.damage(w.duplicate(true), buffer, options.hit.duplicate(true), c, tick, react)
		"hazard": result = preload("res://Scripts/Sim/U13Hazards.gd").pulse(c, options.active, "exposure-hazard", react)
	check(result.action == "resolved", label + " resolves")
	if result.action != "resolved": return result
	cases += 1
	if output != null:
		output.store_line(Codec.encode({"name": label, "operation": operation, "context": c, "options": options, "result": {"world": result.world, "events": result.events}}).text)
	return result

func after(result: Dictionary, id: String) -> Dictionary:
	var ids = Ids.new(); ids.restore(result.world.entities)
	return ids.get_entity(id).attributes

func regular_checks() -> void:
	# Both seats; no Rout, recovery and active retreat. A monster's basic swing
	# and a Tower shot are ordinary attacks, just like Butcher/Vulture hits.
	for owner in [0, 1]:
		for applied in [0, 1, 2]:
			for name in ["Butcher", "Vulture", "Lemek", "Tower"]:
				var w: Dictionary = world()
				var direction: int = 1 if owner == 0 else -1
				var x: int = 1200
				var operation: String = "ranged" if name in ["Vulture", "Tower"] else "melee"
				var base: int = {"Butcher": 3, "Vulture": 2, "Lemek": 4, "Tower": 1}[name]
				if name == "Tower":
					var p: Dictionary = Marching.Fort.site_point(owner, 2); x = int(p.x_fp)
					var builder: Dictionary = put(w, "Wright", owner, x)
					var ids = Ids.new(); ids.restore(w.entities); ids.retire(builder.id); w.entities = ids.snapshot()
					w.data["field_structures"] = [{"id": Marching.Fort.Data.instance_id("wright_structure", builder.id, "2"), "kind": "fortification", "owner": owner, "attributes": {"structure": "Tower", "site": 2, "lane": "Lord", "x_fp": x, "y_fp": p.y_fp, "hp": 6, "max_hp": 6, "armor": 4, "max_armor": 4, "attack": 1, "ranged_next_tick": 0, "builder_id": builder.id}}]
				else: put(w, name, owner, x)
				var victim: Dictionary = put(w, "Butcher", 1-owner, x + direction * (300 if operation == "ranged" else 60), target_attributes(applied))
				var label: String = "rout_%s_owner%d_stage%d" % [name, owner, applied]
				var result: Dictionary = direct(label, operation, w)
				check(after(result, victim.id).hp == 100 - base - (1 if applied == 2 else 0), label + " damage")
	for bypass in [false, true]:
		var w: Dictionary = world()
		put(w, "Butcher", 0, 1000, {"armor_bypass": bypass})
		var victim: Dictionary = put(w, "Butcher", 1, 1060, target_attributes(2, {"armor": 3}))
		var a: Dictionary = after(direct("rout_armor_bypass_" + str(bypass), "melee", w), victim.id)
		check(a.hp == (96 if bypass else 99) and a.armor == (3 if bypass else 0), "bonus applies before Armor and respects bypass")
	var w: Dictionary = world()
	put(w, "Butcher", 0, 1000)
	var victim: Dictionary = put(w, "Butcher", 1, 1060, target_attributes(2, {"dotra_exposed_from_tick": 400, "dotra_exposed_until_tick": 600}))
	check(after(direct("rout_plus_dotra", "melee", w), victim.id).hp == 95, "Rout and Dotra exposure add independently")
	w = world(); put(w, "Butcher", 0, 1000, {"attack": 0})
	victim = put(w, "Butcher", 1, 1060, target_attributes(2))
	check(after(direct("rout_zero_attack", "melee", w), victim.id).hp == 100, "zero attack stays zero")

func defense_checks() -> void:
	for kind in ["block", "evade"]:
		for wanted in [false, true]:
			var w: Dictionary = world()
			var source: Dictionary = put(w, "Vulture" if kind == "block" else "Butcher", 0, 1000)
			var victim: Dictionary = put(w, "Penitent" if kind == "block" else "Kurchin", 1, 1300 if kind == "block" else 1060, target_attributes(2, {"armor": 6}))
			var seed_value: String = ""
			for i in range(1000):
				var candidate: String = "rout-defense:" + str(i)
				var prevented: bool = Marching.Ranged.Defense.blocks(victim, source.id, candidate, 2, 0, "Vulture") if kind == "block" else Effects.evades(victim, source, [], context(w, candidate), 0, "Melee")
				if prevented == wanted: seed_value = candidate; break
			check(not seed_value.is_empty(), "deterministic " + kind + " fixture")
			var result: Dictionary = direct("rout_%s_%s" % [kind, wanted], "ranged" if kind == "block" else "melee", w, {"seed": seed_value})
			var a: Dictionary = after(result, victim.id)
			check(a.hp == 100 and a.armor == (6 if wanted else (4 if kind == "block" else 2)), kind + " prevents the complete hit")

func special_checks() -> void:
	for spec in [["Poison", 1, true], ["Kopita", 1, false], ["Beam", 3, false], ["Muno", 3, false], ["Ambush", 5, false]]:
		var w: Dictionary = world()
		var source: Dictionary = put(w, "Dotra", 0, 1000)
		var victim: Dictionary = put(w, "Butcher", 1, 1200, target_attributes(2))
		var result: Dictionary = direct("rout_special_" + spec[0], "packet", w, {"hit": {"source": source, "target": victim.id, "ability": spec[0], "amount": spec[1], "bypass": spec[2]}})
		check(after(result, victim.id).hp == 100 - spec[1], "Rout does not amplify " + spec[0])
	var w: Dictionary = world()
	var victim: Dictionary = put(w, "Butcher", 1, 1200, target_attributes(2))
	var active: Dictionary = {"effect_id": "rout-inferno", "target": {"kind": "lane", "lane": "Lord"}, "stage_index": 0, "stages": [{"intensity": 1}], "declaration": {"player_id": 0, "power_id": "Inferno"}}
	check(after(direct("rout_hazard", "hazard", w, {"active": active}), victim.id).hp == 99, "Rout does not amplify a Lord hazard")

func boundary_checks() -> void:
	check(preload("res://Scripts/Sim/U13Deimos.gd").rules().Rout.retreat_regular_attack_bonus == 1, "Rout rules hash records the new damage mechanic")
	for clock in [399, 400, 599, 600, 799, 800]:
		check(Incoming.regular_amount({"rout_round": 2}, 3, clock) == (4 if clock in [400, 599] else 3), "retreat boundary " + str(clock))
	for applied in [0, 1, 2]:
		var a: Dictionary = target_attributes(applied, {"armor": 3})
		var dealt: int = Marching._attack(a, 3, false, 400)
		check(dealt == (1 if applied == 2 else 0) and a.armor == 0, "legacy melee stage " + str(applied))

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		output = FileAccess.open(args[0], FileAccess.WRITE)
		if output == null: check(false, "open packet output"); quit(1); return
	regular_checks()
	defense_checks()
	special_checks()
	boundary_checks()
	if output != null: output.close()
	print("U13 Rout damage: %d packet cases, %d failures" % [cases, failures])
	quit(0 if failures == 0 else 1)
