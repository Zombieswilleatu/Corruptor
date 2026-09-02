class_name ValakControllerRuntimeTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const PlayableRoundControllerData = preload(
	"res://Prototype/PlayableRoundController.gd"
)


static func run() -> Array[Dictionary]:
	return [
		_test_post_reflex_pause(),
		_test_hold_preserves_essence(),
		_test_projection_equality_no_feedback(),
		_test_projection_whiff_spends(),
	]


static func _fresh_controller(
	lord_guards: Array,
	castle_guards: Array
):
	var controller = PlayableRoundControllerData.new()

	controller.start_match(
		"Valak",
		"Orias",
		88241
	)

	var human = controller.get_human_player()
	var opponent = controller.get_bot_player()

	human.lord = "Valak"
	human.alive = true
	human.valak_life_essence = 5
	human.valak_projection_used_this_round = false

	opponent.lord = "Orias"
	opponent.alive = true
	opponent.lord_guards = lord_guards
	opponent.castle_guards = castle_guards

	controller.resolution_state.clear()
	controller.resolution_state["order"] = [
		0,
		1,
	]
	controller.resolution_state["reflex_result"] = {}

	controller.stage = (
		PlayableRoundControllerData.Stage.RESOLUTION_REFLEX
	)

	return controller


static func _enter_projection(controller) -> Dictionary:
	return controller._after_human_reflex()


static func _test_post_reflex_pause() -> Dictionary:
	var controller = _fresh_controller(
		[
			CardData.new(
				"Wright",
				4
			),
		],
		[]
	)

	_enter_projection(
		controller
	)

	if (
		controller.stage
		!= PlayableRoundControllerData.Stage.RESOLUTION_VALAK_PROJECTION
	):
		return _fail(
			"valak_controller_pause",
			"Post-Reflex continuation did not pause at Valak Projection."
		)

	if int(
		controller.get_human_player().valak_life_essence
	) != 5:
		return _fail(
			"valak_controller_pause",
			"Entering the Projection decision spent Essence before the human chose."
		)

	return _pass(
		"valak_controller_pause"
	)


static func _test_hold_preserves_essence() -> Dictionary:
	var controller = _fresh_controller(
		[
			CardData.new(
				"Wright",
				4
			),
		],
		[]
	)
	var opponent = controller.get_bot_player()

	_enter_projection(
		controller
	)

	controller.resolve_human_valak_projection(
		"",
		0
	)

	if int(
		controller.get_human_player().valak_life_essence
	) != 5:
		return _fail(
			"valak_controller_hold",
			"Hold Essence changed the human Valak pool."
		)

	if opponent.lord_guards.size() != 1:
		return _fail(
			"valak_controller_hold",
			"Hold Essence removed an enemy Guard."
		)

	if (
		controller.stage
		== PlayableRoundControllerData.Stage.RESOLUTION_VALAK_PROJECTION
	):
		return _fail(
			"valak_controller_hold",
			"Hold Essence did not advance beyond the Projection decision."
		)

	return _pass(
		"valak_controller_hold"
	)


static func _test_projection_equality_no_feedback() -> Dictionary:
	var controller = _fresh_controller(
		[
			CardData.new(
				"Wright",
				4
			),
			CardData.new(
				"Vulture",
				5
			),
		],
		[]
	)
	var opponent = controller.get_bot_player()

	_enter_projection(
		controller
	)

	controller.resolve_human_valak_projection(
		"Lord",
		4
	)

	if int(
		controller.get_human_player().valak_life_essence
	) != 1:
		return _fail(
			"valak_controller_equality",
			(
				"Projection 4 should leave exactly 1 Essence. "
				+ "A result of 3 would indicate illegal Essence feedback from the kill."
			)
		)

	if opponent.lord_guards.size() != 1:
		return _fail(
			"valak_controller_equality",
			"Projection 4 did not remove exactly one Lord Guard."
		)

	if int(
		opponent.lord_guards[0].value
	) != 5:
		return _fail(
			"valak_controller_equality",
			"Projection 4 did not kill the equal-value Guard while preserving value 5."
		)

	return _pass(
		"valak_controller_equality"
	)


static func _test_projection_whiff_spends() -> Dictionary:
	var controller = _fresh_controller(
		[],
		[
			CardData.new(
				"Wright",
				4
			),
			CardData.new(
				"Vulture",
				5
			),
		]
	)
	var opponent = controller.get_bot_player()

	_enter_projection(
		controller
	)

	controller.resolve_human_valak_projection(
		"Castle",
		3
	)

	if int(
		controller.get_human_player().valak_life_essence
	) != 2:
		return _fail(
			"valak_controller_whiff",
			"A Projection whiff did not spend the committed 3 Essence."
		)

	if opponent.castle_guards.size() != 2:
		return _fail(
			"valak_controller_whiff",
			"A Projection 3 whiff into [4,5] incorrectly removed a Castle Guard."
		)

	return _pass(
		"valak_controller_whiff"
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
