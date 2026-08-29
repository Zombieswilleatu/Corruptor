extends SceneTree

const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)
const PlayerStateData = preload(
	"res://Scripts/Sim/PlayerState.gd"
)
const FractureEngineData = preload(
	"res://Scripts/Sim/FractureEngine.gd"
)
const SummonEngineData = preload(
	"res://Scripts/Sim/SummonEngine.gd"
)
const RuleConfigData = preload(
	"res://Scripts/Sim/RuleConfig.gd"
)

var failures: int = 0


func _init() -> void:
	_test_values()
	_test_subject_spread_and_hand_immunity()
	_test_garrison_is_subject()
	_test_marcher_is_subject()
	_test_infrastructure_spread()
	_test_infrastructure_ruin()
	_test_summon_baseline()

	print("Fracture failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _test_values() -> void:
	var expected: Dictionary = {
		"Orias": 0,
		"Deimos": 0,
		"Valak": 1,
		"Kroni": 1,
		"Kalligan": 1,
		"Gremory": 2,
		"Odradek": 2,
		"Kanifous": 1,
		"Humbaba": 2,
	}
	for lord_id: String in expected:
		if FractureEngineData.fracture_value(lord_id) != int(expected[lord_id]):
			_fail("values", "%s Fracture mismatch" % lord_id)
			return
	_pass("values")


func _test_subject_spread_and_hand_immunity() -> void:
	var target = _player("Gremory")
	var lord_card = CardData.new("Penitent", 5)
	var castle_card = CardData.new("Penitent", 3)
	var hand_card = CardData.new("Butcher", 5)
	target.lord_guards.append(lord_card)
	target.castle_guards.append(castle_card)
	target.hand.append(hand_card)

	var result: Dictionary = FractureEngineData.resolve(
		null,
		RuleConfigData.lab_v6_5(),
		null,
		target,
		"subjects"
	)
	var reveal_events: Array = result.get("events", [])
	if (
		not bool(lord_card.guard_revealed)
		or not bool(castle_card.guard_revealed)
		or reveal_events.size() < 2
		or not bool(reveal_events[0].get("newly_revealed", false))
		or not bool(reveal_events[1].get("newly_revealed", false))
	):
		_fail("guard_reveal", "Fractured Guards did not flip face-up.")
		return
	if (
		int(lord_card.value) != 3
		or int(castle_card.value) != 1
		or int(hand_card.value) != 5
		or result.get("events", []).size() != 2
	):
		_fail("subject_spread", str(result))
		return
	_pass("subject_spread")


func _test_garrison_is_subject() -> void:
	var target = _player("Valak")
	var card = CardData.new("Penitent", 5)
	target.garrison.append(card)
	FractureEngineData.resolve(
		null,
		RuleConfigData.lab_v6_5(),
		null,
		target,
		"subjects"
	)
	if int(card.value) != 3:
		_fail("garrison_subject", "Garrison 5 did not mar to 3")
		return
	_pass("garrison_subject")


func _test_marcher_is_subject() -> void:
	var target = _player("Valak")
	var card = CardData.new("Vulture", 5)
	target.marchers.append({
		"card": card,
		"value": 4,
		"lane": "Lord",
		"pos": 1,
	})
	var result: Dictionary = FractureEngineData.resolve(
		null,
		RuleConfigData.lab_v6_5(),
		null,
		target,
		"subjects"
	)
	var marcher: Dictionary = target.marchers[0]
	var events: Array = result.get("events", [])
	if (
		int(card.value) != 3
		or int(marcher.get("value", -1)) != 2
		or events.is_empty()
		or String(events[0].get("zone", "")) != "Marcher"
	):
		_fail("marcher_subject", str(result))
		return
	_pass("marcher_subject")


func _test_infrastructure_spread() -> void:
	var target = _player("Gremory")
	target.castles.clear()
	target.castles.append("Keep")
	target.castles.append("Bastion")
	target.castle_integrity["Keep"] = 10
	target.castle_integrity["Bastion"] = 8
	var result: Dictionary = FractureEngineData.resolve(
		null,
		RuleConfigData.lab_v6_5(),
		null,
		target,
		"infrastructure"
	)
	if (
		int(target.castle_integrity.get("Keep", -1)) != 8
		or int(target.castle_integrity.get("Bastion", -1)) != 6
		or result.get("events", []).size() != 2
	):
		_fail("infrastructure_spread", str(result))
		return
	_pass("infrastructure_spread")


func _test_infrastructure_ruin() -> void:
	var target = _player("Valak")
	target.castles.clear()
	target.ruined_castles.clear()
	target.castles.append("Bastion")
	target.castle_integrity["Bastion"] = 2
	FractureEngineData.resolve(
		null,
		RuleConfigData.lab_v6_5(),
		null,
		target,
		"infrastructure"
	)
	if (
		target.castles.has("Bastion")
		or not target.ruined_castles.has("Bastion")
		or int(target.castle_integrity.get("Bastion", -1)) != 0
	):
		_fail("infrastructure_ruin", "Bastion did not Ruin at zero Integrity")
		return
	_pass("infrastructure_ruin")


func _test_summon_baseline() -> void:
	var rules = RuleConfigData.lab_v6_5()
	var player = _player("Gremory")
	player.return_threat_override = -1
	player.vessel_offered_lord = ""
	if SummonEngineData.return_threat_for(player, rules, "Gremory") != 0:
		_fail("summon_baseline", "ordinary Gremory did not return at Threat 0")
		return

	player.return_threat_override = 2
	if SummonEngineData.return_threat_for(player, rules, "Gremory") != 2:
		_fail("summon_baseline", "explicit override was not honored")
		return

	player.return_threat_override = -1
	player.vessel_offered_lord = "Gremory"
	if SummonEngineData.return_threat_for(player, rules, "Gremory") != 2:
		_fail("summon_baseline", "Vessel Threat-2 return was not honored")
		return
	_pass("summon_baseline")


func _player(lord_id: String):
	var pool: Array[String] = [lord_id]
	var player = PlayerStateData.new(1, pool)
	player.lord = lord_id
	player.alive = true
	return player


func _pass(name: String) -> void:
	print("PASS  %s" % name)


func _fail(name: String, reason: String) -> void:
	failures += 1
	print("FAIL  %s: %s" % [name, reason])
