class_name FractureEngine
# FRACTURE_GUARD_REVEAL_V1
# FRACTURE_MARCHERS_AFTERMATH_V1
# FRACTURE_RANDOM_SUBJECT_BUCKETS_V1
extends RefCounted

const GameSetupData = preload(
	"res://Scripts/Sim/GameSetup.gd"
)

const CastleIntegrityRulesData = preload(
	"res://Scripts/Sim/CastleIntegrityRules.gd"
)

const PythonRandomData = preload(
	"res://Scripts/Sim/PythonRandom.gd"
)

const SUBJECT_DAMAGE: int = 2
const INFRASTRUCTURE_DAMAGE: int = 2
const MARCHER_DAMAGE: int = 1
const MARCHER_TARGETS_PER_FRACTURE: int = 3

const SUBJECT_GROUP_LORD: String = "Lord"
const SUBJECT_GROUP_CASTLE: String = "Castle"
const SUBJECT_GROUP_MARCHERS: String = "Marcher"
const CATEGORY_SUBJECTS: String = "subjects"
const CATEGORY_INFRASTRUCTURE: String = "infrastructure"

const CASTLE_ORDER: Array[String] = [
	"Keep",
	"Bastion",
	"SummoningCircle",
	"Stockpile",
	"SiegeEngine",
]


static func fracture_value(lord_id: String) -> int:
	var data: Dictionary = GameSetupData.LORD_CONTENT.get(
		lord_id,
		{}
	)
	return maxi(
		0,
		int(data.get("return_threat", 0))
	)


static func resolve(
	_game,
	_rules: RuleConfig,
	_banisher,
	target,
	category: String = "",
	random_source = null
) -> Dictionary:
	var fracture: int = fracture_value(String(target.lord))
	var chosen: String = category.strip_edges().to_lower()

	if chosen not in [
		CATEGORY_SUBJECTS,
		CATEGORY_INFRASTRUCTURE,
	]:
		chosen = _choose_category(
			target,
			fracture
		)

	var events: Array[Dictionary] = []

	if fracture > 0:
		if chosen == CATEGORY_INFRASTRUCTURE:
			events = _fracture_infrastructure(
				target,
				fracture
			)
		else:
			var effective_random_source = (
				_effective_random_source(
					_game,
					random_source
				)
			)
			events = _fracture_subjects(
				target,
				fracture,
				effective_random_source
			)

	return {
		"triggered": fracture > 0,
		"lord": String(target.lord),
		"fracture": fracture,
		"category": chosen,
		"events": events,
	}


static func _choose_category(target, fracture: int) -> String:
	var subject_score: int = _subject_score(target, fracture)
	var infrastructure_score: int = _infrastructure_score(
		target,
		fracture
	)
	return (
		CATEGORY_INFRASTRUCTURE
		if infrastructure_score > subject_score
		else CATEGORY_SUBJECTS
	)


static func _subject_score(
	target,
	fracture: int
) -> int:
	if fracture <= 0:
		return 0

	var groups: Array[String] = _subject_groups(
		target
	)

	if groups.is_empty():
		return 0

	# The player chooses Subjects vs Infrastructure, but the actual Subject
	# damage is intentionally unpredictable. This score is only the default/bot
	# category heuristic, so estimate one random bucket hit rather than claiming
	# knowledge of the eventual victims.
	var one_roll_capacity: float = 0.0

	for group_name: String in groups:
		match group_name:
			SUBJECT_GROUP_LORD:
				one_roll_capacity += float(
					_guard_group_capacity(
						target.lord_guards
					)
				)
			SUBJECT_GROUP_CASTLE:
				one_roll_capacity += float(
					_guard_group_capacity(
						target.castle_guards
					)
				)
			SUBJECT_GROUP_MARCHERS:
				one_roll_capacity += float(
					mini(
						MARCHER_TARGETS_PER_FRACTURE,
						_living_marcher_indices(
							target
						).size()
					)
				)

	var expected_per_roll: float = (
		one_roll_capacity
		/ float(groups.size())
	)

	return int(
		round(
			expected_per_roll
			* float(fracture)
		)
	)


static func _infrastructure_score(target, fracture: int) -> int:
	var available: int = 0
	for castle_name_value in target.castles:
		var castle_name: String = String(castle_name_value)
		var maximum: int = CastleIntegrityRulesData.max_integrity(
			castle_name
		)
		available += maxi(
			0,
			int(
				target.castle_integrity.get(
					castle_name,
					maximum
				)
			)
		)
	return mini(
		maxi(0, fracture) * INFRASTRUCTURE_DAMAGE,
		available
	)


