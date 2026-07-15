class_name BotSelector
extends RefCounted


const BotPolicyData = preload(
	"res://Scripts/Sim/BotPolicy.gd"
)


const VERY_LOW_SCORE: float = -1.0e300
const MIN_EXPONENT: float = -700.0


static func choose(
	candidates: Array,
	random_source,
	policy = null
) -> Dictionary:
	if candidates.is_empty():
		return {
			"valid": false,
			"reason": "no_candidates",
			"candidate": {},
			"candidate_id": "",
			"payload": {},
			"index": -1,
			"mode": "",
			"roll": -1.0,
			"error_roll": -1.0,
			"draw_count": 0,
			"used_degraded_evaluation": false,
			"probabilities": [],
		}

	var effective_policy = policy

	if effective_policy == null:
		effective_policy = BotPolicyData.competitive()

	var use_degraded_evaluation: bool = false
	var error_roll: float = -1.0
	var draw_count: int = 0

	if (
		effective_policy.error_rate > 0.0
		and _has_degraded_scores(
			candidates
		)
	):
		assert(
			random_source != null,
			"Bot error selection requires PythonRandom."
		)

		error_roll = random_source.random_float()
		draw_count += 1

		use_degraded_evaluation = (
			error_roll
			< effective_policy.error_rate
		)

	if effective_policy.temperature <= 0.0:
		var argmax_index: int = _argmax_index(
			candidates,
			use_degraded_evaluation
		)

		return _selection_result(
			candidates,
			argmax_index,
			"argmax",
			-1.0,
			error_roll,
			draw_count,
			use_degraded_evaluation,
			_argmax_probabilities(
				candidates.size(),
				argmax_index
			)
		)

	assert(
		random_source != null,
		"Softmax selection requires PythonRandom."
	)

	var probabilities: Array = _softmax_probabilities(
		candidates,
		effective_policy.temperature,
		use_degraded_evaluation
	)

	var roll: float = random_source.random_float()
	draw_count += 1

	var selected_index: int = _sample_probability_index(
		probabilities,
		roll
	)

	return _selection_result(
		candidates,
		selected_index,
		"softmax",
		roll,
		error_roll,
		draw_count,
		use_degraded_evaluation,
		probabilities
	)


static func _selection_result(
	candidates: Array,
	selected_index: int,
	mode: String,
	roll: float,
	error_roll: float,
	draw_count: int,
	used_degraded_evaluation: bool,
	probabilities: Array
) -> Dictionary:
	if (
		selected_index < 0
		or selected_index >= candidates.size()
	):
		return {
			"valid": false,
			"reason": "selection_failed",
			"candidate": {},
			"candidate_id": "",
			"payload": {},
			"index": -1,
			"mode": mode,
			"roll": roll,
			"error_roll": error_roll,
			"draw_count": draw_count,
			"used_degraded_evaluation": (
				used_degraded_evaluation
			),
			"probabilities": probabilities,
		}

	var selected_candidate: Dictionary = (
		candidates[selected_index]
	)

	var payload = selected_candidate.get(
		"payload",
		{}
	)

	if typeof(
		payload
	) != TYPE_DICTIONARY:
		payload = {}

	return {
		"valid": true,
		"reason": "",
		"candidate": selected_candidate,
		"candidate_id": String(
			selected_candidate.get(
				"id",
				""
			)
		),
		"payload": payload,
		"index": selected_index,
		"mode": mode,
		"roll": roll,
		"error_roll": error_roll,
		"draw_count": draw_count,
		"used_degraded_evaluation": (
			used_degraded_evaluation
		),
		"probabilities": probabilities,
	}


static func _argmax_index(
	candidates: Array,
	use_degraded_evaluation: bool
) -> int:
	var selected_index: int = 0

	var selected_score: float = _candidate_score(
		candidates[0],
		use_degraded_evaluation
	)

	var selected_tie_rank: int = int(
		candidates[0].get(
			"tie_rank",
			0
		)
	)

	for index: int in range(
		1,
		candidates.size()
	):
		var candidate: Dictionary = candidates[
			index
		]

		var candidate_score: float = _candidate_score(
			candidate,
			use_degraded_evaluation
		)

		var candidate_tie_rank: int = int(
			candidate.get(
				"tie_rank",
				0
			)
		)

		if candidate_score > selected_score:
			selected_index = index
			selected_score = candidate_score
			selected_tie_rank = candidate_tie_rank
			continue

		if (
			candidate_score == selected_score
			and candidate_tie_rank > selected_tie_rank
		):
			selected_index = index
			selected_tie_rank = candidate_tie_rank

	return selected_index


static func _softmax_probabilities(
	candidates: Array,
	temperature: float,
	use_degraded_evaluation: bool
) -> Array:
	assert(
		temperature > 0.0,
		"Softmax temperature must be greater than zero."
	)

	var highest_score: float = VERY_LOW_SCORE

	for candidate in candidates:
		var candidate_score: float = _candidate_score(
			candidate,
			use_degraded_evaluation
		)

		if candidate_score > highest_score:
			highest_score = candidate_score

	var weights: Array = []
	var total_weight: float = 0.0

	for candidate in candidates:
		var candidate_score: float = _candidate_score(
			candidate,
			use_degraded_evaluation
		)

		var exponent: float = (
			candidate_score - highest_score
		) / temperature

		var weight: float = 0.0

		if exponent >= MIN_EXPONENT:
			weight = exp(
				exponent
			)

		weights.append(
			weight
		)

		total_weight += weight

	if total_weight <= 0.0:
		var fallback_index: int = _argmax_index(
			candidates,
			use_degraded_evaluation
		)

		return _argmax_probabilities(
			candidates.size(),
			fallback_index
		)

	var probabilities: Array = []

	for weight in weights:
		probabilities.append(
			float(
				weight
			) / total_weight
		)

	return probabilities


static func _sample_probability_index(
	probabilities: Array,
	roll: float
) -> int:
	if probabilities.is_empty():
		return -1

	var cumulative: float = 0.0

	for index: int in range(
		probabilities.size()
	):
		cumulative += float(
			probabilities[index]
		)

		if roll < cumulative:
			return index

	# Floating-point accumulation can finish a few ulps below 1.
	return probabilities.size() - 1


static func _argmax_probabilities(
	candidate_count: int,
	selected_index: int
) -> Array:
	var probabilities: Array = []

	for index: int in range(
		candidate_count
	):
		probabilities.append(
			1.0
			if index == selected_index
			else 0.0
		)

	return probabilities


static func _candidate_score(
	candidate: Dictionary,
	use_degraded_evaluation: bool
) -> float:
	if (
		use_degraded_evaluation
		and candidate.has(
			"degraded_score"
		)
	):
		return float(
			candidate.get(
				"degraded_score",
				VERY_LOW_SCORE
			)
		)

	return float(
		candidate.get(
			"score",
			VERY_LOW_SCORE
		)
	)


static func _has_degraded_scores(
	candidates: Array
) -> bool:
	for candidate in candidates:
		if (
			typeof(
				candidate
			) == TYPE_DICTIONARY
			and candidate.has(
				"degraded_score"
			)
		):
			return true

	return false
