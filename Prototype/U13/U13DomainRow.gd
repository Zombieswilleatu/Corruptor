extends HBoxContainer

# Same upper/lower Domain1 artwork used by UI2PlayerBoard. No U12 rules binding.
const DOMAIN = preload("res://ConceptImages/Menus/Domain1.png")
var player_id: int = 0


func _ready() -> void:
	add_theme_constant_override("separation", 18)
	resized.connect(queue_redraw)


func _draw() -> void:
	var image_size: Vector2 = DOMAIN.get_size()
	var source := Rect2(
		0, image_size.y * (0.5 if player_id == 0 else 0.0), image_size.x, image_size.y * 0.5
	)
	draw_texture_rect_region(Rect2(Vector2.ZERO, size), DOMAIN, source)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.42))
