extends "res://Prototype/U13/U13WebPlacement.gd"

const Content = preload("res://Scripts/Sim/U13Odradek.gd")
var marchers: Array = []
var allegiance_mode: bool = false
var battlefield: Control
var instruction_panel: PanelContainer
var heading: Label
var description: Label
var count_label: Label
var vortex


func _ready() -> void:
	super._ready()
	vortex = preload("res://Prototype/U13/U13ParadoxVisual.gd").new()
	add_child(vortex)
	move_child(vortex, 0)
	radius_fp = Content.REDIRECT_RADIUS_FP
	confirm_button.text = "REWRITE THE PATH"
	instruction_panel = PanelContainer.new()
	add_child(instruction_panel)
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("191521")
	skin.border_color = Color("ae92cf")
	skin.set_border_width_all(2)
	skin.set_content_margin_all(16)
	instruction_panel.add_theme_stylebox_override("panel", skin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	instruction_panel.add_child(column)
	heading = _label(column, 21)
	description = _label(column, 17)
	count_label = _label(column, 16)
	var actions: Control = confirm_button.get_parent()
	actions.reparent(column)
	actions.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	confirm_button.custom_minimum_size.x = 205
	cancel_button.custom_minimum_size.x = 85


func _label(parent: Node, font_size: int) -> Label:
	var result := Label.new()
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", Color("e2d4f2"))
	parent.add_child(result)
	return result


func lane_rect(lane: String) -> Rect2:
	if battlefield == null:
		return super.lane_rect(lane)
	var transform: Transform2D = get_global_transform().affine_inverse() * battlefield.get_global_transform()
	return transform * battlefield.travel_rect(lane)


func _process(_delta: float) -> void:
	var field: Rect2 = lane_rect("Lord")
	instruction_panel.size.x = 390
	instruction_panel.position = Vector2(maxf(12, field.position.x - 410), maxf(100, field.position.y))
	heading.text = "ALLEGIANCE SHIFT" if allegiance_mode else "REDIRECT"
	description.text = ("Enemy Marchers inside become yours. Their position stays the same." if allegiance_mode else "Every Marcher inside—yours and theirs—moves to the other lane at the same progress.") + "\n\nClick a spot on the battlefield to place the circle. Drag it to adjust, then confirm."
	count_label.text = "%d %s now inside. %s\nResolves after combat; membership may change. Outlines include earlier queued powers." % [affected().size(), "enemies" if allegiance_mode else "Marchers", "Blue rings show conversions." if allegiance_mode else "Arrows show destinations."]
	if placed:
		var transform: Transform2D = get_global_transform_with_canvas()
		vortex.present(transform * Visuals.region_rect(lane_rect(target.lane), target.field_position, radius_fp), transform * lane_rect(target.lane), 0.28, 1.2)
	else:
		vortex.hide()
	queue_redraw()


func _point(lane: String, a: Dictionary) -> Vector2:
	var rect: Rect2 = lane_rect(lane)
	return rect.position + Vector2(float(a.y_fp) / 600.0 * rect.size.x, (1.0 - float(a.x_fp) / 2400.0) * rect.size.y)


func affected() -> Array:
	var result: Array = []
	if not placed:
		return result
	var area: Dictionary = Content.Space.circle_region(target.lane, target.field_position, radius_fp)
	for unit in marchers:
		var a: Dictionary = unit.attributes
		if allegiance_mode and unit.owner != 1:
			continue
		if Content.Space.contains(area, a.lane, {"x_fp": a.x_fp, "y_fp": a.y_fp}).inside:
			result.append(unit)
	return result


func _draw() -> void:
	# Transparent overlay: the actual battlefield, art and chits stay visible.
	for lane in Content.Space.LANES:
		draw_rect(lane_rect(lane), Color("ae92cf"), false, 2)
	if placed:
		var area: Rect2 = Visuals.region_rect(lane_rect(target.lane), target.field_position, radius_fp)
		var points := PackedVector2Array()
		for index in range(65):
			var angle: float = TAU * index / 64.0
			points.append(area.get_center() + Vector2(cos(angle), sin(angle)) * area.size * 0.5)
		draw_colored_polygon(points, Color(0.7, 0.5, 1, 0.14))
		draw_polyline(points, Color("e0baff"), 3, true)
	# Subtle outlines show the working positions after earlier queued Redirects.
	for unit in marchers:
		draw_arc(_point(unit.attributes.lane, unit.attributes), 25, 0, TAU, 40, Color(0.8, 0.75, 1, 0.35), 1, true)
	for unit in affected():
		var a: Dictionary = unit.attributes
		var point: Vector2 = _point(a.lane, a)
		var destination: Vector2 = point if allegiance_mode else _point("Castle" if a.lane == "Lord" else "Lord", a)
		var tint: Color = Color("83ddff") if allegiance_mode or unit.owner == 0 else Color("ffaaa2")
		draw_arc(point, 27, 0, TAU, 48, tint, 3, true)
		draw_arc(destination, 23, 0, TAU, 48, tint, 3, true)
		if not allegiance_mode:
			draw_line(point, destination, tint, 2, true)
			var direction: Vector2 = (destination - point).normalized()
			var normal: Vector2 = direction.orthogonal()
			draw_colored_polygon(PackedVector2Array([destination, destination - direction * 12 + normal * 6, destination - direction * 12 - normal * 6]), tint)
