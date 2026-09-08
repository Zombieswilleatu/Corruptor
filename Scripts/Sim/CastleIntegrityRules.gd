class_name CastleIntegrityRules
extends RefCounted


const CASTLES: Array[String] = [
	"Keep",
	"Bastion",
	"SummoningCircle",
	"Stockpile",
	"SiegeEngine",
]

# CASTLE_INTEGRITY_150_PERCENT_V1
const MAX_INTEGRITY: int = 21

const STATE_OPERATIONAL: String = "operational"
const STATE_DEFUNCT: String = "defunct"
const STATE_RUINED: String = "ruined"

const DEFAULT_PRIORITY: Array[String] = [
	"Keep",
	"Bastion",
	"SummoningCircle",
	"Stockpile",
	"SiegeEngine",
]

const CASTLE_PICK_PRIORITY: Dictionary = {
	"Orias": [
		"SiegeEngine", "Bastion", "Stockpile", "SummoningCircle", "Keep",
	],
	"Deimos": [
		"SiegeEngine", "Bastion", "Stockpile", "Keep", "SummoningCircle",
	],
	"Valak": [
		"SiegeEngine", "Keep", "Bastion", "Stockpile", "SummoningCircle",
	],
	"Kroni": [
		"Keep", "Bastion", "Stockpile", "SummoningCircle", "SiegeEngine",
	],
	"Kalligan": [
		"SiegeEngine", "Stockpile", "SummoningCircle", "Bastion", "Keep",
	],
	"Gremory": [
		"SiegeEngine", "Stockpile", "SummoningCircle", "Bastion", "Keep",
	],
	"Odradek": [
		"Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine",
	],
	"Kanifous": [
		"Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine",
	],
	"Humbaba": [
		"Keep", "Bastion", "Stockpile", "SummoningCircle", "SiegeEngine",
	],
}


static func max_integrity(_castle_name: String) -> int:
	return MAX_INTEGRITY


static func state_for(player, castle_name: String, rules: RuleConfig) -> String:
	if player == null or not player.castles.has(castle_name):
		return STATE_RUINED

	var integrity: int = int(
		player.castle_integrity.get(castle_name, max_integrity(castle_name))
	)
	if integrity <= 0:
		return STATE_RUINED

	if rules == null or String(rules.castle_power_gate_mode) == "owned":
		return STATE_OPERATIONAL

	if String(rules.castle_power_gate_mode) != "operational":
		push_error("Unknown Castle power gate mode: %s" % String(rules.castle_power_gate_mode))
		return STATE_RUINED

	return (
		STATE_OPERATIONAL
		if integrity >= maxi(1, int(rules.castle_operational_floor))
		else STATE_DEFUNCT
	)


static func standing(player, castle_name: String) -> bool:
	if player == null or not player.castles.has(castle_name):
		return false
	return int(
		player.castle_integrity.get(castle_name, max_integrity(castle_name))
	) > 0


static func power_active(player, castle_name: String, rules: RuleConfig) -> bool:
	return state_for(player, castle_name, rules) == STATE_OPERATIONAL


static func keep_interposes(
	player,
	rules: RuleConfig
) -> bool:
	return (
		player != null
		and rules != null
		and rules.keep_interposition
		and standing(player, "Keep")
	)


static func keep_fortification(
	player,
	rules: RuleConfig
) -> int:
	if not keep_interposes(player, rules):
		return 0

	# The physical Keep remains while Defunct, but Fortification is an
	# Operational benefit and disappears below the operational floor.
	if not power_active(player, "Keep", rules):
		return 0

	var override: int = int(
		player.keep_fortification_level
	)

	if override >= 0:
		return maxi(0, override)

	return maxi(
		0,
		int(rules.keep_fortification)
	)


static func repair_locked(
	player,
	castle_name: String,
	rules: RuleConfig
) -> bool:
	return (
		player != null
		and rules != null
		and rules.defunct_repair_lock
		and bool(
			player.castle_repair_locked_this_round.get(
				castle_name,
				false
			)
		)
	)


static func note_operational(
	player,
	castle_name: String,
	rules: RuleConfig
) -> void:
	if (
		player == null
		or rules == null
		or not rules.defunct_repair_lock
		or not standing(player, castle_name)
	):
		return

	var integrity: int = int(
		player.castle_integrity.get(
			castle_name,
			max_integrity(castle_name)
		)
	)

	if integrity >= maxi(
		1,
		int(rules.castle_operational_floor)
	):
		player.castle_operational_seen_this_round[
			castle_name
		] = true


static func prepare_repair_locks_for_new_round(
	player,
	rules: RuleConfig
) -> void:
	if player == null:
		return

	var next_locked: Dictionary = {}

	if (
		rules != null
		and rules.defunct_repair_lock
	):
		var floor: int = maxi(
			1,
			int(rules.castle_operational_floor)
		)

		for castle_name: String in CASTLES:
			if not bool(
				player.castle_operational_seen_this_round.get(
					castle_name,
					false
				)
			):
				continue

			if not standing(
				player,
				castle_name
			):
				continue

			var integrity: int = int(
				player.castle_integrity.get(
					castle_name,
					max_integrity(castle_name)
				)
			)

			if (
				integrity > 0
				and integrity < floor
			):
				next_locked[
					castle_name
				] = true

	player.castle_repair_locked_this_round = (
		next_locked
	)

	# Start recording the new round from the current board state.
	player.castle_operational_seen_this_round.clear()

	if (
		rules != null
		and rules.defunct_repair_lock
	):
		for castle_name: String in CASTLES:
			note_operational(
				player,
				castle_name,
				rules
			)


