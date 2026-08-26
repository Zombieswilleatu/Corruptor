# UI2_SUBJECT_CARD_ART_V1
extends SceneTree


const ArtData = preload(
	"res://Prototype/UI2/SubjectCardArtCatalog.gd"
)


const SUITS: Array[String] = [
	"Butcher",
	"Penitent",
	"Vulture",
	"Wright",
]


func _initialize() -> void:
	var failures: int = 0

	var back_path: String = ArtData.BACK_PATH
	var back_ok: bool = (
		not back_path.is_empty()
		and ResourceLoader.exists(back_path)
		and ArtData.texture_for("Penitent", 1, true) != null
	)

	if back_ok:
		print("PASS  shared_back")
	else:
		failures += 1
		print("FAIL  shared_back  %s" % back_path)

	for suit_name: String in SUITS:
		for value: int in range(1, 6):
			var path: String = ArtData.path_for(
				suit_name,
				value,
				false
			)
			var ok: bool = (
				not path.is_empty()
				and ResourceLoader.exists(path)
				and ArtData.texture_for(
					suit_name,
					value,
					false
				) != null
			)

			if ok:
				print(
					"PASS  %s_%d"
					% [
						suit_name.to_lower(),
						value,
					]
				)
			else:
				failures += 1
				print(
					"FAIL  %s_%d  %s"
					% [
						suit_name.to_lower(),
						value,
						path,
					]
				)

	print(
		"Subject card art failures: %d"
		% failures
	)
	quit(failures)
