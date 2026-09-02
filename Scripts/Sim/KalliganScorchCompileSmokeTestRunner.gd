# KALLIGAN_SCORCH_HUMAN_CHOICE_V1_1
extends SceneTree

const ControllerData = preload(
	"res://Prototype/PlayableRoundController.gd"
)
const RoundEngineData = preload(
	"res://Scripts/Sim/RoundEngine.gd"
)
const ActionZoneData = preload(
	"res://Prototype/UI2/ActionZone.gd"
)
const PlayableUI2Data = preload(
	"res://Prototype/UI2/PlayableUI2.gd"
)
const PlayablePrototypeData = preload(
	"res://Prototype/PlayablePrototype.gd"
)


func _initialize() -> void:
	print("")
	print("============================================================")
	print("KALLIGAN SCORCH COMPILE SMOKE")
	print("============================================================")
	print("PASS  controller / RoundEngine / root UI / UI2 scripts compile")
	print("")
	quit(0)
