extends "res://Scripts/Sim/U13UIFeedbackTestRunner.gd"

const Monsters = preload("res://Scripts/Sim/U13MonsterRules.gd")
const MonsterFX = preload("res://Scripts/Sim/U13MonsterEffects.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Kanifous = preload("res://Scripts/Sim/U13Kanifous.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
var phase_output

func put(world: Dictionary, name: String, owner: int, x: int, extra: Dictionary = {}, ordinal: int = 0) -> Dictionary:
	var ids = Work.Ids.new(); ids.restore(world.entities)
	var a: Dictionary = Monsters.profile(name, "Lord", owner, 0, 1) if name in Monsters.NAMES else Marching.profile(name, "Lord", owner, 0, 1, true)
	a.x_fp = x
	a.merge(extra, true)
	var made: Dictionary = ids.create("marcher", "monster-test:" + name + ":" + str(owner), ordinal, owner, a)
	world.entities = ids.snapshot()
	return made.entity

func phase_world() -> Dictionary:
	var world: Dictionary = fixture()
	world.data["marching_round"] = 1
	world.data["marching_regen_round"] = 2
	world.data.kanifous_loss_round = 2
	world.data.monsters.phase_round = 1
	return world

func context(world: Dictionary, seed_value: String = "monster-check") -> Dictionary:
	return {"world": world, "round": 2, "hook": "marching", "seed": seed_value, "player_order": [0, 1], "persistent_effects": [], "full_roster": true}

func selected_seed(id: String, purpose: String, chance: int) -> String:
	for i in range(1000):
		var seed_value: String = "monster-check:" + str(i)
		if MonsterFX.Lamp.draw(seed_value, id + ":2", purpose, 100) < chance: return seed_value
	return "missing"

func phase(name: String, world: Dictionary, seed_value: String = "monster-check") -> Dictionary:
	var c: Dictionary = context(world, seed_value)
	var content = Game.Content.new()
	var result: Dictionary = Marching.resolve(c, Callable(content, "react"))
	check(result.action == "resolved", name + " resolves")
	if result.action == "invalid": print(result); return result
	check(Marching.valid(result.world) and Monsters.valid(result.world), name + " keeps valid unit and field state")
	var replay: Dictionary = Marching.resolve(c, Callable(content, "react"))
	check(replay == result, name + " deterministic replay")
	if phase_output != null:
		var record: Dictionary = {"name": name, "context": c, "result": result}
		var encoded: Dictionary = Codec.encode(record)
		if not encoded.has("text"):
			bad_data(record, "record")
			check(false, "phase transport encodes")
		else: phase_output.store_line(encoded.text)
		phase_output.flush()
	return result

func facts(result: Dictionary, kind: String) -> Array:
	return result.get("events", []).filter(func(r): return r.event.type == kind).map(func(r): return r.event.data)

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	var rows: Array = []
	for suit in ["Penitent", "Butcher", "Vulture", "Wright"]:
		for i in range(3): rows.append({"id": suit + str(i), "kind": "card", "attributes": {"suit": suit, "value": 1}})
	for name in Monsters.NAMES:
		var selected: Array = []
		for suit in Monsters.ROSTER[name].recipe:
			for i in range(Monsters.ROSTER[name].recipe[suit]): selected.append(suit + str(i))
		check(Monsters.qualifies(rows, selected, name), name + " exact recipe accepts value-one cards")
		check(not Monsters.qualifies(rows, selected.slice(1), name), name + " rejects missing ingredient")
		check(not Monsters.qualifies(rows, selected + [selected[0]], name), name + " rejects repeated card identity")
		check(Monsters.valid_unit(Monsters.profile(name, "Castle", 0, 1, 2)), name + " has a valid profile")
	var overlap: Array = ["Penitent0", "Penitent1", "Vulture0", "Vulture1", "Wright0", "Wright1"]
	check(Monsters.available(rows, overlap, 0) == ["Lemek", "Varn", "Kopita", "Tumler"], "overlapping recipes offer a choice, not multiple summons")
	var w: Dictionary = phase_world()
	var sooge: Dictionary = put(w, "Sooge", 0, 700)
	check(Monsters.living(w.entities.entities, 0, "Sooge") and not Monsters.living(w.entities.entities, 0, "Sinodek"), "Very hard living caps are separate")
	var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
	var root_seed: String = selected_seed(sooge.id, "ROOT", 25)
	var content = Game.Content.new()
	var first: Dictionary = MonsterFX.step(w, buffer, context(w, root_seed), 0, Callable(content, "react"))
	var rooted: Dictionary = buffer.get_entity(sooge.id)
	check(rooted.attributes.sprite_form == "turret" and rooted.attributes.armor == 6 and rooted.attributes.step_fp == 0, "Sooge roots into turret stats")
	rooted.attributes.armor = 2; buffer.update(rooted.id, rooted.owner, rooted.attributes)
	var future: Dictionary = context(first.world, root_seed); future.round = 3
	MonsterFX.step(first.world, buffer, future, 0, Callable(content, "react"))
	check(buffer.get_entity(sooge.id).attributes.sprite_form == "turret" and buffer.get_entity(sooge.id).attributes.armor == 2, "turret persists without refreshing armor each round")
	w = phase_world()
	var attacker: Dictionary = put(w, "Sooge", 0, 600, {"sprite_form": "turret", "attack": 3, "armor": 6, "max_armor": 6, "step_fp": 0})
	put(w, "Butcher", 0, 820, {"hp": 30, "max_hp": 30, "movement_ready_round": 9})
	put(w, "Penitent", 1, 1020, {"hp": 30, "max_hp": 30, "movement_ready_round": 9})
	var beam: Dictionary = phase("turret_piercing", w)
	check(facts(beam, "MONSTER_ATTACK").any(func(d): return d.ability == "Beam" and d.target.owner == 0), "turret beam also damages allies in its path")
	check(beam.world.entities.entities.any(func(u): return u.id == attacker.id and u.attributes.x_fp == 600 and u.attributes.sprite_form == "turret"), "turret remains rooted throughout Marching")
	w = phase_world()
	var portal_source: Dictionary = put(w, "Sinodek", 0, 600)
	var lost: Dictionary = put(w, "Lemek", 1, 950)
	var portal: Dictionary = phase("portal_banishes", w, selected_seed(portal_source.id, "PORTAL", 25))
	check(facts(portal, "MONSTER_BANISHED").any(func(d): return d.unit.id == lost.id), "portal banishes a body caught inside")
	check(not portal.world.data.kanifous_losses.any(func(r): return r.id == lost.id) and not portal.world.data.monsters.death_ids.has(lost.id), "banishment cannot resurrect or leave a Lemek death pool")
	var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
	check(playback.build(portal.events.map(func(r): return r.event)), "monster playback consumes spatial events")
	check(not playback.death_rows.any(func(r): return r.unit.id == lost.id), "portal playback omits the death animation")
	check(not playback.sample(playback.duration * 0.5).monster_fields.is_empty(), "portal is visible during playback")
	for name in ["Lemek", "Fyra", "Varn", "Kopita", "Tumler", "Kurchin", "Muno", "Dotra"]:
		w = phase_world()
		var unit: Dictionary = put(w, name, 0, 800, {"hp": 20, "max_hp": 20})
		put(w, "Wright", 1, 1030, {"hp": 25, "max_hp": 25})
		put(w, "Vulture", 1, 1250, {"hp": 20, "max_hp": 20, "y_fp": 480})
		var seed_value: String = selected_seed(unit.id, "HIDE", 25) if name == "Dotra" else "monster-check"
		var result: Dictionary = phase(name, w, seed_value)
		if name == "Muno": check(facts(result, "MONSTER_ATTACK").filter(func(d): return d.ability == "Muno").size() == 1, "Muno free strike is once per active round")
		if name == "Dotra": check(facts(result, "MONSTER_ATTACK").any(func(d): return d.ability == "Ambush"), "hidden Dotra delivers the ambush")
		if name == "Lemek": check(result.world.data.monsters.fields.any(func(f): return f.kind == "pool"), "Lemek death creates a pool")
	w = phase_world()
	put(w, "Fyra", 0, 800, {"hp": 25, "max_hp": 25})
	put(w, "Fyra", 1, 1030, {"hp": 25, "max_hp": 25})
	phase("reciprocal_charm", w)
	w = phase_world()
	var eaten: Dictionary = put(w, "Lemek", 1, 800, {"movement_ready_round": 9})
	var actor: Dictionary = Marching.KroniActors.create("monster-devour-check", 0, 2, 0)
	actor.x_fp = 700; actor.y_fp = 300; actor.vy_fp = 1
	w.data.kroni_actors = [actor]
	var consumed: Dictionary = phase("consumed_lemek", w)
	var bites: Array = facts(consumed, "MARCHER_DEVOURED").filter(func(d): return d.before.id == eaten.id)
	var pools: Array = facts(consumed, "MONSTER_FIELD_CREATED")
	check(not bites.is_empty() and pools.size() == 1 and pools[0].get("tick", -1) == bites[0].tick, "devoured Lemek creates its pool on the death tick")
	# Longevity is tested at both admission and firing, including reduced maxima.
	for maximum in [10, 21]:
		for health in [0, 7, 13, 14, 15, 21]:
			if health > maximum: continue
			w = fixture()
			var castle: Dictionary = w.entities.entities.filter(func(r): return r.kind == "castle" and r.owner == 0)[0]
			castle.attributes.merge({"integrity": health, "max_integrity": maximum, "status": "standing" if health else "defunct", "construction_state": "active"}, true)
			var source: Dictionary = {"power_id": "WishLongevity", "player_id": 0, "target": {"entity_id": castle.id}, "parameters": {}, "declaration_id": "longevity-check"}
			var eligible: bool = health < mini(14, maximum)
			check(content.validate(source, w, "declaration").legal == eligible and content.validate(source, w, "firing").legal == eligible, "Longevity eligibility %d/%d" % [health, maximum])
			var result: Dictionary = content.resolve({"declaration": source}, {"world": w, "round": 1, "seed": "longevity"})
			check(Kanifous._entity(result.world, castle.id).attributes.integrity == (mini(14, maximum) if eligible else health), "Longevity never harms or exceeds ceiling")
			check(result.world.data.kanifous_prices.size() == (1 if eligible else 0), "only actual healing creates a Price")
	special_checks()
	if phase_output != null: phase_output.close()
	board = Board.new(); root.add_child(board); board._runtime_ok = true
	await process_frame
	board._open_recipes()
	check(board.recipe_menu.visible and board.recipe_menu.column.get_child_count() == 13, "RECIPES opens all ten monster entries")
	check(board.monster_picker.get_parent() == board.action_zone.action_box, "summon chooser belongs to the Combat modal")
	board.queue_free()
	print("U13 monster checks failures: ", failures)
	quit(1 if failures else 0)

func bad_data(value, path: String) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for key in value:
			if typeof(key) != TYPE_STRING: print("BAD KEY ", path, " ", key)
			bad_data(value[key], path + "." + str(key))
	elif typeof(value) == TYPE_ARRAY:
		for i in range(value.size()): bad_data(value[i], path + "." + str(i))
	elif typeof(value) not in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]: print("BAD VALUE ", path, " ", typeof(value))
	elif typeof(value) == TYPE_FLOAT and not is_finite(value): print("BAD FLOAT ", path)

