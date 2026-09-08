class_name BotRoundEngine
extends RefCounted


const LordMathData = preload(
	"res://Scripts/Sim/LordMath.gd"
)

const RoundEngineData = preload(
	"res://Scripts/Sim/RoundEngine.gd"
)

# SIEGE_ENGINE_BOMBARDMENT_V1
const SiegeEngineFireEngineData = preload(
	"res://Scripts/Sim/SiegeEngineFireEngine.gd"
)

const DrawEngineData = preload(
	"res://Scripts/Sim/DrawEngine.gd"
)

const DevelopmentStartEngineData = preload(
	"res://Scripts/Sim/DevelopmentStartEngine.gd"
)

const DominionRiteEngineData = preload(
	"res://Scripts/Sim/DominionRiteEngine.gd"
)

const DeployEngineData = preload(
	"res://Scripts/Sim/DeployEngine.gd"
)

const SummonEngineData = preload(
	"res://Scripts/Sim/SummonEngine.gd"
)

const ReflexBidEngineData = preload(
	"res://Scripts/Sim/ReflexBidEngine.gd"
)

const CommitmentEngineData = preload(
	"res://Scripts/Sim/CommitmentEngine.gd"
)

const RevealEngineData = preload(
	"res://Scripts/Sim/RevealEngine.gd"
)

const ResolutionEngineData = preload(
	"res://Scripts/Sim/ResolutionEngine.gd"
)

const BotDoctrineData = preload(
	"res://Scripts/Sim/BotDoctrine.gd"
)

const BotPolicyData = preload(
	"res://Scripts/Sim/BotPolicy.gd"
)

const BotDevelopmentDoctrineData = preload(
	"res://Scripts/Sim/BotDevelopmentDoctrine.gd"
)

const BotDominionRiteDoctrineData = preload(
	"res://Scripts/Sim/BotDominionRiteDoctrine.gd"
)

const BotDeployDoctrineData = preload(
	"res://Scripts/Sim/BotDeployDoctrine.gd"
)

const BotMarchingDoctrineData = preload(
	"res://Scripts/Sim/BotMarchingDoctrine.gd"
)

const MarchingEngineData = preload(
	"res://Scripts/Sim/MarchingEngine.gd"
)

const VacantThroneEngineData = preload(
	"res://Scripts/Sim/VacantThroneEngine.gd"
)

const BotResolutionDoctrineData = preload(
	"res://Scripts/Sim/BotResolutionDoctrine.gd"
)


const BASE_DRAW_COUNT: int = 5
const STOCKPILE_DRAW_BONUS: int = 1

const SIGIL_ZONES: Array[String] = [
	"Lord",
	"Castle",
]


# DEFENSE_CULPABILITY_PHASE_PROFILER_V1
static var _culpability_phase_profile_enabled: bool = false
static var _culpability_phase_profile_events: Array[Dictionary] = []


static func culpability_phase_profile_start() -> void:
	_culpability_phase_profile_events.clear()
	_culpability_phase_profile_enabled = true


static func culpability_phase_profile_stop() -> Array[Dictionary]:
	_culpability_phase_profile_enabled = false
	var out: Array[Dictionary] = []
	for row in _culpability_phase_profile_events:
		out.append(row.duplicate(true))
	return out


static func _culpability_profile_now() -> int:
	return Time.get_ticks_usec()


static func _culpability_profile_mark(
	label: String,
	started_us: int,
	game
) -> void:
	if not _culpability_phase_profile_enabled:
		return

	_culpability_phase_profile_events.append({
		"round": int(game.round),
		"phase": label,
		"elapsed_us": (
			Time.get_ticks_usec()
			- started_us
		),
	})


