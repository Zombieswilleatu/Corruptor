class_name RawStreamTests
extends RefCounted


const PythonRandomData = preload(
	"res://Scripts/Sim/PythonRandom.gd"
)


const TRACE_NAME: String = "rng_stream"
const SEED: int = 1


static func run(
	_rules: RuleConfig
) -> Array:
	var messages: Array = []

	var trace: Dictionary = GoldenMaster.load_trace(
		TRACE_NAME
	)

	if trace.has(
		"_error"
	):
		messages.append(
			_fail(
				"%s failed to load: %s"
				% [
					TRACE_NAME,
					trace["_error"],
				]
			)
		)

		return messages

	var fixture_seed: int = int(
		trace.get(
			"seed",
			-1
		)
	)

	if fixture_seed != SEED:
		messages.append(
			_fail(
				"RNG fixture expected seed %d but contains seed %d."
				% [
					SEED,
					fixture_seed,
				]
			)
		)

		return messages

	var streams = trace.get(
		"streams",
		{}
	)

	if typeof(
		streams
	) != TYPE_DICTIONARY:
		messages.append(
			_fail(
				"%s field 'streams' is not a Dictionary."
				% TRACE_NAME
			)
		)

		return messages

	var stream_dictionary: Dictionary = streams

	if stream_dictionary.is_empty():
		messages.append(
			_fail(
				"%s has no streams."
				% TRACE_NAME
			)
		)

		return messages

	messages.append(
		_check_getrandbits32(
			stream_dictionary.get(
				"getrandbits32",
				[]
			)
		)
	)

	messages.append(
		_check_random(
			stream_dictionary.get(
				"random",
				[]
			)
		)
	)

	messages.append(
		_check_randint(
			stream_dictionary.get(
				"randint_0_1000000",
				[]
			)
		)
	)

	messages.append(
		_check_uniform(
			stream_dictionary.get(
				"uniform_neg1000_1000",
				[]
			)
		)
	)

	messages.append(
		_check_shuffle(
			stream_dictionary.get(
				"shuffle_range60",
				[]
			)
		)
	)

	return messages


static func _check_getrandbits32(
	golden
) -> Dictionary:
	if typeof(
		golden
	) != TYPE_ARRAY:
		return _fail(
			"getrandbits32 golden data is not an Array."
		)

	var golden_values: Array = golden

	if golden_values.is_empty():
		return _fail(
			"getrandbits32 has no golden data."
		)

	var rng = PythonRandomData.new()

	rng.seed(
		SEED
	)

	for index: int in range(
		golden_values.size()
	):
		var expected: int = int(
			golden_values[index]
		)

		var actual: int = int(
			rng.getrandbits(
				32
			)
		)

		if actual != expected:
			return _fail(
				"getrandbits(32) diverges at index %d: expected %d, got %d. Check init_by_array, genrand and tempering."
				% [
					index,
					expected,
					actual,
				]
			)

	return _pass(
		"getrandbits(32): %d/%d match. Core Twister proven."
		% [
			golden_values.size(),
			golden_values.size(),
		]
	)


static func _check_random(
	golden
) -> Dictionary:
	if typeof(
		golden
	) != TYPE_ARRAY:
		return _fail(
			"random golden data is not an Array."
		)

	var golden_values: Array = golden

	if golden_values.is_empty():
		return _fail(
			"random has no golden data."
		)

	var rng = PythonRandomData.new()

	rng.seed(
		SEED
	)

	for index: int in range(
		golden_values.size()
	):
		if typeof(
			golden_values[index]
		) != TYPE_DICTIONARY:
			return _fail(
				"random golden row %d is not a Dictionary."
				% index
			)

		var row: Dictionary = golden_values[
			index
		]

		var expected_hex: String = String(
			row.get(
				"hex",
				""
			)
		)

		var value: float = rng.random_float()

		var actual_hex: String = _float_hex(
			value
		)

		if actual_hex != expected_hex:
			return _fail(
				"random() diverges at index %d: expected %s (%s), got %s (%.17g). The raw words passed, so check 53-bit float construction."
				% [
					index,
					expected_hex,
					String(
						row.get(
							"dec",
							"?"
						)
					),
					actual_hex,
					value,
				]
			)

	return _pass(
		"random(): %d/%d bit-exact."
		% [
			golden_values.size(),
			golden_values.size(),
		]
	)


