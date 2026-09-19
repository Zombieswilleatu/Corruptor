extends RefCounted

# Standalone playtest roster. Named suits count cards, never printed values.
# Unsettled numerical abilities are deliberately explicit tuning values.
# Bump VERSION in both engines when changing recipes, profiles or tuning.
const VERSION: String = "U13_MONSTERS_V16_DOTRA_TIMED_HIDE"
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const NAMES: Array = ["Lemek", "Varn", "Fyra", "Kopita", "Tumler", "Kurchin", "Muno", "Dotra", "Sooge", "Sinodek"]
const ROSTER: Dictionary = {
	"Lemek": {"tier": "Easy", "recipe": {"Penitent": 2}, "attack": 4, "armor": 4, "speed": 2, "hp": 10, "ability": "On death, leaves a slowing pool through the following round. Ground units inside move at half speed. All Lemeks are immune, regardless of side."},
	"Varn": {"tier": "Easy", "recipe": {"Vulture": 2}, "attack": 1, "armor": 0, "speed": 2, "hp": 4, "ability": "Summons 3–5 bodies. Each damaging hit has a 10% chance to poison: 1 HP at the start of each of the next two Marching phases. Refreshes; does not stack."},
	"Fyra": {"tier": "Moderate", "recipe": {"Butcher": 2, "Vulture": 2}, "attack": 2, "armor": 1, "speed": 4, "hp": 10, "ability": "Flies over ground hazards. Each hit has a 30% chance to charm a surviving target for the rest of this round. Ownership returns before the next round."},
	"Kopita": {"tier": "Moderate", "recipe": {"Wright": 2, "Penitent": 2}, "attack": 2, "armor": 1, "speed": 2, "hp": 10, "ability": "Pulses twice per active round: at the start and about 10 seconds in. If any ally within 360, including herself, is wounded, heals nearby allies 1 HP; otherwise deals 1 damage to nearby enemies. Slows near allied front-line fighters to stay behind them."},
	"Tumler": {"tier": "Moderate", "recipe": {"Vulture": 2, "Wright": 2}, "attack": 2, "armor": 1, "speed": 3, "hp": 10, "ability": "Pursues a chosen enemy, preferring ordinary Vultures and support monsters. Deals +1 damage against his marked hunt target, before Armor; normal damage against others. Pursues through enemy clusters while avoiding slowing pools. Always has 50% evasion against direct attacks, including at melee contact and during fear. Poison cannot be dodged. While hunting, a landed melee hit switches his target to the attacker, even if Armor absorbs it; ranged hits do not."},
	"Kurchin": {"tier": "Hard", "recipe": {"Penitent": 3, "Wright": 1}, "attack": 1, "armor": 6, "speed": 1, "hp": 15, "ability": "Taunts enemies within 360, pulling them off engaged targets to approach and attack him. Walls still block approach. While Armor remains, deflects 75% of direct attacks without losing Armor or HP. Landed hits deal normal damage; deflection ends when Armor is depleted. Poison cannot be deflected."},
	"Muno": {"tier": "Hard", "recipe": {"Wright": 3, "Vulture": 1}, "attack": 3, "armor": 1, "speed": 2, "hp": 10, "ability": "Once per active round, dashes to an enemy within 480 for one free melee strike, then dashes back with a fading afterimage before moving normally."},
	"Dotra": {"tier": "Hard", "recipe": {"Butcher": 3, "Vulture": 1}, "attack": 2, "armor": 2, "speed": 2, "hp": 10, "ability": "Once per summon, hides after his first 15 seconds on the field. Protected staging and birth hold do not count. Stalks at full speed while hidden until delivering a 5-damage ambush within 240. On emergence, exposes enemies within 360 for one full round: +1 incoming damage per hit, before Armor. Refreshes but never stacks. Blocks and evasion still prevent damage."},
	"Sooge": {"tier": "Very hard", "recipe": {"Butcher": 3, "Wright": 2}, "attack": 1, "armor": 2, "speed": 2, "hp": 5, "ability": "Stays behind nearby allied front-line fighters while mobile. Root chance starts at 25%, rising by 15 percentage points each active round it stays mobile, up to 100%. Permanently becomes a turret: 3 Attack / 6 Armor / 0 Speed. Charges before firing once per round at the nearest enemy. The blue-white beam traces the ground to range 1800, then detonates shortly afterward: 3 damage to enemies and 1 to allies in its path. One living copy per player."},
	"Sinodek": {"tier": "Very hard", "recipe": {"Wright": 3, "Vulture": 2}, "attack": 1, "armor": 3, "speed": 1, "hp": 5, "ability": "Stays behind nearby allied front-line fighters. Once each active round, when a visible enemy unit is within 600, has a 25% chance to open a portal on the nearest enemy for that Marching phase. Waits if no enemy is in range. Nearby units flee; entering units, including allies beside the target, are banished without death triggers or resurrection. Immune to his own portal's fear and banishment. One living copy per player."}
}
const TUNING: Dictionary = {"tumler_evasion_chance": 50, "tumler_hunt_bonus": 1, "kurchin_deflection_chance": 75, "varn_poison_chance": 10, "fyra_charm_chance": 30, "kopita_radius": 360, "kopita_second_pulse_tick": 133, "taunt_radius": 360, "muno_radius": 480, "dotra_hide_delay_ticks": 200, "dotra_ambush_radius": 240, "dotra_expose_radius": 360, "dotra_expose_ticks": 200, "sooge_root_chance": 25, "sooge_root_increase": 15, "beam_range": 1800, "beam_half_width": 70, "beam_interval_ticks": 200, "beam_charge_ticks": 32, "beam_blast_delay_ticks": 8, "sinodek_portal_chance": 25, "portal_target_range": 600, "portal_radius": 100, "portal_fear_radius": 300, "pool_radius": 200}

