class_name VacantThroneTests
extends RefCounted


const RuleConfigData = preload(
	"res://Scripts/Sim/RuleConfig.gd"
)

const SeededGameSetupData = preload(
	"res://Scripts/Sim/SeededGameSetup.gd"
)

const VacantThroneEngineData = preload(
	"res://Scripts/Sim/VacantThroneEngine.gd"
)


static func run() -> Array[Dictionary]:
	return [
		_test_kill_round_does_not_count(),
		_test_two_full_vacant_rounds_are_safe(),
		_test_third_and_later_rounds_score(),
		_test_resummon_resets_clock(),
		_test_breach_occupant_is_irrelevant(),
		_test_scoring_soul_can_win_ritual(),
	]


static func _fixture() -> Dictionary:
	var rules = RuleConfigData.lab_v6_5()
	var setup: Dictionary = (
		SeededGameSetupData.setup_locked_game(
			"Orias",
			"Deimos",
			88241,
			rules
		)
	)

	var game = setup.get(
		"game",
		null
	)

	if game == null:
		return {
			"error": "setup_missing_game",
		}

	var absent = game.get_player(
		0
	)
	var opponent = game.get_player(
		1
	)

	game.winner = -1
	game.win_by = ""

	absent.alive = false
	absent.souls = 0
	absent.vacant_throne_rounds = 0
	absent.lord_present_this_round = false

	opponent.alive = true
	opponent.souls = 0
	opponent.vacant_throne_rounds = 0
	opponent.lord_present_this_round = true

	return {
		"game": game,
		"rules": rules,
		"absent": absent,
		"opponent": opponent,
	}


static func _test_kill_round_does_not_count() -> Dictionary:
	var fixture: Dictionary = _fixture()
	if fixture.has("error"):
		return _fail(
			"vacant_throne_kill_round",
			String(fixture["error"])
		)

	var game = fixture["game"]
	var rules = fixture["rules"]
	var absent = fixture["absent"]
	var opponent = fixture["opponent"]

	absent.lord_present_this_round = true
	absent.alive = false

	VacantThroneEngineData.resolve_end_round(
		game,
		rules
	)

	if int(absent.vacant_throne_rounds) != 0:
		return _fail(
			"vacant_throne_kill_round",
			"The Banishing/removal round incorrectly counted as a full Vacant round."
		)

	if int(opponent.souls) != 0:
		return _fail(
			"vacant_throne_kill_round",
			"The Banishing/removal round awarded a Vacant Throne Soul."
		)

	return _pass(
		"vacant_throne_kill_round"
	)


static func _test_two_full_vacant_rounds_are_safe() -> Dictionary:
	var fixture: Dictionary = _fixture()
	if fixture.has("error"):
		return _fail(
			"vacant_throne_two_safe",
			String(fixture["error"])
		)

	var game = fixture["game"]
	var rules = fixture["rules"]
	var absent = fixture["absent"]
	var opponent = fixture["opponent"]

	VacantThroneEngineData.resolve_end_round(
		game,
		rules
	)
	VacantThroneEngineData.resolve_end_round(
		game,
		rules
	)

	if int(absent.vacant_throne_rounds) != 2:
		return _fail(
			"vacant_throne_two_safe",
			"Two complete Lordless rounds did not produce a Vacant count of exactly 2."
		)

	if int(opponent.souls) != 0:
		return _fail(
			"vacant_throne_two_safe",
			"One of the two grace rounds incorrectly awarded a Soul."
		)

	return _pass(
		"vacant_throne_two_safe"
	)


static func _test_third_and_later_rounds_score() -> Dictionary:
	var fixture: Dictionary = _fixture()
	if fixture.has("error"):
		return _fail(
			"vacant_throne_scoring",
			String(fixture["error"])
		)

	var game = fixture["game"]
	var rules = fixture["rules"]
	var absent = fixture["absent"]
	var opponent = fixture["opponent"]

	for _round_index: int in range(
		4
	):
		VacantThroneEngineData.resolve_end_round(
			game,
			rules
		)

	if int(absent.vacant_throne_rounds) != 4:
		return _fail(
			"vacant_throne_scoring",
			"Four full Lordless rounds did not produce count 4."
		)

	if int(opponent.souls) != 2:
		return _fail(
			"vacant_throne_scoring",
			"Rounds 3 and 4 should have awarded exactly two Souls total."
		)

	return _pass(
		"vacant_throne_scoring"
	)