static func _check_randint(
	golden
) -> Dictionary:
	if typeof(
		golden
	) != TYPE_ARRAY:
		return _fail(
			"randint golden data is not an Array."
		)

	var golden_values: Array = golden

	if golden_values.is_empty():
		return _fail(
			"randint has no golden data."
		)

	var rng = PythonRandomData.new()

	rng.seed(
		SEED
	)

	for index: int in range(
		golden_values.size()
	):
		var expected: int = int(
			golden_values[index]
		)

		var actual: int = int(
			rng.randint(
				0,
				1000000
			)
		)

		if actual != expected:
			return _fail(
				"randint(0, 1000000) diverges at index %d: expected %d, got %d. Check randbelow bit-length and rejection sampling."
				% [
					index,
					expected,
					actual,
				]
			)

	return _pass(
		"randint(0, 1000000): %d/%d match. randbelow proven."
		% [
			golden_values.size(),
			golden_values.size(),
		]
	)


static func _check_uniform(
	golden
) -> Dictionary:
	if typeof(
		golden
	) != TYPE_ARRAY:
		return _fail(
			"uniform golden data is not an Array."
		)

	var golden_values: Array = golden

	if golden_values.is_empty():
		return _fail(
			"uniform has no golden data."
		)

	var rng = PythonRandomData.new()

	rng.seed(
		SEED
	)

	for index: int in range(
		golden_values.size()
	):
		if typeof(
			golden_values[index]
		) != TYPE_DICTIONARY:
			return _fail(
				"uniform golden row %d is not a Dictionary."
				% index
			)

		var row: Dictionary = golden_values[
			index
		]

		var expected_hex: String = String(
			row.get(
				"hex",
				""
			)
		)

		var value: float = rng.uniform(
			-1000.0,
			1000.0
		)

		var actual_hex: String = _float_hex(
			value
		)

		if actual_hex != expected_hex:
			return _fail(
				"uniform(-1000, 1000) diverges at index %d: expected %s (%s), got %s (%.17g). If random passed, check uniform arithmetic."
				% [
					index,
					expected_hex,
					String(
						row.get(
							"dec",
							"?"
						)
					),
					actual_hex,
					value,
				]
			)

	return _pass(
		"uniform(-1000, 1000): %d/%d bit-exact."
		% [
			golden_values.size(),
			golden_values.size(),
		]
	)


static func _check_shuffle(
	golden
) -> Dictionary:
	if typeof(
		golden
	) != TYPE_ARRAY:
		return _fail(
			"shuffle golden data is not an Array."
		)

	var golden_values: Array = golden

	if golden_values.is_empty():
		return _fail(
			"shuffle has no golden data."
		)

	var rng = PythonRandomData.new()

	rng.seed(
		SEED
	)

	var items: Array = []

	for index: int in range(
		golden_values.size()
	):
		items.append(
			index
		)

	rng.shuffle(
		items
	)

	for index: int in range(
		golden_values.size()
	):
		var expected: int = int(
			golden_values[index]
		)

		var actual: int = int(
			items[index]
		)

		if actual != expected:
			return _fail(
				"shuffle(range(%d)) diverges at index %d: expected %d, got %d. Check backward Fisher-Yates order or randbelow draw sequence."
				% [
					golden_values.size(),
					index,
					expected,
					actual,
				]
			)

	return _pass(
		"shuffle(range(%d)): permutation exact."
		% golden_values.size()
	)


static func _float_hex(
	value: float
) -> String:
	var bytes: PackedByteArray = PackedByteArray()

	bytes.resize(
		8
	)

	bytes.encode_double(
		0,
		value
	)

	var result: String = ""

	for index: int in range(
		7,
		-1,
		-1
	):
		result += "%02x" % bytes[
			index
		]

	return result


static func _pass(
	text: String
) -> Dictionary:
	return {
		"passed": true,
		"text": "PASS  %s"
		% text,
	}


static func _fail(
	text: String
) -> Dictionary:
	return {
		"passed": false,
		"text": "FAIL  %s"
		% text,
	}
