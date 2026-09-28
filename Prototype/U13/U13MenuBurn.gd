extends Control
var areas: Array = []
var progress: float = 0.0:
	set(value):
		progress = value
		queue_redraw()
var fire: Texture2D
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	fire = preload("res://Prototype/U13/U13BoardTextures.gd").texture("res://ConceptImages/Sprites/Scorch/Fire1.png")
func _draw() -> void:
	if fire == null: return
	var cell := Vector2(float(fire.get_width()) / 5.0, fire.get_height())
	var opacity: float = sin(progress * PI)
	for index in range(areas.size()):
		var rect: Rect2 = areas[index]
		for i in range(8):
			var height: float = 95.0 + 35.0 * sin(float(i) * 2.1 + progress * 9.0)
			var width: float = height * cell.x / cell.y
			var x: float = rect.position.x + rect.size.x * float(i) / 8.0
			var y: float = rect.end.y - progress * 45.0
			var frame: int = (int(progress * 13.0) + i + index) % 5
			draw_texture_rect_region(fire, Rect2(x - width * 0.5,y - height,width,height),Rect2(Vector2(cell.x * frame,0),cell),Color(1,0.9,0.7,opacity))
