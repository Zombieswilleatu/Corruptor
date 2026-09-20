extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")

# Target selectors use the current tick's state. MonsterEffects clears expired
# deadlines before any acquisition; explicit clocks also support saved replays.
static func active(a: Dictionary, clock: int = -1) -> bool:
	var until: int = int(a.get("dotra_shroud_until_tick", 0))
	return a.get("monster_id") == "Dotra" and until > 0 and (clock < 0 or (int(a.get("dotra_shroud_from_tick", 0)) <= clock and clock < until))

static func targetable(a: Dictionary) -> bool:
	return not a.get("hidden", false) and not active(a)

static func valid(a: Dictionary) -> bool:
	for key in ["dotra_shroud_from_tick", "dotra_shroud_until_tick"]:
		if a.has(key) and (not Data.is_integer(a[key]) or a[key] < 0): return false
	return int(a.get("dotra_shroud_until_tick", 0)) >= int(a.get("dotra_shroud_from_tick", 0))
