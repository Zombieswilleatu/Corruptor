extends RefCounted

const Victory = preload("res://Scripts/Sim/U13Victory.gd")

# Public presentation only. Never infer an attacker from the victim's owner.
static func render(world: Dictionary, events: Array, round_number: int, before: Dictionary = {}, pending: Array = []) -> String:
	var groups: Array = [{}, {}, {}]
	# Public pending declarations include delayed powers used this round.
	events = events.duplicate()
	for record in pending:
		var source: Dictionary = record.get("declaration", {})
		if int(source.get("declared_round", -1)) == round_number:
			events.append({"type": "POWER_QUEUED", "data": {"round": round_number, "player_id": source.get("player_id", -1), "power_id": source.get("power_id", ""), "fire_round": record.get("fire_round", round_number)}})

	for event in events:
		var d: Dictionary = event.get("data", {})
		if int(d.get("round", d.get("created_round", d.get("attributes", {}).get("birth_round", -1)))) != round_number:
			continue
		var pid: int = int(d.get("player_id", d.get("owner", -1)))
		if event.get("type") == "VACANT_THRONE_RESOLVED": pid = int(d.get("soul_recipient", -1))
		if d.get("attacker") is Dictionary:
			pid = int(d.attacker.get("owner", -1))
		if event.get("type") == "MARCHER_ALLEGIANCE_CHANGED":
			pid = int(d.get("new_owner", -1))
		d = d.duplicate(true)
		if event.get("type") == "SIEGE_RESOLVED":
			# Bastion facts credit the defender. Join to this attack using the
			# opposite seat, round and original target; never add unrelated hits.
			for fact in events:
				var hit: Dictionary = fact.get("data", {})
				if fact.get("type") == "BASTION_SCREENED" and int(hit.get("round", -1)) == round_number and hit.get("player_id", -1) == 1 - pid and hit.get("target_id", "") == d.get("target_id", ""):
					d["bastion_damage"] = int(d.get("bastion_damage", 0)) + int(hit.get("damage", 0))
		if d.has("castle_id"):
			var castle_id: String = str(d.castle_id)
			d.castle_id = "Castle"
			for entity in world.get("entities", []):
				if entity.id == castle_id:
					d.castle_id = name_of(entity)
					break
		var line: String = describe(String(event.get("type", "")), d)
		if line.is_empty():
			continue
		var group: Dictionary = groups[pid if pid in [0, 1] else 2]
		group[line] = int(group.get(line, 0)) + 1
	var sections: PackedStringArray = []
	var victory: Dictionary = world.get("victory", {})
	if int(victory.get("winner", -1)) in [0, 1] and int(victory.get("checked_round", -1)) == round_number:
		sections.append(result_summary(world, victory))
	for pid in [0, 1]:
		var lines: PackedStringArray = ["%s · %s" % ["YOU" if pid == 0 else "OPPONENT", world.get("lord_ids", ["", ""])[pid]]]
		for key in ["souls", "personal_tears"]:
			var value: int = int(world.get(key, [0, 0])[pid])
			var label: String = "Souls" if key == "souls" else "Personal Tears"
			if before.has(key):
				lines.append("%s: %d → %d (%+d net)" % [label, before[key][pid], value, value - int(before[key][pid])])
			else:
				lines.append("%s: %d current" % [label, value])
		append_rows(lines, groups[pid])
		sections.append("\n".join(lines))
	var shared: PackedStringArray = ["SHARED / UNATTRIBUTED"]
	var neutral: int = int(world.get("neutral_tears", 0))
	shared.append("Neutral Tears: %d → %d (%+d net)" % [before.neutral_tears, neutral, neutral - int(before.neutral_tears)] if before.has("neutral_tears") else "Neutral Tears: %d current" % neutral)
	append_rows(shared, groups[2])
	sections.append("\n".join(shared))
	return "\n\n".join(sections)

static func result_summary(world: Dictionary, outcome: Dictionary) -> String:
	var winner: int = int(outcome.get("winner", -1))
	if winner not in [0, 1]: return ""
	var method: String = outcome.get("win_by", "")
	var title: String = "%s · %s" % ["VICTORY" if winner == 0 else "DEFEAT", method.capitalize()]
	var lord: String = world.get("lord_ids", ["You", "Opponent"])[winner]
	var tears: Array = world.get("personal_tears", [0, 0])
	var souls: Array = world.get("souls", [0, 0])
	var veil: int = int(world.get("veil_total", int(world.get("neutral_tears", 0)) + int(tears[0]) + int(tears[1])))
	match method:
		"Dominion": return "%s\n%s won with %d Personal Tears to %d. Veil reached %d.\nRequires Veil %d+, at least %d Personal Tears and more than the opponent." % [title, lord, tears[winner], tears[1 - winner], veil, Victory.DOMINION_VEIL, Victory.DOMINION_TEARS]
		"Ritual": return "%s\n%s won with %d Souls and their Lord present.\nRequires %d Souls and a present Lord." % [title, lord, souls[winner], Victory.RITUAL_SOULS]
		"RoundLimit": return "%s\nRound 25 reached. %s won with %d Souls to %d.%s" % [title, lord, souls[winner], souls[1 - winner], " Seat 0 wins a tied Soul count." if souls[0] == souls[1] else ""]
		"FinalCollapse": return "%s\nVeil reached %d. %s won with %d Souls to %d.%s" % [title, veil, lord, souls[winner], souls[1 - winner], " Seat 0 wins a tied Soul count." if souls[0] == souls[1] else ""]
	return title

