extends RefCounted

# Source-checkout board: load original PNGs without editor-generated .ctex files.
# Keep UI2's path tables, but do not call its imported-resource loaders.
const Subjects = preload("res://Prototype/UI2/SubjectCardArtCatalog.gd")
const Lords = preload("res://Prototype/UI2/LordArtCatalog.gd")
static var _cache: Dictionary = {}


static func texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path]
	# Source checkout: decode bytes without Image.load's export warning.
	# Export: when source PNGs are omitted, use the imported texture resource.
	if not FileAccess.file_exists(path) and ResourceLoader.exists(path):
		var imported = load(path)
		if imported is Texture2D:
			_cache[path] = imported
			return imported
	var image := Image.new()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty() or image.load_png_from_buffer(bytes) != OK or image.is_empty():
		push_error("U13 board source image could not be loaded: " + path)
		_cache[path] = null
		return null
	var result: ImageTexture = ImageTexture.create_from_image(image)
	_cache[path] = result
	return result


static func texture_for(suit: String, value: int, hidden: bool = false) -> Texture2D:
	return texture(Subjects.path_for(suit, value, hidden))


static func lord_texture(lord_name: String) -> Texture2D:
	return texture(Lords.path_for(lord_name))
