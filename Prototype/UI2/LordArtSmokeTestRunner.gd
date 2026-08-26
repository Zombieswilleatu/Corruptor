# UI2_LORD_CARD_ART_V1
extends SceneTree


const LordArtCatalogData = preload(
	"res://Prototype/UI2/LordArtCatalog.gd"
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

	for lord_name: String in LORDS:
		for is_back: bool in [false, true]:
			var side: String = "back" if is_back else "front"
			var path: String = LordArtCatalogData.path_for(
				lord_name,
				is_back
			)
			var ok: bool = (
				not path.is_empty()
				and ResourceLoader.exists(path)
				and LordArtCatalogData.texture_for(
					lord_name,
					is_back
				) != null
			)

			if ok:
				print(
					"PASS  %s_%s" % [
						lord_name.to_lower(),
						side,
					]
				)
			else:
				failures += 1
				print(
					"FAIL  %s_%s  %s" % [
						lord_name.to_lower(),
						side,
						path,
					]
				)

	print(
		"Lord art failures: %d" % failures
	)
	quit(failures)