func special_checks() -> void:
	var world: Dictionary = phase_world()
	var dead: Dictionary = put(world, "Sooge", 0, 900, {"sprite_form": "turret", "step_fp": 0, "attack": 3, "armor": 0})
	var ids = Work.Ids.new(); ids.restore(world.entities); ids.retire(dead.id); world.entities = ids.snapshot()
	world.data.kanifous_losses = [dead]
	var content = Game.Content.new()
	var source: Dictionary = {"power_id": "WishResurrection", "player_id": 0, "target": {"lane": "Lord"}, "parameters": {}, "declaration_id": "resurrect-monster"}
	var revived: Dictionary = content.resolve({"declaration": source}, {"world": world, "round": 2, "seed": "monster-resurrection"})
	var bodies: Array = revived.world.entities.entities.filter(func(r): return r.attributes.get("monster_id") == "Sooge")
	check(bodies.size() == 1 and bodies[0].attributes.sprite_form == "turret" and bodies[0].attributes.armor == 6 and bodies[0].attributes.movement_ready_round == 3, "resurrection preserves turret form and restores monster stats")
	check(Kanifous.Lamp.valid(revived.world), "monster corpses and resurrection remain valid save data")
	source.declaration_id = "second-resurrection"
	var again: Dictionary = content.resolve({"declaration": source}, {"world": revived.world, "round": 2, "seed": "monster-resurrection"})
	check(again.events.back().event.data.count == 0 and again.world.data.kanifous_prices.size() == 1, "resurrection cannot duplicate a living Very hard monster or create a no-op Price")
	world = phase_world()
	put(world, "Sooge", 0, 800)
	var enemy_turret: Dictionary = put(world, "Sooge", 1, 850)
	var shifted: Dictionary = content._shift({"action": "resolved", "world": world, "events": []}, {"lane": "Lord", "field_position": {"x_fp": 850, "y_fp": 300}}, 0, 2, "monster-cap-shift")
	check(shifted.action == "resolved" and shifted.events.back().event.data.affected_ids.is_empty(), "allegiance powers cannot exceed the living monster cap")
	enemy_turret.owner = 0; enemy_turret.attributes["charm_owner"] = 1
	check(Monsters.living([enemy_turret], 1, "Sooge"), "charm reserves the original owner's living slot")
	world = phase_world()
	var caster: Dictionary = put(world, "Fyra", 0, 800)
	var victim: Dictionary = put(world, "Wright", 1, 1000)
	var buffer = Marching.Buffer.new(); buffer.restore(world.entities)
	var seed_value: String = ""
	for i in range(1000):
		if MonsterFX.Lamp.draw(str(i), "%s:2:0:%s" % [caster.id, victim.id], "CHARM", 100) < 15: seed_value = str(i); break
	var charm: Array = MonsterFX.on_hit(buffer, caster, victim.id, 1, context(world, seed_value), 0)
	check(charm.size() == 1 and buffer.get_entity(victim.id).owner == 0, "Fyra charm changes allegiance")
	world.entities = buffer.snapshot()
	MonsterFX.end_round(world, 2)
	check(world.entities.entities.any(func(r): return r.id == victim.id and r.owner == 1 and not r.attributes.has("charm_owner")), "charm restores ownership before the next round")
	world = phase_world(); caster = put(world, "Varn", 0, 0); victim = put(world, "Wright", 1, 1500)
	buffer.restore(world.entities)
	for i in range(1000):
		if MonsterFX.Lamp.draw(str(i), "%s:2:0:%s" % [caster.id, victim.id], "POISON", 100) < 10: seed_value = str(i); break
	check(not MonsterFX.on_hit(buffer, caster, victim.id, 1, context(world, seed_value), 0).is_empty(), "Varn applies poison after a damaging hit")
	world.entities = buffer.snapshot()
	var c: Dictionary = context(world); c.round = 3
	var poisoned: Dictionary = MonsterFX.step(world, buffer, c, 0, Callable(content, "react"))
	check(buffer.get_entity(victim.id).attributes.hp == 4 and buffer.get_entity(victim.id).attributes.armor == 2, "poison damages HP through armor next round")
	c.round = 4; MonsterFX.step(poisoned.world, buffer, c, 0, Callable(content, "react"))
	check(buffer.get_entity(victim.id).attributes.hp == 3, "poison lasts a second round")
	c.round = 5; MonsterFX.step(poisoned.world, buffer, c, 0, Callable(content, "react"))
	check(buffer.get_entity(victim.id).attributes.hp == 3 and not buffer.get_entity(victim.id).attributes.has("poison_until_round"), "poison expires without stacking")
	check(not MonsterFX.slowed({"flying": true, "lane": "Lord", "x_fp": 200, "y_fp": 300}, [{"kind": "pool", "lane": "Lord", "x_fp": 200, "y_fp": 300}]), "Fyra ignores ground pools")
