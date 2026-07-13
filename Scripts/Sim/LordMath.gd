class_name LordMath
extends RefCounted


static func lord_base_def(
	lord_id: String,
	castles_in: Array,
	threat: int,
	_rules: RuleConfig
) -> int:
	var castles: Array[String] = (
		_to_string_array(
			castles_in
		)
	)

	if lord_id == "Humbaba":
		return _humbaba_lord_base_def(
			castles,
			threat
		)

	push_error(
		"LordMath.lord_base_def does not know lord: %s"
		% lord_id
	)

	return 0


static func _humbaba_lord_base_def(
	castles: Array[String],
	threat: int
) -> int:
	var defense: int = (
		2
		+ castles.size()
	)

	if threat >= 4:
		defense -= 3
	elif threat >= 3:
		defense -= 2
	elif threat >= 2:
		defense -= 1

	if castles.has("Bastion"):
		defense += 2

	return max(
		0,
		defense
	)


static func dominion_requirement(
	players: Array,
	rules: RuleConfig
) -> int:
	var requirement: int = (
		rules.dominion_requirement
	)

	if not rules.humbaba_seal:
		return requirement

	for player in players:
		if typeof(player) != TYPE_DICTIONARY:
			continue

		var lord_id: String = String(
			player.get(
				"lord",
				""
			)
		)

		var alive: bool = bool(
			player.get(
				"alive",
				false
			)
		)

		if (
			alive
			and lord_id == "Humbaba"
		):
			requirement += 1
			break

	return requirement


static func _to_string_array(
	values: Array
) -> Array[String]:
	var out: Array[String] = []

	for value in values:
		out.append(
			String(value)
		)

	return out
