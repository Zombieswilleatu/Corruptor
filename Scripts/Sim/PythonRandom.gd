class_name PythonRandom
extends RefCounted


const STATE_SIZE: int = 624
const PERIOD: int = 397

const MATRIX_A: int = 0x9908B0DF
const UPPER_MASK: int = 0x80000000
const LOWER_MASK: int = 0x7FFFFFFF
const UINT32_MASK: int = 0xFFFFFFFF

const INIT_MULTIPLIER: int = 1812433253
const ARRAY_MULTIPLIER_ONE: int = 1664525
const ARRAY_MULTIPLIER_TWO: int = 1566083941


var _state: Array[int] = []
var _index: int = STATE_SIZE


func _init(
	seed_value: int = 0
) -> void:
	_initialize_from_seed(
		seed_value
	)


func seed(
	seed_value: int
) -> void:
	_initialize_from_seed(
		seed_value
	)


func next_uint32() -> int:
	if _index >= STATE_SIZE:
		_twist()

	var value: int = _state[
		_index
	]

	_index += 1

	value ^= value >> 11

	value ^= (
		value << 7
	) & 0x9D2C5680

	value ^= (
		value << 15
	) & 0xEFC60000

	value ^= value >> 18

	return value & UINT32_MASK


func random_float() -> float:
	var upper_value: int = (
		next_uint32() >> 5
	)

	var lower_value: int = (
		next_uint32() >> 6
	)

	var numerator: float = (
		float(
			upper_value
		) * 67108864.0
	) + float(
		lower_value
	)

	return numerator * (
		1.0 / 9007199254740992.0
	)


func getrandbits(
	bit_count: int
) -> int:
	assert(
		bit_count >= 0
		and bit_count <= 32,
		"PythonRandom currently supports getrandbits from 0 through 32 bits."
	)

	if bit_count == 0:
		return 0

	return next_uint32() >> (
		32 - bit_count
	)


func randbelow(
	upper_bound: int
) -> int:
	assert(
		upper_bound > 0,
		"randbelow requires a positive upper bound."
	)

	var bit_count: int = _bit_length(
		upper_bound
	)

	var result: int = getrandbits(
		bit_count
	)

	while result >= upper_bound:
		result = getrandbits(
			bit_count
		)

	return result


func randint(
	minimum: int,
	maximum: int
) -> int:
	assert(
		maximum >= minimum,
		"randint maximum must not be below its minimum."
	)

	return minimum + randbelow(
		maximum - minimum + 1
	)


func uniform(
	minimum: float,
	maximum: float
) -> float:
	return minimum + (
		(
			maximum - minimum
		)
		* random_float()
	)


func choice(
	values: Array
):
	assert(
		not values.is_empty(),
		"PythonRandom.choice requires a nonempty Array."
	)

	return values[
		randbelow(
			values.size()
		)
	]


func shuffle(
	values: Array
) -> void:
	if values.size() <= 1:
		return

	for index: int in range(
		values.size() - 1,
		0,
		-1
	):
		var swap_index: int = randbelow(
			index + 1
		)

		var temporary_value = values[
			index
		]

		values[index] = values[
			swap_index
		]

		values[swap_index] = temporary_value


func _initialize_from_seed(
	seed_value: int
) -> void:
	var normalized_seed: int = seed_value

	if normalized_seed < 0:
		normalized_seed = -normalized_seed

	var seed_words: Array[int] = []

	if normalized_seed == 0:
		seed_words.append(
			0
		)
	else:
		while normalized_seed > 0:
			seed_words.append(
				normalized_seed & UINT32_MASK
			)

			normalized_seed >>= 32

	_init_by_array(
		seed_words
	)


func _init_genrand(
	initial_seed: int
) -> void:
	_state.clear()

	_state.resize(
		STATE_SIZE
	)

	_state[0] = (
		initial_seed
		& UINT32_MASK
	)

	for index: int in range(
		1,
		STATE_SIZE
	):
		var previous: int = _state[
			index - 1
		]

		var mixed: int = previous ^ (
			previous >> 30
		)

		_state[index] = (
			(
				INIT_MULTIPLIER
				* mixed
			)
			+ index
		) & UINT32_MASK

	_index = STATE_SIZE


func _init_by_array(
	seed_words: Array[int]
) -> void:
	assert(
		not seed_words.is_empty(),
		"PythonRandom seed word array cannot be empty."
	)

	_init_genrand(
		19650218
	)

	var state_index: int = 1
	var key_index: int = 0

	var loop_count: int = STATE_SIZE

	if seed_words.size() > loop_count:
		loop_count = seed_words.size()

	for iteration: int in range(
		loop_count
	):
		var previous: int = _state[
			state_index - 1
		]

		var mixed: int = previous ^ (
			previous >> 30
		)

		_state[state_index] = (
			(
				_state[state_index]
				^ (
					mixed
					* ARRAY_MULTIPLIER_ONE
				)
			)
			+ seed_words[
				key_index
			]
			+ key_index
		) & UINT32_MASK

		state_index += 1
		key_index += 1

		if state_index >= STATE_SIZE:
			_state[0] = _state[
				STATE_SIZE - 1
			]

			state_index = 1

		if key_index >= seed_words.size():
			key_index = 0

	for iteration: int in range(
		STATE_SIZE - 1
	):
		var previous: int = _state[
			state_index - 1
		]

		var mixed: int = previous ^ (
			previous >> 30
		)

		_state[state_index] = (
			(
				_state[state_index]
				^ (
					mixed
					* ARRAY_MULTIPLIER_TWO
				)
			)
			- state_index
		) & UINT32_MASK

		state_index += 1

		if state_index >= STATE_SIZE:
			_state[0] = _state[
				STATE_SIZE - 1
			]

			state_index = 1

	_state[0] = 0x80000000
	_index = STATE_SIZE


func _twist() -> void:
	assert(
		_state.size() == STATE_SIZE,
		"PythonRandom state was not initialized."
	)

	for index: int in range(
		STATE_SIZE
	):
		var next_index: int = (
			index + 1
		) % STATE_SIZE

		var period_index: int = (
			index + PERIOD
		) % STATE_SIZE

		var joined_value: int = (
			_state[index]
			& UPPER_MASK
		) | (
			_state[next_index]
			& LOWER_MASK
		)

		var matrix_value: int = 0

		if (
			joined_value
			& 1
		) != 0:
			matrix_value = MATRIX_A

		_state[index] = (
			_state[period_index]
			^ (
				joined_value >> 1
			)
			^ matrix_value
		) & UINT32_MASK

	_index = 0


func _bit_length(
	value: int
) -> int:
	var remaining: int = value
	var result: int = 0

	while remaining > 0:
		result += 1
		remaining >>= 1

	return result
