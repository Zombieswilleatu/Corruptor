## OdradekInterlockEngine
##
## Single owner of Psychic Recoil, the face-up Interlock bank, bank spending,
## bank discard on Banishment, and the associated doctrine terms.
class_name OdradekInterlockEngine
extends RefCounted


static func empty_result(
	odradek_player_id: int,
	attacker_id: int
) -> Dictionary:
	return {
		"triggered": false,
		"odradek_player_id": odradek_player_id,
		"attacker_id": attacker_id,
		"attempted_card": "",
		"taken_card": "",
		"discarded_card": "",
		"bank_before": "",
		"bank_after": "",
		"replaced_card": "",
		"locked": false,
		"soul_gain": 0,
	}


static func resolve_recoil(
	game,
	odradek,
	attacker,
	rules: RuleConfig
) -> Dictionary:
	var result: Dictionary = empty_result(
		int(odradek.pid),
		int(attacker.pid)
	)

	if not rules.odr_recoil or odradek.odradek_recoil_done:
		return result

	# Psychic Recoil names the attacker's second-highest committed card.
	# With fewer than two CURRENT committed cards there is no legal victim:
	# do not fire, do not gain a Soul, and do not spend Recoil for the round.
	if attacker.committed.size() < 2:
		return result

	# A qualifying Recoil attempt is spent even if an existing Interlock bank
	# later blocks replacement.
	odradek.odradek_recoil_done = true
	result["triggered"] = true
	result["bank_before"] = _card_id(odradek.odradek_bank)
	result["bank_after"] = result["bank_before"]

	var victim = _select_victim(attacker.committed, rules)
	result["attempted_card"] = _card_id(victim)

	if not rules.odr_recoil_strip:
		if rules.odr_recoil_soul:
			odradek.souls += 1
			result["soul_gain"] = 1
		return result

	if rules.odr_recoil_bank:
		if odradek.odradek_bank != null:
			# Replacement is strictly greater. Equal or lower leaves the bank locked.
			if int(victim.value) <= int(odradek.odradek_bank.value):
				result["locked"] = true
				return result

			result["replaced_card"] = _card_id(odradek.odradek_bank)
			game.discard.append(odradek.odradek_bank)
			odradek.odradek_bank = null

		attacker.committed.erase(victim)
		odradek.odradek_bank = victim
		result["taken_card"] = _card_id(victim)
		result["bank_after"] = result["taken_card"]
	else:
		attacker.committed.erase(victim)
		game.discard.append(victim)
		result["taken_card"] = _card_id(victim)
		result["discarded_card"] = result["taken_card"]

	if rules.odr_recoil_soul:
		odradek.souls += 1
		result["soul_gain"] = 1

	return result


static func _select_victim(
	committed: Array,
	rules: RuleConfig
):
	assert(
		committed.size() >= 2,
		"Psychic Recoil requires at least two current committed cards."
	)

	if rules.recoil_lowest:
		var lowest = committed[0]
		for index: int in range(1, committed.size()):
			if int(committed[index].value) < int(lowest.value):
				lowest = committed[index]
		return lowest

	# Python's descending sort is stable. Explicit original-index tiebreak keeps
	# duplicate-valued commitments deterministic in Godot as well.
	var indices: Array[int] = []
	for index: int in range(committed.size()):
		indices.append(index)
	indices.sort_custom(
		func(left: int, right: int) -> bool:
			var left_value: int = int(committed[left].value)
			var right_value: int = int(committed[right].value)
			if left_value == right_value:
				return left < right
			return left_value > right_value
	)
	return committed[indices[1]]


static func spend_bank(
	odradek,
	action: String,
	rules: RuleConfig
):
	if (
		not rules.odr_recoil_bank
		or odradek.lord != "Odradek"
		or not ["Hunt", "Siege"].has(action)
		or odradek.odradek_bank == null
	):
		return null

	var bank = odradek.odradek_bank
	odradek.odradek_bank = null
	odradek.committed.append(bank)
	return bank


static func discard_bank(
	game,
	odradek,
	rules: RuleConfig
):
	if not rules.odr_recoil_bank or odradek.odradek_bank == null:
		return null

	var bank = odradek.odradek_bank
	odradek.odradek_bank = null
	game.discard.append(bank)
	return bank


static func doctrine_delta(
	player,
	rules: RuleConfig
) -> Vector3:
	var hunt_delta: float = 0.0
	var siege_delta: float = 0.0
	var ward_delta: float = 0.0

	ward_delta -= float(player.threat) * rules.doctrine_ward_threat
	ward_delta -= float(player.consecutive_wards) * rules.doctrine_ward_stagnation

	if (
		rules.odr_recoil_bank
		and player.lord == "Odradek"
		and player.odradek_bank != null
	):
		var urgency: float = (
			rules.doctrine_bank_urgency
			* float(player.odradek_bank.value)
		)
		hunt_delta += urgency
		siege_delta += urgency
		ward_delta -= urgency * 0.5

	return Vector3(hunt_delta, siege_delta, ward_delta)


static func update_ward_streak(
	player
) -> void:
	if player.action == "Ward":
		player.consecutive_wards += 1
	else:
		player.consecutive_wards = 0


static func _card_id(card) -> String:
	if card == null:
		return ""
	if card.has_method("card_id"):
		return String(card.card_id())
	return "%s:%d" % [String(card.suit), int(card.value)]
