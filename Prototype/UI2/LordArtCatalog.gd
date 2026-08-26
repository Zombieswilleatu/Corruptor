# UI2_LORD_CARD_ART_V1
class_name UI2LordArtCatalog
extends RefCounted


const ART: Dictionary = {
	"Orias": {
		"front": "res://ConceptImages/Orias/OriasFront.png",
		"back": "res://ConceptImages/Orias/OriasBack.png",
	},
	"Deimos": {
		"front": "res://ConceptImages/Deimos/DeimosFront.png",
		"back": "res://ConceptImages/Deimos/DeimosBack.png",
	},
	"Valak": {
		"front": "res://ConceptImages/Valak/ValakFront.png",
		"back": "res://ConceptImages/Valak/ValakBack.png",
	},
	"Kroni": {
		"front": "res://ConceptImages/Kroni/KroniFront.png",
		"back": "res://ConceptImages/Kroni/KroniBack.png",
	},
	"Kalligan": {
		"front": "res://ConceptImages/Kalligan/KalliganFront.png",
		"back": "res://ConceptImages/Kalligan/KalliganBack.png",
	},
	"Gremory": {
		"front": "res://ConceptImages/Gremory/GremoryFront.png",
		"back": "res://ConceptImages/Gremory/GremoryBack.png",
	},
	"Odradek": {
		"front": "res://ConceptImages/Odradek/OdradekFront.png",
		"back": "res://ConceptImages/Odradek/OdradekRear.png",
	},
	"Kanifous": {
		"front": "res://ConceptImages/Kanifous/KanifousFront.png",
		"back": "res://ConceptImages/Kanifous/KanifousBack.png",
	},
	"Humbaba": {
		"front": "res://ConceptImages/Humbaba/HumbabaFront.png",
		"back": "res://ConceptImages/Humbaba/HumbabaBack.png",
	},
}


static func path_for(lord_name: String, back: bool = false) -> String:
	var entry = ART.get(lord_name, {})
	if typeof(entry) != TYPE_DICTIONARY:
		return ""
	return String(entry.get("back" if back else "front", ""))


static func texture_for(lord_name: String, back: bool = false) -> Texture2D:
	var path: String = path_for(lord_name, back)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var resource = load(path)
	return resource if resource is Texture2D else null