static func can_exert(
	player,
	castle_name: String,
	amount: int,
	rules: RuleConfig
) -> bool:
	if amount <= 0 or not power_active(player, castle_name, rules):
		return false
	var current: int = int(
		player.castle_integrity.get(castle_name, max_integrity(castle_name))
	)
	# Self-spend may drive a Castle Defunct, but never Ruin it.
	return current - amount >= 1


static func exert(
	player,
	castle_name: String,
	amount: int,
	rules: RuleConfig
) -> int:
	if not can_exert(player, castle_name, amount, rules):
		return 0
	var current: int = int(
		player.castle_integrity.get(castle_name, max_integrity(castle_name))
	)
	player.castle_integrity[castle_name] = current - amount
	return amount


static func gain_threat(
	player,
	rules: RuleConfig,
	amount: int = 1
) -> Dictionary:
	var before: int = int(player.threat)
	var requested: int = maxi(0, amount)
	var applied: int = requested
	var prevented: int = 0
	var conduit_spent: int = 0

	if (
		requested > 0
		and rules != null
		and rules.circle_blood_conduit
		and power_active(player, "SummoningCircle", rules)
	):
		var capped_after: int = mini(int(rules.max_threat), before + requested)
		# Threat 2/3/4 are Lord-defense breakpoints. 0->1 buys no defense change.
		if capped_after >= 2 and capped_after > before:
			var cost: int = maxi(1, int(rules.circle_conduit_cost))
			if can_exert(player, "SummoningCircle", cost, rules):
				conduit_spent = exert(player, "SummoningCircle", cost, rules)
				if conduit_spent > 0:
					applied = maxi(0, applied - 1)
					prevented = 1

	player.threat = mini(int(rules.max_threat), before + applied)
	return {
		"before": before,
		"after": int(player.threat),
		"requested": requested,
		"applied": applied,
		"prevented": prevented,
		"circle_integrity_spent": conduit_spent,
	}


static func priority_for(lord_name: String) -> Array[String]:
	var result: Array[String] = []
	var raw_priority = CASTLE_PICK_PRIORITY.get(
		lord_name,
		DEFAULT_PRIORITY
	)

	for castle_name_value in raw_priority:
		var castle_name := String(castle_name_value)
		if CASTLES.has(castle_name):
			result.append(castle_name)

	for castle_name: String in CASTLES:
		if not result.has(castle_name):
			result.append(castle_name)

	return result


# KEEP_BASELINE_OPENING_V1
static func opening_castles(
	lord_name: String,
	starting_count: int
) -> Array[String]:
	var priority: Array[String] = priority_for(lord_name)
	var result: Array[String] = []
	var count: int = clampi(starting_count, 0, CASTLES.size())

	if count <= 0:
		return result

	# Common defensive baseline; personality still controls the remaining slots.
	result.append("Keep")
	for castle_name: String in priority:
		if result.size() >= count:
			break
		if castle_name == "Keep":
			continue
		if not result.has(castle_name):
			result.append(castle_name)

	return result


static func board_fraction(
	standing_count: int,
	denominator: int = 5
) -> float:
	var safe_denominator: int = maxi(1, denominator)
	return clampf(
		float(maxi(0, standing_count)) / float(safe_denominator),
		0.0,
		1.0
	)


static func choose_payment_cards(
	cards: Array,
	target: int
) -> Array:
	if cards.is_empty() or target <= 0:
		return []

	# total -> physical card indices. Prefer fewer cards for an equal total.
	var paths: Dictionary = {0: []}
	for card_index: int in range(cards.size()):
		var snapshot: Dictionary = paths.duplicate(true)
		for raw_total in snapshot.keys():
			var total: int = int(raw_total)
			var candidate_indices: Array = snapshot[raw_total].duplicate()
			candidate_indices.append(card_index)
			var new_total: int = total + int(cards[card_index].value)
			if (
				not paths.has(new_total)
				or candidate_indices.size() < Array(paths[new_total]).size()
			):
				paths[new_total] = candidate_indices

	var chosen_total: int = -1
	for raw_total in paths.keys():
		var total: int = int(raw_total)
		if total <= 0:
			continue
		if total >= target:
			if chosen_total < target:
				chosen_total = total
				continue
			var overshoot: int = total - target
			var chosen_overshoot: int = chosen_total - target
			var count: int = Array(paths[total]).size()
			var chosen_count: int = Array(paths[chosen_total]).size()
			if (
				overshoot < chosen_overshoot
				or (overshoot == chosen_overshoot and count < chosen_count)
				or (
					overshoot == chosen_overshoot
					and count == chosen_count
					and total < chosen_total
				)
			):
				chosen_total = total
		elif chosen_total < target:
			if (
				total > chosen_total
				or (
					total == chosen_total
					and Array(paths[total]).size() < Array(paths[chosen_total]).size()
				)
			):
				chosen_total = total

	if chosen_total <= 0:
		return []

	var selected: Array = []
	for raw_index in paths[chosen_total]:
		selected.append(cards[int(raw_index)])
	return selected
