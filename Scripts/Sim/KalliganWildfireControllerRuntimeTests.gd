class_name KalliganWildfireControllerRuntimeTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const RoundEngineData = preload(
	"res://Scripts/Sim/RoundEngine.gd"
)

const PlayableRoundControllerData = preload(
	"res://Prototype/PlayableRoundController.gd"
)


static func run() -> Array[Dictionary]:
	return [
		_test_repair_pause_before_commit(),
		_test_repair_castle_choice_single_commit(),
		_test_siege_pause_before_commit(),
		_test_siege_lord_choice_single_commit(),
		_test_default_repair_still_targets_lord(),
	]


static func _fresh_controller():
	var controller = PlayableRoundControllerData.new()
	controller.start_match(
		"Kalligan",
		"Orias",
		88241
	)
	return controller


static func _prepare_repair_controller():
	var controller = _fresh_controller()
	var human = controller.get_human_player()
	var opponent = controller.get_bot_player()

	human.lord = "Kalligan"
	human.alive = true

	# SiegeEngine is one of Kalligan's normal opening Castles, so this avoids
	# fabricating a Castle type that setup never initialized for the player.
	if not human.castles.has(
		"SiegeEngine"
	):
		human.castles.append(
			"SiegeEngine"
		)

	human.ruined_castles.erase(
		"SiegeEngine"
	)
	human.castle_integrity[
		"SiegeEngine"
	] = 10

	human.hand = [
		CardData.new(
			"Wright",
			5
		),
	]
	human.garrison.clear()

	# Keep a legal enemy Castle zone available for the human Scorch choice.
	opponent.castles.clear()
	opponent.castles.append(
		"Keep"
	)
	opponent.castles.append(
		"Stockpile"
	)
	opponent.ruined_castles.clear()
	opponent.castle_integrity = {
		"Keep": 14,
		"Stockpile": 14,
	}

	controller.game.persist_scorch_pid = -1
	controller.game.persist_scorch_type = ""
	controller.game.persist_scorch_level = 0

	controller.pending_kalligan_scorch.clear()
	controller.stage = (
		PlayableRoundControllerData.Stage.REPAIR
	)

	return controller


static func _repair_decision() -> Dictionary:
	return {
		"action": "repair",
		"castle": "SiegeEngine",
		"payment": [
			"Wright:5",
		],
		"use_token": false,
	}


static func _test_repair_pause_before_commit() -> Dictionary:
	var controller = _prepare_repair_controller()
	var human = controller.get_human_player()

	var integrity_before: int = int(
		human.castle_integrity.get(
			"SiegeEngine",
			-1
		)
	)
	var hand_before: int = human.hand.size()
	var discard_before: int = controller.game.discard.size()

	var result: Dictionary = controller.resolve_human_repair(
		_repair_decision()
	)

	if (
		controller.stage
		!= PlayableRoundControllerData.Stage.KALLIGAN_SCORCH
	):
		return _fail(
			"kalligan_repair_pause",
			"Successful Kalligan Repair preview did not pause for Scorch choice."
		)

	if int(
		human.castle_integrity.get(
			"SiegeEngine",
			-1
		)
	) != integrity_before:
		return _fail(
			"kalligan_repair_pause",
			"Repair preview mutated live Castle Integrity before Scorch choice."
		)

	if human.hand.size() != hand_before:
		return _fail(
			"kalligan_repair_pause",
			"Repair preview consumed the live payment card before Scorch choice."
		)

	if controller.game.discard.size() != discard_before:
		return _fail(
			"kalligan_repair_pause",
			"Repair preview changed the live discard pile."
		)

	if (
		int(
			controller.game.persist_scorch_pid
		) != -1
		or not String(
			controller.game.persist_scorch_type
		).is_empty()
	):
		return _fail(
			"kalligan_repair_pause",
			"Repair preview placed Scorch before the human selected a zone."
		)

	if String(
		controller.pending_kalligan_scorch.get(
			"source",
			""
		)
	) != "repair":
		return _fail(
			"kalligan_repair_pause",
			"Repair pause did not preserve the pending Repair context."
		)

	return _pass(
		"kalligan_repair_pause"
	)


