extends SceneTree

const ASSETS: Dictionary = {
	"res://ConceptImages/Splash/Logo1.png": "Texture2D",
	"res://ConceptImages/Menus/TitleCard.png": "Texture2D",
	"res://ConceptImages/StoryBoard/IdyllicConcept.png": "Texture2D",
	"res://ConceptImages/StoryBoard/DeathConcept.png": "Texture2D",
	"res://ConceptImages/StoryBoard/ResurrectionConcept.png": "Texture2D",
	"res://ConceptImages/StoryBoard/WallConcept.png": "Texture2D",
	"res://ConceptImages/StoryBoard/CapitalConcept.png": "Texture2D",
	"res://ConceptImages/StoryBoard/SoupConcept.png": "Texture2D",
	"res://ConceptImages/StoryBoard/ConfrontationConcept.png": "Texture2D",
	"res://ConceptImages/StoryBoard/DespairConcept.png": "Texture2D",
	"res://Music/MenuThemeConcept.mp3": "AudioStream",
	"res://Fonts/Grenze_Gotisch/static/GrenzeGotisch-Regular.ttf": "Font",
	"res://Prototype/Splash/GraveGamesSplash.tscn": "PackedScene",
	"res://Prototype/Prologue/PrologueRunner.tscn": "PackedScene",
	"res://Prototype/TitleScreen/TitleScreen.tscn": "PackedScene",
}


func _initialize() -> void:
	var failures: int = 0
	for path: String in ASSETS:
		if not FileAccess.file_exists(path):
			printerr("INTRO MISSING FILE: " + path)
			failures += 1
			continue
		var resource: Resource = ResourceLoader.load(path)
		if resource == null or not resource.is_class(ASSETS[path]):
			printerr("INTRO IMPORT/LOAD FAILED: " + path)
			failures += 1
	if failures:
		printerr("Intro cannot start: %d missing or unloadable assets. See paths above." % failures)
		quit(1)
	else:
		print("INTRO ASSETS OK: splash, eight illustrations, music, font and title.")
		quit(0)