static func resolve_round(
	game,
	rules: RuleConfig,
	random_source,
	round_number: int = -1,
	policy = null
) -> Dictionary:
	assert(
		game != null,
		"BotRoundEngine requires a GameState."
	)

	assert(
		rules != null,
		"BotRoundEngine requires RuleConfig."
	)

	assert(
		random_source != null,
		"BotRoundEngine requires a deterministic random source."
	)

	if int(
		game.winner
	) >= 0:
		return {
			"action": "round",
			"reason": "game_already_terminal",
			"round": int(
				game.round
			),
			"completed": false,
			"terminal": true,
			"stopped_phase": "pre_round",
			"winner": int(
				game.winner
			),
			"win_by": String(
				game.win_by
			),
			"phases": {},
			"events": [],
		}

	var effective_round: int = round_number

	if effective_round <= 0:
		effective_round = int(
			game.round
		) + 1

	assert(
		effective_round >= 1,
		"Bot round number must be at least one."
	)

	var effective_policy = _policy_or_default(
		policy
	)

	var phase_results: Dictionary = {}
	var events: Array[Dictionary] = []

	RoundEngineData.begin_round(
		game,
		effective_round
	)

	phase_results["begin_round"] = {
		"round": effective_round,
	}

	_append_event(
		events,
		game,
		"begin_round",
		phase_results["begin_round"]
	)

	# BATTLEFIELD_CLOCK_V1 — autonomous first half at round opening.
	# Gate this entirely so marching-disabled canonical traces remain unchanged.
	if rules.marching:
		var march_regen_result: Dictionary = (
			MarchingEngineData.regenerate_at_round_start(game, rules)
		)
		phase_results["march_regen"] = march_regen_result
		_append_event(events, game, "march_regen", march_regen_result)

		var march_first_half_result: Dictionary = (
			MarchingEngineData.resolve_half(
				game,
				rules,
				random_source,
				"first"
			)
		)
		phase_results["march_first_half"] = march_first_half_result
		_append_event(events, game, "march_first_half", march_first_half_result)

		if bool(march_first_half_result.get("terminal", false)):
			return _finish_round(
				game,
				phase_results,
				events,
				false,
				"march_first_half"
			)

	var sigil_result: Dictionary = (
		_update_sigils(
			game,
			rules
		)
	)

	phase_results["sigil_update"] = sigil_result

	_append_event(
		events,
		game,
		"sigil_update",
		sigil_result
	)

	var veil_result: Dictionary = (
		_apply_veil_drift(
			game,
			rules
		)
	)

	phase_results["veil_drift"] = veil_result

	_append_event(
		events,
		game,
		"veil_drift",
		veil_result
	)

	if int(
		game.winner
	) >= 0:
		return _finish_round(
			game,
			phase_results,
			events,
			false,
			"veil_drift"
		)

	var _culp_prof_development_start_us: int = _culpability_profile_now()
	var development_start_result: Dictionary = (
		DevelopmentStartEngineData.resolve(
			game,
			rules,
			random_source
		)
	)
	_culpability_profile_mark(
		"development_start",
		_culp_prof_development_start_us,
		game
	)

	phase_results["development_start"] = (
		development_start_result
	)

	_append_event(
		events,
		game,
		"development_start",
		development_start_result
	)

	var _culp_prof_draw_us: int = _culpability_profile_now()
	var draw_result: Dictionary = (
		_resolve_normal_draws(
			game,
			rules,
			random_source
		)
	)
	_culpability_profile_mark(
		"draw",
		_culp_prof_draw_us,
		game
	)

	phase_results["draw"] = draw_result

	_append_event(
		events,
		game,
		"draw",
		draw_result
	)

	var _culp_prof_market_rollover_us: int = _culpability_profile_now()
	var market_rollover_result: Dictionary = (
		RoundEngineData.refresh_market_offers(
			game,
			rules,
			random_source
		)
	)
	_culpability_profile_mark(
		"market_rollover",
		_culp_prof_market_rollover_us,
		game
	)

	# Market rollover is a lab-only phase beginning in round two. Canonical
	# DE v2 and the opening Market return an inert result, but that result must
	# not alter the serialized round-event contract.
	if bool(
		market_rollover_result.get(
			"enabled",
			false
		)
	):
		phase_results["market_rollover"] = market_rollover_result

		_append_event(
			events,
			game,
			"market_rollover",
			market_rollover_result
		)

	var _culp_prof_market_choices_us: int = _culpability_profile_now()
	var market_choices: Dictionary = (
		BotDoctrineData.market_choices(
			game,
			random_source
		)
	)
	_culpability_profile_mark(
		"market_choices",
		_culp_prof_market_choices_us,
		game
	)

	var _culp_prof_market_resolve_us: int = _culpability_profile_now()
	var market_results: Array[Dictionary] = (
		RoundEngineData.resolve_market(
			game,
			market_choices
		)
	)
	_culpability_profile_mark(
		"market_resolve",
		_culp_prof_market_resolve_us,
		game
	)

	phase_results["market"] = {
		"choices": market_choices,
		"results": market_results,
	}

	_append_event(
		events,
		game,
		"market",
		phase_results["market"]
	)

	if _contains_invalid(
		market_results
	):
		return _invalid_round(
			game,
			phase_results,
			events,
			"market",
			"Market generated an invalid decision."
		)

	var _culp_prof_repair_choices_us: int = _culpability_profile_now()
	var repair_choices: Dictionary = (
		BotDevelopmentDoctrineData
		.repair_choices(
			game,
			rules,
			random_source,
			effective_policy
		)
	)
	_culpability_profile_mark(
		"repair_choices",
		_culp_prof_repair_choices_us,
		game
	)

	var _culp_prof_repair_resolve_us: int = _culpability_profile_now()
	var repair_results: Array[Dictionary] = (
		RoundEngineData.resolve_repairs(
			game,
			rules,
			repair_choices
		)
	)
	_culpability_profile_mark(
		"repair_resolve",
		_culp_prof_repair_resolve_us,
		game
	)

	phase_results["repair"] = {
		"choices": repair_choices,
		"results": repair_results,
	}

	_append_event(
		events,
		game,
		"repair",
		phase_results["repair"]
	)

	if _contains_invalid(
		repair_results
	):
		return _invalid_round(
			game,
			phase_results,
			events,
			"repair",
			"Repair generated an invalid decision."
		)

	# SIEGE_ENGINE_BOMBARDMENT_V1
	# Castle powers resolve after the complete Repair phase and before Dominion.
	var siege_engine_fire_result: Dictionary = (
		SiegeEngineFireEngineData.resolve(
			game,
			rules,
			random_source
		)
	)
	phase_results["siege_engine_fire"] = (
		siege_engine_fire_result
	)
	_append_event(
		events,
		game,
		"siege_engine_fire",
		siege_engine_fire_result
	)

	var _culp_prof_rite_choices_us: int = _culpability_profile_now()
	var rite_choices: Dictionary = (
		BotDominionRiteDoctrineData
		.rite_choices(
			game,
			rules,
			random_source,
			effective_policy
		)
	)
	_culpability_profile_mark(
		"rite_choices",
		_culp_prof_rite_choices_us,
		game
	)

	var _culp_prof_rite_resolve_us: int = _culpability_profile_now()
	var rite_results: Array[Dictionary] = (
		DominionRiteEngineData.resolve(
			game,
			rules,
			rite_choices
		)
	)
	_culpability_profile_mark(
		"rite_resolve",
		_culp_prof_rite_resolve_us,
		game
	)

	phase_results["dominion_rites"] = {
		"choices": rite_choices,
		"results": rite_results,
	}

	_append_event(
		events,
		game,
		"dominion_rites",
		phase_results["dominion_rites"]
	)

	if _contains_invalid(
		rite_results
	):
		return _invalid_round(
			game,
			phase_results,
			events,
			"dominion_rites",
			"Dominion Rite generated an invalid decision."
		)

	if int(
		game.winner
	) >= 0:
		return _finish_round(
			game,
			phase_results,
			events,
			false,
			"dominion_rites"
		)

	var _culp_prof_deploy_choices_us: int = _culpability_profile_now()
	var deploy_choices: Dictionary = (
		BotDeployDoctrineData.deploy_choices(
			game,
			rules
		)
	)
	_culpability_profile_mark(
		"deploy_choices",
		_culp_prof_deploy_choices_us,
		game
	)

	var _culp_prof_deploy_resolve_us: int = _culpability_profile_now()
	var deploy_results: Array[Dictionary] = (
		DeployEngineData.resolve(
			game,
			rules,
			deploy_choices
		)
	)
	_culpability_profile_mark(
		"deploy_resolve",
		_culp_prof_deploy_resolve_us,
		game
	)

	phase_results["deploy"] = {
		"choices": deploy_choices,
		"results": deploy_results,
	}

	_append_event(
		events,
		game,
		"deploy",
		phase_results["deploy"]
	)

	if _contains_invalid(
		deploy_results
	):
		return _invalid_round(
			game,
			phase_results,
			events,
			"deploy",
			"Deploy generated an invalid decision."
		)

	# COMMITMENT_MARCHING_FOUNDATION_V1
	# Guard-launch Marching Orders is retired. Commitment-generated tokens are
	# created after Reveal below.

	var _culp_prof_summon_choices_us: int = _culpability_profile_now()
	var summon_choices: Dictionary = (
		BotDevelopmentDoctrineData
		.summon_choices(
			game,
			rules,
			random_source,
			effective_policy
		)
	)
	_culpability_profile_mark(
		"summon_choices",
		_culp_prof_summon_choices_us,
		game
	)

	var _culp_prof_summon_resolve_us: int = _culpability_profile_now()
	var summon_results: Array[Dictionary] = (
		SummonEngineData.resolve(
			game,
			rules,
			summon_choices
		)
	)
	_culpability_profile_mark(
		"summon_resolve",
		_culp_prof_summon_resolve_us,
		game
	)

	phase_results["summon"] = {
		"choices": summon_choices,
		"results": summon_results,
	}

	_append_event(
		events,
		game,
		"summon",
		phase_results["summon"]
	)

	if _contains_invalid(
		summon_results
	):
		return _invalid_round(
			game,
			phase_results,
			events,
			"summon",
			"Summon generated an invalid decision."
		)

	if int(
		game.winner
	) >= 0:
		return _finish_round(
			game,
			phase_results,
			events,
			false,
			"summon"
		)

	# REFLEX_BID_DEPRECATED_RUNTIME_V1
	# Reflex Bid is a retired rules state. Keep a structural phase record so
	# old reports/snapshots remain readable, but never ask doctrine for bids and
	# never call ReflexBidEngine. Momentum may still award the later extra action.
	var _culp_prof_reflex_us: int = _culpability_profile_now()
	var bid_choices: Dictionary = {}
	var bid_result: Dictionary = {
		"action": "pass",
		"reason": "reflex_bid_deprecated",
		"winner": -1,
		"tie": false,
		"invalid_player_id": -1,
		"bid_totals": [],
		"players": [],
	}

	_culpability_profile_mark(
		"reflex_total",
		_culp_prof_reflex_us,
		game
	)

	phase_results["reflex_bid"] = {
		"choices": bid_choices,
		"result": bid_result,
	}

	_append_event(
		events,
		game,
		"reflex_bid",
		phase_results["reflex_bid"]
	)

	var _culp_prof_commitment_choices_us: int = _culpability_profile_now()
	var commitment_choices: Dictionary = (
		BotDoctrineData.commitment_choices(
			game,
			random_source,
			rules,
			effective_policy
		)
	)
	_culpability_profile_mark(
		"commitment_choices",
		_culp_prof_commitment_choices_us,
		game
	)

	var _culp_prof_commitment_resolve_us: int = _culpability_profile_now()
	var commitment_result: Dictionary = (
		CommitmentEngineData.resolve(
			game,
			commitment_choices,
			rules
		)
	)
	_culpability_profile_mark(
		"commitment_resolve",
		_culp_prof_commitment_resolve_us,
		game
	)

	phase_results["commitment"] = {
		"choices": commitment_choices,
		"result": commitment_result,
	}

	_append_event(
		events,
		game,
		"commitment",
		phase_results["commitment"]
	)

	if String(
		commitment_result.get(
			"action",
			""
		)
	) == "invalid":
		return _invalid_round(
			game,
			phase_results,
			events,
			"commitment",
			String(
				commitment_result.get(
					"reason",
					"invalid_commitment"
				)
			)
		)

	var _culp_prof_reveal_us: int = _culpability_profile_now()
	var reveal_result: Dictionary = (
		RevealEngineData.resolve(
			game,
			rules,
			random_source
		)
	)
	_culpability_profile_mark(
		"reveal",
		_culp_prof_reveal_us,
		game
	)

	phase_results["reveal"] = reveal_result

	_append_event(
		events,
		game,
		"reveal",
		reveal_result
	)

	if String(
		reveal_result.get(
			"action",
			""
		)
	) == "invalid":
		return _invalid_round(
			game,
			phase_results,
			events,
			"reveal",
			String(
				reveal_result.get(
					"reason",
					"invalid_reveal"
				)
			)
		)

	# BATTLEFIELD_CLOCK_V1 — public Reveal, then spawn, then autonomous second half.
	# Keep the whole battlefield extension absent when marching is disabled.
	if rules.marching:
		var march_spawn_result: Dictionary = (
			MarchingEngineData.spawn_from_commitments(
				game,
				rules,
				commitment_choices
			)
		)
		phase_results["march_spawn"] = march_spawn_result
		_append_event(events, game, "march_spawn", march_spawn_result)

		var march_second_half_result: Dictionary = (
			MarchingEngineData.resolve_half(
				game,
				rules,
				random_source,
				"second"
			)
		)
		phase_results["march_second_half"] = march_second_half_result
		_append_event(events, game, "march_second_half", march_second_half_result)

		if bool(march_second_half_result.get("terminal", false)):
			return _finish_round(
				game,
				phase_results,
				events,
				false,
				"march_second_half"
			)

	# Python oracle timing: Reveal mutations are not a victory checkpoint.
	# Resolution begins before Kanifous Reveal gains are checked for victory.

	var _culp_prof_resolution_choices_us: int = _culpability_profile_now()
	var resolution_choices: Dictionary = (
		BotResolutionDoctrineData
		.build_decisions(
			game,
			rules,
			commitment_choices,
			random_source,
			effective_policy
		)
	)
	_culpability_profile_mark(
		"resolution_choices",
		_culp_prof_resolution_choices_us,
		game
	)

	var _culp_prof_resolution_resolve_us: int = _culpability_profile_now()
	var resolution_result: Dictionary = (
		ResolutionEngineData.resolve(
			game,
			rules,
			resolution_choices,
			random_source
		)
	)
	_culpability_profile_mark(
		"resolution_resolve",
		_culp_prof_resolution_resolve_us,
		game
	)

	phase_results["resolution"] = {
		"choices": resolution_choices,
		"result": resolution_result,
	}

	_append_event(
		events,
		game,
		"resolution",
		phase_results["resolution"]
	)

	if String(
		resolution_result.get(
			"action",
			""
		)
	) == "invalid":
		return _invalid_round(
			game,
			phase_results,
			events,
			"resolution",
			String(
				resolution_result.get(
					"reason",
					"invalid_resolution"
				)
		)
	)

	# COMMITMENT_MARCHING_FOUNDATION_V1
	# Legacy end-of-round step movement is retired from the live round engine.
	# The upcoming battlefield clock will own first-half / second-half movement.

	var vacant_throne_result: Dictionary = (
		VacantThroneEngineData.resolve_end_round(
			game,
			rules
		)
	)
	phase_results["vacant_throne"] = vacant_throne_result
	_append_event(
		events,
		game,
		"vacant_throne",
		vacant_throne_result
	)

	return _finish_round(
		game,
		phase_results,
		events,
		true,
		(
			"resolution"
			if int(game.winner) >= 0
			else ""
		)
	)