static func _test_repair_castle_choice_single_commit() -> Dictionary:
	var controller = _prepare_repair_controller()
	var human = controller.get_human_player()
	var opponent = controller.get_bot_player()

	var integrity_before: int = int(
		human.castle_integrity.get(
			"SiegeEngine",
			-1
		)
	)

	controller.resolve_human_repair(
		_repair_decision()
	)

	var result: Dictionary = (
		controller.resolve_human_kalligan_scorch(
			"Castle"
		)
	)

	if String(
		result.get(
			"action",
			""
		)
	) == "invalid":
		return _fail(
			"kalligan_repair_castle_choice",
			"Choosing Castle after the Repair pause rejected the committed Repair."
		)

	if int(
		human.castle_integrity.get(
			"SiegeEngine",
			-1
		)
	) <= integrity_before:
		return _fail(
			"kalligan_repair_castle_choice",
			"The committed Repair did not restore Castle Integrity."
		)

	if human.hand.size() != 0:
		return _fail(
			"kalligan_repair_castle_choice",
			"The single Wright payment was not consumed exactly once."
		)

	if (
		int(
			controller.game.persist_scorch_pid
		) != int(
			opponent.pid
		)
		or String(
			controller.game.persist_scorch_type
		) != "Castle"
	):
		return _fail(
			"kalligan_repair_castle_choice",
			"Repair Scorch did not land on the human-selected enemy Castle zone."
		)

	if not controller.pending_kalligan_scorch.is_empty():
		return _fail(
			"kalligan_repair_castle_choice",
			"Repair Scorch context survived after the choice was committed."
		)

	if (
		controller.stage
		== PlayableRoundControllerData.Stage.KALLIGAN_SCORCH
	):
		return _fail(
			"kalligan_repair_castle_choice",
			"Controller remained stuck in Kalligan Scorch after committing Repair."
		)

	return _pass(
		"kalligan_repair_castle_choice"
	)


static func _prepare_siege_controller():
	var controller = _fresh_controller()
	var human = controller.get_human_player()
	var opponent = controller.get_bot_player()

	human.lord = "Kalligan"
	human.alive = true
	human.action = "Siege"
	human.tgt_pid = int(
		opponent.pid
	)
	human.tgt_type = "Castle"
	human.committed = [
		CardData.new(
			"Butcher",
			5
		),
		CardData.new(
			"Butcher",
			5
		),
		CardData.new(
			"Butcher",
			4
		),
	]

	opponent.lord = "Orias"
	opponent.alive = true
	opponent.castles.clear()
	opponent.castles.append(
		"Keep"
	)
	opponent.castles.append(
		"Stockpile"
	)
	opponent.ruined_castles.clear()
	opponent.castle_integrity = {
		"Keep": 14,
		"Stockpile": 14,
	}
	opponent.castle_guards.clear()
	opponent.committed.clear()
	opponent.sigils = {
		"Lord": "",
		"Castle": "",
	}

	controller.game.persist_scorch_pid = -1
	controller.game.persist_scorch_type = ""
	controller.game.persist_scorch_level = 0

	controller.pending_kalligan_scorch.clear()
	controller.resolution_state.clear()
	controller.stage = (
		PlayableRoundControllerData.Stage.RESOLUTION_ACTION
	)

	return controller


static func _siege_options() -> Dictionary:
	return {
		"target_castle": "Keep",
		"consume_siege": false,
		"use_inferno": false,
	}


static func _test_siege_pause_before_commit() -> Dictionary:
	var controller = _prepare_siege_controller()
	var human = controller.get_human_player()
	var opponent = controller.get_bot_player()

	var souls_before: int = int(
		human.souls
	)
	var integrity_before: int = int(
		opponent.castle_integrity.get(
			"Keep",
			-1
		)
	)

	var result: Dictionary = (
		controller.resolve_human_resolution_action(
			_siege_options()
		)
	)

	if (
		controller.stage
		!= PlayableRoundControllerData.Stage.KALLIGAN_SCORCH
	):
		return _fail(
			"kalligan_siege_pause",
			"A Castle-ruining Kalligan Siege did not pause for Wildfire choice."
		)

	if (
		not opponent.castles.has(
			"Keep"
		)
		or opponent.ruined_castles.has(
			"Keep"
		)
		or int(
			opponent.castle_integrity.get(
				"Keep",
				-1
			)
		) != integrity_before
	):
		return _fail(
			"kalligan_siege_pause",
			"Siege preview mutated the live Keep before Wildfire choice."
		)

	if int(
		human.souls
	) != souls_before:
		return _fail(
			"kalligan_siege_pause",
			"Siege preview awarded live Souls before Wildfire choice."
		)

	if (
		int(
			controller.game.persist_scorch_pid
		) != -1
		or not String(
			controller.game.persist_scorch_type
		).is_empty()
	):
		return _fail(
			"kalligan_siege_pause",
			"Siege preview placed live Scorch before the human selected a zone."
		)

	if String(
		controller.pending_kalligan_scorch.get(
			"source",
			""
		)
	) != "wildfire":
		return _fail(
			"kalligan_siege_pause",
			"Siege pause did not preserve Wildfire pending context."
		)

	return _pass(
		"kalligan_siege_pause"
	)


