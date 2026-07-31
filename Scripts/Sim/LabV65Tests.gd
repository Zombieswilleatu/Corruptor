class_name LabV65Tests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const CommitmentEngineData = preload(
	"res://Scripts/Sim/CommitmentEngine.gd"
)

const RevealEngineData = preload(
	"res://Scripts/Sim/RevealEngine.gd"
)

const HuntResolutionEngineData = preload(
	"res://Scripts/Sim/HuntResolutionEngine.gd"
)

const SiegeResolutionEngineData = preload(
	"res://Scripts/Sim/SiegeResolutionEngine.gd"
)

const ProfaneResolutionEngineData = preload(
	"res://Scripts/Sim/ProfaneResolutionEngine.gd"
)

const SummonEngineData = preload(
	"res://Scripts/Sim/SummonEngine.gd"
)

const MarchingEngineData = preload(
	"res://Scripts/Sim/MarchingEngine.gd"
)

const RoundEngineData = preload(
	"res://Scripts/Sim/RoundEngine.gd"
)

const PythonRandomData = preload(
	"res://Scripts/Sim/PythonRandom.gd"
)


static func run(_baseline_rules: RuleConfig) -> Array:
	return [
		_test_profile(),
		_test_threshold_ward(),
		_test_humbaba_reactive_lane(),
		_test_kanifous_hand_toll(),
		_test_ward_refund(),
		_test_flat_ward_and_fix_b(),
		_test_market_rollover(),
		_test_marching_clash(),
		_test_scarred_castle_and_momentum(),
		_test_scarred_repair_cost(),
		_test_retained_threat(),
	]


static func _test_profile() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	if (
		rules.win_souls != 12
		or rules.dominion_track != 12
		or rules.dominion_requirement != 5
		or rules.final_collapse_threshold != 26
		or rules.reflex_bid
		or not rules.fix_b
		or not rules.sigil_flat
		or not rules.momentum
		or not rules.marching
		or rules.humbaba_seal
		or rules.humbaba_gate4
		or rules.humbaba_patient
		or rules.humbaba_sigil_commit
		or not rules.humbaba_reactive_lane
		or not rules.kani_hand_cost
		or rules.kani_threat_cost
	):
		return _fail(
			"unit_lab_v6_5_profile",
			"Measured clocks, systems, or Lord revisions drifted."
		)

	return _pass("unit_lab_v6_5_profile")

static func _test_threshold_ward() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var fixture: Dictionary = _fixture(rules)
	var game = fixture["game"]
	var attacker = fixture["p0"]
	var defender = fixture["p1"]

	game.round = 2
	attacker.hand = [CardData.new("Butcher", 4)]
	defender.hand = [CardData.new("Penitent", 4)]
	# v6.5 deliberately removes Ward's old anti-repeat target restriction.
	defender.prev_ward_target = "Lord"

	var committed: Dictionary = CommitmentEngineData.resolve(
		game,
		{
			0: {
				"action": "Hunt",
				"target_pid": 1,
				"cards": ["Butcher:4"],
			},
			1: {
				"action": "Ward",
				"target_pid": 1,
				"target_type": "Lord",
				"cards": ["Penitent:4"],
			},
		},
		rules
	)

	if String(committed.get("action", "")) != "commit":
		return _fail("unit_lab_threshold_ward", "Fixture Commitment failed.")

	var reveal: Dictionary = RevealEngineData.resolve(game, rules)
	var hunt: Dictionary = HuntResolutionEngineData.resolve(game, rules, 0)

	if (
		String(reveal.get("action", "")) != "reveal"
		or not bool(defender.ward_turned.get("Lord", false))
		or String(hunt.get("reason", "")) != "ward_turned"
	):
		return _fail(
			"unit_lab_threshold_ward",
			"Equal Ward commitment did not turn the matching Hunt."
		)

	return _pass("unit_lab_threshold_ward")


static func _test_humbaba_reactive_lane() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var fixture: Dictionary = _fixture(rules)
	var game = fixture["game"]
	var humbaba = fixture["p0"]
	var opponent = fixture["p1"]
	humbaba.lord = "Humbaba"

	# PlayerState.marchers is Array[Dictionary]. Append into the existing
	# typed container instead of assigning a generic Array literal.
	humbaba.marchers.clear()
	humbaba.marchers.append({
		"card": CardData.new("Wright", 3),
		"value": 3,
		"lane": "Lord",
		"pos": 0,
	})
	opponent.marchers.clear()
	opponent.marchers.append({
		"card": CardData.new("Penitent", 3),
		"value": 3,
		"lane": "Castle",
		"pos": 0,
	})
	humbaba.lord_guards = [
		CardData.new("Butcher", 5),
		CardData.new("Butcher", 4),
	]

	var result: Dictionary = MarchingEngineData.launch(
		game,
		rules,
		0,
		{
			"action": "march",
			"source_zone": "Lord",
			"lane": "Lord",
			"card": "Butcher:4",
		}
	)

	if (
		String(result.get("action", "")) != "march"
		or not bool(result.get("reactive", false))
		or String(result.get("lane", "")) != "Castle"
		or humbaba.marchers.size() != 2
	):
		return _fail(
			"unit_lab_humbaba_reactive_lane",
			"Humbaba did not receive a forced response marcher in the enemy lane."
		)

	return _pass("unit_lab_humbaba_reactive_lane")