static func _test_resummon_resets_clock() -> Dictionary:
	var fixture: Dictionary = _fixture()
	if fixture.has("error"):
		return _fail(
			"vacant_throne_resummon_reset",
			String(fixture["error"])
		)

	var game = fixture["game"]
	var rules = fixture["rules"]
	var absent = fixture["absent"]
	var opponent = fixture["opponent"]

	absent.vacant_throne_rounds = 2
	absent.alive = true
	absent.lord_present_this_round = true

	VacantThroneEngineData.resolve_end_round(
		game,
		rules
	)

	if int(absent.vacant_throne_rounds) != 0:
		return _fail(
			"vacant_throne_resummon_reset",
			"Returning a living Lord did not reset the Vacant clock."
		)

	if int(opponent.souls) != 0:
		return _fail(
			"vacant_throne_resummon_reset",
			"A round containing a living Lord incorrectly awarded a Soul."
		)

	absent.vacant_throne_rounds = 2
	absent.alive = false
	absent.lord_present_this_round = true

	VacantThroneEngineData.resolve_end_round(
		game,
		rules
	)

	if int(absent.vacant_throne_rounds) != 0:
		return _fail(
			"vacant_throne_resummon_reset",
			"A Summon-then-Banish round incorrectly counted as fully Vacant."
		)

	return _pass(
		"vacant_throne_resummon_reset"
	)


static func _test_breach_occupant_is_irrelevant() -> Dictionary:
	var fixture: Dictionary = _fixture()
	if fixture.has("error"):
		return _fail(
			"vacant_throne_breach_independent",
			String(fixture["error"])
		)

	var game = fixture["game"]
	var rules = fixture["rules"]
	var absent = fixture["absent"]
	var opponent = fixture["opponent"]

	game.breach = String(
		opponent.lord
	)
	game.breach_owner = int(
		opponent.pid
	)

	absent.vacant_throne_rounds = 2
	absent.lord_present_this_round = false
	absent.alive = false

	VacantThroneEngineData.resolve_end_round(
		game,
		rules
	)

	if (
		int(absent.vacant_throne_rounds) != 3
		or int(opponent.souls) != 1
	):
		return _fail(
			"vacant_throne_breach_independent",
			"Vacant Throne incorrectly depended on which Lord occupied the Breach."
		)

	return _pass(
		"vacant_throne_breach_independent"
	)


static func _test_scoring_soul_can_win_ritual() -> Dictionary:
	var fixture: Dictionary = _fixture()
	if fixture.has("error"):
		return _fail(
			"vacant_throne_ritual_win",
			String(fixture["error"])
		)

	var game = fixture["game"]
	var rules = fixture["rules"]
	var absent = fixture["absent"]
	var opponent = fixture["opponent"]

	absent.vacant_throne_rounds = 2
	opponent.souls = int(
		rules.win_souls
	) - 1

	VacantThroneEngineData.resolve_end_round(
		game,
		rules
	)

	if int(opponent.souls) != int(rules.win_souls):
		return _fail(
			"vacant_throne_ritual_win",
			"Vacant Throne did not award the threshold Soul."
		)

	if (
		int(game.winner) != int(opponent.pid)
		or String(game.win_by) != "Ritual"
	):
		return _fail(
			"vacant_throne_ritual_win",
			"A living opponent reaching the Soul threshold did not win by Ritual."
		)

	return _pass(
		"vacant_throne_ritual_win"
	)


static func _pass(
	name: String
) -> Dictionary:
	return {
		"name": name,
		"passed": true,
		"detail": "",
	}


static func _fail(
	name: String,
	detail: String
) -> Dictionary:
	return {
		"name": name,
		"passed": false,
		"detail": detail,
	}
