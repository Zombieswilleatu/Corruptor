extends RefCounted
# Read-only observer. No combat, spawn, targeting, or RNG decisions happen here.
const FX = preload("res://Scripts/Sim/U13MonsterEffects.gd")
const Fort = preload("res://Scripts/Sim/U13FieldFortifications.gd")
const Matchups = preload("res://Scripts/Sim/U13MarcherMatchups.gd")
const Wish = preload("res://Scripts/Sim/U13Wishmaster.gd")
var units: Dictionary = {}
var hp: Dictionary = {}
var deployed: Dictionary = {}
var charms: Dictionary = {}
var fields: Dictionary = {}
var exposed: Dictionary = {}
var bases: Dictionary = {}
var previous: Dictionary = {}
var goals: Dictionary = {}
var event_counts: Dictionary = {}
var ticks: int = 0

func remember(row: Dictionary) -> String:
	var id: String = row.id
	if not units.has(id):
		var a: Dictionary = row.attributes
		units[id] = {"id": id, "name": a.get("monster_id", a.get("structure", a.get("suit", "Unknown"))), "kind": row.get("kind", "marcher"), "birth_owner": row.owner, "birth_round": a.get("birth_round", 0), "builder_id": a.get("builder_id", ""), "counts": {"bodies": 1}}
		if a.has("hp"): hp[id] = int(a.hp)
	return id

func add(id: String, key: String, amount: int = 1) -> void:
	if id.is_empty() or not units.has(id) or amount == 0: return
	var counts: Dictionary = units[id].counts
	counts[key] = int(counts.get(key, 0)) + amount

func observe(rows: Array, staged: bool = false) -> void:
	for row in rows:
		var id: String = remember(row)
		if staged: add(id, "staged_rounds")

func packet(d: Dictionary, kind: String, clock: int) -> int:
	# Reconstruct the engine's deterministic pre-Armor packet; never roll RNG.
	# Block/evasion/ward outcomes come from the authoritative event itself.
	if d.get("blocked", false) or d.get("evaded", false) or d.get("warded", false): return 0
	var amount: int = 0
	if kind == "MONSTER_ATTACK":
		match d.ability:
			"Muno": amount = int(d.attacker.attributes.attack)
			"Ambush": amount = 5
			"Poison": amount = 1
			"Kopita": amount = int(FX.Rules.TUNING.kopita_damage)
			"Beam": amount = 1 if d.attacker.owner == d.target.owner else 3
			_: return -1
	elif d.attacker.get("kind") == "fortification": amount = 1
	else:
		amount = Wish.attack_amount(d.attacker.attributes.duplicate(true)) + Matchups.bonus(d.attacker, d.target)
		if kind == "MARCHER_MELEE_ATTACK": amount += FX.hunt_bonus(d.attacker, d.target)
	if d.target.get("kind") == "fortification": return amount
	return FX.Incoming.amount(d.target.attributes, amount, clock) if kind == "MONSTER_ATTACK" else FX.Incoming.regular_amount(d.target.attributes, amount, clock)

func attack(d: Dictionary, kind: String, clock: int) -> void:
	var source: String = remember(d.attacker)
	var target: String = remember(d.target)
	var before: int = int(hp.get(target, d.target.attributes.hp))
	var raw: int = int(d.get("damage_dealt", 0))
	var after: int = int(d.get("hp_after", before))
	# A batch can contain stale target snapshots or shots after a lethal hit.
	# Ordered HP accounting prevents duplicate damage credit and overkill.
	var actual: int = mini(raw, maxi(0, before - after))
	hp[target] = after
	var friendly: bool = d.attacker.owner == d.target.owner
	var ability: String = str(d.get("ability", "Melee" if kind == "MARCHER_MELEE_ATTACK" else "Ranged"))
	add(source, "attacks"); add(target, "incoming_attacks")
	add(source, "ability_" + ability + "_attacks")
	add(source, "ability_" + ability + "_hp", actual)
	var incoming: int = packet(d, kind, clock) if before > 0 else 0
	if incoming < raw:
		add(source, "unaccounted_packets")
	else:
		var armor: int = incoming - raw
		add(source, "friendly_armor_damage" if friendly else "enemy_armor_damage", armor)
		add(target, "armor_absorbed", armor)
	add(source, "raw_post_armor_damage", raw)
	add(source, "overkill_hp", maxi(0, raw - actual))
	add(source, "friendly_hp_damage" if friendly else "enemy_hp_damage", actual)
	add(source, "structure_hp_damage" if d.target.get("kind") == "fortification" else "unit_hp_damage", actual)
	add(target, "friendly_hp_taken" if friendly else "enemy_hp_taken", actual)
	if actual > 0: add(source, "damaging_hits")
	if d.get("blocked", false): add(target, "blocked_hits")
	if d.get("evaded", false): add(target, "evaded_hits")
	if d.get("warded", false): add(target, "ward_absorbed_hits")
	if charms.has(source) and d.attacker.attributes.has("charm_owner"):
		add(charms[source], "charmed_body_hp_damage", actual)
	if exposed.has(target) and clock < int(exposed[target].until) and not friendly:
		# This bonus is already part of the attacker's HP damage, not additive.
		var extra: int = actual - mini(maxi(0, raw - 1), before) if raw > 0 else 0
		add(exposed[target].source, "exposure_bonus_hp", maxi(0, extra))