static func _test_kanifous_hand_toll() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var fixture: Dictionary = _fixture(rules)
	var game = fixture["game"]
	var player = fixture["p0"]
	player.lord = "Kanifous"
	player.threat = 2
	player.hand = [
		CardData.new("Wright", 4),
		CardData.new("Penitent", 1),
	]
	game.deck = [
		CardData.new("Butcher", 2),
		CardData.new("Butcher", 4),
	]
	game.discard.clear()

	var result: Dictionary = RevealEngineData._resolve_kanifous(
		game,
		player,
		rules,
		null,
		{
			"chosen_card": "Butcher:4",
			"toll_card": "Wright:4",
		}
	)

	if (
		not bool(result.get("invoked", false))
		or not bool(result.get("toll_paid", false))
		or String(result.get("toll_card", "")) != "Wright:4"
		or player.threat != 2
		or player.hand.size() != 1
		or String(player.hand[0].card_id()) != "Penitent:1"
	):
		return _fail(
			"unit_lab_kanifous_hand_toll",
			"Kanifous did not pay the selected Hand toll without gaining Threat."
		)

	return _pass("unit_lab_kanifous_hand_toll")

static func _test_ward_refund() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var fixture: Dictionary = _fixture(rules)
	var game = fixture["game"]
	var warder = fixture["p0"]
	var opponent = fixture["p1"]

	warder.hand = [
		CardData.new("Wright", 4),
		CardData.new("Penitent", 1),
	]
	opponent.hand = [CardData.new("Butcher", 2)]

	var committed: Dictionary = CommitmentEngineData.resolve(
		game,
		{
			0: {
				"action": "Ward",
				"target_pid": 0,
				"target_type": "Castle",
				"cards": ["Wright:4", "Penitent:1"],
			},
			1: {
				"action": "Ward",
				"target_pid": 1,
				"target_type": "Lord",
				"cards": ["Butcher:2"],
			},
		},
		rules
	)
	var reveal: Dictionary = RevealEngineData.resolve(game, rules)

	if (
		String(committed.get("action", "")) != "commit"
		or String(reveal.get("action", "")) != "reveal"
		or warder.garrison.size() != 1
		or String(warder.garrison[0].suit) != "Penitent"
		or int(warder.garrison[0].value) != 1
		or warder.committed.size() != 1
	):
		return _fail(
			"unit_lab_ward_refund",
			"An uncontested Ward did not return exactly its lowest card to Garrison."
		)

	return _pass("unit_lab_ward_refund")


static func _test_flat_ward_and_fix_b() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var fixture: Dictionary = _fixture(rules)
	var game = fixture["game"]
	var player = fixture["p0"]
	var opponent = fixture["p1"]

	player.castles.clear()
	player.castles.append("Keep")
	player.castles.append("Stockpile")
	opponent.sigils = {"Lord": "fresh", "Castle": ""}
	game.neutral_tears = 3

	var omen_fresh_value: int = SiegeResolutionEngineData._sigil_value(
		game,
		opponent,
		"fresh",
		rules
	)
	var omen_flipped_value: int = SiegeResolutionEngineData._sigil_value(
		game,
		opponent,
		"flipped",
		rules
	)
	opponent.castles.clear()
	opponent.castles.append("Keep")
	game.neutral_tears = 0
	var keep_fresh_value: int = SiegeResolutionEngineData._sigil_value(
		game,
		opponent,
		"fresh",
		rules
	)
	var keep_flipped_value: int = SiegeResolutionEngineData._sigil_value(
		game,
		opponent,
		"flipped",
		rules
	)

	player.action = "Profane"
	player.tgt_pid = int(player.pid)
	player.tgt_type = "Castle"
	player.pending_profane = "Stockpile"
	var profane: Dictionary = ProfaneResolutionEngineData.resolve(
		game,
		rules,
		int(player.pid),
		{"target_castle": "Stockpile"}
	)

	if (
		omen_fresh_value != 2
		or omen_flipped_value != 1
		or keep_fresh_value != 2
		or keep_flipped_value != 1
		or bool(profane.get("blocked", true))
		or not player.profaned_castles.has("Stockpile")
	):
		return _fail(
			"unit_lab_flat_ward_fix_b",
			"Flat Ward values or Fresh-Sigil Profane removal drifted."
		)

	return _pass("unit_lab_flat_ward_fix_b")


