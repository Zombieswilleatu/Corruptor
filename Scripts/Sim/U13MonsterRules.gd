extends RefCounted

# Standalone playtest roster. Named suits count cards, never printed values.
# Unsettled numerical abilities are deliberately explicit tuning values.
# Bump VERSION in both engines when changing recipes, profiles or tuning.
const VERSION: String = "U13_MONSTERS_V1"
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const NAMES: Array = ["Lemek", "Varn", "Fyra", "Kopita", "Tumler", "Kurchin", "Muno", "Dotra", "Sooge", "Sinodek"]
const ROSTER: Dictionary = {
	"Lemek": {"tier": "Easy", "recipe": {"Penitent": 2}, "attack": 3, "armor": 4, "speed": 2, "hp": 5, "ability": "On death, leaves a slowing pool through the following round. Ground units inside move at half speed."},
	"Varn": {"tier": "Easy", "recipe": {"Vulture": 2}, "attack": 1, "armor": 0, "speed": 2, "hp": 2, "ability": "Summons 3–5 bodies. Each damaging hit has a 10% chance to poison: 1 HP at the start of each of the next two Marching phases. Refreshes; does not stack."},
	"Fyra": {"tier": "Moderate", "recipe": {"Butcher": 2, "Vulture": 2}, "attack": 2, "armor": 1, "speed": 4, "hp": 5, "ability": "Flies over ground hazards. Each hit has a 15% chance to charm its target for the rest of this round. Ownership returns before the next round."},
	"Kopita": {"tier": "Moderate", "recipe": {"Wright": 2, "Penitent": 2}, "attack": 2, "armor": 1, "speed": 2, "hp": 5, "ability": "Alternates once per active round: heal nearby allies 1 HP, then deal 1 damage to nearby enemies. Starts with healing; radius 360."},
	"Tumler": {"tier": "Moderate", "recipe": {"Vulture": 2, "Wright": 2}, "attack": 2, "armor": 1, "speed": 3, "hp": 5, "ability": "Pursues a chosen enemy, preferring ordinary Vultures and support monsters. Tries to skirt other enemies and slowing pools; can be intercepted."},
	"Kurchin": {"tier": "Hard", "recipe": {"Penitent": 3, "Wright": 1}, "attack": 1, "armor": 6, "speed": 1, "hp": 5, "ability": "Taunts enemies within 360, drawing their movement and ranged attacks when reachable."},
	"Muno": {"tier": "Hard", "recipe": {"Wright": 3, "Vulture": 1}, "attack": 3, "armor": 1, "speed": 2, "hp": 5, "ability": "Once per active round, strikes an enemy within 480 for one free attack, then returns to its position before moving normally."},
	"Dotra": {"tier": "Hard", "recipe": {"Butcher": 3, "Vulture": 1}, "attack": 2, "armor": 2, "speed": 2, "hp": 5, "ability": "25% chance to hide each active round. A nearby enemy triggers a 5-damage ambush. Otherwise, next round it has a 50% chance to emerge. Hidden units cannot be selected for ordinary attacks."},
	"Sooge": {"tier": "Very hard", "recipe": {"Butcher": 3, "Wright": 2}, "attack": 1, "armor": 2, "speed": 2, "hp": 5, "ability": "25% chance each active round to root permanently: 3 Attack / 6 Armor / 0 Speed. Fires a piercing beam up to 600: 3 damage to enemies and 1 to allies in its path. One living copy per player."},
	"Sinodek": {"tier": "Very hard", "recipe": {"Wright": 3, "Vulture": 2}, "attack": 1, "armor": 3, "speed": 1, "hp": 5, "ability": "25% chance each active round to open a portal ahead for that Marching phase. Nearby units flee; entering units are banished, without death triggers or resurrection. One living copy per player."}
}
const TUNING: Dictionary = {"varn_poison_chance": 10, "fyra_charm_chance": 15, "kopita_radius": 360, "taunt_radius": 360, "muno_radius": 480, "dotra_hide_chance": 25, "dotra_ambush_radius": 240, "sooge_root_chance": 25, "beam_range": 600, "beam_half_width": 70, "sinodek_portal_chance": 25, "portal_ahead": 350, "portal_radius": 100, "portal_fear_radius": 300, "pool_radius": 200}

static func configure(world: Dictionary) -> void:
	world.data["monsters"] = {"version": VERSION, "unlocked": [NAMES.duplicate(), NAMES.duplicate()], "fields": [], "death_ids": [], "phase_round": 0}

