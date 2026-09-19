extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")

static func active(a: Dictionary, clock: int) -> bool:
	return int(a.get("dotra_exposed_from_tick", 0)) <= clock and clock < int(a.get("dotra_exposed_until_tick", 0))

# A positive packet gains one point BEFORE Armor. Blocks, evasion, healing,
# banishment and direct execution never become damage packets through this rule.
static func amount(a: Dictionary, base: int, clock: int) -> int:
	return maxi(0, base) + (1 if base > 0 and active(a, clock) else 0)

static func phase_clock(world: Dictionary, round_number: int) -> int:
	# Automatic powers between Marching phases share the intervening boundary.
	return round_number * 200 + (200 if int(world.data.get("marching_round", 0)) >= round_number else 0)

static func valid(a: Dictionary) -> bool:
	for key in ["dotra_exposed_from_tick", "dotra_exposed_until_tick"]:
		if a.has(key) and (not Data.is_integer(a[key]) or a[key] < 0): return false
	return int(a.get("dotra_exposed_until_tick", 0)) >= int(a.get("dotra_exposed_from_tick", 0))
