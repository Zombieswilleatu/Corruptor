extends RefCounted

# Tooling transport only. Does not change U13's authoritative save codec.
const VERSION: String = "U13_EXACT_DATA_V1"

static func pack(value, depth: int = 0) -> Array:
	if depth > 128: return []
	match typeof(value):
		TYPE_NIL: return ["n"]
		TYPE_BOOL: return ["b", value]
		TYPE_INT: return ["i", str(value)]
		TYPE_FLOAT:
			if not is_finite(value): return []
			var bytes := PackedByteArray()
			bytes.resize(8)
			bytes.encode_double(0, value)
			return ["f", bytes.hex_encode()]
		TYPE_STRING: return ["s", value]
		TYPE_ARRAY:
			var items: Array = []
			for child in value:
				var item: Array = pack(child, depth + 1)
				if item.is_empty(): return []
				items.append(item)
			return ["a", items]
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			if keys.any(func(key): return typeof(key) != TYPE_STRING): return []
			keys.sort()
			var entries: Array = []
			for key in keys:
				var item: Array = pack(value[key], depth + 1)
				if item.is_empty(): return []
				entries.append([key, item])
			return ["d", entries]
	return []

static func invalid() -> Dictionary:
	return {"action": "invalid", "reason": "exact_data_invalid"}

static func unpack(node, depth: int = 0) -> Dictionary:
	if depth > 128 or typeof(node) != TYPE_ARRAY or node.is_empty(): return invalid()
	if node == ["n"]: return {"action": "decoded", "value": null}
	if node.size() != 2 or typeof(node[0]) != TYPE_STRING: return invalid()
	var tag: String = node[0]
	var value = node[1]
	if (tag == "b" and typeof(value) == TYPE_BOOL) or (tag == "s" and typeof(value) == TYPE_STRING):
		return {"action": "decoded", "value": value}
	if tag == "i" and typeof(value) == TYPE_STRING:
		var number: int = value.to_int()
		if str(number) == value: return {"action": "decoded", "value": number}
	if tag == "f" and typeof(value) == TYPE_STRING and value.length() == 16:
		for character in value:
			if character not in "0123456789abcdef": return invalid()
		var number: float = value.hex_decode().decode_double(0)
		if is_finite(number): return {"action": "decoded", "value": number}
	if tag == "a" and typeof(value) == TYPE_ARRAY:
		var items: Array = []
		for child in value:
			var decoded: Dictionary = unpack(child, depth + 1)
			if decoded.action == "invalid": return decoded
			items.append(decoded.value)
		return {"action": "decoded", "value": items}
	if tag == "d" and typeof(value) == TYPE_ARRAY:
		var entries: Dictionary = {}
		var previous = null
		for row in value:
			if typeof(row) != TYPE_ARRAY or row.size() != 2 or typeof(row[0]) != TYPE_STRING: return invalid()
			if previous != null and row[0] <= previous: return invalid()
			var decoded: Dictionary = unpack(row[1], depth + 1)
			if decoded.action == "invalid": return decoded
			entries[row[0]] = decoded.value
			previous = row[0]
		return {"action": "decoded", "value": entries}
	return invalid()

static func encode(value) -> Dictionary:
	var payload: Array = pack(value)
	if payload.is_empty(): return invalid()
	return {"action": "encoded", "text": JSON.stringify({"codec": VERSION, "payload": payload})}

static func decode(text: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(text) != OK: return invalid()
	var envelope = parser.data
	if typeof(envelope) != TYPE_DICTIONARY or envelope.size() != 2 or envelope.get("codec") != VERSION or not envelope.has("payload"):
		return invalid()
	return unpack(envelope.payload)

static func difference(expected, actual, path: String = "$") -> String:
	if typeof(expected) != typeof(actual): return path + ": type mismatch"
	if typeof(expected) == TYPE_DICTIONARY:
		var keys: Array = expected.keys()
		for key in actual:
			if key not in keys: keys.append(key)
		keys.sort()
		for key in keys:
			var child: String = path + "." + key
			if not actual.has(key): return child + ": missing"
			if not expected.has(key): return child + ": unexpected"
			var delta: String = difference(expected[key], actual[key], child)
			if not delta.is_empty(): return delta
	elif typeof(expected) == TYPE_ARRAY:
		if expected.size() != actual.size(): return path + ": array length mismatch"
		for index in range(expected.size()):
			var delta: String = difference(expected[index], actual[index], path + "[%d]" % index)
			if not delta.is_empty(): return delta
	elif typeof(expected) == TYPE_FLOAT:
		if pack(expected) != pack(actual): return path + ": float bits mismatch"
	elif expected != actual:
		return path + ": value mismatch"
	return ""
