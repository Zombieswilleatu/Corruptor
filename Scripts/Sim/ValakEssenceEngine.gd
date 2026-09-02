class_name ValakEssenceEngine
extends RefCounted


const DrawEngineData = preload(
	"res://Scripts/Sim/DrawEngine.gd"
)


const CAP: int = 5
const GAIN_PER_GUARD: int = 2

const ZONE_LORD: String = "Lord"
const ZONE_CASTLE: String = "Castle"

# Public distribution used by the agreed V5 no-cheat blind Projection doctrine.
const CARD_DIST: Dictionary = {
	1: 4,
	2: 4,
	3: 4,
	4: 3,
	5: 3,
}


static func enabled(
	rules: RuleConfig
) -> bool:
	# Life Essence is the current lab/playable Valak revision, not historical
	# DE-v2. This profile gate preserves old DE-v2 identity and Siphon behavior.
	return (
		rules != null
		and not String(rules.lab_profile_version).is_empty()
	)


static func gain_from_guards(
	player,
	guards_defeated: Array,
	rules: RuleConfig
) -> Dictionary:
	var before: int = (
		int(player.valak_life_essence)
		if player != null
		else 0
	)

	if (
		not enabled(rules)
		or player == null
		or String(player.lord) != "Valak"
		or not bool(player.alive)
		or guards_defeated.is_empty()
	):
		return {
			"triggered": false,
			"guards": 0,
			"raw": 0,
			"gained": 0,
			"overflow": 0,
			"before": before,
			"after": before,
		}

	var raw: int = GAIN_PER_GUARD * guards_defeated.size()
	var room: int = max(
		0,
		CAP - before
	)
	var gained: int = min(
		raw,
		room
	)

	player.valak_life_essence = before + gained

	return {
		"triggered": true,
		"guards": guards_defeated.size(),
		"raw": raw,
		"gained": gained,
		"overflow": max(0, raw - gained),
		"before": before,
		"after": int(player.valak_life_essence),
	}


static func reinforce_hunt(
	player,
	incoming_after_ward: int,
	rules: RuleConfig
) -> Dictionary:
	var before: int = (
		int(player.valak_life_essence)
		if player != null
		else 0
	)

	if (
		not enabled(rules)
		or player == null
		or String(player.lord) != "Valak"
		or not bool(player.alive)
		or before <= 0
	):
		return {
			"triggered": false,
			"spent": 0,
			"before": before,
			"after": before,
		}

	var spend: int = min(
		before,
		max(
			0,
			incoming_after_ward
		)
	)

	if spend <= 0:
		return {
			"triggered": false,
			"spent": 0,
			"before": before,
			"after": before,
		}

	player.valak_life_essence = before - spend

	return {
		"triggered": true,
		"spent": spend,
		"before": before,
		"after": int(player.valak_life_essence),
	}


static func projection_available(
	player,
	opponent,
	rules: RuleConfig
) -> bool:
	return (
		enabled(rules)
		and player != null
		and opponent != null
		and String(player.lord) == "Valak"
		and bool(player.alive)
		and not bool(player.valak_projection_used_this_round)
		and int(player.valak_life_essence) > 0
		and (
			not opponent.lord_guards.is_empty()
			or not opponent.castle_guards.is_empty()
		)
	)


static func resolve_projection_window(
	game,
	rules: RuleConfig,
	player_order: Array,
	explicit_choices: Dictionary = {},
	random_source = null
) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var order: Array[int] = _normalized_order(
		game,
		player_order
	)

	for player_id: int in order:
		var player = game.get_player(
			player_id
		)
		var opponent = game.get_opponent(
			player_id
		)

		if not projection_available(
			player,
			opponent,
			rules
		):
			continue

		var has_explicit: bool = (
			explicit_choices.has(player_id)
			or explicit_choices.has(
				str(player_id)
			)
		)

		var decision: Dictionary = {}

		if has_explicit:
			var raw = explicit_choices.get(
				player_id,
				explicit_choices.get(
					str(player_id),
					{}
				)
			)
			if typeof(raw) == TYPE_DICTIONARY:
				decision = raw
		else:
			decision = bot_projection_decision(
				player,
				opponent,
				rules
			)

		if decision.is_empty():
			continue

		var event: Dictionary = resolve_projection(
			game,
			rules,
			player_id,
			decision,
			random_source
		)
		events.append(
			event
		)

	return events


