class_name ActionForecast
extends RefCounted


const HuntResolutionEngineData = preload(
	"res://Scripts/Sim/HuntResolutionEngine.gd"
)
const SiegeResolutionEngineData = preload(
	"res://Scripts/Sim/SiegeResolutionEngine.gd"
)
const CastleIntegrityRulesData = preload(
	"res://Scripts/Sim/CastleIntegrityRules.gd"
)
const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)
const PythonRandomData = preload(
	"res://Scripts/Sim/PythonRandom.gd"
)


const MODEL_VERSION: String = "action-forecast-v1.1-monotonic-fastpath-doctrine-fast"
const MAX_OWN_HAND: int = 12

const VALUE_COUNTS: Dictionary = {
	1: 4,
	2: 4,
	3: 4,
	4: 3,
	5: 3,
}

const SUITS: Array[String] = [
	"Butcher",
	"Penitent",
	"Vulture",
	"Wright",
]


# DEFENSE_CULPABILITY_FORECAST_SIM_PROFILER_V1
static var _forecast_sim_perf_enabled: bool = false
static var _forecast_sim_perf_events: Array[Dictionary] = []


static func forecast_sim_perf_start() -> void:
	_forecast_sim_perf_events.clear()
	_forecast_sim_perf_enabled = true


static func forecast_sim_perf_stop() -> Array[Dictionary]:
	_forecast_sim_perf_enabled = false
	var out: Array[Dictionary] = []
	for row in _forecast_sim_perf_events:
		out.append(row.duplicate(true))
	_forecast_sim_perf_events.clear()
	return out


static func _forecast_sim_perf_record(row: Dictionary) -> void:
	if not _forecast_sim_perf_enabled:
		return
	_forecast_sim_perf_events.append(row)


static func forecast_all(
	game,
	rules: RuleConfig,
	attacker_id: int,
	doctrine_fast: bool = false
) -> Dictionary:
	var result: Dictionary = {
		"model_version": MODEL_VERSION,
		"hunt": forecast_hunt(
			game,
			rules,
			attacker_id,
			doctrine_fast
		),
		"siege_targets": {},
	}

	var defender = game.get_opponent(
		attacker_id
	)

	if defender == null:
		return result

	var siege_targets: Dictionary = {}

	for castle_value in defender.castles:
		var castle_name: String = String(
			castle_value
		)

		if not CastleIntegrityRulesData.standing(
			defender,
			castle_name
		):
			continue

		siege_targets[castle_name] = forecast_siege(
			game,
			rules,
			attacker_id,
			castle_name,
			doctrine_fast
		)

	result["siege_targets"] = siege_targets

	return result


static func forecast_hunt(
	game,
	rules: RuleConfig,
	attacker_id: int,
	doctrine_fast: bool = false
) -> Dictionary:
	var availability: Dictionary = _availability(
		game,
		rules,
		attacker_id
	)

	if not bool(
		availability.get(
			"available",
			false
		)
	):
		return availability

	var defender = game.get_opponent(
		attacker_id
	)

	if not defender.alive:
		return _unavailable(
			"Hunt",
			"target_banished"
		)

	var core: Dictionary = _forecast_action(
		game,
		rules,
		attacker_id,
		"Hunt",
		"",
		doctrine_fast
	)

	return {
		"available": true,
		"action": "Hunt",
		"model_version": MODEL_VERSION,
		"guard_model": "base_value_distribution",
		"ward_model": "public_hand_count_by_commit_depth",
		"public_depletion_conditioned": false,
		"hidden_guard_count": int(
			core.get(
				"hidden_guard_count",
				0
			)
		),
		"opponent_hand_count": int(
			core.get(
				"opponent_hand_count",
				0
			)
		),
		"pressure": _objective_report(
			float(
				core.get(
					"open_primary",
					0.0
				)
			),
			core.get(
				"ward_primary",
				{}
			)
		),
		"banish": _objective_report(
			float(
				core.get(
					"open_secondary",
					0.0
				)
			),
			core.get(
				"ward_secondary",
				{}
			)
		),
	}


