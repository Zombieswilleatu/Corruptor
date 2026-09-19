extends RefCounted

# Target-specific damage, before armor; never a permanent attack-stat change.
static func bonus(attacker: Dictionary, target: Dictionary) -> int:
	return 1 if attacker.get("kind") == "marcher" and attacker.attributes.get("suit") == "Vulture" and target.get("kind") == "marcher" and target.attributes.get("suit") == "Butcher" else 0
