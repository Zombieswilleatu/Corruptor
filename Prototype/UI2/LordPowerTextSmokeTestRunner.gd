# UI2_LORD_BACK_POWER_TEXT_V1
extends SceneTree


const PowerTextData = preload(
	"res://Prototype/UI2/LordPowerText.gd"
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


func _initialize() -> void:
	var failures: int = 0

	var font_ok: bool = (
		ResourceLoader.exists(
			PowerTextData.POWER_FONT_PATH
		)
		and PowerTextData.font() != null
	)

	if font_ok:
		print(
			"PASS  grenze_gotisch_font  %s"
			% PowerTextData.POWER_FONT_PATH
		)
	else:
		failures += 1
		print(
			"FAIL  grenze_gotisch_font  %s"
			% PowerTextData.POWER_FONT_PATH
		)

	for lord_name: String in LORDS:
		var count: int = (
			PowerTextData.power_count(
				lord_name
			)
		)
		var text: String = (
			PowerTextData.bbcode_for(
				lord_name
			)
		)

		var ok: bool = (
			count > 0
			and not text.is_empty()
			and text.contains(
				lord_name.to_upper()
			)
		)

		if ok:
			print(
				"PASS  %s  powers=%d"
				% [
					lord_name.to_lower(),
					count,
				]
			)
		else:
			failures += 1
			print(
				"FAIL  %s  powers=%d"
				% [
					lord_name.to_lower(),
					count,
				]
			)

	print(
		"Lord back power-text failures: %d"
		% failures
	)
	quit(failures)
