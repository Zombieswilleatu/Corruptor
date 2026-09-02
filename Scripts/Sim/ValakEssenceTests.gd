class_name ValakEssenceTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameStateData = preload(
	"res://Scripts/Sim/GameState.gd"
)

const PlayerStateData = preload(
	"res://Scripts/Sim/PlayerState.gd"
)

const HuntResolutionEngineData = preload(
	"res://Scripts/Sim/HuntResolutionEngine.gd"
)

const ValakEssenceEngineData = preload(
	"res://Scripts/Sim/ValakEssenceEngine.gd"
)


static func run() -> Array[Dictionary]:
	return [
		_test_gain_and_cap(),
		_test_persistent_duplicate(),
		_test_defensive_partial_spend(),
		_test_projection_equality_kill(),
		_test_projection_whiff_spends(),
		_test_hunt_integration(),
		_test_hunt_defense_integration(),
	]


static func _test_gain_and_cap() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var player := PlayerStateData.new()
	player.lord = "Valak"
	player.alive = true

	var first: Dictionary = (
		ValakEssenceEngineData.gain_from_guards(
			player,
			[
				CardData.new("Wright", 5),
				CardData.new("Vulture", 1),
			],
			rules
		)
	)

	if int(
		first.get(
			"gained",
			0
		)
	) != 4:
		return _fail(
			"valak_gain_cap",
			"Two defeated Guards should grant exactly 4 Essence."
		)

	var second: Dictionary = (
		ValakEssenceEngineData.gain_from_guards(
			player,
			[
				CardData.new("Butcher", 5),
			],
			rules
		)
	)

	if (
		int(
			second.get(
				"gained",
				0
			)
		) != 1
		or int(
			player.valak_life_essence
		) != 5
	):
		return _fail(
			"valak_gain_cap",
			"Life Essence did not cap at 5."
		)

	return _pass(
		"valak_gain_cap"
	)


static func _test_persistent_duplicate() -> Dictionary:
	var player := PlayerStateData.new()
	player.lord = "Valak"
	player.valak_life_essence = 4

	var copy = player.duplicate_state()

	if int(
		copy.valak_life_essence
	) != 4:
		return _fail(
			"valak_duplicate",
			"Life Essence was lost while duplicating PlayerState."
		)

	player.reset_round_state()

	if int(
		player.valak_life_essence
	) != 4:
		return _fail(
			"valak_duplicate",
			"Life Essence incorrectly decayed at round reset."
		)

	return _pass(
		"valak_duplicate"
	)


static func _test_defensive_partial_spend() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var player := PlayerStateData.new()
	player.lord = "Valak"
	player.alive = true
	player.valak_life_essence = 5

	var event: Dictionary = (
		ValakEssenceEngineData.reinforce_hunt(
			player,
			3,
			rules
		)
	)

	if int(
		event.get(
			"spent",
			0
		)
	) != 3:
		return _fail(
			"valak_defense_partial",
			"Defense should spend exactly the incoming 3 Essence."
		)

	if int(
		player.valak_life_essence
	) != 2:
		return _fail(
			"valak_defense_partial",
			"Defense did not preserve the unused 2 Essence."
		)

	return _pass(
		"valak_defense_partial"
	)


static func _test_projection_equality_kill() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var game := GameStateData.new(
		["Valak"],
		["Orias"]
	)
	var valak = game.players[0]
	var enemy = game.players[1]

	valak.lord = "Valak"
	valak.alive = true
	valak.valak_life_essence = 5

	enemy.lord = "Orias"
	enemy.alive = true
	enemy.lord_guards = [
		CardData.new("Wright", 4),
		CardData.new("Vulture", 5),
	]

	var event: Dictionary = (
		ValakEssenceEngineData.resolve_projection(
			game,
			rules,
			0,
			{
				"zone": "Lord",
				"spend": 4,
			}
		)
	)

	if String(
		event.get(
			"victim",
			""
		)
	) != "Wright:4":
		return _fail(
			"valak_projection_equality",
			"Projection 4 did not defeat the value-4 Guard."
		)

	if not bool(
		event.get(
			"equality_kill",
			false
		)
	):
		return _fail(
			"valak_projection_equality",
			"Projection equality was not treated as a kill."
		)

	if int(
		valak.valak_life_essence
	) != 1:
		return _fail(
			"valak_projection_equality",
			"Projection did not spend exactly 4 Essence."
		)

	return _pass(
		"valak_projection_equality"
	)


