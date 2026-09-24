extends RefCounted

const Embolden = preload("res://Scripts/Sim/U13Embolden.gd")

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const ROUT_RETREAT_ATTACK_BONUS: int = 1

static func active(a: Dictionary, clock: int) -> bool:
	return int(a.get("dotra_exposed_from_tick", 0)) <= clock and clock < int(a.get("dotra_exposed_until_tick", 0))

# A positive packet gains one point BEFORE Armor. Blocks, evasion, healing,
# banishment and direct execution never become damage packets through this rule.
static func amount(a: Dictionary, base, clock: int):
	return max(0, base) + (1 if base > 0 and active(a, clock) else 0)

static func regular_amount(a: Dictionary, base, clock: int, round_number: int = -1):
	# Only ordinary melee/ranged attacks enter here. Recovery, blocked/evaded
	# hits and zero-damage attacks gain nothing. Exposure remains independent.
	@warning_ignore("integer_division")
	var retreating: bool = int(a.get("rout_round", -1)) == (clock / 200 if round_number < 0 else round_number)
	return amount(a, base, clock) + (ROUT_RETREAT_ATTACK_BONUS if base > 0 and retreating else 0)

# Only damage resolution calls this mutating helper. Forecasts use amount().
# A ward cancels one positive packet, including its exposure bonus, before Armor.
static func apply(a: Dictionary, base, clock: int, regular: bool = false, round_number: int = -1):
	var incoming = regular_amount(a, base, clock, round_number) if regular else amount(a, base, clock)
	if incoming > 0 and a.get("muno_ward", false):
		a["muno_ward"] = false
		return 0
	return incoming

static func phase_clock(world: Dictionary, round_number: int) -> int:
	# Automatic powers between Marching phases share the intervening boundary.
	if world.data.has("marching_clock"): return int(world.data.marching_clock)
	return round_number * 200 + (200 if int(world.data.get("marching_round", 0)) >= round_number else 0)

static func valid(a: Dictionary) -> bool:
	if a.has("muno_ward") and (typeof(a.muno_ward) != TYPE_BOOL or a.get("monster_id") != "Muno"): return false
	for key in ["dotra_exposed_from_tick", "dotra_exposed_until_tick"]:
		if a.has(key) and (not Data.is_integer(a[key]) or a[key] < 0): return false
	return int(a.get("dotra_exposed_until_tick", 0)) >= int(a.get("dotra_exposed_from_tick", 0))
