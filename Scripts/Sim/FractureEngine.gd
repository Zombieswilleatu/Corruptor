class_name FractureEngine
# FRACTURE_MARCHERS_AFTERMATH_V1
extends RefCounted

const GameSetupData = preload(
	"res://Scripts/Sim/GameSetup.gd"
)

const CastleIntegrityRulesData = preload(
	"res://Scripts/Sim/CastleIntegrityRules.gd"
)

const SUBJECT_DAMAGE: int = 2
const INFRASTRUCTURE_DAMAGE: int = 2
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
	category: String = ""
) -> Dictionary:
	var fracture: int = fracture_value(String(target.lord))
	var chosen: String = category.strip_edges().to_lower()
	if chosen not in [CATEGORY_SUBJECTS, CATEGORY_INFRASTRUCTURE]:
		chosen = _choose_category(target, fracture)

	var events: Array[Dictionary] = []
	if fracture > 0:
		if chosen == CATEGORY_INFRASTRUCTURE:
			events = _fracture_infrastructure(target, fracture)
		else:
			events = _fracture_subjects(target, fracture)

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


static func _subject_score(target, fracture: int) -> int:
	var available: int = 0
	for entry: Dictionary in _subject_candidates(target, {}):
		available += maxi(
			0,
			int(entry.get("value", 0)) - 1
		)
	return mini(maxi(0, fracture) * SUBJECT_DAMAGE, available)


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
	fracture: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var used: Dictionary = {}

	for _event_index: int in range(fracture):
		var candidates: Array[Dictionary] = _subject_candidates(
			target,
			used
		)
		if candidates.is_empty():
			used.clear()
			candidates = _subject_candidates(target, used)
		if candidates.is_empty():
			break

		var selected: Dictionary = candidates[0]
		var card = selected.get("card", null)
		if card == null:
			break

		var before: int = int(card.value)
		var after: int = maxi(1, before - SUBJECT_DAMAGE)
		var before_id: String = _card_id(card)
		var march_before: int = -1
		var march_after: int = -1

		if String(selected.get("zone", "")) == "Marcher":
			var marcher_index: int = int(selected.get("marcher_index", -1))
			if marcher_index >= 0 and marcher_index < target.marchers.size():
				var marcher: Dictionary = target.marchers[marcher_index]
				march_before = int(marcher.get("value", before))
				march_after = maxi(1, march_before - SUBJECT_DAMAGE)
				marcher["value"] = march_after
				target.marchers[marcher_index] = marcher

		card.value = after
		used[String(selected.get("key", ""))] = true

		var event: Dictionary = {
			"kind": "subject",
			"zone": String(selected.get("zone", "")),
			"card_before": before_id,
			"card_after": _card_id(card),
			"before": before,
			"after": after,
		}
		if String(selected.get("zone", "")) == "Marcher":
			event["lane"] = String(selected.get("lane", ""))
			event["march_before"] = march_before
			event["march_after"] = march_after
		result.append(event)

	return result

static func _subject_candidates(
	target,
	used: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var zones: Array[Dictionary] = [
		{"name": "Lord", "rank": 0, "cards": target.lord_guards},
		{"name": "Castle", "rank": 1, "cards": target.castle_guards},
		{"name": "Garrison", "rank": 2, "cards": target.garrison},
	]

	for zone: Dictionary in zones:
		var cards: Array = zone.get("cards", [])
		for index: int in range(cards.size()):
			var card = cards[index]
			if card == null or int(card.value) <= 1:
				continue
			var key: String = "%s:%d" % [
				String(zone.get("name", "")),
				index,
			]
			if bool(used.get(key, false)):
				continue
			result.append({
				"zone": String(zone.get("name", "")),
				"rank": int(zone.get("rank", 0)),
				"index": index,
				"card": card,
				"value": int(card.value),
				"key": key,
			})

	# A marcher is still a Subject card on the board. Candidate priority uses
	# persistent card value; current lane force is updated separately on hit.
	for index: int in range(target.marchers.size()):
		var marcher: Dictionary = target.marchers[index]
		var card = marcher.get("card", null)
		if card == null or int(card.value) <= 1:
			continue
		var key: String = "Marcher:%d" % index
		if bool(used.get(key, false)):
			continue
		result.append({
			"zone": "Marcher",
			"rank": 3,
			"index": index,
			"marcher_index": index,
			"lane": String(marcher.get("lane", "")),
			"card": card,
			"value": int(card.value),
			"key": key,
		})

	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var av: int = int(a.get("value", 0))
			var bv: int = int(b.get("value", 0))
			if av != bv:
				return av > bv
			var ar: int = int(a.get("rank", 0))
			var br: int = int(b.get("rank", 0))
			if ar != br:
				return ar < br
			return int(a.get("index", 0)) < int(b.get("index", 0))
	)
	return result

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
