extends RefCounted
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")

static func apply(panel: Control) -> void:
	if panel.has_meta("corruptor_bespoke_skin"): return
	var texture: Texture2D = Art.texture("res://ConceptImages/Menus/DecisionPanel.png")
	if texture == null: return
	panel.set_meta("corruptor_bespoke_skin", true)
	# Keep all existing padding and layout. Paint only the background.
	panel.draw.connect(_draw_frame.bind(panel, texture))
	panel.resized.connect(panel.queue_redraw)
	panel.queue_redraw()

static func _draw_frame(panel: Control, texture: Texture2D) -> void:
	var extent: Vector2 = panel.size
	if extent.x <= 0.0 or extent.y <= 0.0: return
	var source: Vector2 = texture.get_size()
	var edge: float = minf(24.0, minf(extent.x, extent.y) * 0.25)
	var cut: float = 48.0
	# Use the quiet center and outer frame of the existing image, leaving its
	# baked-in action/title plaques out of arbitrary-sized dialogs.
	panel.draw_texture_rect_region(texture, Rect2(Vector2.ZERO, extent),
		Rect2(source * Vector2(0.18, 0.25), source * Vector2(0.64, 0.46)), Color(0.90, 0.90, 0.90))
	var dx: Array = [0.0, edge, extent.x - edge, extent.x]
	var dy: Array = [0.0, edge, extent.y - edge, extent.y]
	var sx: Array = [0.0, cut, source.x - cut, source.x]
	var sy: Array = [0.0, cut, source.y - cut, source.y]
	for y in range(3):
		for x in range(3):
			if x == 1 and y == 1: continue
			panel.draw_texture_rect_region(texture,
				Rect2(dx[x], dy[y], dx[x+1]-dx[x], dy[y+1]-dy[y]),
				Rect2(sx[x], sy[y], sx[x+1]-sx[x], sy[y+1]-sy[y]))

static func window(dialog: Window) -> void:
	var texture: Texture2D = Art.texture("res://ConceptImages/Menus/LordPanel.png")
	if texture == null: return
	var style := StyleBoxTexture.new()
	style.texture = texture
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_texture_margin(side, 70.0)
		style.set_content_margin(side, 14.0)
		style.set_expand_margin(side, 0.0)
	var skin: Theme = dialog.theme.duplicate() if dialog.theme != null else Theme.new()
	skin.set_stylebox("panel", "Window", style)
	dialog.theme = skin