func consume(events: Array, number: int) -> void:
	for row in events:
		var e: Dictionary = row.event
		var d: Dictionary = e.data
		var kind: String = e.type
		event_counts[kind] = int(event_counts.get(kind, 0)) + 1
		var clock: int = number * 200 + int(d.get("tick", 0))
		match kind:
			"MARCHING_STARTED":
				bases = {}; fields = {}
				for field in d.get("monster_fields", []): fields[field.id] = field
				for unit in d.units:
					var id: String = remember(unit)
					add(id, "self_regen_hp", maxi(0, int(unit.attributes.hp) - int(hp[id])))
					hp[id] = int(unit.attributes.hp)
					bases[id] = unit
					if not deployed.has(id) and not unit.attributes.waiting and int(unit.attributes.movement_ready_round) <= number:
						deployed[id] = true; add(id, "deployed")
					if not unit.attributes.has("charm_owner"): charms.erase(id)
				for structure in d.get("field_structures", []): remember(structure)
			"MARCHER_MELEE_ATTACK", "MARCHER_RANGED_ATTACK", "MONSTER_ATTACK": attack(d, kind, clock)
			"MARCHER_DEFEATED":
				var id: String = remember(d.victim)
				add(id, "deaths")
				if d.has("attacker"):
					var killer: String = remember(d.attacker)
					add(killer, "friendly_kills" if d.attacker.owner == d.victim.owner else "enemy_kills")
			"MARCHER_WAITING":
				if not goals.has(d.entity_id):
					goals[d.entity_id] = true
					add(d.entity_id, "goal_crossings")
			"MONSTER_PULSE":
				var source: String = remember(d.source)
				add(source, "heal_pulses" if d.healing else "harm_pulses")
				for healed in d.healed:
					add(source, "heal_hp", int(healed.amount))
					add(healed.id, "healing_received", int(healed.amount))
					hp[healed.id] = int(healed.attributes.hp)
			"WRIGHT_STRUCTURE_BUILT":
				remember(d.structure)
				add(d.unit_id, "towers_built" if d.structure.attributes.structure == "Tower" else "walls_built")
			"WRIGHT_STRUCTURE_REPAIRED":
				remember(d.structure)
				var healed: int = int(d.hp_after) - int(d.hp_before)
				add(d.unit_id, "repair_hp", healed); add(d.structure.id, "repairs_received", healed)
				hp[d.structure.id] = int(d.hp_after)
			"WRIGHT_STRUCTURE_DESTROYED":
				remember(d.structure); add(d.structure.id, "destroyed")
				add(remember(d.attacker), "structures_destroyed")
			"MONSTER_CHARMED":
				charms[d.unit_id] = d.source_id
				add(d.source_id, "charms"); add(d.unit_id, "times_charmed")
			"MONSTER_POISONED": add(d.source_id, "poison_procs")
			"MONSTER_WARD_GAINED": add(d.unit_id, "wards_gained")
			"MONSTER_HUNT_RETARGETED": add(d.unit_id, "hunt_intercepts")
			"MONSTER_EXPOSURE_PULSE":
				var source: String = remember(d.source)
				add(source, "exposure_pulses"); add(source, "bodies_exposed", d.affected.size())
				for unit in d.affected: exposed[unit.id] = {"source": source, "until": d.until_tick}
			"MONSTER_ROOTED": add(d.unit_id, "rooted")
			"MONSTER_BEAM_FIRED": add(remember(d.attacker), "beams_fired")
			"MONSTER_FIELD_CREATED":
				fields[d.field.id] = d.field
				add(field_source(d.field), "pools_created" if d.field.kind == "pool" else "portals_created")
			"MONSTER_BANISHED":
				var target: String = remember(d.unit)
				add(target, "banished")
				var field: Dictionary = fields.get(d.portal_id, {})
				if not field.is_empty(): add(field_source(field), "ally_banishments" if d.unit.owner == field.owner else "enemy_banishments")
			"MARCHING_TICK": sample_tick(d, number, clock)