static func _test_projection_whiff_spends() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var game := GameStateData.new(
		["Valak"],
		["Orias"]
	)
	var valak = game.players[0]
	var enemy = game.players[1]

	valak.lord = "Valak"
	valak.alive = true
	valak.valak_life_essence = 5

	enemy.lord = "Orias"
	enemy.alive = true
	enemy.castle_guards = [
		CardData.new("Wright", 4),
		CardData.new("Vulture", 5),
	]

	var event: Dictionary = (
		ValakEssenceEngineData.resolve_projection(
			game,
			rules,
			0,
			{
				"zone": "Castle",
				"spend": 3,
			}
		)
	)

	if not bool(
		event.get(
			"whiff",
			false
		)
	):
		return _fail(
			"valak_projection_whiff",
			"Projection 3 into [4,5] should whiff."
		)

	if int(
		valak.valak_life_essence
	) != 2:
		return _fail(
			"valak_projection_whiff",
			"A whiff must still spend the chosen 3 Essence."
		)

	if enemy.castle_guards.size() != 2:
		return _fail(
			"valak_projection_whiff",
			"A whiff incorrectly removed a Guard."
		)

	return _pass(
		"valak_projection_whiff"
	)


static func _test_hunt_integration() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var game := GameStateData.new(
		["Valak"],
		["Orias"]
	)
	var attacker = game.players[0]
	var defender = game.players[1]

	attacker.lord = "Valak"
	attacker.alive = true
	attacker.action = "Hunt"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Lord"
	attacker.committed = [
		CardData.new("Butcher", 5),
		CardData.new("Butcher", 2),
	]

	defender.lord = "Orias"
	defender.alive = true
	defender.castles.clear()
	defender.lord_guards = [
		CardData.new("Vulture", 5),
		CardData.new("Wright", 5),
		CardData.new("Penitent", 1),
	]

	var result: Dictionary = (
		HuntResolutionEngineData.resolve(
			game,
			rules,
			0
		)
	)

	var defeated = result.get(
		"guards_defeated",
		[]
	)

	if (
		typeof(defeated) != TYPE_ARRAY
		or defeated.size() != 1
	):
		return _fail(
			"valak_hunt_integration",
			"Fixture should defeat exactly one Guard."
		)

	if int(
		attacker.valak_life_essence
	) != 2:
		return _fail(
			"valak_hunt_integration",
			"One combat Guard defeat should grant exactly 2 Essence."
		)

	# The old extra-kill Siphon must be disabled in the current lab.
	if defender.lord_guards.size() != 2:
		return _fail(
			"valak_hunt_integration",
			"Legacy extra-Guard Siphon still fired in the current lab."
		)

	return _pass(
		"valak_hunt_integration"
	)


static func _test_hunt_defense_integration() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var game := GameStateData.new(
		["Orias"],
		["Valak"]
	)
	var attacker = game.players[0]
	var defender = game.players[1]

	attacker.lord = "Orias"
	attacker.alive = true
	attacker.action = "Hunt"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Lord"
	attacker.committed = [
		CardData.new("Butcher", 5),
		CardData.new("Butcher", 2),
	]

	defender.lord = "Valak"
	defender.alive = true
	defender.threat = 0
	defender.castles.clear()
	defender.lord_guards.clear()
	defender.valak_life_essence = 5

	var result: Dictionary = (
		HuntResolutionEngineData.resolve(
			game,
			rules,
			0
		)
	)

	if (
		bool(
			result.get(
				"banished",
				false
			)
		)
		or not defender.alive
	):
		return _fail(
			"valak_hunt_defense",
			"Stored Essence failed to protect Valak from the Hunt."
		)

	if int(
		defender.valak_life_essence
	) != 0:
		return _fail(
			"valak_hunt_defense",
			"The incoming Hunt should consume all 5 stored Essence."
		)

	return _pass(
		"valak_hunt_defense"
	)


static func _pass(
	name: String
) -> Dictionary:
	return {
		"name": name,
		"passed": true,
		"reason": "",
	}


static func _fail(
	name: String,
	reason: String
) -> Dictionary:
	return {
		"name": name,
		"passed": false,
		"reason": reason,
	}
