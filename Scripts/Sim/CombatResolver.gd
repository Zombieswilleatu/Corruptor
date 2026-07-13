class_name CombatResolver
extends RefCounted


static func combat_layers(
	_attacker,
	strength: int,
	guards_in: Array,
	ignore_lowest: bool,
	sigil_value: int,
	has_sigil: bool,
	struct_def: int,
	bypass: bool = false
) -> Dictionary:
	var remaining: int = strength

	var guards: Array[String] = (
		_to_string_array(
			guards_in
		)
	)

	var sigil_broken: bool = false
	var destroyed: bool = false
	var excess: int = 0

	if bypass:
		if (
			has_sigil
			and sigil_value > 0
			and remaining >= sigil_value
		):
			sigil_broken = true
			remaining -= sigil_value

		if remaining > struct_def:
			destroyed = true
			remaining -= struct_def
		else:
			return {
				"destroyed": false,
				"sigil_broken": sigil_broken,
				"excess": 0,
				"guards_out": _card_multiset(
					guards
				)
			}

		var bypass_guard_result: Dictionary = (
			_strip_guards(
				guards,
				remaining,
				ignore_lowest
			)
		)

		guards = _to_string_array(
			bypass_guard_result["guards"]
		)

		remaining = int(
			bypass_guard_result["remaining"]
		)

		excess = 0

		return {
			"destroyed": destroyed,
			"sigil_broken": sigil_broken,
			"excess": excess,
			"guards_out": _card_multiset(
				guards
			)
		}

	var normal_guard_result: Dictionary = (
		_strip_guards(
			guards,
			remaining,
			ignore_lowest
		)
	)

	guards = _to_string_array(
		normal_guard_result["guards"]
	)

	remaining = int(
		normal_guard_result["remaining"]
	)

	if (
		has_sigil
		and sigil_value > 0
		and remaining >= sigil_value
	):
		sigil_broken = true
		remaining -= sigil_value

	if remaining > struct_def:
		destroyed = true
		excess = remaining - struct_def
	else:
		destroyed = false
		excess = 0

	return {
		"destroyed": destroyed,
		"sigil_broken": sigil_broken,
		"excess": excess,
		"guards_out": _card_multiset(
			guards
		)
	}


static func _strip_guards(
	guards_in: Array,
	strength: int,
	ignore_lowest: bool
) -> Dictionary:
	var remaining: int = strength

	var guards: Array[String] = (
		_to_string_array(
			guards_in
		)
	)

	var ordered: Array[String] = []

	for guard: String in guards:
		ordered.append(guard)

	ordered.sort_custom(
		func(
			card_a: String,
			card_b: String
		) -> bool:
			return (
				_card_value(card_a)
				> _card_value(card_b)
			)
	)

	if (
		ignore_lowest
		and not ordered.is_empty()
	):
		var lowest: String = ordered[
			ordered.size() - 1
		]

		ordered.erase(lowest)

	for guard: String in ordered:
		var value: int = _card_value(
			guard
		)

		if remaining >= value:
			remaining -= value
			guards.erase(guard)
		else:
			break

	return {
		"remaining": remaining,
		"guards": guards
	}


static func _card_value(
	card_token: String
) -> int:
	var parts: PackedStringArray = (
		card_token.split(":")
	)

	if parts.is_empty():
		return 0

	return int(
		parts[
			parts.size() - 1
		]
	)


static func _card_multiset(
	cards: Array
) -> Array[String]:
	var out: Array[String] = (
		_to_string_array(
			cards
		)
	)

	out.sort()

	return out


static func _to_string_array(
	values: Array
) -> Array[String]:
	var out: Array[String] = []

	for value in values:
		out.append(
			String(value)
		)

	return out