static func enabled(world: Dictionary) -> bool:
	return world.get("data", {}).get("monsters", {}).get("version") == VERSION

static func profile(name: String, lane: String, pid: int, birth: int, ready: int, turret: bool = false) -> Dictionary:
	var r: Dictionary = ROSTER[name]
	return {"suit": "Monster", "monster_id": name, "attack": 3 if turret else r.attack, "armor": 6 if turret else r.armor, "max_armor": 6 if turret else r.armor, "step_fp": 0 if turret else r.speed * 2, "hp": r.hp, "max_hp": r.hp, "regen": 1, "armor_bypass": false, "lane": lane, "birth_round": birth, "movement_ready_round": ready, "x_fp": 0 if pid == 0 else 2400, "y_fp": 300, "contact_tick": -1, "direction": 1 if pid == 0 else -1, "waiting": false, "waiting_since_round": 0, "sprite_form": "turret" if turret else "mobile", "flying": name == "Fyra"}

static func valid_unit(a: Dictionary) -> bool:
	if not a.has("monster_id"):
		return a.get("suit") != "Monster"
	return a.get("suit") == "Monster" and a.monster_id in NAMES and a.get("sprite_form") in ["mobile", "turret"] and (a.sprite_form != "turret" or a.monster_id == "Sooge") and typeof(a.get("flying")) == TYPE_BOOL

static func limited(name: String) -> bool:
	return name in ["Sooge", "Sinodek"]

static func living(rows: Array, pid: int, name: String, except_id: String = "") -> bool:
	# A charmed copy still reserves its original owner's slot until it dies
	# or returns. Otherwise summoning during the charm could exceed the cap.
	return rows.any(func(r): return r.kind == "marcher" and (r.owner == pid or r.attributes.get("charm_owner", -1) == pid) and r.id != except_id and r.attributes.get("monster_id") == name)

static func qualifies(rows: Array, card_ids: Array, name: String) -> bool:
	if name not in NAMES:
		return false
	var counts: Dictionary = {}
	var seen: Dictionary = {}
	for id in card_ids:
		if seen.has(id): return false
		seen[id] = true
		for row in rows:
			if row.id == id and row.kind == "card":
				var suit: String = row.attributes.suit
				counts[suit] = counts.get(suit, 0) + 1
	for suit in ROSTER[name].recipe:
		if counts.get(suit, 0) < ROSTER[name].recipe[suit]: return false
	return true

static func available(rows: Array, card_ids: Array, pid: int, unlocked: Array = NAMES) -> Array:
	var result: Array = []
	for name in NAMES:
		if name in unlocked and qualifies(rows, card_ids, name) and (not limited(name) or not living(rows, pid, name)):
			result.append(name)
	return result

static func validate_choice(world: Dictionary, pid: int, order: Dictionary) -> Dictionary:
	if not order.has("monster_choice"): return {"action": "legal"}
	if not enabled(world) or order.monster_choice not in available(world.entities.entities, order.get("card_ids", []), pid, world.data.monsters.unlocked[pid]):
		return Data.invalid("monster_recipe_unavailable")
	return {"action": "legal"}

static func valid(world: Dictionary) -> bool:
	if not enabled(world): return false
	var s: Dictionary = world.data.monsters
	if typeof(s.get("unlocked")) != TYPE_ARRAY or s.unlocked.size() != 2 or typeof(s.get("fields")) != TYPE_ARRAY or typeof(s.get("death_ids")) != TYPE_ARRAY or not Data.is_integer(s.get("phase_round")) or s.phase_round < 0: return false
	for names in s.unlocked:
		if typeof(names) != TYPE_ARRAY: return false
		for name in names:
			if name not in NAMES: return false
	for field in s.fields:
		if typeof(field) != TYPE_DICTIONARY or field.get("kind") not in ["pool", "portal"] or field.get("lane") not in ["Lord", "Castle"] or typeof(field.get("id")) != TYPE_STRING: return false
		for key in ["x_fp", "y_fp", "expires_round", "owner"]:
			if not Data.is_integer(field.get(key)): return false
		if field.x_fp < 0 or field.x_fp > 2400 or field.y_fp < 0 or field.y_fp > 600 or field.owner not in [0, 1] or field.expires_round < 0: return false
	return true

static func recipe_text(name: String) -> String:
	var parts: PackedStringArray = []
	for suit in ["Penitent", "Butcher", "Vulture", "Wright"]:
		if ROSTER[name].recipe.has(suit): parts.append("%d %s" % [ROSTER[name].recipe[suit], suit])
	return " + ".join(parts)
