# HUMAN_AGENCY_RUNTIME_CONTRACT_LAYER_B0_V1
class_name HumanDecisionContractTests
extends RefCounted

const CONTROLLER_PATH := "res://Prototype/PlayableRoundController.gd"
const ACTION_ZONE_PATH := "res://Prototype/UI2/ActionZone.gd"
const PLAYABLE_UI2_PATH := "res://Prototype/UI2/PlayableUI2.gd"
const LORD_TEXT_PATH := "res://Prototype/UI2/LordPowerText.gd"
const ROUND_ENGINE_PATH := "res://Scripts/Sim/RoundEngine.gd"
const SIEGE_ENGINE_PATH := "res://Scripts/Sim/SiegeResolutionEngine.gd"


static func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {
		"name": name,
		"passed": passed,
		"text": "%s  %s - %s" % [
			"PASS" if passed else "FAIL",
			name,
			message,
		],
	}


static func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


static func _function_block(source: String, function_name: String) -> String:
	var needle := "func %s(" % function_name
	var start := source.find(needle)
	if start < 0:
		return ""

	var next := source.find(
		"\nfunc ",
		start + needle.length()
	)
	if next < 0:
		return source.substr(start)

	return source.substr(start, next - start)


static func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	var controller := _read(CONTROLLER_PATH)
	var action_zone := _read(ACTION_ZONE_PATH)
	var playable_ui2 := _read(PLAYABLE_UI2_PATH)
	var lord_text := _read(LORD_TEXT_PATH)
	var round_engine := _read(ROUND_ENGINE_PATH)
	var siege_engine := _read(SIEGE_ENGINE_PATH)

	results.append_array(_test_orias(controller))
	results.append_array(_test_valak(controller, lord_text))
	results.append_array(_test_kroni(controller, lord_text))
	results.append_array(
		_test_kalligan(
			controller,
			action_zone,
			playable_ui2,
			round_engine,
			siege_engine
		)
	)
	results.append_array(_test_gremory(controller))
	results.append_array(_test_odradek(controller, lord_text))
	results.append_array(_test_kanifous(controller))
	results.append_array(_test_humbaba(controller))

	return results


static func _test_orias(controller: String) -> Array[Dictionary]:
	var block := _function_block(controller, "resolve_human_snare")
	var ok := (
		controller.contains("Stage.DEVELOPMENT_SNARE")
		and controller.contains('return _awaiting("orias_snare")')
		and block.contains("activate: bool")
		and block.contains("if activate else")
		and block.contains('"pass": true')
	)

	return [
		_result(
			"ORIAS/SNARE/OPTIONAL_ACTIVATION",
			ok,
			"controller stops before Snare and exposes activate/pass"
		),
	]


static func _test_valak(
	controller: String,
	lord_text: String
) -> Array[Dictionary]:
	var projection_production := (
		controller.contains("Stage.RESOLUTION_VALAK_PROJECTION")
		and controller.contains("resolve_human_valak_projection")
		and controller.contains('return _awaiting("valak_projection")')
		and lord_text.contains("Projection")
		and lord_text.contains("Life Essence")
	)

	return [
		_result(
			"VALAK/PROJECTION/PRODUCTION_TRUTH",
			projection_production,
			(
				"production controller exposes Projection and current Lord text declares Life Essence"
				if projection_production
				else "PRODUCTION_DRIFT: Valak Projection controller/text seam is incomplete"
			)
		),
	]


static func _test_kroni(
	controller: String,
	lord_text: String
) -> Array[Dictionary]:
	var consume_auto := (
		lord_text.contains("[b]Consume[/b]")
		and lord_text.contains("after the first combat")
		and not controller.contains("KRONI_CONSUME")
		and not controller.contains("resolve_human_kroni_consume")
	)

	var ravenous_auto := (
		lord_text.contains("[b]Ravenous[/b]")
		and lord_text.contains("At Hunger 3+")
		and not controller.contains("KRONI_RAVENOUS")
		and not controller.contains("resolve_human_kroni_ravenous")
	)

	return [
		_result(
			"KRONI/CONSUME/AUTOMATIC",
			consume_auto,
			"Consume has no human activation path"
		),
		_result(
			"KRONI/RAVENOUS/AUTOMATIC",
			ravenous_auto,
			"Ravenous has no human activation path"
		),
	]