static func forecast_siege(
	game,
	rules: RuleConfig,
	attacker_id: int,
	target_castle: String,
	doctrine_fast: bool = false
) -> Dictionary:
	var availability: Dictionary = _availability(
		game,
		rules,
		attacker_id
	)

	if not bool(
		availability.get(
			"available",
			false
		)
	):
		return availability

	var defender = game.get_opponent(
		attacker_id
	)

	if (
		target_castle.is_empty()
		or not CastleIntegrityRulesData.standing(
			defender,
			target_castle
		)
	):
		return _unavailable(
			"Siege",
			"target_castle_unavailable"
		)

	var core: Dictionary = _forecast_action(
		game,
		rules,
		attacker_id,
		"Siege",
		target_castle,
		doctrine_fast
	)

	return {
		"available": true,
		"action": "Siege",
		"target_castle": target_castle,
		"model_version": MODEL_VERSION,
		"guard_model": "base_value_distribution",
		"ward_model": "public_hand_count_by_commit_depth",
		"public_depletion_conditioned": false,
		"hidden_guard_count": int(
			core.get(
				"hidden_guard_count",
				0
			)
		),
		"opponent_hand_count": int(
			core.get(
				"opponent_hand_count",
				0
			)
		),
		"damage": _objective_report(
			float(
				core.get(
					"open_primary",
					0.0
				)
			),
			core.get(
				"ward_primary",
				{}
			)
		),
		"ruin": _objective_report(
			float(
				core.get(
					"open_secondary",
					0.0
				)
			),
			core.get(
				"ward_secondary",
				{}
			)
		),
	}


static func band(
	probability: float
) -> String:
	var value: float = clampf(
		probability,
		0.0,
		1.0
	)

	if value <= 0.0:
		return "IMPOSSIBLE"

	if value < 0.35:
		return "RISKY"

	if value < 0.70:
		return "FAVORABLE"

	return "STRONG"


static func _availability(
	game,
	rules: RuleConfig,
	attacker_id: int
) -> Dictionary:
	if game == null:
		return _unavailable(
			"",
			"game_missing"
		)

	if rules == null:
		return _unavailable(
			"",
			"rules_missing"
		)

	var attacker = game.get_player(
		attacker_id
	)

	var defender = game.get_opponent(
		attacker_id
	)

	if attacker == null:
		return _unavailable(
			"",
			"attacker_missing"
		)

	if defender == null:
		return _unavailable(
			"",
			"defender_missing"
		)

	if not attacker.alive:
		return _unavailable(
			"",
			"attacker_banished"
		)

	if attacker.hand.is_empty():
		return _unavailable(
			"",
			"hand_empty"
		)

	if attacker.hand.size() > MAX_OWN_HAND:
		return _unavailable(
			"",
			"hand_above_forecast_cap"
		)

	return {
		"available": true,
		"reason": "",
	}


static func _unavailable(
	action_name: String,
	reason: String
) -> Dictionary:
	return {
		"available": false,
		"action": action_name,
		"model_version": MODEL_VERSION,
		"reason": reason,
	}