static func _resolve_normal_draws(
	game,
	rules: RuleConfig,
	random_source
) -> Dictionary:
	var player_results: Array[Dictionary] = []

	for player in game.players:
		var draw_count: int = BASE_DRAW_COUNT

		if player.castles.has(
			"Stockpile"
		):
			draw_count += STOCKPILE_DRAW_BONUS

		var draw_results: Array[Dictionary] = []
		var drawn_cards: Array[String] = []

		for _draw_index: int in range(
			draw_count
		):
			var draw_result: Dictionary = (
				DrawEngineData.draw_to_hand(
					game,
					player,
					rules,
					random_source,
					false
				)
			)

			draw_results.append(
				draw_result
			)

			if bool(
				draw_result.get(
					"drawn",
					false
				)
			):
				drawn_cards.append(
					String(
						draw_result.get(
							"card",
							""
						)
					)
				)

		player_results.append({
			"player_id": int(
				player.pid
			),
			"requested_draws": draw_count,
			"drawn_cards": drawn_cards,
			"draw_results": draw_results,
		})

	return {
		"action": "draw",
		"players": player_results,
	}


static func _update_sigils(
	game,
	rules: RuleConfig
) -> Dictionary:
	var events: Array[Dictionary] = []

	for player in game.players:
		var preserved_zone: String = ""

		if (
			rules.humbaba_patient
			and player.humbaba_patient
		):
			player.humbaba_patient = false

			if _sigil_state(
				player,
				"Lord"
			) == "fresh":
				preserved_zone = "Lord"
			elif _sigil_state(
				player,
				"Castle"
			) == "fresh":
				preserved_zone = "Castle"
			elif _sigil_state(
				player,
				"Lord"
			) == "flipped":
				preserved_zone = "Lord"
			elif _sigil_state(
				player,
				"Castle"
			) == "flipped":
				preserved_zone = "Castle"

		for zone: String in SIGIL_ZONES:
			var state_before: String = (
				_sigil_state(
					player,
					zone
				)
			)

			if zone != preserved_zone:
				if state_before == "flipped":
					player.sigils[zone] = ""
				elif state_before == "fresh":
					player.sigils[zone] = "flipped"

			events.append({
				"player_id": int(
					player.pid
				),
				"zone": zone,
				"preserved": (
					zone == preserved_zone
				),
				"state_before": state_before,
				"state_after": _sigil_state(
					player,
					zone
				),
			})

	return {
		"action": "sigil_update",
		"events": events,
	}


