extends "res://Scripts/Sim/U13MonsterTestRunner.gd"
const Meter = preload("res://Scripts/Sim/U13LaneBattleMetrics.gd")

func event(kind: String, data: Dictionary) -> Dictionary:
	return {"event": {"type": kind, "data": data}}

func run() -> void:
	var w: Dictionary = phase_world()
	var source: Dictionary = put(w, "Butcher", 0, 1000)
	var target: Dictionary = put(w, "Penitent", 1, 1060, {"hp": 2, "max_hp": 2, "armor": 2})
	var meter = Meter.new(); meter.observe([source, target])
	meter.consume([event("MARCHING_STARTED", {"units": [source, target]})], 2)
	check(meter.units[target.id].counts.deployed == 1, "a body killed during its first tick still counts as deployed")
	var hit: Dictionary = {"attacker": source, "target": target, "damage_dealt": 1, "hp_after": 1, "tick": 0}
	meter.consume([event("MARCHER_MELEE_ATTACK", hit)], 2)
	hit = hit.duplicate(true); hit.damage_dealt = 3; hit.hp_after = 0
	meter.consume([event("MARCHER_MELEE_ATTACK", hit)], 2)
	hit = hit.duplicate(true); hit.damage_dealt = 0
	meter.consume([event("MARCHER_MELEE_ATTACK", hit)], 2)
	check(meter.units[source.id].counts.enemy_hp_damage == 2, "stale volley snapshots and already-dead targets cannot duplicate HP damage")
	check(meter.units[source.id].counts.enemy_armor_damage == 2 and meter.units[source.id].counts.overkill_hp == 2, "Armor and overkill are separate from actual HP removed")
	meter = Meter.new(); meter.observe([source, target])
	hit = {"attacker": source, "target": target, "damage_dealt": 0, "hp_after": 2, "evaded": true, "tick": 0}
	meter.consume([event("MARCHER_MELEE_ATTACK", hit)], 2)
	check(meter.units[target.id].counts.evaded_hits == 1 and meter.units[source.id].counts.get("enemy_armor_damage", 0) == 0, "evaded damage never consumes fictitious Armor")
	var healer: Dictionary = put(w, "Kopita", 1, 950)
	meter.observe([healer])
	meter.hp[target.id] = 1
	var healed: Dictionary = target.duplicate(true); healed.attributes.hp = 2; healed["amount"] = 1
	meter.consume([event("MONSTER_PULSE", {"source": healer, "healing": true, "healed": [healed]})], 2)
	hit = {"attacker": source, "target": target, "damage_dealt": 3, "hp_after": 0, "tick": 0}
	meter.consume([event("MARCHER_MELEE_ATTACK", hit)], 2)
	check(meter.units[healer.id].counts.heal_hp == 1 and meter.units[source.id].counts.enemy_hp_damage == 2, "healing updates the ordered HP ledger")
	var wall: Dictionary = {"id": "test-wall", "kind": "fortification", "owner": 1, "attributes": {"hp": 2, "armor": 1, "structure": "Wall", "builder_id": "builder"}}
	meter = Meter.new(); meter.observe([source, wall])
	var destroyed: Dictionary = wall.duplicate(true); destroyed.attributes.hp = 0
	meter.consume([event("WRIGHT_STRUCTURE_DESTROYED", {"structure": destroyed, "attacker": source}), event("MARCHER_MELEE_ATTACK", {"attacker": source, "target": wall, "damage_dealt": 2, "hp_after": 0, "tick": 0})], 2)
	check(meter.units[source.id].counts.enemy_hp_damage == 2 and meter.units[source.id].counts.enemy_armor_damage == 1, "destroy-before-hit event order preserves structure damage credit")
	var dog: Dictionary = put(w, "Tumler", 0, 900)
	var turret: Dictionary = put(w, "Sinodek", 1, 1500)
	meter = Meter.new(); meter.observe([source, target, dog, turret])
	var field: Dictionary = {"kind": "portal", "id": "portal", "source_id": turret.id, "owner": 1, "lane": "Lord", "x_fp": 900, "y_fp": 300}
	meter.consume([event("MONSTER_FIELD_CREATED", {"field": field}), event("MONSTER_BANISHED", {"unit": dog, "portal_id": field.id}), event("MONSTER_BANISHED", {"unit": target, "portal_id": field.id})], 2)
	check(meter.units[turret.id].counts.enemy_banishments == 1 and meter.units[turret.id].counts.ally_banishments == 1, "portal contribution separates friendly and enemy banishments")
	meter.consume([event("MARCHER_WAITING", {"entity_id": source.id}), event("MARCHER_WAITING", {"entity_id": source.id})], 2)
	check(meter.units[source.id].counts.goal_crossings == 1, "goal credit is unique per body")
	# Validate ledger totals against actual ending HP and Armor, not just totals
	# incremented by the same observer on the attacker and victim sides.
	for pid in [0, 1]:
		w = phase_world()
		var allies: Array = []
		for i in range(2): allies.append(put(w, "Butcher", pid, 1000, {"y_fp": 270+i*60, "hp": 5, "max_hp": 5, "step_fp": 0}, i))
		var victim: Dictionary = put(w, "Penitent", 1-pid, 1060, {"hp": 3, "max_hp": 3, "step_fp": 0})
		var r: Dictionary = phase("audit_real_volley_%d" % pid, w)
		meter = Meter.new(); meter.observe(w.entities.entities.filter(func(u): return u.kind == "marcher"))
		var encoded: String = Codec.encode(r).text
		meter.consume(r.events, 2)
		check(encoded == Codec.encode(r).text, "observer cannot mutate native events or combat world")
		var remaining: Dictionary = Kanifous._entity(r.world, victim.id)
		var loss: int = 3 - (0 if remaining.is_empty() else int(remaining.attributes.hp))
		var armor_loss: int = int(victim.attributes.armor) - (0 if remaining.is_empty() else int(remaining.attributes.armor))
		check(meter.units[victim.id].counts.enemy_hp_taken == loss and meter.units[victim.id].counts.armor_absorbed == armor_loss, "observed HP/Armor loss reconciles with native survivor state")
		check(meter.units.values().all(func(u): return u.counts.get("unaccounted_packets", 0) == 0), "all native damage packets are accounted")
	# Real direct-ability packets, including rare beams and temporary wards.
	for ability in ["Beam", "Muno", "Kopita", "Ambush", "Poison"]:
		w = phase_world()
		var caster: Dictionary = put(w, {"Beam": "Sooge", "Muno": "Muno", "Kopita": "Kopita", "Ambush": "Dotra", "Poison": "Varn"}[ability], 0, 1000)
		var victim: Dictionary = put(w, "Butcher", 1, 1100, {"hp": 20, "max_hp": 20, "armor": 2})
		var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
		var amounts: Dictionary = {"Beam": 3, "Muno": caster.attributes.attack, "Kopita": MonsterFX.Rules.TUNING.kopita_damage, "Ambush": 5, "Poison": 1}
		var r: Dictionary = MonsterFX.damage(w, buffer, {"source": caster, "target": victim.id, "amount": amounts[ability], "bypass": ability == "Poison", "ability": ability}, context(w), 0, Callable(Game.Content.new(), "react"))
		meter = Meter.new(); meter.observe([caster, victim]); meter.consume(r.events, 2)
		var after: Dictionary = buffer.get_entity(victim.id)
		check(meter.units[caster.id].counts.get("enemy_hp_damage", 0) == 20-int(after.attributes.hp) and meter.units[caster.id].counts.get("enemy_armor_damage", 0) == 2-int(after.attributes.armor), "native " + ability + " HP/Armor attribution matches actual damage state")
		check(meter.units[caster.id].counts.get("unaccounted_packets", 0) == 0, "native " + ability + " packet is accounted")
	print("U13 lane contribution metrics failures: ", failures)
	quit(1 if failures else 0)