static func _forecast_action(
	game,
	rules: RuleConfig,
	attacker_id: int,
	action_name: String,
	target_castle: String,
	doctrine_fast: bool = false
) -> Dictionary:
	var attacker = game.get_player(
		attacker_id
	)

	var defender = game.get_opponent(
		attacker_id
	)

	var source_guards: Array = (
		defender.lord_guards
		if action_name == "Hunt"
		else defender.castle_guards
	)

	var guard_scenarios: Array[Dictionary] = _guard_scenarios(
		source_guards,
		rules
	)

	var valak_barrier_cache_enabled: bool = (
		action_name == "Siege"
		and attacker != null
		and bool(attacker.alive)
		and String(attacker.lord) == "Valak"
		and source_guards.size() >= 2
		and _valak_guard_barrier_rules_safe(rules)
	)


	var opponent_hand_count: int = defender.hand.size()
	var ward_models: Dictionary = {}

	if (
		rules.ward_frontline
		and rules.ward_commit_defense
		and opponent_hand_count > 0
	):
		ward_models = _ward_models(
			defender,
			rules,
			opponent_hand_count
		)

	var ward_screens: Array[int] = _union_ward_screens(
		ward_models
	)

	var best_open_primary: float = 0.0
	var best_open_secondary: float = 0.0
	var best_ward_primary: Dictionary = {}
	var best_ward_secondary: Dictionary = {}

	for depth_value in ward_models.keys():
		var depth: int = int(depth_value)
		best_ward_primary[depth] = 0.0
		best_ward_secondary[depth] = 0.0

	# MONOTONIC WHOLE-HAND FAST PATH
	#
	# For ordinary defenders, Hunt/Siege reachability is monotonic with
	# commitment size: every additional committed Subject contributes
	# non-negative attack Strength, Butcher suit bonus cannot decrease, and
	# the combat layers only consume arriving Strength. Therefore the maximum
	# probability over EVERY non-empty subset is attained by the whole Hand.
	#
	# Odradek is deliberately excluded from this proof because Psychic
	# Recoil / Interlock can mutate the committed set before Strength is
	# measured. Keep the original exhaustive search there until that mechanic
	# gets its own exact reduced-state model.
	var mask_limit: int = 1 << attacker.hand.size()
	var full_hand_mask: int = mask_limit - 1
	var candidate_masks: Array[int] = []

	var odradek_non_monotonic: bool = (
		defender != null
		and bool(defender.alive)
		and String(defender.lord) == "Odradek"
	)

	# UI/default Forecast remains exact against Odradek. Bot doctrine
	# takes the whole-Hand fast path to keep AI turns bounded.
	if odradek_non_monotonic and not doctrine_fast:
		for candidate_mask: int in range(1, mask_limit):
			candidate_masks.append(candidate_mask)
	else:
		candidate_masks.append(full_hand_mask)

	for mask: int in candidate_masks:
		var open_primary: float = 0.0
		var open_secondary: float = 0.0
		var ward_primary: Dictionary = {}
		var ward_secondary: Dictionary = {}

		for depth_value in ward_models.keys():
			var depth: int = int(depth_value)
			ward_primary[depth] = 0.0
			ward_secondary[depth] = 0.0

		var valak_barrier_caches: Dictionary = {}

		for guard_scenario: Dictionary in guard_scenarios:
			var guard_probability: float = float(
				guard_scenario.get(
					"probability",
					0.0
				)
			)

			if guard_probability <= 0.0:
				continue

			var cache: Dictionary = {}

			if valak_barrier_cache_enabled:
				var barrier_key: String = (
					_valak_guard_barrier_cache_key(
						source_guards,
						guard_scenario,
						rules
					)
				)

				if not barrier_key.is_empty():
					if not valak_barrier_caches.has(
						barrier_key
					):
						valak_barrier_caches[barrier_key] = {}

					cache = valak_barrier_caches[
						barrier_key
					]
			var open_outcomes: Dictionary = _cached_outcomes(
				cache,
				0,
				game,
				rules,
				attacker_id,
				action_name,
				target_castle,
				mask,
				source_guards,
				guard_scenario
			)

			var primary_open_success: bool = bool(
				open_outcomes.get(
					"primary",
					false
				)
			)
			var secondary_open_success: bool = bool(
				open_outcomes.get(
					"secondary",
					false
				)
			)

			if primary_open_success:
				open_primary += guard_probability
			if secondary_open_success:
				open_secondary += guard_probability

			if ward_models.is_empty():
				continue

			var primary_threshold: int = -1
			var secondary_threshold: int = -1

			if primary_open_success:
				primary_threshold = _max_successful_ward_screen(
					"primary",
					ward_screens,
					cache,
					game,
					rules,
					attacker_id,
					action_name,
					target_castle,
					mask,
					source_guards,
					guard_scenario
				)

			if secondary_open_success:
				secondary_threshold = _max_successful_ward_screen(
					"secondary",
					ward_screens,
					cache,
					game,
					rules,
					attacker_id,
					action_name,
					target_castle,
					mask,
					source_guards,
					guard_scenario
				)

			for depth_value in ward_models.keys():
				var depth: int = int(depth_value)
				var ward_model: Dictionary = ward_models.get(depth, {})

				ward_primary[depth] = (
					float(ward_primary.get(depth, 0.0))
					+ guard_probability
					* _ward_probability_at_most(
						ward_model,
						primary_threshold
					)
				)

				ward_secondary[depth] = (
					float(ward_secondary.get(depth, 0.0))
					+ guard_probability
					* _ward_probability_at_most(
						ward_model,
						secondary_threshold
					)
				)

		best_open_primary = maxf(
			best_open_primary,
			open_primary
		)
		best_open_secondary = maxf(
			best_open_secondary,
			open_secondary
		)

		for depth_value in ward_models.keys():
			var depth: int = int(depth_value)
			best_ward_primary[depth] = maxf(
				float(best_ward_primary.get(depth, 0.0)),
				float(ward_primary.get(depth, 0.0))
			)
			best_ward_secondary[depth] = maxf(
				float(best_ward_secondary.get(depth, 0.0)),
				float(ward_secondary.get(depth, 0.0))
			)

	return {
		"open_primary": clampf(best_open_primary, 0.0, 1.0),
		"open_secondary": clampf(best_open_secondary, 0.0, 1.0),
		"ward_primary": best_ward_primary,
		"ward_secondary": best_ward_secondary,
		"hidden_guard_count": _hidden_guard_count(
			source_guards,
			rules
		),
		"opponent_hand_count": opponent_hand_count,
	}


static func _cached_outcomes(
	cache: Dictionary,
	ward_screen: int,
	game,
	rules: RuleConfig,
	attacker_id: int,
	action_name: String,
	target_castle: String,
	mask: int,
	source_guards: Array,
	guard_scenario: Dictionary
) -> Dictionary:
	if cache.has(ward_screen):
		return cache[ward_screen]

	var outcomes: Dictionary = _simulate_outcomes(
		game,
		rules,
		attacker_id,
		action_name,
		target_castle,
		mask,
		source_guards,
		guard_scenario,
		ward_screen
	)

	cache[ward_screen] = outcomes
	return outcomes


