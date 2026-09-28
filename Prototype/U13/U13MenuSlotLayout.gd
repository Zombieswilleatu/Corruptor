extends RefCounted
# Read geometry from the installed playable UI, without starting a match.
# The isolated viewport never renders, receives input, or runs game workers.
static func measure(owner: Control) -> Dictionary:
	var window: Window = owner.get_window()
	var old_size: Vector2i = window.size
	var old_mode: int = window.mode
	var old_canvas_size: Vector2i = window.content_scale_size
	var old_canvas_mode: int = window.content_scale_mode
	var old_canvas_aspect: int = window.content_scale_aspect
	var old_quit: bool = owner.get_tree().auto_accept_quit
	var viewport := SubViewport.new()
	viewport.size = Vector2i(owner.size)
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	owner.add_child(viewport)
	var scene: PackedScene = load("res://Prototype/U13/U13PlayableBoard.tscn")
	if scene == null:
		viewport.queue_free()
		return {}
	var board = scene.instantiate()
	# Scene-level playlist preparation belongs to a real game, not a layout read.
	for child in board.get_children():
		if child.name == "U13GameMusic": child.free()
	board.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(board)
	window.content_scale_size = old_canvas_size
	window.content_scale_mode = old_canvas_mode
	window.content_scale_aspect = old_canvas_aspect
	window.size = old_size
	window.mode = old_mode
	owner.get_tree().auto_accept_quit = old_quit
	_silence(board)
	if not board.has_method("_new_loadout_session"):
		viewport.queue_free()
		return {}
	board.session = board._new_loadout_session()
	var slots: Array = preload("res://Scripts/Sim/U13CastleSlots.gd").TYPES
	board.session.configure(["Deimos", "Gremory"], [slots, slots], true)
	board._refresh()
	for i in range(5): await owner.get_tree().process_frame
	var rectangles: Array = []
	for card in board.sides[1].castle_row.get_children(): rectangles.append(card.get_global_rect())
	var result: Dictionary = {"lord":board.sides[1].lord_card.get_global_rect(), "castles":rectangles}
	viewport.queue_free()
	return result if rectangles.size() == 5 else {}

static func _silence(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.volume_db = -80.0
	for child in node.get_children(): _silence(child)