static func configure(world: Dictionary) -> void:
	world.data["monsters"] = {"version": VERSION, "unlocked": [NAMES.duplicate(), NAMES.duplicate()], "fields": [], "pending_beams": [], "death_ids": [], "phase_round": 0}

static func enabled(world: Dictionary) -> bool:
	return world.get("data", {}).get("monsters", {}).get("version") == VERSION

static func profile(name: String, lane: String, pid: int, birth: int, ready: int, turret: bool = false) -> Dictionary:
	var r: Dictionary = ROSTER[name]
	var a: Dictionary = {"suit": "Monster", "monster_id": name, "attack": 3 if turret else r.attack, "armor": 6 if turret else r.armor, "max_armor": 6 if turret else r.armor, "step_fp": 0 if turret else r.speed * 2, "hp": r.hp, "max_hp": r.hp, "regen": 1, "armor_bypass": false, "lane": lane, "birth_round": birth, "movement_ready_round": ready, "x_fp": 0 if pid == 0 else 2400, "y_fp": 300, "contact_tick": -1, "direction": 1 if pid == 0 else -1, "waiting": false, "waiting_since_round": 0, "sprite_form": "turret" if turret else "mobile", "flying": name == "Fyra"}
	if name == "Sooge": a.merge({"sooge_root_attempts": 0, "sooge_root_round": 0})
	return a

static func root_chance(a: Dictionary) -> int:
	return mini(100, int(TUNING.sooge_root_chance) + int(a.get("sooge_root_attempts", 0)) * int(TUNING.sooge_root_increase))

static func valid_unit(a: Dictionary) -> bool:
	if not a.has("monster_id"):
		return a.get("suit") != "Monster"
	for key in ["sooge_root_attempts", "sooge_root_round", "beam_next_tick", "beam_charge_tick", "beam_ready_tick", "dotra_concealment_round", "dotra_hide_at_tick", "sinodek_portal_round", "kopita_pulses", "kopita_last_pulse_tick"]:
		if a.has(key) and (not Data.is_integer(a[key]) or a[key] < 0): return false
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
	if typeof(s.get("unlocked")) != TYPE_ARRAY or s.unlocked.size() != 2 or typeof(s.get("fields")) != TYPE_ARRAY or typeof(s.get("pending_beams")) != TYPE_ARRAY or typeof(s.get("death_ids")) != TYPE_ARRAY or not Data.is_integer(s.get("phase_round")) or s.phase_round < 0: return false
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