static func _test_market_rollover() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var game = GameDealFixtureData.build_game_deimos_valak_s1(rules)
	var opening_offers: Array = game.market.duplicate()
	var random_source = PythonRandomData.new(6501)

	game.round = 1
	var opening_result: Dictionary = RoundEngineData.refresh_market_offers(
		game,
		rules,
		random_source
	)
	if (
		bool(opening_result.get("enabled", true))
		or game.market != opening_offers
	):
		return _fail(
			"unit_lab_market_rollover",
			"The setup Market must remain available during round one."
		)

	# Market refresh must not be coupled to Marching Orders.  A lab test can
	# isolate Marching without accidentally restoring the static Market.
	rules.marching = false
	game.round = 2
	var rollover_result: Dictionary = RoundEngineData.refresh_market_offers(
		game,
		rules,
		random_source
	)
	if (
		not bool(rollover_result.get("enabled", false))
		or game.market.size() != rules.market_size
	):
		return _fail(
			"unit_lab_market_rollover",
			"Round-two Market offers did not refresh."
		)

	for offer in opening_offers:
		if game.market.has(offer) or game.discard.has(offer):
			return _fail(
				"unit_lab_market_rollover",
				"A rolled offer was not returned beneath the deck."
			)

	var recycle_game = GameDealFixtureData.build_game_deimos_valak_s1(rules)
	var recycle_rolled_offers: Array = recycle_game.market.duplicate()
	var fresh_offers: Array = [
		CardData.new("Butcher", 5),
		CardData.new("Penitent", 4),
		CardData.new("Vulture", 3),
	]
	recycle_game.deck.clear()
	recycle_game.discard = fresh_offers.duplicate()
	recycle_game.round = 2
	var recycle_result: Dictionary = RoundEngineData.refresh_market_offers(
		recycle_game,
		rules,
		PythonRandomData.new(6502)
	)
	if (
		int(recycle_result.get("recycled_count", 0)) != fresh_offers.size()
		or not _same_cards(recycle_game.market, fresh_offers)
		or not recycle_game.discard.is_empty()
		or not _same_cards(recycle_game.deck, recycle_rolled_offers)
	):
		return _fail(
			"unit_lab_market_rollover",
			"Market refresh did not recycle discard before reusing rolled offers."
		)

	var canonical_rules := RuleConfig.de_v2()
	var canonical_game = GameDealFixtureData.build_game_deimos_valak_s1(
		canonical_rules
	)
	var canonical_offers: Array = canonical_game.market.duplicate()
	canonical_game.round = 2
	var canonical_result: Dictionary = RoundEngineData.refresh_market_offers(
		canonical_game,
		canonical_rules,
		PythonRandomData.new(6503)
	)
	if (
		bool(canonical_result.get("enabled", true))
		or canonical_game.market != canonical_offers
	):
		return _fail(
			"unit_lab_market_rollover",
			"Canonical DE v2 Market behavior changed."
		)

	return _pass("unit_lab_market_rollover")


static func _same_cards(
	first: Array,
	second: Array
) -> bool:
	if first.size() != second.size():
		return false

	var first_ids: Array[String] = []
	var second_ids: Array[String] = []
	for card in first:
		first_ids.append(card.card_id())
	for card in second:
		second_ids.append(card.card_id())
	first_ids.sort()
	second_ids.sort()
	return first_ids == second_ids


static func _test_marching_clash() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var fixture: Dictionary = _fixture(rules)
	var game = fixture["game"]
	var first = fixture["p0"]
	var second = fixture["p1"]

	first.marchers.clear()
	var first_marcher: Dictionary = {
		"card": CardData.new("Butcher", 2),
		"value": 2,
		"lane": "Lord",
		"pos": 0,
	}
	first.marchers.append(first_marcher)

	second.marchers.clear()
	var second_marcher: Dictionary = {
		"card": CardData.new("Butcher", 2),
		"value": 2,
		"lane": "Lord",
		"pos": 0,
	}
	second.marchers.append(second_marcher)

	var result: Dictionary = MarchingEngineData.advance(game, rules)

	if (
		first.souls != 1
		or second.souls != 1
		or not first.marchers.is_empty()
		or not second.marchers.is_empty()
		or game.discard.size() != 2
		or not bool(result.get("enabled", false))
	):
		return _fail(
			"unit_lab_marching_clash",
			"Lane destruction must award each opposing Soul and discard both cards."
		)

	return _pass("unit_lab_marching_clash")


