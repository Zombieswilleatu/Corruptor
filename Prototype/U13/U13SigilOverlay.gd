extends Node2D

# A non-interactive child of the affected zone: follows its layout and scale,
# without entering Container layout or intercepting clicks and drag/drop.
const Textures = preload("res://Prototype/U13/U13BoardTextures.gd")
const FRESH: String = "res://ConceptImages/Sprites/Sigils/SigilFresh.png"
const DECAYING: String = "res://ConceptImages/Sprites/Sigils/SigilDecaying.png"
var state: String = ""
var texture: Texture2D
var zone_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	z_index = 2
	set_state(state)

func state_label() -> String:
	return "◈ Fresh" if state == "fresh" else ("◈ Decaying" if state == "flipped" else "")

func set_state(value: String) -> void:
	state = "flipped" if value == "decaying" else value
	texture = Textures.texture(FRESH if state == "fresh" else DECAYING) if state in ["fresh", "flipped"] else null
	visible = texture != null
	queue_redraw()

func _process(_delta: float) -> void:
	var zone := get_parent() as Control
	if zone != null and zone_size != zone.size:
		zone_size = zone.size
		queue_redraw()

func _draw() -> void:
	if texture != null and zone_size.x > 0 and zone_size.y > 0:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, zone_size), false, Color(1, 1, 1, 0.65))
