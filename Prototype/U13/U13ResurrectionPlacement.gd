extends "res://Prototype/U13/U13GravityPlacement.gd"

func _ready() -> void:
	super._ready()
	confirm_button.text = "WISH FOR RESURRECTION"

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_place_at(event.position)
		accept_event()

func _confirm() -> void:
	if placed:
		confirmed.emit({"lane": target.lane})

func _draw() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(24, 45), "RESURRECTION · Choose a lane. Your Marchers killed there this round return after Marching.", HORIZONTAL_ALIGNMENT_CENTER, size.x - 48, 20, Color("b8efdc"))
	for lane in ["Lord", "Castle"]:
		var area: Rect2 = lane_rect(lane)
		if placed and target.lane == lane:
			draw_rect(area, Color(0.2, 0.7, 0.5, 0.25))
		draw_rect(area, Color("9bd9bb"), false, 3 if placed and target.lane == lane else 1)