func field_source(field: Dictionary) -> String:
	return str(field.get("source_id", str(field.id).trim_suffix(":pool")))

func sample_tick(d: Dictionary, number: int, clock: int) -> void:
	ticks += 1
	var rows: Array = []
	for delta in d.units:
		var unit: Dictionary = bases.get(delta.id, delta).duplicate()
		unit.attributes = unit.attributes.merged(delta.attributes, true)
		unit.owner = delta.owner
		rows.append(unit)
	var has_taunt: bool = rows.any(func(u): return u.attributes.get("monster_id") == "Kurchin")
	for unit in rows:
		var id: String = remember(unit)
		var a: Dictionary = unit.attributes
		add(id, "field_ticks")
		if not a.waiting and int(a.movement_ready_round) <= number:
			if not deployed.has(id): deployed[id] = true; add(id, "deployed")
			add(id, "active_ticks")
			if a.get("hidden", false): add(id, "hidden_ticks")
			if charms.has(id) and a.has("charm_owner"): add(charms[id], "charmed_body_ticks")
			if exposed.has(id) and clock < int(exposed[id].until): add(exposed[id].source, "exposed_body_ticks")
			if previous.has(id) and Fort.distance(previous[id], a) == 0 and (int(a.y_fp) <= 30 or int(a.y_fp) >= 570 or int(a.x_fp) == 0 or int(a.x_fp) == 2400):
				add(id, "edge_stationary_ticks") # Diagnostic, includes legitimate holds.
			if has_taunt and not a.get("hidden", false):
				var target: Dictionary = FX.preferred(unit, rows)
				if not target.is_empty() and target.attributes.get("monster_id") == "Kurchin": add(target.id, "taunt_target_ticks")
			var nearest_pool: Dictionary = {}
			var pool_gap: int = 9223372036854775807
			for field in fields.values():
				if field.lane != a.lane: continue
				var gap: int = Fort.distance(a, field)
				if field.kind == "pool" and FX.slowed(a, [field]) and gap < pool_gap:
					nearest_pool = field; pool_gap = gap
				elif field.kind == "portal" and id != field.get("source_id", "") and gap <= int(FX.Rules.TUNING.portal_fear_radius) ** 2:
					add(field_source(field), "ally_portal_zone_ticks" if unit.owner == field.owner else "enemy_portal_zone_ticks")
			if not nearest_pool.is_empty(): add(field_source(nearest_pool), "ally_slow_ticks" if unit.owner == nearest_pool.owner else "enemy_slow_ticks")
		previous[id] = {"x_fp": a.x_fp, "y_fp": a.y_fp}
	for structure in d.get("field_structures", []): add(remember(structure), "field_ticks")

func finish(alive: Array, staged: Array, structures: Array) -> Dictionary:
	var active_ids: Dictionary = {}; var staged_ids: Dictionary = {}
	for row in alive + structures: active_ids[row.id] = true
	for row in staged: staged_ids[row.id] = true
	var output: Array = []
	for record in units.values():
		var copy: Dictionary = record.duplicate(true)
		copy["alive_at_cutoff"] = active_ids.has(record.id)
		copy["staged_at_cutoff"] = staged_ids.has(record.id)
		output.append(copy)
	return {"units": output, "event_counts": event_counts, "ticks": ticks}