static func _apply_veil_drift(
	game,
	rules: RuleConfig
) -> Dictionary:
	var veil_before: int = int(
		game.calculate_veil_total()
	)

	if (
		rules.veil_drift <= 0
		or game.round <= 1
		or game.round
			% rules.veil_drift
			!= 0
	):
		return {
			"action": "veil_drift",
			"applied": false,
			"veil_before": veil_before,
			"veil_after": veil_before,
			"harvested_card": "",
			"harvested_by": -1,
			"won": false,
		}

	var tear_event: Dictionary = (
		_gain_neutral_tear(
			game
		)
	)

	var won: bool = _check_win(
		game,
		rules
	)

	return {
		"action": "veil_drift",
		"applied": true,
		"veil_before": veil_before,
		"veil_after": int(
			game.calculate_veil_total()
		),
		"harvested_card": String(
			tear_event.get(
				"harvested_card",
				""
			)
		),
		"harvested_by": int(
			tear_event.get(
				"harvested_by",
				-1
			)
		),
		"won": won,
	}


static func _gain_neutral_tear(
	game
) -> Dictionary:
	game.neutral_tears += 1

	var harvested_card: String = ""
	var harvested_by: int = -1

	for player in game.players:
		if (
			player.lord != "Gremory"
			or not player.alive
			or player.gremory_veil_draw_done
		):
			continue

		player.gremory_veil_draw_done = true

		var target_index: int = -1

		for discard_index: int in range(
			game.discard.size() - 1,
			-1,
			-1
		):
			if int(
				game.discard[
					discard_index
				].value
			) >= 4:
				target_index = discard_index
				break

		if target_index >= 0:
			var card = game.discard[
				target_index
			]

			game.discard.remove_at(
				target_index
			)

			player.hand.append(
				card
			)

			harvested_card = _card_id(
				card
			)

			harvested_by = int(
				player.pid
			)

		break

	game.refresh_derived_values()

	return {
		"harvested_card": harvested_card,
		"harvested_by": harvested_by,
	}


