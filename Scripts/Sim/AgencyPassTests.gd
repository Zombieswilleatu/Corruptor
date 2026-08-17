class_name AgencyPassTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameStateData = preload(
	"res://Scripts/Sim/GameState.gd"
)

const RoundEngineData = preload(
	"res://Scripts/Sim/RoundEngine.gd"
)

const DeployEngineData = preload(
	"res://Scripts/Sim/DeployEngine.gd"
)

const SummonEngineData = preload(
	"res://Scripts/Sim/SummonEngine.gd"
)

const ResolutionFinaleEngineData = preload(
	"res://Scripts/Sim/ResolutionFinaleEngine.gd"
)

const DominionRiteEngineData = preload(
	"res://Scripts/Sim/DominionRiteEngine.gd"
)


static func run() -> Array:
	return [
		_test_profile_contract(),
		_test_repair_currency_and_chooser(),
		_test_offsuit_repair_resolves(),
		_test_repair_no_longer_blocks_hand_deploy(),
		_test_summon_shortfall_and_voluntary_underpay(),
		_test_summon_retention_and_vessel_baselines(),
		_test_kroni_fallback_conserves_card(),
	]


static func _test_profile_contract() -> Dictionary:
	var lab := RuleConfig.lab_v6_5()
	var historical := RuleConfig.de_v2()

	if (
		lab.repair_wright_mode != "tax"
		or lab.repair_offsuit_penalty != 1
		or lab.repair_offsuit_floor != 1
		or lab.repair_exempt_suit != "Wright"
		or lab.repair_blocks_hand_deploy
		or not lab.summon_threat_shortfall
		or lab.repair_token_integrity != 3
	):
		return _fail(
			"unit_agency_profile",
			"Current lab agency dials drifted."
		)

	if (
		historical.repair_wright_mode == "tax"
		or not historical.repair_blocks_hand_deploy
		or historical.summon_threat_shortfall
	):
		return _fail(
			"unit_agency_historical_profile",
			"Agency rules leaked into DE v2 defaults."
		)

	return _pass("unit_agency_profile")


static func _test_repair_currency_and_chooser() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var butcher = CardData.new("Butcher", 4)
	var wright = CardData.new("Wright", 4)
	var vulture = CardData.new("Vulture", 1)

	if (
		RoundEngineData.effective_repair_value(wright, rules) != 4
		or RoundEngineData.effective_repair_value(butcher, rules) != 3
		or RoundEngineData.effective_repair_value(vulture, rules) != 1
	):
		return _fail(
			"unit_agency_repair_currency",
			"Repair effective values are not Wright full / off-suit -1 floor 1."
		)

	var chosen: Array = RoundEngineData.choose_repair_payment_cards(
		[butcher, wright],
		4,
		rules
	)

	if chosen.size() != 1 or chosen[0] != wright:
		return _fail(
			"unit_agency_repair_chooser",
			"Repair DP optimized printed value instead of effective value."
		)

	return _pass("unit_agency_repair_currency_and_chooser")


static func _test_offsuit_repair_resolves() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var game = GameStateData.new(["Orias"], ["Valak"])
	var player = game.players[0]

	player.alive = true
	player.castles.clear()
	player.castles.append("Keep")
	player.castle_integrity = {"Keep": 10}
	player.hand = [CardData.new("Butcher", 4)]

	var result: Dictionary = RoundEngineData.resolve_repair_player(
		game,
		0,
		rules,
		{
			"action": "repair",
			"castle": "Keep",
			"payment": ["Butcher:4"],
		}
	)

	if (
		String(result.get("action", "")) != "repair"
		or int(result.get("effective_paid_total", 0)) != 3
		or int(player.castle_integrity.get("Keep", 0)) != 13
	):
		return _fail(
			"unit_agency_offsuit_repair",
			"Off-suit Repair was rejected or restored the wrong Integrity."
		)

	return _pass("unit_agency_offsuit_repair")


static func _test_repair_no_longer_blocks_hand_deploy() -> Dictionary:
	var lab := RuleConfig.lab_v6_5()
	var game = GameStateData.new(["Orias"], ["Valak"])
	var player = game.players[0]
	player.alive = true
	player.hand = [CardData.new("Butcher", 1)]
	player.repaired_this_round = true
	player.repair_token_used_this_repair = false

	var result: Dictionary = DeployEngineData.resolve_player(
		game,
		0,
		lab,
		{
			"moves": [{
				"source": "Hand",
				"card": "Butcher:1",
				"target": "Castle",
			}],
		}
	)

	if (
		String(result.get("action", "")) == "invalid"
		or player.castle_guards.size() != 1
	):
		return _fail(
			"unit_agency_repair_deploy",
			"Current lab still blocked Hand deployment after Repair."
		)

	var historical := RuleConfig.de_v2()
	var old_game = GameStateData.new(["Orias"], ["Valak"])
	var old_player = old_game.players[0]
	old_player.alive = true
	old_player.hand = [CardData.new("Butcher", 1)]
	old_player.repaired_this_round = true
	old_player.repair_token_used_this_repair = false

	var old_result: Dictionary = DeployEngineData.resolve_player(
		old_game,
		0,
		historical,
		{
			"moves": [{
				"source": "Hand",
				"card": "Butcher:1",
				"target": "Castle",
			}],
		}
	)

	var old_moves: Array = old_result.get("moves", [])
	if (
		old_moves.size() != 1
		or String(
			(old_moves[0] as Dictionary).get("reason", "")
		) != "hand_deploy_blocked_by_repair"
		or int(old_result.get("moved_count", -1)) != 0
		or int(old_result.get("invalid_count", -1)) != 1
	):
		return _fail(
			"unit_agency_repair_deploy_historical",
			"Historical Repair deploy restriction was not preserved."
		)

	return _pass("unit_agency_repair_deploy")


