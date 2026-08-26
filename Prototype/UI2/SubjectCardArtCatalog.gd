# UI2_SUBJECT_CARD_ART_V1
class_name UI2SubjectCardArtCatalog
extends RefCounted


const BACK_PATH: String = "res://ConceptImages/Penitent/SubjectBack.png"

const FRONTS: Dictionary = {
	"Butcher": {
		1: "res://ConceptImages/Butcher/Butcher1.png",
		2: "res://ConceptImages/Butcher/Butcher2.png",
		3: "res://ConceptImages/Butcher/Butcher3.png",
		4: "res://ConceptImages/Butcher/Butcher4.png",
		5: "res://ConceptImages/Butcher/Butcher5.png",
	},
	"Penitent": {
		1: "res://ConceptImages/Penitent/Penitent1.png",
		2: "res://ConceptImages/Penitent/Penitent2.png",
		3: "res://ConceptImages/Penitent/Penitent3.png",
		4: "res://ConceptImages/Penitent/Penitent4.png",
		5: "res://ConceptImages/Penitent/Penitent5.png",
	},
	"Vulture": {
		1: "res://ConceptImages/Vulture/Vulture1.png",
		2: "res://ConceptImages/Vulture/Vulture2.png",
		3: "res://ConceptImages/Vulture/Vulture3.png",
		4: "res://ConceptImages/Vulture/Vulture4.png",
		5: "res://ConceptImages/Vulture/Vulture5.png",
	},
	"Wright": {
		1: "res://ConceptImages/Wright/Wright1.png",
		2: "res://ConceptImages/Wright/Wright2.png",
		3: "res://ConceptImages/Wright/Wright3.png",
		4: "res://ConceptImages/Wright/Wright4.png",
		5: "res://ConceptImages/Wright/Wright5.png",
	},
}


static func path_for(
	suit_name: String,
	value: int,
	hidden: bool = false
) -> String:
	if hidden:
		return BACK_PATH

	var suit_map = FRONTS.get(suit_name, {})
	if typeof(suit_map) != TYPE_DICTIONARY:
		return ""

	return String(suit_map.get(value, ""))


static func texture_for(
	suit_name: String,
	value: int,
	hidden: bool = false
) -> Texture2D:
	var path: String = path_for(suit_name, value, hidden)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null

	var resource = load(path)
	return resource if resource is Texture2D else null