static func _check_win(
	game,
	rules: RuleConfig
) -> bool:
	if int(
		game.winner
	) >= 0:
		return true

	for player in game.players:
		if (
			player.alive
			and player.souls
			>= rules.win_souls
		):
			game.winner = int(
				player.pid
			)

			game.win_by = "Ritual"

			game.refresh_derived_values()

			return true

	var veil_total: int = int(
		game.calculate_veil_total()
	)

	if veil_total >= rules.final_collapse_threshold:
		var selected_player = game.players[0]

		for player in game.players:
			if player.souls > selected_player.souls:
				selected_player = player

		game.winner = int(
			selected_player.pid
		)

		game.win_by = "FinalCollapse"

		game.refresh_derived_values()

		return true

	if veil_total >= rules.dominion_track:
		var leading_player = game.players[0]
		var tied: bool = false

		for player_index: int in range(
			1,
			game.players.size()
		):
			var candidate = game.players[
				player_index
			]

			if candidate.tears > leading_player.tears:
				leading_player = candidate
				tied = false
			elif candidate.tears == leading_player.tears:
				tied = true

		if (
			not tied
			and leading_player.tears
			>= _dominion_requirement(
				game,
				rules
			)
		):
			game.winner = int(
				leading_player.pid
			)

			game.win_by = "Dominion"

			game.refresh_derived_values()

			return true

	return false