static func _max_successful_ward_screen(
	objective_key: String,
	ward_screens: Array[int],
	cache: Dictionary,
	game,
	rules: RuleConfig,
	attacker_id: int,
	action_name: String,
	target_castle: String,
	mask: int,
	source_guards: Array,
	guard_scenario: Dictionary
) -> int:
	if ward_screens.is_empty():
		return 0

	var low: int = 0
	var high: int = ward_screens.size() - 1
	var best: int = 0

	while low <= high:
		var middle: int = int((low + high) / 2)
		var screen: int = int(ward_screens[middle])
		var outcomes: Dictionary = _cached_outcomes(
			cache,
			screen,
			game,
			rules,
			attacker_id,
			action_name,
			target_castle,
			mask,
			source_guards,
			guard_scenario
		)

		if bool(outcomes.get(objective_key, false)):
			best = screen
			low = middle + 1
		else:
			high = middle - 1

	return best


# DEFENSE_CULPABILITY_FORECAST_SETUP_PROFILER_V1
# DEFENSE_CULPABILITY_FORECAST_RNG_PROFILER_V1
static func _simulate_outcomes(
	game,
	rules: RuleConfig,
	attacker_id: int,
	action_name: String,
	target_castle: String,
	mask: int,
	source_guards: Array,
	guard_scenario: Dictionary,
	ward_screen: int
) -> Dictionary:
	var perf_enabled: bool = _forecast_sim_perf_enabled
	var total_started_us: int = Time.get_ticks_usec() if perf_enabled else 0

	var clone_started_us: int = Time.get_ticks_usec() if perf_enabled else 0
	# FORECAST_SHALLOW_CLONE_V1
	var clone = game.duplicate_state(true)
	var clone_us: int = Time.get_ticks_usec() - clone_started_us if perf_enabled else 0

	var rng_started_us: int = Time.get_ticks_usec() if perf_enabled else 0
	var forecast_rng = PythonRandomData.forecast_seed_zero_fast()
	var rng_init_us: int = Time.get_ticks_usec() - rng_started_us if perf_enabled else 0

	var meta_started_us: int = Time.get_ticks_usec() if perf_enabled else 0
	clone.set_meta(
		"_resolution_random_source",
		forecast_rng
	)
	var meta_us: int = Time.get_ticks_usec() - meta_started_us if perf_enabled else 0

	var lookup_started_us: int = Time.get_ticks_usec() if perf_enabled else 0
	var attacker = clone.get_player(attacker_id)
	var defender = clone.get_opponent(attacker_id)
	var lookup_us: int = Time.get_ticks_usec() - lookup_started_us if perf_enabled else 0

	if attacker == null or defender == null:
		if perf_enabled:
			_forecast_sim_perf_record({
				"action": action_name,
				"target_castle": target_castle,
				"ward_screen": ward_screen,
				"hidden_guard_count": int(guard_scenario.get("hidden_values", []).size()),
				"source_guard_count": source_guards.size(),
				"attacker_lord": "",
				"defender_lord": "",
				"clone_us": clone_us,
				"rng_init_us": rng_init_us,
				"meta_us": meta_us,
				"lookup_us": lookup_us,
				"seal_us": 0,
				"sanitize_us": 0,
				"guard_apply_us": 0,
				"action_setup_us": 0,
				"ward_setup_us": 0,
				"before_snapshot_us": 0,
				"setup_us": 0,
				"resolve_us": 0,
				"outcome_us": 0,
				"elapsed_us": Time.get_ticks_usec() - total_started_us,
				"invalid": true,
			})
		return {
			"primary": false,
			"secondary": false,
		}

	var setup_started_us: int = Time.get_ticks_usec() if perf_enabled else 0

	var step_started_us: int = Time.get_ticks_usec() if perf_enabled else 0
	_seal_commitment(attacker, mask)
	var seal_us: int = Time.get_ticks_usec() - step_started_us if perf_enabled else 0

	step_started_us = Time.get_ticks_usec() if perf_enabled else 0
	_sanitize_hidden_resources(defender)
	var sanitize_us: int = Time.get_ticks_usec() - step_started_us if perf_enabled else 0

	step_started_us = Time.get_ticks_usec() if perf_enabled else 0
	_apply_guard_scenario(
		defender,
		action_name,
		source_guards,
		guard_scenario,
		rules
	)
	var guard_apply_us: int = Time.get_ticks_usec() - step_started_us if perf_enabled else 0

	step_started_us = Time.get_ticks_usec() if perf_enabled else 0
	attacker.action = action_name
	attacker.tgt_pid = int(defender.pid)
	attacker.tgt_type = "Lord" if action_name == "Hunt" else "Castle"

	defender.action = ""
	defender.ward_target = ""
	defender.committed.clear()
	defender.ward_turned.clear()
	var action_setup_us: int = Time.get_ticks_usec() - step_started_us if perf_enabled else 0

	step_started_us = Time.get_ticks_usec() if perf_enabled else 0
	if ward_screen > 0:
		defender.action = "Ward"
		defender.ward_target = "Lord" if action_name == "Hunt" else "Castle"

		var static_bonus: int = _ward_static_bonus(defender, rules)
		var card_effective_value: int = maxi(1, ward_screen - static_bonus)

		defender.committed.append(
			_synthetic_ward_card(
				defender,
				rules,
				card_effective_value
			)
		)
	var ward_setup_us: int = Time.get_ticks_usec() - step_started_us if perf_enabled else 0

	step_started_us = Time.get_ticks_usec() if perf_enabled else 0
	var before: Dictionary = _combat_snapshot(defender)
	var before_snapshot_us: int = Time.get_ticks_usec() - step_started_us if perf_enabled else 0

	var setup_us: int = Time.get_ticks_usec() - setup_started_us if perf_enabled else 0

	var resolve_started_us: int = Time.get_ticks_usec() if perf_enabled else 0
	var resolution: Dictionary = {}

	if action_name == "Hunt":
		resolution = HuntResolutionEngineData.resolve(
			clone,
			rules,
			attacker_id
		)
	else:
		resolution = SiegeResolutionEngineData.resolve(
			clone,
			rules,
			attacker_id,
			{
				"target_castle": target_castle,
				"consume_siege": false,
				"use_inferno": false,
			}
		)

	var resolve_us: int = Time.get_ticks_usec() - resolve_started_us if perf_enabled else 0

	var outcome_started_us: int = Time.get_ticks_usec() if perf_enabled else 0
	var after: Dictionary = _combat_snapshot(defender)

	var result: Dictionary = _outcomes_from_resolution(
		action_name,
		resolution,
		before,
		after
	)

	if perf_enabled:
		var outcome_us: int = Time.get_ticks_usec() - outcome_started_us
		_forecast_sim_perf_record({
			"round": int(game.round),
			"action": action_name,
			"target_castle": target_castle,
			"ward_screen": ward_screen,
			"hidden_guard_count": int(guard_scenario.get("hidden_values", []).size()),
			"source_guard_count": source_guards.size(),
			"attacker_lord": String(attacker.lord),
			"defender_lord": String(defender.lord),
			"clone_us": clone_us,
			"rng_init_us": rng_init_us,
			"meta_us": meta_us,
			"lookup_us": lookup_us,
			"seal_us": seal_us,
			"sanitize_us": sanitize_us,
			"guard_apply_us": guard_apply_us,
			"action_setup_us": action_setup_us,
			"ward_setup_us": ward_setup_us,
			"before_snapshot_us": before_snapshot_us,
			"setup_us": setup_us,
			"resolve_us": resolve_us,
			"outcome_us": outcome_us,
			"elapsed_us": Time.get_ticks_usec() - total_started_us,
			"invalid": false,
		})

	return result