static func _test_scarred_castle_and_momentum() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var fixture: Dictionary = _fixture(rules)
	var game = fixture["game"]
	var attacker = fixture["p0"]
	var defender = fixture["p1"]

	game.round = 2
	attacker.lord = "Orias"
	attacker.action = "Siege"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Castle"
	attacker.committed = [
		CardData.new("Butcher", 5),
		CardData.new("Wright", 4),
		CardData.new("Penitent", 3),
	]
	defender.castles.clear()
	defender.castles.append("Keep")
	defender.castle_scars = {"Keep": 1}
	defender.castle_guards.clear()

	var result: Dictionary = SiegeResolutionEngineData.resolve(
		game,
		rules,
		0,
		{"target_castle": "Keep"}
	)

	if (
		not bool(result.get("destroyed", false))
		or not bool(result.get("permanent_loss", false))
		or not defender.lost_castles.has("Keep")
		or defender.ruined_castles.has("Keep")
		or game.reflex_winner != 0
		or game.neutral_tears < 1
	):
		return _fail(
			"unit_lab_scarred_castle_momentum",
			"Scarred destruction must be permanent, fray the Veil, and grant precise Momentum."
		)

	return _pass("unit_lab_scarred_castle_momentum")


static func _test_scarred_repair_cost() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var fixture: Dictionary = _fixture(rules)
	var player = fixture["p0"]
	player.castle_scars = {"Keep": 1}

	var cost: int = RoundEngineData.repair_cost_for(
		fixture["game"],
		player,
		"Keep",
		false,
		rules
	)

	if cost != 11:
		return _fail(
			"unit_lab_scarred_repair_cost",
			"Keep repair with one scar should cost 11, got %d." % cost
		)

	return _pass("unit_lab_scarred_repair_cost")


static func _test_retained_threat() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var fixture: Dictionary = _fixture(rules)
	var game = fixture["game"]
	var attacker = fixture["p0"]
	var defender = fixture["p1"]

	game.round = 2
	attacker.action = "Hunt"
	attacker.tgt_pid = int(defender.pid)
	attacker.tgt_type = "Lord"
	attacker.committed = [
		CardData.new("Butcher", 5),
		CardData.new("Butcher", 4),
	]
	defender.threat = 4

	var hunt: Dictionary = HuntResolutionEngineData.resolve(
		game,
		rules,
		int(attacker.pid)
	)
	var retained_threat: int = int(defender.threat)
	defender.hand = [
		CardData.new("Butcher", 5),
		CardData.new("Wright", 5),
	]
	var summon: Dictionary = SummonEngineData.resolve_player(
		game,
		int(defender.pid),
		rules,
		{
			"lord": String(defender.lord),
			"payment": ["Butcher:5", "Wright:5"],
		}
	)

	if (
		not bool(hunt.get("banished", false))
		or retained_threat != 3
		or String(summon.get("action", "")) != "summon"
		or not defender.alive
		or defender.threat != 3
		or defender.return_threat_override >= 0
	):
		return _fail(
			"unit_lab_retained_threat",
			"A Banished Lord did not retain and return at printed Threat plus half retained Threat."
		)

	return _pass("unit_lab_retained_threat")


static func _fixture(rules: RuleConfig) -> Dictionary:
	var game = GameDealFixtureData.build_game_deimos_valak_s1(rules)
	assert(game != null, "Lab fixture returned no GameState.")

	for player in game.players:
		player.alive = true
		player.souls = 0
		player.tears = 0
		player.threat = 0
		player.hand.clear()
		player.garrison.clear()
		player.committed.clear()
		player.lord_guards.clear()
		player.castle_guards.clear()
		player.marchers.clear()
		player.castles.clear()
		player.ruined_castles.clear()
		player.lost_castles.clear()
		player.castle_scars.clear()
		player.ward_turned.clear()
		player.sigils = {"Lord": "", "Castle": ""}

	game.deck.clear()
	game.discard.clear()
	game.neutral_tears = 0
	game.reflex_winner = -1
	game.winner = -1
	game.win_by = ""
	game.refresh_derived_values()

	return {
		"game": game,
		"p0": game.get_player(0),
		"p1": game.get_player(1),
	}


static func _pass(test_name: String) -> Dictionary:
	return {
		"passed": true,
		"text": "PASS  %s" % test_name,
	}


static func _fail(test_name: String, reason: String) -> Dictionary:
	return {
		"passed": false,
		"text": "FAIL  %s: %s" % [test_name, reason],
	}