static func append_rows(lines: PackedStringArray, rows: Dictionary) -> void:
	for line in rows:
		lines.append("• " + line + (" ×%d" % rows[line] if rows[line] > 1 else ""))

static func name_of(entity: Dictionary) -> String:
	var a: Dictionary = entity.get("attributes", {})
	var label: String = str(a.get("castle_type", a.get("lord_id", a.get("suit", entity.get("kind", "unit"))))).capitalize()
	return ("Your " if entity.get("owner", -1) == 0 else "Opponent's " if entity.get("owner", -1) == 1 else "") + label

static func describe(kind: String, d: Dictionary) -> String:
	match kind:
		"STAGING_OVERFLOW_RELEASED": return "%s staging full · %d oldest reserves marched" % [d.lane, d.unit_ids.size()]
		"STAGING_RECRUITMENT_CAPPED": return "%s staging capped at 15 · %d excess recruits not retained" % [d.lane, d.count]
		"WRIGHT_STRUCTURE_REPAIRED": return "Wright repaired %s · HP %d → %d" % [d.structure.attributes.structure, d.hp_before, d.hp_after]
		"WRIGHT_REPAIR_ASSIGNED": return "Wright taking over damaged %s" % d.structure.attributes.structure
		"MONSTER_SUMMONED": return "%s summoned · %d %s lane bodies" % [d.monster_id, d.unit_ids.size(), d.lane]
		"MONSTER_ROOTED": return "Sooge rooted permanently into turret form"
		"MONSTER_BANISHED": return "%s banished by Sinodek" % d.unit.attributes.get("monster_id", d.unit.attributes.get("suit", "Marcher"))
		"MONSTER_CHARMED": return "Fyra charmed an enemy for the remainder of the round"
		"PILLAGE_RETARGETED": return "Pillage became Siege against " + str(d.get("castle_id", "Castle"))
		"CASTLE_DEFUNCT": return "%s · %s is defunct (repairable)" % [d.get("cause", "Castle disabled"), d.get("castle_id", "Castle")]
		"CASTLE_DAMAGED": return "%s · %d damage · Castle health %d" % [d.get("cause", d.get("source", "Castle damage")), d.get("damage", 0), d.get("integrity", 0)]
		"COMMISSION_FIZZLED": return "Commission failed · " + str(d.get("castle_id", "Castle"))
		"KANIFOUS_WISH_RESOLVED":
			var power: String = d.get("power", "")
			var count: int = int(d.get("count", 0))
			match power:
				"WishDeath": return "Deathwish · %d Marchers killed" % count
				"WishPower": return "Wish of Power · %d Marchers summoned" % count
				"WishLongevity": return "Wish of Longevity · %d Castles restored" % count
				"WishResurrection": return "Wish of Resurrection · %d Marchers revived in %s lane" % [count, d.target.lane]
				"WishWealth": return "Wish of Wealth · %d cards drawn" % count
			return "Wish · no effect" if count == 0 else "Wish resolved"
		"CASTLE_RUINED": return "Ruined " + str(d.get("castle_id", "Castle"))
		"WORK_RESOLVED": return "Work · %s: %d → %d" % [d.get("castle_id", "Castle"), d.get("before", 0), d.get("after", 0)]
		"GUARD_PAIR_DRAW": return "Vulture pair drew 1 card"
		"GUARD_PAIR_STRIKE": return "Butcher pair destroyed an enemy Marcher"
		"GUARD_PAIR_SCREEN": return "Penitent pair provided %d protection" % d.get("amount", 0)
		"WARD_SOUL_GAINED": return "+1 Soul · Ward prevented a successful attack in " + str(d.get("lane", ""))
		"DECISIVE_SOUL_GAINED": return "+1 Soul · late-game " + str(d.get("attack", "attack")) + " victory"
		"COMBAT_ORDER_REVEALED": return "Action: " + str(d.get("order", {}).get("action", "Pass"))
		"MARCHER_SPAWNED":
			return "Power summoned a " + str(d.get("attributes", {}).get("suit", "Marcher")) if d.get("attributes", {}).has("source_effect_id") else ""
		"ROUT_APPLIED": return "Rout · %d Marchers routed in %s lane" % [d.get("affected_ids", []).size(), d.get("lane", "")]
		"REDIRECT_RESOLVED": return "Redirect · %d Marchers redirected" % d.get("changes", []).size()
		"RECONFIGURATION_RESOLVED": return "Reconfiguration · %d Marchers moved" % d.get("moved", 0)
		"ALLEGIANCE_SHIFT_RESOLVED": return "Allegiance Shift · %d Marchers affected" % d.get("affected_ids", []).size()
		"LANE_AURA_STARTED": return "%s · active in %s lane" % [str(d.get("power_id", "Power")).capitalize(), d.get("lane", "")]
		"BREATH_PULSED": return "Breath of Life · healed %d Marchers for %d HP in %s lane" % [d.get("healed_ids", []).size(), d.get("healing", 0), d.get("lane", "")]
		"RAVENOUS_REWARDED": return "Ravenous · %d %s consumed; +%d Soul, +%d Hunger, +%d neutral Tear" % [d.get("enemy_consumed", d.get("consumed", 0)), "enemies" if d.has("enemy_consumed") else "units", d.get("souls", 0), d.get("hunger", 0), d.get("neutral_tears", 0)]
		"POWER_RESOLVED": return "Power: " + str(d.get("power_id", "")).capitalize()
		"FIZZLE_INVALID_TARGET": return "Power: " + str(d.get("power_id", "")).capitalize() + " · fizzled"
		"POWER_QUEUED": return "Power: %s · scheduled for round %d" % [str(d.get("power_id", "")).capitalize(), d.get("fire_round", 0)]
		"ARTILLERY_FIRED": return "Siege Engine · %d damage%s" % [d.get("damage", 0), "; Castle destroyed · +%d Souls" % d.get("soul_gain", 0) if d.get("destroyed", false) else ""]
		"CASTLE_DESTROYED": return "Destroyed " + name_of(d.get("castle", {}))
		"LORD_BANISHED": return "Banished " + name_of(d.get("lord", {"kind": "lord"}))
		"GUARD_DEFEATED": return "Guard defeated" if d.get("attack_kind", "") not in ["Hunt", "Siege"] else ""
		"MARCHER_DEFEATED": return "Marcher killed"
		"PERSONAL_TEAR_CREATED", "NEUTRAL_TEAR_CREATED":
			return "+%d %s Tear · %s" % [d.get("amount", 1), "personal" if kind == "PERSONAL_TEAR_CREATED" else "neutral", str(d.get("source", "effect")).capitalize()]
		"VACANT_THRONE_RESOLVED": return "+%d Soul · enemy throne vacant" % d.soul_gain if d.get("soul_gain", 0) > 0 else ""
		"SIEGE_RESOLVED":
			var result: String = "Siege: "
			if d.has("bastion_damage"):
				result += "Bastion interposed and took %d damage" % d.bastion_damage
				if d.get("damage", 0) > 0: result += "; original target took %d damage" % d.damage
			else:
				result += "%d Castle damage" % d.get("damage", 0)
			if d.get("guards_defeated", 0) > 0: result += "; %d Guards defeated" % d.guards_defeated
			return result
		"HUNT_RESOLVED": return "Hunt: %d Guards defeated; %s" % [d.get("guards_defeated", 0), "Lord banished" if d.get("banished", false) else "no banishment"]
		"CASTLE_REPAIRED", "CASTLE_RESTORED":
			return "%s · %s" % ["Repaired" if kind == "CASTLE_REPAIRED" else "Restored", d.get("castle_id", "Castle")]
		"CASTLE_ACTIVATED": return "Completed " + str(d.get("castle_id", "Castle"))
		"LORD_RESUMMONED": return "Lord resummoned"
		"MARCHER_ALLEGIANCE_CHANGED":
			var unit: Dictionary = d.get("after", {})
			var suit: String = str(unit.get("attributes", {}).get("suit", ""))
			return "Gained control of " + (suit + " Marcher" if suit in ["Butcher", "Penitent", "Wright", "Vulture"] else "a Marcher")
		"FRACTURE_RESOLVED": return "Fracture: %s · %d" % [str(d.get("category", "")).capitalize(), d.get("value", 0)]
		"KANIFOUS_PRICE_PAID": return "Wish price paid"
		"KANIFOUS_PRICE_SCHEDULED": return "Wish price due round %d" % d.get("due_round", 0)
		"COMBAT_ORDER_FIZZLED": return "Combat action fizzled · target or payment no longer available"
		"PROFANE_RESOLVED": return "Castle profaned" if d.get("profaned", false) else "Profane failed · Castle no longer eligible"
	# Only explicitly formatted results belong in the ledger. Never serialize
	# arbitrary event fields: before/after may contain entire entity records.
	return ""