static func _seal_commitment(
	attacker,
	mask: int
) -> void:
	var available: Array = attacker.hand.duplicate()
	var remaining_hand: Array = []

	attacker.committed.clear()

	for index: int in range(available.size()):
		var card = available[index]

		if (mask & (1 << index)) != 0:
			attacker.committed.append(card)
		else:
			remaining_hand.append(card)

	attacker.hand = remaining_hand


static func _sanitize_hidden_resources(
	defender
) -> void:
	var hand_count: int = defender.hand.size()
	var garrison_count: int = defender.garrison.size()

	defender.hand.clear()
	defender.garrison.clear()

	for _hand_index: int in range(hand_count):
		defender.hand.append(
			CardData.new(
				"Wright",
				1
			)
		)

	for _garrison_index: int in range(garrison_count):
		defender.garrison.append(
			CardData.new(
				"Wright",
				1
			)
		)


static func _apply_guard_scenario(
	defender,
	action_name: String,
	source_guards: Array,
	guard_scenario: Dictionary,
	rules: RuleConfig
) -> void:
	var rebuilt: Array = []
	var hidden_values: Array = guard_scenario.get(
		"hidden_values",
		[]
	)
	var hidden_index: int = 0

	for source_card in source_guards:
		var hidden: bool = (
			rules.fog_of_war
			and not bool(source_card.guard_revealed)
		)

		if hidden:
			var hidden_value: int = int(
				hidden_values[hidden_index]
			)
			hidden_index += 1

			var replacement = CardData.new(
				"Wright",
				hidden_value
			)
			replacement.guard_revealed = false
			rebuilt.append(replacement)
		else:
			rebuilt.append(
				source_card.duplicate_card()
			)

	if action_name == "Hunt":
		defender.lord_guards = rebuilt
	else:
		defender.castle_guards = rebuilt


