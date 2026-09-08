class_name U13KeyedRng
extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const VERSION: String = "U13_SHA256_REJECTION_V1"
const DOMAIN_SIZE: int = 4294967296


# No mutable draw cursor. UTF-8 fields are length prefixed in BYTES.
# Digest's first four bytes are an unsigned big-endian integer.
static func draw(
	seed_value: String, effect_id: String, purpose: String, roll_index: int, bound: int
) -> Dictionary:
	if seed_value.is_empty() or effect_id.is_empty() or purpose.is_empty():
		return Data.invalid("rng_key_required")
	if not Data.is_integer(roll_index) or roll_index < 0 or bound < 1 or bound > DOMAIN_SIZE:
		return Data.invalid("rng_range_invalid")
	var limit: int = DOMAIN_SIZE - DOMAIN_SIZE % bound
	var attempt: int = 0
	while attempt < 1024:
		var fields: Array = [VERSION, seed_value, effect_id, purpose, str(roll_index), str(attempt)]
		var material: String = ""
		for field: String in fields:
			material += str(field.to_utf8_buffer().size()) + ":" + field
		var digest: PackedByteArray = material.sha256_buffer()
		var value: int = (int(digest[0]) << 24) | (int(digest[1]) << 16)
		value |= (int(digest[2]) << 8) | int(digest[3])
		if value < limit:
			return {"action": "u13_roll", "value": value % bound}
		attempt += 1
	return Data.invalid("rng_rejection_limit")
