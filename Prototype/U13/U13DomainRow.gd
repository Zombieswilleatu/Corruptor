extends HBoxContainer

# Same upper/lower Domain1 artwork used by UI2PlayerBoard. No U12 rules binding.
const Textures = preload("res://Prototype/U13/U13BoardTextures.gd")
var domain: Texture2D = null
var player_id: int = 0


func _ready() -> void:
	domain = Textures.texture("res://ConceptImages/Menus/Domain1.png")
	add_theme_constant_override("separation", 18)
	resized.connect(queue_redraw)


func _draw() -> void:
	if domain == null:
		return
	var image_size: Vector2 = domain.get_size()
	var source := Rect2(
		0, image_size.y * (0.5 if player_id == 0 else 0.0), image_size.x, image_size.y * 0.5
	)
	draw_texture_rect_region(domain, Rect2(Vector2.ZERO, size), source)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.42))