static func _combat_snapshot(
	defender
) -> Dictionary:
	return {
		"alive": bool(defender.alive),
		"lord_guard_count": defender.lord_guards.size(),
		"castle_guard_count": defender.castle_guards.size(),
		"lord_sigil": String(
			defender.sigils.get(
				"Lord",
				""
			)
		),
		"castle_sigil": String(
			defender.sigils.get(
				"Castle",
				""
			)
		),
		"castle_integrity": defender.castle_integrity.duplicate(true),
		"castles": defender.castles.duplicate(),
		"ruined_castles": defender.ruined_castles.duplicate(),
		"lost_castles": defender.lost_castles.duplicate(),
	}


static func _outcomes_from_resolution(
	action_name: String,
	resolution: Dictionary,
	before: Dictionary,
	after: Dictionary
) -> Dictionary:
	if action_name == "Hunt":
		var banished: bool = (
			bool(resolution.get("banished", false))
			or (
				bool(before.get("alive", false))
				and not bool(after.get("alive", true))
			)
		)

		var pressure: bool = banished

		if not pressure:
			pressure = (
				int(after.get("lord_guard_count", 0))
				< int(before.get("lord_guard_count", 0))
			)

		if not pressure:
			pressure = bool(
				resolution.get(
					"sigil_broken",
					false
				)
			)

		if not pressure:
			var before_integrity: Dictionary = before.get(
				"castle_integrity",
				{}
			)
			var after_integrity: Dictionary = after.get(
				"castle_integrity",
				{}
			)
			var keep_before: int = int(
				before_integrity.get(
					"Keep",
					0
				)
			)
			var keep_after: int = int(
				after_integrity.get(
					"Keep",
					keep_before
				)
			)
			pressure = keep_after < keep_before

		return {
			"primary": pressure,
			"secondary": banished,
		}

	var ruined: bool = bool(
		resolution.get(
			"destroyed",
			false
		)
	)

	if not ruined:
		ruined = _new_ruination(
			before,
			after
		)

	var damaged: bool = ruined

	if not damaged:
		damaged = _integrity_decreased(
			before,
			after
		)

	return {
		"primary": damaged,
		"secondary": ruined,
	}


static func _integrity_decreased(
	before: Dictionary,
	after: Dictionary
) -> bool:
	var before_integrity: Dictionary = before.get(
		"castle_integrity",
		{}
	)
	var after_integrity: Dictionary = after.get(
		"castle_integrity",
		{}
	)

	for castle_value in before_integrity.keys():
		var castle_name: String = String(castle_value)
		var before_value: int = int(
			before_integrity.get(
				castle_name,
				0
			)
		)
		var after_value: int = int(
			after_integrity.get(
				castle_name,
				before_value
			)
		)

		if after_value < before_value:
			return true

	return false


static func _new_ruination(
	before: Dictionary,
	after: Dictionary
) -> bool:
	var before_ruined: Array = before.get(
		"ruined_castles",
		[]
	)
	var after_ruined: Array = after.get(
		"ruined_castles",
		[]
	)

	if after_ruined.size() > before_ruined.size():
		return true

	var before_lost: Array = before.get(
		"lost_castles",
		[]
	)
	var after_lost: Array = after.get(
		"lost_castles",
		[]
	)

	return after_lost.size() > before_lost.size()


# VALAK_GUARD_BARRIER_CACHE_V1
#
# Valak-Siege-only exact forecast cache reuse.
#
# Crushing Presence makes the lowest defending Guard contribute zero Defense
# whenever Valak attacks a pool containing 2+ Guards. Under the current locked
# Guard rules (off-suit penalty = 0), Siege reachability depends on the Guard
# pool through sum(values) - lowest(values).
#
# We do NOT merge/reorder scenarios or probabilities. Equivalent scenarios only
# share their _cached_outcomes() dictionary, preserving the caller's original
# probability accumulation order.
static func _valak_guard_barrier_rules_safe(
	rules: RuleConfig
) -> bool:
	# Current Godot RuleConfig has no Guard off-suit penalty property.
	# If a future RuleConfig adds one, disable this optimization unless
	# that property is explicitly zero.
	for raw_property in rules.get_property_list():
		if typeof(raw_property) != TYPE_DICTIONARY:
			continue

		var property: Dictionary = raw_property
		if String(
			property.get("name", "")
		) != "guard_offsuit_penalty":
			continue

		return int(
			rules.get("guard_offsuit_penalty")
		) == 0

	return true


