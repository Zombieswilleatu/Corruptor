extends "res://Prototype/U13/U13SinodekPortalVisuals.gd"

func _update_geometry() -> void:
	if not is_instance_valid(battlefield):
		clear()
		return
	var transform: Transform2D = battlefield.get_global_transform_with_canvas()
	for id in portals:
		var field: Dictionary = fields[id]
		var lane: Rect2 = battlefield.travel_rect(field.lane)
		var center: Vector2 = battlefield._monster_point(field)
		var half_size := Vector2(radius_fp / 2400.0 * lane.size.x, radius_fp / 600.0 * lane.size.y)
		var area := Rect2(center - half_size, half_size * 2.0)
		var visible_area: Rect2 = area.intersection(lane)
		var visual = portals[id]
		# Bound each draw to its footprint as well as the shader's lane clip.
		visual.position = visible_area.position
		visual.size = visible_area.size
		visual.present(transform * area, transform * lane, 1.0, 4.0, 0.0)
		if not visible_area.has_area():
			visual.hide()
