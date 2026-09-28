extends RefCounted
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const FOLDER: String = "res://ConceptImages/Menus"
const DEFAULT: String = FOLDER + "/Domain1.png"

static func discover() -> Array[String]:
	var result: Array[String] = []
	for entry in DirAccess.get_files_at(FOLDER):
		var filename: String = String(entry).trim_suffix(".remap")
		var stem: String = filename.get_basename().to_lower()
		# Domain.png is the older UI backdrop, not one of the numbered boards.
		if filename.get_extension().to_lower() != "png" or not stem.begins_with("domain") or stem == "domain": continue
		var path: String = FOLDER.path_join(filename)
		if not result.has(path): result.append(path)
	result.sort()
	if result.is_empty(): result.append(DEFAULT)
	return result

static func choose() -> String:
	# Cosmetic randomness must not advance the match's deterministic RNG.
	var random := RandomNumberGenerator.new()
	random.randomize()
	var candidates: Array[String] = discover()
	while not candidates.is_empty():
		var index: int = random.randi_range(0, candidates.size() - 1)
		var path: String = candidates[index]
		if Art.texture(path) != null: return path
		candidates.remove_at(index)
	return DEFAULT

static func from_save(envelope: Dictionary) -> String:
	var presentation = envelope.get("presentation", {})
	if typeof(presentation) != TYPE_DICTIONARY: return DEFAULT
	var path: String = str(presentation.get("domain", DEFAULT))
	# Restrict saved paths to our local domain pool; missing art falls back.
	if not discover().has(path) or Art.texture(path) == null: return DEFAULT
	return path

static func apply(board: Node, path: String) -> void:
	var texture: Texture2D = Art.texture(path)
	if texture == null: texture = Art.texture(DEFAULT)
	for side in board.sides:
		side.UI2_SHARED_DOMAIN_TEXTURE = texture
		side.queue_redraw()
	board.lanes.domain = texture
	board.lanes.queue_redraw()
