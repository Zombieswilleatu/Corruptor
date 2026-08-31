# UI2_CASTLE_CARD_ART_V1
class_name UI2CastleArtCatalog
extends RefCounted


const ART_PATHS: Dictionary = {
	"Keep": "res://ConceptImages/CastleCards/Keep.png",
	"Bastion": "res://ConceptImages/CastleCards/Bastion.png",
	"SummoningCircle": "res://ConceptImages/CastleCards/SummoningCircle.png",
	"Stockpile": "res://ConceptImages/CastleCards/Stockpile.png",
	"SiegeEngine": "res://ConceptImages/CastleCards/SiegeEngine.png",
}


static var _cache: Dictionary = {}


static func texture_for(
	castle_name: String
) -> Texture2D:
	if _cache.has(castle_name):
		return _cache[castle_name]

	var path: String = String(
		ART_PATHS.get(
			castle_name,
			""
		)
	)

	if (
		path.is_empty()
		or not ResourceLoader.exists(path)
	):
		_cache[castle_name] = null
		return null

	var resource = load(path)

	if resource is Texture2D:
		_cache[castle_name] = resource
		return resource

	_cache[castle_name] = null
	return null
