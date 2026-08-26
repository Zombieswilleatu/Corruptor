# UI2_LORD_CARD_STAT_SLOTS_V1
extends SceneTree


const GameSetupData = preload(
	"res://Scripts/Sim/GameSetup.gd"
)


const LORDS: Array[String] = [
	"Orias",
	"Deimos",
	"Valak",
	"Kroni",
	"Kalligan",
	"Gremory",
	"Odradek",
	"Kanifous",
	"Humbaba",
]


func _first_int(
	data: Dictionary,
	keys: Array,
	fallback: int = -999
) -> int:
	for raw_key in keys:
		var key: String = String(raw_key)
		if data.has(key):
			return int(data.get(key, fallback))
	return fallback


func _initialize() -> void:
	var failures: int = 0

	for lord_name: String in LORDS:
		var data: Dictionary = GameSetupData.LORD_CONTENT.get(
			lord_name,
			{}
		)
		var summon_value: int = _first_int(
			data,
			["summon_cost", "summon", "cost", "s"]
		)
		var fracture_value: int = _first_int(
			data,
			["fracture", "return_threat", "r"]
		)

		if summon_value == -999 or fracture_value == -999:
			failures += 1
			print(
				"FAIL  %s  summon=%d fracture=%d keys=%s"
				% [
					lord_name.to_lower(),
					summon_value,
					fracture_value,
					str(data.keys()),
				]
			)
			continue

		print(
			"PASS  %s  summon=%d fracture=%d"
			% [
				lord_name.to_lower(),
				summon_value,
				fracture_value,
			]
		)

	print(
		"Lord stat-slot failures: %d" % failures
	)
	quit(failures)
