extends RefCounted

# Explicit world opt-in. Never mutate the shared roster or global tuning.
const PROFILE: String = "crossing-monsters-v1"
const HIDE_TICKS: int = 27
const ROOT_RANGE: int = 1200
const BEAM_RANGE: int = 2400
const BEAM_CHARGE_TICKS: int = 16
const PORTAL_RANGE: int = 900
const PORTAL_CHANCE: int = 50
const DESCRIPTIONS: Dictionary = {
	"Dotra": "CROSSING: Conceals after 2 seconds on the field, once per summon. Stalks while hidden, then ambushes within 240 for 5 damage. Emerges with 5 seconds of protection from targeting and exposes nearby enemies to +1 incoming damage. Area damage and poison still hurt him.",
	"Sooge": "CROSSING: Advances until an enemy unit or fortification is within 1200, then reliably becomes a permanent turret (3 Attack, 6 Armor). Charges for 1.2 seconds and fires a beam to range 2400, once per 15 seconds. Beam deals 3 damage to enemies and 1 to allies; keep your troops out of its path.",
	"Sinodek": "CROSSING: Opens his first portal reliably when a visible enemy comes within 900. Later active rounds have a 50% chance, with one attempt per round. Portals banish nearby units, including allies, and frighten surrounding troops. Immune to his own portal."
}

static func enabled(world: Dictionary) -> bool:
	return world.get("data", {}).get("encounter", {}).get("monster_profile", "") == PROFILE