static func _dominion_requirement(
	game,
	rules: RuleConfig
) -> int:
	var players: Array = []

	for player in game.players:
		players.append({
			"lord": String(
				player.lord
			),
			"alive": bool(
				player.alive
			),
		})

	return LordMathData.dominion_requirement(
		players,
		rules
	)


static func _finish_round(
	game,
	phase_results: Dictionary,
	events: Array[Dictionary],
	completed: bool,
	stopped_phase: String
) -> Dictionary:
	return {
		"action": "round",
		"reason": "",
		"round": int(
			game.round
		),
		"completed": completed,
		"terminal": (
			int(
				game.winner
			) >= 0
		),
		"stopped_phase": stopped_phase,
		"winner": int(
			game.winner
		),
		"win_by": String(
			game.win_by
		),
		"phases": phase_results,
		"events": events,
	}


static func _invalid_round(
	game,
	phase_results: Dictionary,
	events: Array[Dictionary],
	phase_name: String,
	reason: String
) -> Dictionary:
	return {
		"action": "invalid",
		"reason": reason,
		"round": int(
			game.round
		),
		"completed": false,
		"terminal": (
			int(
				game.winner
			) >= 0
		),
		"stopped_phase": phase_name,
		"winner": int(
			game.winner
		),
		"win_by": String(
			game.win_by
		),
		"phases": phase_results,
		"events": events,
	}


static func _append_event(
	events: Array[Dictionary],
	game,
	phase_name: String,
	data
) -> void:
	events.append({
		"round": int(
			game.round
		),
		"phase": phase_name,
		"data": data,
	})

static func _contains_invalid(
	value
) -> bool:
	if typeof(
		value
	) == TYPE_DICTIONARY:
		var dictionary: Dictionary = value

		if String(
			dictionary.get(
				"action",
				""
			)
		) == "invalid":
			return true

		for nested_value in dictionary.values():
			if _contains_invalid(
				nested_value
			):
				return true

		return false

	if typeof(
		value
	) == TYPE_ARRAY:
		var array: Array = value

		for nested_value in array:
			if _contains_invalid(
				nested_value
			):
				return true

	return false


static func _sigil_state(
	player,
	zone: String
) -> String:
	return String(
		player.sigils.get(
			zone,
			""
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
			card.get(
				"suit"
			)
		),
		int(
			card.get(
				"value"
			)
		),
	]


static func _policy_or_default(
	policy
):
	# Deploy currently reserves cards against the deterministic Commitment
	# plan. Keep the round default deterministic until those two decisions
	# share a single sampled plan.
	if policy == null:
		return BotPolicyData.golden_core()

	return policy