static func resolve_projection(
	game,
	rules: RuleConfig,
	player_id: int,
	decision: Dictionary,
	random_source = null
) -> Dictionary:
	var player = game.get_player(
		player_id
	)
	var opponent = game.get_opponent(
		player_id
	)

	if not projection_available(
		player,
		opponent,
		rules
	):
		return _projection_event(
			player_id,
			false,
			false,
			"not_available"
		)

	if bool(
		decision.get(
			"pass",
			false
		)
	):
		return _projection_event(
			player_id,
			false,
			true,
			"passed"
		)

	var zone_name: String = String(
		decision.get(
			"zone",
			""
		)
	)
	var spend: int = int(
		decision.get(
			"spend",
			0
		)
	)

	if zone_name not in [
		ZONE_LORD,
		ZONE_CASTLE,
	]:
		return _projection_event(
			player_id,
			false,
			false,
			"invalid_zone"
		)

	var pool_before: int = int(
		player.valak_life_essence
	)

	if (
		spend < 1
		or spend > pool_before
	):
		return _projection_event(
			player_id,
			false,
			false,
			"invalid_spend"
		)

	var zone: Array = (
		opponent.lord_guards
		if zone_name == ZONE_LORD
		else opponent.castle_guards
	)

	if zone.is_empty():
		return _projection_event(
			player_id,
			false,
			false,
			"empty_zone"
		)

	# The spend is committed before hidden identities are consulted.
	player.valak_life_essence = pool_before - spend
	player.valak_projection_used_this_round = true

	var victim_index: int = -1
	var victim_value: int = -1

	for index: int in range(
		zone.size()
	):
		var guard = zone[
			index
		]
		var value: int = int(
			guard.value
		)

		if (
			value <= spend
			and value > victim_value
		):
			victim_index = index
			victim_value = value

	var event: Dictionary = {
		"player_id": player_id,
		"triggered": true,
		"passed": false,
		"reason": "",
		"zone": zone_name,
		"spend": spend,
		"pool_before": pool_before,
		"pool_after": int(
			player.valak_life_essence
		),
		"whiff": victim_index < 0,
		"victim": "",
		"victim_value": 0,
		"equality_kill": false,
		"gremory_trigger": {},
	}

	if victim_index < 0:
		game.refresh_derived_values()
		return event

	var victim = zone[
		victim_index
	]

	zone.remove_at(
		victim_index
	)

	game.discard.append(
		victim
	)

	event["victim"] = _card_id(
		victim
	)
	event["victim_value"] = victim_value
	event["equality_kill"] = (
		victim_value == spend
	)

	_mark_destruction(
		game
	)

	if (
		zone_name == ZONE_LORD
		and String(opponent.lord) == "Odradek"
	):
		opponent.odradek_guards_defeated += 1

	if zone_name == ZONE_LORD:
		event["gremory_trigger"] = (
			_trigger_gremory_lord_guard(
				game,
				rules,
				random_source
			)
		)

	# Projection intentionally never calls gain_from_guards(): no self-refund.
	game.refresh_derived_values()

	return event