static func _test_siege_lord_choice_single_commit() -> Dictionary:
	var controller = _prepare_siege_controller()
	var human = controller.get_human_player()
	var opponent = controller.get_bot_player()

	var souls_before: int = int(
		human.souls
	)

	controller.resolve_human_resolution_action(
		_siege_options()
	)

	var result: Dictionary = (
		controller.resolve_human_kalligan_scorch(
			"Lord"
		)
	)

	if String(
		result.get(
			"action",
			""
		)
	) == "invalid":
		return _fail(
			"kalligan_siege_lord_choice",
			"Choosing Lord after the Wildfire pause rejected the Siege."
		)

	if (
		opponent.castles.has(
			"Keep"
		)
		or not opponent.ruined_castles.has(
			"Keep"
		)
		or int(
			opponent.castle_integrity.get(
				"Keep",
				-1
			)
		) != 0
	):
		var pending_debug: Dictionary = Dictionary(
			controller.resolution_state.get(
				"pending_action_result",
				{}
			)
		)
		return _fail(
			"kalligan_siege_lord_choice",
			(
				"The committed Siege did not Ruin Keep exactly as previewed. "
				+ "castles=%s ruined=%s integrity=%s pending=%s"
			)
			% [
				str(opponent.castles),
				str(opponent.ruined_castles),
				str(opponent.castle_integrity),
				str(pending_debug),
			]
		)

	if not opponent.castles.has(
		"Stockpile"
	):
		return _fail(
			"kalligan_siege_lord_choice",
			"The non-targeted surviving Stockpile was incorrectly removed."
		)

	if (
		int(
			controller.game.persist_scorch_pid
		) != int(
			opponent.pid
		)
		or String(
			controller.game.persist_scorch_type
		) != "Lord"
	):
		return _fail(
			"kalligan_siege_lord_choice",
			"Wildfire did not override the Siege's normal Castle Scorch with the human-selected Lord zone."
		)

	var pending_action: Dictionary = Dictionary(
		controller.resolution_state.get(
			"pending_action_result",
			{}
		)
	)

	if String(
		pending_action.get(
			"wildfire_zone",
			""
		)
	) != "Lord":
		return _fail(
			"kalligan_siege_lord_choice",
			"Reported pending Siege result did not retain the human Wildfire zone."
		)

	if (
		controller.stage
		!= PlayableRoundControllerData.Stage.RESOLUTION_VESSEL
	):
		return _fail(
			"kalligan_siege_lord_choice",
			"After the real Siege, controller did not advance to the normal Vessel aftermath seam."
		)

	# Existing equal-strength Castle ruination pays 2 Souls. A delta of 4 would
	# be the obvious signature of accidentally resolving the Siege twice.
	var soul_delta: int = int(
		human.souls
	) - souls_before

	if soul_delta != 2:
		return _fail(
			"kalligan_siege_lord_choice",
			"Expected exactly one Castle-ruination Soul payout (delta 2), got %d."
			% soul_delta
		)

	if not controller.pending_kalligan_scorch.is_empty():
		return _fail(
			"kalligan_siege_lord_choice",
			"Wildfire pending context survived after the Siege was committed."
		)

	return _pass(
		"kalligan_siege_lord_choice"
	)


static func _test_default_repair_still_targets_lord() -> Dictionary:
	var controller = _prepare_repair_controller()
	var game = controller.game
	var human = controller.get_human_player()
	var opponent = controller.get_bot_player()

	game.persist_scorch_pid = -1
	game.persist_scorch_type = ""
	game.persist_scorch_level = 0

	var result: Dictionary = RoundEngineData.resolve_repair_player(
		game,
		int(
			human.pid
		),
		controller.rules,
		_repair_decision()
	)

	if String(
		result.get(
			"action",
			""
		)
	) != "repair":
		return _fail(
			"kalligan_default_repair_lord",
			"Direct/default Kalligan Repair fixture did not resolve as a Repair."
		)

	if (
		int(
			game.persist_scorch_pid
		) != int(
			opponent.pid
		)
		or String(
			game.persist_scorch_type
		) != "Lord"
	):
		return _fail(
			"kalligan_default_repair_lord",
			"Omitted/default Repair Scorch no longer preserves the historical Lord target."
		)

	return _pass(
		"kalligan_default_repair_lord"
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