static func _fracture_subjects(
	target,
	fracture: int,
	random_source
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	# Every Fracture point is an independent roll. If all three groups are live,
	# Lord Guards / Castle Guards / Marchers are exactly equal buckets.
	# Empty buckets are omitted, equivalent to rerolling until a live bucket is
	# selected. No victim is remembered across Fracture points.
	for _event_index: int in range(
		maxi(
			0,
			fracture
		)
	):
		var groups: Array[String] = _subject_groups(
			target
		)

		if groups.is_empty():
			break

		var group_name: String = groups[
			_random_index(
				random_source,
				groups.size()
			)
		]

		if group_name == SUBJECT_GROUP_MARCHERS:
			result.append_array(
				_fracture_marcher_group(
					target,
					random_source
				)
			)
		else:
			var guard_event: Dictionary = (
				_fracture_guard_group(
					target,
					group_name,
					random_source
				)
			)

			if not guard_event.is_empty():
				result.append(
					guard_event
				)

	return result


static func _subject_groups(
	target
) -> Array[String]:
	var groups: Array[String] = []

	if not _eligible_guard_indices(
		target.lord_guards
	).is_empty():
		groups.append(
			SUBJECT_GROUP_LORD
		)

	if not _eligible_guard_indices(
		target.castle_guards
	).is_empty():
		groups.append(
			SUBJECT_GROUP_CASTLE
		)

	if not _living_marcher_indices(
		target
	).is_empty():
		groups.append(
			SUBJECT_GROUP_MARCHERS
		)

	# Garrison is intentionally gone from Fracture. It is expected to fold into
	# the future Retinue layer instead of remaining a fourth Subject bucket.
	return groups


static func _eligible_guard_indices(
	cards: Array
) -> Array[int]:
	var result: Array[int] = []

	for index: int in range(
		cards.size()
	):
		var card = cards[index]

		if (
			card != null
			and int(card.value) > 1
		):
			result.append(
				index
			)

	return result


static func _living_marcher_indices(
	target
) -> Array[int]:
	var result: Array[int] = []

	for index: int in range(
		target.marchers.size()
	):
		var marcher: Dictionary = (
			target.marchers[index]
		)

		if int(
			marcher.get(
				"hp",
				0
			)
		) > 0:
			result.append(
				index
			)

	return result


static func _guard_group_capacity(
	cards: Array
) -> int:
	var best: int = 0

	for card in cards:
		if card == null:
			continue

		best = maxi(
			best,
			mini(
				SUBJECT_DAMAGE,
				maxi(
					0,
					int(card.value) - 1
				)
			)
		)

	return best


static func _fracture_guard_group(
	target,
	group_name: String,
	random_source
) -> Dictionary:
	var cards: Array = (
		target.lord_guards
		if group_name == SUBJECT_GROUP_LORD
		else target.castle_guards
	)

	var eligible: Array[int] = (
		_eligible_guard_indices(
			cards
		)
	)

	if eligible.is_empty():
		return {}

	var card_index: int = eligible[
		_random_index(
			random_source,
			eligible.size()
		)
	]

	var card = cards[
		card_index
	]

	var before: int = int(
		card.value
	)
	var before_id: String = _card_id(
		card
	)
	var after: int = maxi(
		1,
		before - SUBJECT_DAMAGE
	)

	var newly_revealed: bool = not bool(
		card.guard_revealed
	)
	card.guard_revealed = true
	card.value = after

	return {
		"kind": "subject",
		"zone": group_name,
		"card_before": before_id,
		"card_after": _card_id(card),
		"before": before,
		"after": after,
		"newly_revealed": newly_revealed,
	}


static func _fracture_marcher_group(
	target,
	random_source
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var available: Array[int] = (
		_living_marcher_indices(
			target
		)
	)

	var hit_count: int = mini(
		MARCHER_TARGETS_PER_FRACTURE,
		available.size()
	)
	var selected: Array[int] = []

	# Within ONE Marcher roll, victims are distinct.
	for _hit_index: int in range(
		hit_count
	):
		var pick_position: int = _random_index(
			random_source,
			available.size()
		)
		selected.append(
			available[
				pick_position
			]
		)
		available.remove_at(
			pick_position
		)

	var dead_indices: Array[int] = []

	for marcher_index: int in selected:
		var marcher: Dictionary = (
			target.marchers[
				marcher_index
			]
		)

		var hp_before: int = int(
			marcher.get(
				"hp",
				0
			)
		)
		var hp_after: int = maxi(
			0,
			hp_before - MARCHER_DAMAGE
		)

		var marcher_id: String = String(
			marcher.get(
				"id",
				"marcher_%d" % marcher_index
			)
		)

		var suit_name: String = String(
			marcher.get(
				"suit",
				""
			)
		)

		if suit_name.is_empty():
			var card = marcher.get(
				"card",
				null
			)
			if card != null:
				suit_name = String(
					card.suit
				)

		if suit_name.is_empty():
			suit_name = "Marcher"

		marcher["hp"] = hp_after
		target.marchers[
			marcher_index
		] = marcher

		result.append({
			"kind": "subject",
			"zone": SUBJECT_GROUP_MARCHERS,
			"group": "Marchers",
			"marcher_id": marcher_id,
			"lane": String(
				marcher.get(
					"lane",
					""
				)
			),
			"suit": suit_name,
			"card_before": suit_name,
			"card_after": suit_name,
			"before": hp_before,
			"after": hp_after,
			"hp_before": hp_before,
			"hp_after": hp_after,
			"armor": int(
				marcher.get(
					"armor",
					0
				)
			),
			"direct_hp": true,
			"destroyed": hp_after <= 0,
		})

		if hp_after <= 0:
			dead_indices.append(
				marcher_index
			)

	# Resolve the whole wave before removing dead tokens so selected indices stay
	# stable. Remove descending afterward.
	dead_indices.sort()
	dead_indices.reverse()

	for marcher_index: int in dead_indices:
		target.marchers.remove_at(
			marcher_index
		)

	return result


static func _effective_random_source(
	game,
	explicit_random_source
):
	if explicit_random_source != null:
		return explicit_random_source

	if (
		game != null
		and game.has_meta(
			"_resolution_random_source"
		)
	):
		var meta_source = game.get_meta(
			"_resolution_random_source",
			null
		)

		if meta_source != null:
			return meta_source

	# Low-level Fracture tests historically call resolve() without a match RNG.
	# Production BotRound and playable paths install the canonical match source.
	return PythonRandomData.new(
		0
	)


static func _random_index(
	random_source,
	count: int
) -> int:
	assert(
		count > 0
	)

	if count == 1:
		return 0

	var roll: float = clampf(
		float(
			random_source.random_float()
		),
		0.0,
		0.9999999999999999
	)

	return mini(
		count - 1,
		int(
			floor(
				roll
				* float(count)
			)
		)
	)


static func _fracture_infrastructure(
	target,
	fracture: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var used: Dictionary = {}

	for _event_index: int in range(fracture):
		var candidates: Array[Dictionary] = _infrastructure_candidates(
			target,
			used
		)
		if candidates.is_empty():
			used.clear()
			candidates = _infrastructure_candidates(target, used)
		if candidates.is_empty():
			break

		var selected: Dictionary = candidates[0]
		var castle_name: String = String(selected.get("castle", ""))
		var before: int = int(selected.get("integrity", 0))
		var after: int = maxi(0, before - INFRASTRUCTURE_DAMAGE)
		target.castle_integrity[castle_name] = after
		used[castle_name] = true

		var ruined: bool = after <= 0
		if ruined:
			target.castles.erase(castle_name)
			if not target.ruined_castles.has(castle_name):
				target.ruined_castles.append(castle_name)

		result.append({
			"kind": "infrastructure",
			"castle": castle_name,
			"before": before,
			"after": after,
			"ruined": ruined,
		})

	return result


static func _infrastructure_candidates(
	target,
	used: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for castle_name_value in target.castles:
		var castle_name: String = String(castle_name_value)
		if bool(used.get(castle_name, false)):
			continue
		var maximum: int = CastleIntegrityRulesData.max_integrity(
			castle_name
		)
		var integrity: int = maxi(
			0,
			int(
				target.castle_integrity.get(
					castle_name,
					maximum
				)
			)
		)
		if integrity <= 0:
			continue
		result.append({
			"castle": castle_name,
			"integrity": integrity,
			"rank": _castle_rank(castle_name),
		})

	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var ai: int = int(a.get("integrity", 0))
			var bi: int = int(b.get("integrity", 0))
			if ai != bi:
				return ai > bi
			return int(a.get("rank", 0)) < int(b.get("rank", 0))
	)
	return result


static func _castle_rank(castle_name: String) -> int:
	var index: int = CASTLE_ORDER.find(castle_name)
	return CASTLE_ORDER.size() if index < 0 else index


static func _card_id(card) -> String:
	if card == null:
		return ""
	if card.has_method("card_id"):
		return String(card.card_id())
	return "%s:%d" % [String(card.suit), int(card.value)]
