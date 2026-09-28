extends RefCounted
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const Lords = preload("res://Prototype/U13/U13LoadoutPicker.gd")
const Castles = preload("res://Prototype/UI2/CastleArtCatalog.gd")
const LordRules = preload("res://Prototype/U13/U13LordRules.gd")
const Help = preload("res://Prototype/U13/U13TutorialCatalog.gd")
const Powers = preload("res://Scripts/Sim/U13Kanifous.gd")
const Session = preload("res://Scripts/Sim/U13PlayableSession.gd")
const Resummon = preload("res://Scripts/Sim/U13Resummoning.gd")
const PlayerBoard = preload("res://Prototype/U13/U13PlayerBoard.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
static var stats_cache: Dictionary = {}

static func display_name(value: String) -> String:
	return value.replace("SiegeEngine", "Siege Engine").replace("SummoningCircle", "Summoning Circle")

static func texture(kind: String, id: String) -> Texture2D:
	return Art.lord_texture(id) if kind == "lord" else Art.texture(Castles.ART_PATHS[id])

static func stats(lord: String) -> Dictionary:
	if stats_cache.has(lord): return stats_cache[lord]
	# Inspect a fresh, unplayed starting position using the installed rules.
	var session = Session.new()
	var result: Dictionary = session.configure([lord, "Deimos"], [Slots.TYPES, Slots.TYPES], true)
	if result.get("action") == "invalid": return {}
	var world: Dictionary = session.board_view().world
	var base: Dictionary = world.lord_stats[0]
	var value: Dictionary = {"lord":lord, "alive":true, "defense":base.defense,
		"threat":base.threat, "summon":Resummon.COSTS.get(lord,0),
		"fracture":PlayerBoard.FRACTURE.get(lord,0), "hunt_bonus":1 if lord == "Orias" else 0}
	stats_cache[lord] = value
	return value

static func lord_text(lord: String) -> String:
	var copy: Dictionary = LordRules.for_lord(lord)
	var value: Dictionary = stats(lord)
	var chunks: Array[String] = []
	chunks.append("[b]STARTING LORD[/b]\nDefense %s · Resummon %s · Fracture %s\nYour starting lord is free." % [value.get("defense","—"),value.get("summon","—"),value.get("fracture","—")])
	if lord == "Humbaba": chunks.append("Defense follows your standing castles.")
	chunks.append("[b]ACTIVE POWERS[/b]")
	var rules: Dictionary = Powers.rules()
	for id in rules:
		var rule: Dictionary = rules[id]
		if rule.get("lord_id") != lord or rule.get("breach_wish",false): continue
		var entry: Dictionary = Help.ENTRIES.get("power:" + id, {})
		var title: String = entry.get("title", String(id).capitalize())
		var body: String = entry.get("body", "")
		var details: Array[String] = []
		for currency in rule.get("cost",{}): details.append("Cost: %s %s." % [rule.cost[currency], String(currency).capitalize()])
		if rule.has("discard_count"): details.append("Discard %d cards." % rule.discard_count)
		if rule.has("target_integrity"): details.append("Leaves an eligible castle at %d Integrity." % rule.target_integrity)
		if rule.has("threat_gain"): details.append("Gain %d Threat when declared." % rule.threat_gain)
		if rule.get("delay_rounds",0) > 0: details.append("Prepared for next round.")
		var cooldown: int = int(rule.get("cooldown_rounds",0))
		if cooldown > 0:
			details.append("Cooldown: %d round%s after %s." % [cooldown,"s" if cooldown != 1 else "","the effect ends" if rule.get("cooldown_on") == "expiration" else "activation"])
		else: details.append("No cooldown between rounds.")
		if rule.get("repeatable",false): details.append("May be used repeatedly while you can pay.")
		chunks.append("[color=#dfc391][b]%s[/b][/color]\n%s\n%s" % [title, body, " ".join(details)])
	chunks.append("[b]PASSIVES & LORD MECHANICS[/b]\n" + String(copy.passive))
	chunks.append("[b]IN THE BREACH[/b]\n" + String(copy.breach))
	return "\n\n".join(chunks)

static func castle_text(id: String) -> String:
	var text: Dictionary = {
		"Keep":"[b]FORTIFICATION[/b]\nAfter Lord defenses, a standing Keep takes the remaining Hunt strength before your Lord. An operational Keep reduces that strength by 3. If the Keep is ruined, excess strength continues to the Lord.\n\nRecommended as your first castle so this protection is available from the start.",
		"Bastion":"[b]FORTIFIED LAYERS[/b]\nA standing Bastion intercepts a Siege aimed at another castle. Overflow reaches the intended target. A Defunct Bastion still screens attacks while it stands. A Siege aimed directly at the Bastion does not spill into another castle.",
		"SummoningCircle":"[b]BLOOD CONDUIT[/b]\nWhen a Threat gain would lower your Lord's defense, an operational Circle spends 3 Integrity to prevent 1 Threat.\n\n[b]BLOOD OFFERING[/b]\nAn operational Circle can spend 3 Integrity to reduce the cost of resummoning your Lord by 3. This may leave it Defunct. Multiple Circles do not stack for the same effect.",
		"Stockpile":"[b]SELECTIVE STORES[/b]\nDuring the round's draw, an operational Stockpile offers two extra cards. Keep one and discard the other. You gain one extra card and a choice of which card to keep.",
		"SiegeEngine":"[b]BOMBARDMENT[/b]\nAfter repairs, an operational Siege Engine fires at an active enemy castle for 2 direct Integrity damage. Its target is selected randomly and retained until ruined. It chooses another target on a later firing.\n\nBombardment bypasses Ward, Guards and Bastion interception. Deimos can order an additional shot with War Machine."
	}
	return String(text.get(id,"")) + "\n\n[b]YOUR FIVE SLOTS[/b]\nSlots 1–3 start active; slots 4–5 begin as unbuilt blueprints. Maximum one Keep and two of each other type. Castle types stay fixed for the match.\n\n[b]INTEGRITY[/b]\nMaximum %d. An active castle at 7 or more Integrity is operational; at 1–6 it is Defunct. All castles share one Castle Guard zone." % Structures.MAX_INTEGRITY