static func _valak_guard_barrier_cache_key(
	source_guards: Array,
	guard_scenario: Dictionary,
	rules: RuleConfig
) -> String:
	if source_guards.size() < 2:
		return ""

	if not _valak_guard_barrier_rules_safe(rules):
		return ""

	var hidden_values: Array = guard_scenario.get(
		"hidden_values",
		[]
	)
	var hidden_index: int = 0
	var total_value: int = 0
	var lowest_value: int = 999999

	for source_card in source_guards:
		var value: int = 0
		var hidden: bool = (
			rules.fog_of_war
			and not bool(source_card.guard_revealed)
		)

		if hidden:
			if hidden_index >= hidden_values.size():
				return ""
			value = int(hidden_values[hidden_index])
			hidden_index += 1
		else:
			value = int(source_card.value)

		total_value += value
		lowest_value = mini(lowest_value, value)

	if hidden_index != hidden_values.size():
		return ""

	return "b%d" % (total_value - lowest_value)

static func _guard_scenarios(
	guards: Array,
	rules: RuleConfig
) -> Array[Dictionary]:
	var hidden_count: int = _hidden_guard_count(
		guards,
		rules
	)

	if hidden_count <= 0:
		return [
			{
				"hidden_values": [],
				"probability": 1.0,
			},
		]

	var states: Dictionary = {
		"": {
			"values": [],
			"probability": 1.0,
		},
	}

	for _hidden_slot: int in range(hidden_count):
		var next_states: Dictionary = {}

		for state_value in states.values():
			var state: Dictionary = state_value
			var values: Array = state.get(
				"values",
				[]
			)
			var state_probability: float = float(
				state.get(
					"probability",
					0.0
				)
			)

			for card_value in VALUE_COUNTS.keys():
				var value: int = int(card_value)
				var next_values: Array = values.duplicate()
				next_values.append(value)
				next_values.sort()

				var key: String = _int_array_key(next_values)
				var probability: float = (
					state_probability
					* float(VALUE_COUNTS.get(value, 0))
					/ 18.0
				)

				if next_states.has(key):
					var existing: Dictionary = next_states[key]
					existing["probability"] = (
						float(existing.get("probability", 0.0))
						+ probability
					)
					next_states[key] = existing
				else:
					next_states[key] = {
						"values": next_values,
						"probability": probability,
					}

		states = next_states

	var result: Array[Dictionary] = []

	for state_value in states.values():
		var state: Dictionary = state_value
		result.append({
			"hidden_values": state.get("values", []),
			"probability": float(
				state.get(
					"probability",
					0.0
				)
			),
		})

	return result


static func _hidden_guard_count(
	guards: Array,
	rules: RuleConfig
) -> int:
	if not rules.fog_of_war:
		return 0

	var count: int = 0

	for card in guards:
		if not bool(card.guard_revealed):
			count += 1

	return count


static func _ward_models(
	defender,
	rules: RuleConfig,
	hand_count: int
) -> Dictionary:
	var categories: Array[Dictionary] = _ward_categories(
		defender,
		rules
	)

	var states: Dictionary = {
		"0|0": {
			"effective_sum": 0,
			"penitent_count": 0,
			"probability": 1.0,
		},
	}

	var result: Dictionary = {}

	for depth: int in range(1, hand_count + 1):
		var next_states: Dictionary = {}

		for state_value in states.values():
			var state: Dictionary = state_value

			for category: Dictionary in categories:
				var effective_sum: int = (
					int(state.get("effective_sum", 0))
					+ int(category.get("effective_value", 0))
				)
				var penitent_count: int = (
					int(state.get("penitent_count", 0))
					+ int(category.get("penitent", 0))
				)
				var key: String = "%d|%d" % [
					effective_sum,
					penitent_count,
				]
				var probability: float = (
					float(state.get("probability", 0.0))
					* float(category.get("probability", 0.0))
				)

				if next_states.has(key):
					var existing: Dictionary = next_states[key]
					existing["probability"] = (
						float(existing.get("probability", 0.0))
						+ probability
					)
					next_states[key] = existing
				else:
					next_states[key] = {
						"effective_sum": effective_sum,
						"penitent_count": penitent_count,
						"probability": probability,
					}

		states = next_states
		var screen_probabilities: Dictionary = {}

		for state_value in states.values():
			var state: Dictionary = state_value
			var screen: int = int(
				state.get(
					"effective_sum",
					0
				)
			)

			if int(state.get("penitent_count", 0)) >= 2:
				screen += 1

			screen += _ward_static_bonus(
				defender,
				rules
			)

			screen_probabilities[screen] = (
				float(screen_probabilities.get(screen, 0.0))
				+ float(state.get("probability", 0.0))
			)

		result[depth] = _finalize_ward_distribution(
			screen_probabilities
		)

	return result


