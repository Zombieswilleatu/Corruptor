extends RefCounted

const HUMBABA_PROFILE: String = "U13_HUMBABA_STONES_V1"


# Absence is distinct from zero, including the zero threshold. Callers must
# not coerce this nullable value into an integer for an absent stat.
static func threat_value(lord: Dictionary):
	if lord.attributes.get("lord_id") == "Humbaba":
		return null
	return lord.attributes.get("threat", 0)


static func threat_at_least(lord: Dictionary, threshold: int) -> bool:
	var value = threat_value(lord)
	return value != null and value >= threshold


static func standing_castles(world: Dictionary, player_id: int) -> int:
	var count: int = 0
	for castle in world.entities.entities:
		if (
			castle.kind == "castle"
			and castle.owner == player_id
			and castle.attributes.get("construction_state", "active") == "active"
			and castle.attributes.get("status") == "standing"
			and castle.attributes.get("integrity", 0) > 0
		):
			count += 1
	return count


static func defense(world: Dictionary, lord: Dictionary) -> int:
	if lord.attributes.get("lord_id") == "Humbaba":
		return 2 + standing_castles(world, lord.owner)
	var threat: int = int(threat_value(lord))
	return 4 - (3 if threat >= 4 else (2 if threat >= 3 else (1 if threat >= 2 else 0)))