static func bot_projection_decision(
	player,
	opponent,
	rules: RuleConfig
) -> Dictionary:
	if not projection_available(
		player,
		opponent,
		rules
	):
		return {}

	var pool: int = int(
		player.valak_life_essence
	)
	var candidates: Array[Dictionary] = []

	if (
		bool(opponent.alive)
		and not opponent.lord_guards.is_empty()
	):
		_add_bot_zone_candidates(
			candidates,
			ZONE_LORD,
			opponent.lord_guards,
			pool
		)

	if not opponent.castle_guards.is_empty():
		_add_bot_zone_candidates(
			candidates,
			ZONE_CASTLE,
			opponent.castle_guards,
			pool
		)

	if candidates.is_empty():
		return {}

	var best: Dictionary = candidates[
		0
	]

	for index: int in range(
		1,
		candidates.size()
	):
		var candidate: Dictionary = candidates[
			index
		]

		if _candidate_better(
			candidate,
			best
		):
			best = candidate

	return {
		"zone": String(
			best.get(
				"zone",
				""
			)
		),
		"spend": int(
			best.get(
				"spend",
				0
			)
		),
		"blind": bool(
			best.get(
				"blind",
				false
			)
		),
		"reason": String(
			best.get(
				"reason",
				""
			)
		),
	}


static func _add_bot_zone_candidates(
	candidates: Array[Dictionary],
	zone_name: String,
	cards: Array,
	pool: int
) -> void:
	var revealed_values: Array[int] = []
	var hidden_count: int = 0

	for guard in cards:
		if bool(
			guard.guard_revealed
		):
			revealed_values.append(
				int(
					guard.value
				)
			)
		else:
			hidden_count += 1

	var known_big: int = 0

	for value: int in revealed_values:
		if (
			value >= 4
			and value <= pool
			and value > known_big
		):
			known_big = value

	if known_big > 0:
		candidates.append({
			"priority": 3,
			"expected": float(
				known_big
			),
			"spend": known_big,
			"lord_tiebreak": (
				1
				if zone_name == ZONE_LORD
				else 0
			),
			"zone": zone_name,
			"blind": false,
			"reason": "known_%d" % known_big,
		})

	if (
		pool == CAP
		and revealed_values.has(
			3
		)
	):
		candidates.append({
			"priority": 2,
			"expected": 3.0,
			"spend": 3,
			"lord_tiebreak": (
				1
				if zone_name == ZONE_LORD
				else 0
			),
			"zone": zone_name,
			"blind": false,
			"reason": "cap3",
		})

	if (
		pool == CAP
		and hidden_count > 0
	):
		var expected: float = (
			_expected_highest_killable_public(
				cards,
				CAP
			)
		)

		if expected >= 4.0:
			candidates.append({
				"priority": 1,
				"expected": expected,
				"spend": CAP,
				"lord_tiebreak": (
					1
					if zone_name == ZONE_LORD
					else 0
				),
				"zone": zone_name,
				"blind": true,
				"reason": "blind5_ev4",
			})


static func _candidate_better(
	candidate: Dictionary,
	best: Dictionary
) -> bool:
	var candidate_priority: int = int(
		candidate.get(
			"priority",
			0
		)
	)
	var best_priority: int = int(
		best.get(
			"priority",
			0
		)
	)

	if candidate_priority != best_priority:
		return candidate_priority > best_priority

	var candidate_expected: float = float(
		candidate.get(
			"expected",
			0.0
		)
	)
	var best_expected: float = float(
		best.get(
			"expected",
			0.0
		)
	)

	if not is_equal_approx(
		candidate_expected,
		best_expected
	):
		return candidate_expected > best_expected

	var candidate_spend: int = int(
		candidate.get(
			"spend",
			0
		)
	)
	var best_spend: int = int(
		best.get(
			"spend",
			0
		)
	)

	if candidate_spend != best_spend:
		return candidate_spend < best_spend

	return int(
		candidate.get(
			"lord_tiebreak",
			0
		)
	) > int(
		best.get(
			"lord_tiebreak",
			0
		)
	)