static func _ward_categories(
	defender,
	rules: RuleConfig
) -> Array[Dictionary]:
	var aggregated: Dictionary = {}

	for suit_name: String in SUITS:
		for card_value in VALUE_COUNTS.keys():
			var printed_value: int = int(card_value)
			var probe = CardData.new(
				suit_name,
				printed_value
			)
			var effective_value: int = int(
				defender.ward_card_value(
					probe,
					rules
				)
			)
			var penitent: int = 1 if suit_name == "Penitent" else 0
			var key: String = "%d|%d" % [
				effective_value,
				penitent,
			]
			var probability: float = (
				float(VALUE_COUNTS.get(printed_value, 0))
				/ 72.0
			)

			if aggregated.has(key):
				var existing: Dictionary = aggregated[key]
				existing["probability"] = (
					float(existing.get("probability", 0.0))
					+ probability
				)
				aggregated[key] = existing
			else:
				aggregated[key] = {
					"effective_value": effective_value,
					"penitent": penitent,
					"probability": probability,
				}

	var result: Array[Dictionary] = []

	for category_value in aggregated.values():
		result.append(category_value)

	return result


static func _ward_static_bonus(
	defender,
	rules: RuleConfig
) -> int:
	if (
		not rules.humbaba_sigil_commit
		or defender.lord != "Humbaba"
		or not defender.alive
	):
		return 0

	var bonus: int = 2

	if CastleIntegrityRulesData.power_active(
		defender,
		"Keep",
		rules
	):
		bonus += 1

	return bonus


static func _synthetic_ward_card(
	defender,
	rules: RuleConfig,
	effective_value: int
):
	var suit_name: String = String(
		rules.ward_penalty_exempt_suit
	)

	if suit_name.is_empty():
		suit_name = "Penitent"

	var printed_value: int = maxi(
		1,
		effective_value
	)
	var probe = CardData.new(
		suit_name,
		printed_value
	)
	var actual_effective: int = int(
		defender.ward_card_value(
			probe,
			rules
		)
	)

	if actual_effective < effective_value:
		printed_value += effective_value - actual_effective

	return CardData.new(
		suit_name,
		printed_value
	)


static func _finalize_ward_distribution(
	screen_probabilities: Dictionary
) -> Dictionary:
	var screens: Array[int] = []

	for screen_value in screen_probabilities.keys():
		screens.append(int(screen_value))

	screens.sort()

	var cumulative: Array[float] = []
	var running: float = 0.0

	for screen: int in screens:
		running += float(
			screen_probabilities.get(
				screen,
				0.0
			)
		)
		cumulative.append(running)

	return {
		"screens": screens,
		"cumulative": cumulative,
	}


static func _ward_probability_at_most(
	model: Dictionary,
	threshold: int
) -> float:
	if threshold < 0:
		return 0.0

	var screens: Array = model.get(
		"screens",
		[]
	)
	var cumulative: Array = model.get(
		"cumulative",
		[]
	)

	if screens.is_empty():
		return 0.0

	var low: int = 0
	var high: int = screens.size() - 1
	var best_index: int = -1

	while low <= high:
		var middle: int = int((low + high) / 2)

		if int(screens[middle]) <= threshold:
			best_index = middle
			low = middle + 1
		else:
			high = middle - 1

	if best_index < 0:
		return 0.0

	return clampf(
		float(cumulative[best_index]),
		0.0,
		1.0
	)


static func _union_ward_screens(
	ward_models: Dictionary
) -> Array[int]:
	var seen: Dictionary = {}

	for model_value in ward_models.values():
		var model: Dictionary = model_value

		for screen_value in model.get("screens", []):
			seen[int(screen_value)] = true

	var result: Array[int] = []

	for screen_value in seen.keys():
		result.append(int(screen_value))

	result.sort()
	return result


static func _objective_report(
	open_probability: float,
	warded_by_depth: Dictionary
) -> Dictionary:
	var warded: Dictionary = {}
	var minimum: float = 1.0
	var maximum: float = 0.0
	var have_warded: bool = false
	var depths: Array[int] = []

	for depth_value in warded_by_depth.keys():
		depths.append(int(depth_value))

	depths.sort()

	for depth: int in depths:
		var probability: float = clampf(
			float(warded_by_depth.get(depth, 0.0)),
			0.0,
			1.0
		)

		warded[str(depth)] = {
			"probability": probability,
			"band": band(probability),
		}

		minimum = minf(
			minimum,
			probability
		)
		maximum = maxf(
			maximum,
			probability
		)
		have_warded = true

	var warded_range: Dictionary = {
		"available": have_warded,
	}

	if have_warded:
		warded_range["min_probability"] = minimum
		warded_range["max_probability"] = maximum
		warded_range["min_band"] = band(minimum)
		warded_range["max_band"] = band(maximum)

	var clean_open: float = clampf(
		open_probability,
		0.0,
		1.0
	)

	return {
		"open": {
			"probability": clean_open,
			"band": band(clean_open),
		},
		"warded_by_cards": warded,
		"warded_range": warded_range,
	}


static func _int_array_key(
	values: Array
) -> String:
	var parts: Array[String] = []

	for value in values:
		parts.append(
			str(int(value))
		)

	return ",".join(parts)