static func _test_summon_shortfall_and_voluntary_underpay() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()

	var game = GameStateData.new(["Kalligan"], ["Valak"])
	var player = game.players[0]
	player.lord = "Kalligan"
	player.alive = false
	player.first_summon_done = true
	player.hand = [CardData.new("Butcher", 1)]

	var short_result: Dictionary = SummonEngineData.resolve_player(
		game,
		0,
		rules,
		{
			"lord": "Kalligan",
			"payment": ["Butcher:1"],
		}
	)

	if (
		String(short_result.get("action", "")) != "summon"
		or int(short_result.get("threat_shortfall", -1)) != 3
		or int(player.threat) != 4
	):
		return _fail(
			"unit_agency_summon_shortfall",
			"Cards 1/4 did not return Kalligan at Threat 4."
		)

	var game_two = GameStateData.new(["Kalligan"], ["Valak"])
	var underpayer = game_two.players[0]
	underpayer.lord = "Kalligan"
	underpayer.alive = false
	underpayer.first_summon_done = true
	underpayer.hand = [
		CardData.new("Butcher", 3),
		CardData.new("Wright", 3),
	]

	var voluntary: Dictionary = SummonEngineData.resolve_player(
		game_two,
		0,
		rules,
		{
			"lord": "Kalligan",
			"payment": ["Butcher:3"],
		}
	)

	if (
		String(voluntary.get("action", "")) != "summon"
		or int(voluntary.get("threat_shortfall", -1)) != 1
		or int(underpayer.threat) != 2
		or underpayer.hand.size() != 1
		or String(underpayer.hand[0].card_id()) != "Wright:3"
	):
		return _fail(
			"unit_agency_summon_voluntary",
			"Fully affordable Summon could not deliberately preserve cards with Threat."
		)

	return _pass("unit_agency_summon_shortfall_and_voluntary")


static func _test_summon_retention_and_vessel_baselines() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()

	var retained_game = GameStateData.new(["Kalligan"], ["Valak"])
	var retained = retained_game.players[0]
	retained.lord = "Kalligan"
	retained.alive = false
	retained.first_summon_done = true
	retained.return_threat_override = 3
	retained.hand = [CardData.new("Butcher", 2)]

	var blocked: Dictionary = SummonEngineData.resolve_player(
		retained_game,
		0,
		rules,
		{
			"lord": "Kalligan",
			"payment": ["Butcher:2"],
		}
	)

	if (
		String(blocked.get("action", "")) != "invalid"
		or String(blocked.get("reason", "")) != "summon_threat_cap"
	):
		return _fail(
			"unit_agency_summon_retention",
			"Retained return Threat did not bound shortfall legality."
		)

	var vessel_game = GameStateData.new(["Kalligan"], ["Valak"])
	var vessel = vessel_game.players[0]
	vessel.lord = "Kalligan"
	vessel.alive = false
	vessel.first_summon_done = true
	vessel.vessel_offered_lord = "Kalligan"
	vessel.hand = [CardData.new("Butcher", 2)]

	var vessel_result: Dictionary = SummonEngineData.resolve_player(
		vessel_game,
		0,
		rules,
		{
			"lord": "Kalligan",
			"payment": ["Butcher:2"],
		}
	)

	if (
		String(vessel_result.get("action", "")) != "summon"
		or int(vessel_result.get("base_return_threat", -1)) != 2
		or int(vessel_result.get("threat_shortfall", -1)) != 2
		or int(vessel.threat) != 4
		or not vessel.vessel_offered_lord.is_empty()
	):
		return _fail(
			"unit_agency_summon_vessel",
			"Vessel Threat 2 erased or mispriced the Summon shortfall."
		)

	return _pass("unit_agency_summon_retention_and_vessel")


static func _test_kroni_fallback_conserves_card() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var game = GameStateData.new(["Kroni"], ["Valak"])
	var kroni = game.players[0]
	kroni.lord = "Kroni"
	kroni.alive = true
	kroni.kroni_hunger = 2
	kroni.kroni_consume_done = false
	kroni.castle_guards.clear()
	var victim = CardData.new("Penitent", 1)
	kroni.castle_guards.append(victim)

	var result: Dictionary = ResolutionFinaleEngineData.resolve(
		game,
		rules
	)
	var events: Array = result.get("fallback_events", [])

	if (
		events.size() != 1
		or not game.discard.has(victim)
		or game.removed_from_play.has(victim)
		or kroni.kroni_hunger != 2
	):
		return _fail(
			"unit_agency_kroni_conservation",
			"Kroni fallback did not pay to discard while staying cost-only in lab."
		)

	return _pass("unit_agency_kroni_conservation")




static func _pass(test_name: String) -> Dictionary:
	return {
		"passed": true,
		"text": "PASS  %s" % test_name,
	}


static func _fail(
	test_name: String,
	why: String
) -> Dictionary:
	return {
		"passed": false,
		"text": "FAIL  %s — %s" % [test_name, why],
	}