static func _expected_highest_killable_public(
	cards: Array,
	spend: int
) -> float:
	var revealed: Array[int] = []
	var hidden_count: int = 0

	for guard in cards:
		if bool(
			guard.guard_revealed
		):
			revealed.append(
				int(
					guard.value
				)
			)
		else:
			hidden_count += 1

	var known_floor: int = 0

	for value: int in revealed:
		if (
			value <= spend
			and value > known_floor
		):
			known_floor = value

	if hidden_count <= 0:
		return float(
			known_floor
		)

	var total: float = 0.0

	for raw_count in CARD_DIST.values():
		total += float(
			raw_count
		)

	if total <= 0.0:
		return float(
			known_floor
		)

	var expected: float = float(
		known_floor
	)

	for threshold: int in range(
		known_floor + 1,
		spend + 1
	):
		var hits: float = 0.0

		for raw_value in CARD_DIST.keys():
			var value: int = int(
				raw_value
			)

			if (
				threshold <= value
				and value <= spend
			):
				hits += float(
					CARD_DIST[
						raw_value
					]
				)

		var p_one: float = (
			hits
			/ total
		)

		expected += (
			1.0
			- pow(
				1.0 - p_one,
				hidden_count
			)
		)

	return expected


static func _normalized_order(
	game,
	requested_order: Array
) -> Array[int]:
	var result: Array[int] = []

	for raw_player_id in requested_order:
		var player_id: int = int(
			raw_player_id
		)

		if (
			game.get_player(
				player_id
			) != null
			and not result.has(
				player_id
			)
		):
			result.append(
				player_id
			)

	for player in game.players:
		var player_id: int = int(
			player.pid
		)

		if not result.has(
			player_id
		):
			result.append(
				player_id
			)

	return result


static func _trigger_gremory_lord_guard(
	game,
	rules: RuleConfig,
	random_source
) -> Dictionary:
	for player in game.players:
		if (
			String(player.lord) != "Gremory"
			or not bool(player.alive)
			or bool(
				player.gremory_lord_guard_draw_done
			)
		):
			continue

		player.gremory_lord_guard_draw_done = true

		var draw_result: Dictionary = (
			DrawEngineData.draw_to_hand(
				game,
				player,
				rules,
				random_source,
				true
			)
		)

		var drawn_card = null

		if (
			bool(
				draw_result.get(
					"drawn",
					false
				)
			)
			and not player.hand.is_empty()
		):
			drawn_card = player.hand.back()

		var discarded_card = null

		if not player.hand.is_empty():
			var lowest_index: int = (
				_lowest_card_index(
					player.hand
				)
			)

			discarded_card = player.hand[
				lowest_index
			]

			player.hand.remove_at(
				lowest_index
			)

			game.discard.append(
				discarded_card
			)

		return {
			"triggered": true,
			"player_id": int(
				player.pid
			),
			"drawn_card": (
				""
				if drawn_card == null
				else _card_id(
					drawn_card
				)
			),
			"discarded_card": (
				""
				if discarded_card == null
				else _card_id(
					discarded_card
				)
			),
		}

	return {
		"triggered": false,
		"player_id": -1,
		"drawn_card": "",
		"discarded_card": "",
	}


static func _lowest_card_index(
	cards: Array
) -> int:
	var selected_index: int = 0
	var selected_value: int = int(
		cards[
			0
		].value
	)

	for index: int in range(
		1,
		cards.size()
	):
		var value: int = int(
			cards[
				index
			].value
		)

		if value < selected_value:
			selected_value = value
			selected_index = index

	return selected_index


static func _mark_destruction(
	game
) -> void:
	game.set_meta(
		"any_destruction_round",
		int(
			game.round
		)
	)


static func _card_id(
	card
) -> String:
	if card == null:
		return ""

	if card.has_method(
		"card_id"
	):
		return String(
			card.card_id()
		)

	return "%s:%d" % [
		String(
			card.suit
		),
		int(
			card.value
		),
	]


static func _projection_event(
	player_id: int,
	triggered: bool,
	passed: bool,
	reason: String
) -> Dictionary:
	return {
		"player_id": player_id,
		"triggered": triggered,
		"passed": passed,
		"reason": reason,
		"zone": "",
		"spend": 0,
		"pool_before": 0,
		"pool_after": 0,
		"whiff": false,
		"victim": "",
		"victim_value": 0,
		"equality_kill": false,
		"gremory_trigger": {},
	}