static func _test_kalligan(
	controller: String,
	action_zone: String,
	playable_ui2: String,
	round_engine: String,
	siege_engine: String
) -> Array[Dictionary]:
	var wildfire_human_path := (
		controller.contains("KALLIGAN_SCORCH")
		and controller.contains("resolve_human_kalligan_scorch")
	)

	var wildfire_auto_target := (
		round_engine.contains("game.persist_scorch_pid = int(opponent.pid)")
		and round_engine.contains('game.persist_scorch_type = "Lord"')
	)

	var inferno_selection := (
		action_zone.contains("allow_inferno")
		and action_zone.contains("Inferno")
		and playable_ui2.contains('"use_inferno"')
	)

	var unsafe_default := (
		siege_engine.contains(
			'"use_inferno",\n\t\t\ttrue'
		)
		or siege_engine.contains('"use_inferno", true')
	)

	return [
		_result(
			"KALLIGAN/WILDFIRE/HUMAN_DECISION",
			wildfire_human_path and not wildfire_auto_target,
			(
				"human chooses Scorch zone"
				if wildfire_human_path and not wildfire_auto_target
				else "HUMAN_DECISION_MISSING: production auto-targets Scorch"
			)
		),
		_result(
			"KALLIGAN/INFERNO/HUMAN_SELECTION",
			inferno_selection,
			"normal vs Inferno is exposed as explicit human selection"
		),
		_result(
			"KALLIGAN/INFERNO/DEFAULT_SAFE",
			not unsafe_default,
			(
				"omitted Inferno does not silently activate"
				if not unsafe_default
				else "HUMAN_DEFAULT_ACTIVATES: omitted use_inferno defaults true"
			)
		),
	]


static func _test_gremory(controller: String) -> Array[Dictionary]:
	var block := _function_block(controller, "resolve_human_gremory")
	var ok := (
		controller.contains("Stage.RESOLUTION_GREMORY")
		and controller.contains('return _awaiting("gremory")')
		and block.contains("payment_ids")
		and block.contains('"pass": true')
		and block.contains("if not payment_ids.is_empty()")
	)

	return [
		_result(
			"GREMORY/INEVITABLE_RUIN/OPTIONAL_ACTIVATION",
			ok,
			"controller exposes pass or explicit payment"
		),
	]


static func _test_odradek(
	controller: String,
	lord_text: String
) -> Array[Dictionary]:
	var auto := (
		lord_text.contains("[b]Reconfiguration[/b]")
		and lord_text.contains("At 3 tokens")
		and not controller.contains("ODRADEK_RECONFIGURATION")
		and not controller.contains("resolve_human_odradek_reconfiguration")
	)

	return [
		_result(
			"ODRADEK/RECONFIGURATION/AUTOMATIC",
			auto,
			"Reconfiguration has no optional human activation path"
		),
	]


static func _test_kanifous(controller: String) -> Array[Dictionary]:
	var block := _function_block(
		controller,
		"resolve_human_kanifous_invoke"
	)

	var triggered_choice := (
		controller.contains("stage = Stage.KANIFOUS_INVOKE")
		and controller.contains('return _awaiting("kanifous_invoke")')
		and block.contains("chosen_card: String")
		and block.contains("toll_card: String")
		and not block.contains("activate: bool")
		and not block.contains('"pass": true')
	)

	return [
		_result(
			"KANIFOUS/INVOKE/TRIGGERED_CHOICE",
			triggered_choice,
			"Reveal forces Invoke when available; human chooses card/toll, not activation"
		),
	]


static func _test_humbaba(controller: String) -> Array[Dictionary]:
	var block := _function_block(
		controller,
		"resolve_human_humbaba_toll"
	)

	var ok := (
		controller.contains("Stage.RESOLUTION_HUMBABA_TOLL")
		and controller.contains('return _awaiting("humbaba_toll")')
		and block.contains("castle_name: String")
		and block.contains('"pass": true')
		and block.contains("if not castle_name.is_empty()")
	)

	return [
		_result(
			"HUMBABA/TOLL/OPTIONAL_ACTIVATION",
			ok,
			"controller stops and accepts pass or Castle target"
		),
	]
