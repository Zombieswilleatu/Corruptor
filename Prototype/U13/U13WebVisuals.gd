extends RefCounted

const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const Space = preload("res://Scripts/Sim/U13SpatialSpace.gd")
# Build one presentation texture, shared by placement, lanes, and Guard webs.
# The source PNG and its alpha channel remain unchanged.
const WEB_BRIGHTNESS: float = 2.4
const WEB_CONTRAST: float = 0.70
const WEB_SATURATION: float = 0.12
const WEB_OPACITY: float = 0.88
const WEB_FADED_OPACITY: float = 0.46
const WEB_GLOW_OPACITY: float = 0.065
static var _silver_web: Texture2D
var web: Texture2D
var spider: Texture2D
var elapsed: float = 0.0
# A closed path on the supplied image's strands, in normalized image space.
const PATH: Array[Vector2] = [
	Vector2(0.25, 0.38),
	Vector2(0.51, 0.56),
	Vector2(0.75, 0.46),
	Vector2(0.62, 0.70),
	Vector2(0.39, 0.73),
	Vector2(0.25, 0.38)
]


func warm_next() -> void:
	if web == null:
		if _silver_web == null:
			var source: Texture2D = Art.texture("res://ConceptImages/Sprites/Orias/Web.png")
			if source != null:
				var adjusted: Image = source.get_image()
				adjusted.adjust_bcs(WEB_BRIGHTNESS, WEB_CONTRAST, WEB_SATURATION)
				_silver_web = ImageTexture.create_from_image(adjusted)
		web = _silver_web
	elif spider == null:
		spider = Art.texture("res://ConceptImages/Sprites/Orias/Spider.png")


func advance(delta: float) -> void:
	elapsed = fposmod(elapsed + maxf(delta, 0.0), 120.0)


# Caller supplies an authoritative region and its actual lane rectangle.
# The same projection used for choosing positions is used for presentation.
static func region_rect(lane_rect: Rect2, center: Dictionary, radius_fp: int) -> Rect2:
	var anchor := Vector2(
		lane_rect.position.x + float(center.y_fp) / Space.WIDTH_FP * lane_rect.size.x,
		lane_rect.end.y - float(center.x_fp) / Space.LANE_FP * lane_rect.size.y
	)
	var half_size := Vector2(
		float(radius_fp) / Space.WIDTH_FP * lane_rect.size.x,
		float(radius_fp) / Space.LANE_FP * lane_rect.size.y
	)
	return Rect2(anchor - half_size, half_size * 2.0)


func spider_pose(phase: float = 0.0) -> Dictionary:
	var travel: float = fposmod(elapsed / 12.0 + phase, 1.0) * float(PATH.size() - 1)
	var segment: int = int(floor(travel))
	var start: Vector2 = PATH[segment]
	var end: Vector2 = PATH[segment + 1]
	return {
		"position": start.lerp(end, travel - float(segment)),
		"frame": int(floor(elapsed * 8.0)) % 6,
		"left": end.x < start.x,
		"direction": end - start
	}


# Static web; only the spider moves. Destination clipping trims the matching
# source rectangle, so neither the web nor the spider bleeds into another lane.
func draw_area(
	canvas: CanvasItem, area: Rect2, clip: Rect2, fading: bool = false,
	phase: float = 0.0, show_spider: bool = true
) -> void:
	if web == null or area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	var tint := Color(1.0, 0.97, 0.91, WEB_FADED_OPACITY if fading else WEB_OPACITY)
	var web_source := Rect2(Vector2.ZERO, web.get_size())
	var glow := Color(1.0, 0.97, 0.91, WEB_GLOW_OPACITY * (0.5 if fading else 1.0))
	# A small screen-space halo holds thin strands against detailed ground art.
	# Every pass uses the same lane clip, including at the lane boundary.
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		_draw_clipped(canvas, web, Rect2(area.position + offset, area.size), web_source, clip, glow)
	_draw_clipped(canvas, web, area, web_source, clip, tint)
	if not show_spider or spider == null:
		return
	var pose: Dictionary = spider_pose(phase)
	var center: Vector2 = area.position + pose.position * area.size
	var width: float = clampf(area.size.x * 0.20, 18.0, 46.0)
	var destination := Rect2(
		center - Vector2(width, width * 1.32) * 0.5, Vector2(width, width * 1.32)
	)
	var cell_width: float = spider.get_width() / 6.0
	# Shared occupied vertical crop; original six-frame PNG is unchanged.
	var source := Rect2(float(pose.frame) * cell_width, 95, cell_width, 451)
	# The supplied sprite faces diagonally down-right. Match its heading to
	# the projected path, including non-square presentation areas.
	var heading: Vector2 = pose.direction * area.size
	var angle: float = heading.angle() - PI / 4.0
	_draw_rotated_clipped(canvas, spider, destination, source, clip, angle, Color(1, 1, 1, 0.5 if fading else 0.95))


static func _draw_rotated_clipped(
	canvas: CanvasItem, texture: Texture2D, destination: Rect2,
	source: Rect2, clip: Rect2, angle: float, tint: Color
) -> void:
	var center: Vector2 = destination.get_center()
	var corners := PackedVector2Array()
	for point in [destination.position, Vector2(destination.end.x, destination.position.y), destination.end, Vector2(destination.position.x, destination.end.y)]:
		corners.append(center + (point - center).rotated(angle))
	var bounds := PackedVector2Array([clip.position, Vector2(clip.end.x, clip.position.y), clip.end, Vector2(clip.position.x, clip.end.y)])
	# Clip the rotated quad and derive UVs from the inverse transform. Rotation
	# never leaks into adjacent panels or samples a neighboring sprite frame.
	for polygon in Geometry2D.intersect_polygons(corners, bounds):
		var uv := PackedVector2Array()
		for point in polygon:
			var local: Vector2 = ((point - center).rotated(-angle) + destination.size * 0.5) / destination.size
			uv.append((source.position + local * source.size) / texture.get_size())
		canvas.draw_polygon(polygon, PackedColorArray([tint]), uv, texture)


static func _draw_clipped(
	canvas: CanvasItem,
	texture: Texture2D,
	destination: Rect2,
	source: Rect2,
	clip: Rect2,
	tint: Color
) -> void:
	var visible: Rect2 = destination.intersection(clip)
	if visible.size.x <= 0.0 or visible.size.y <= 0.0:
		return
	var offset: Vector2 = (visible.position - destination.position) / destination.size
	var fraction: Vector2 = visible.size / destination.size
	canvas.draw_texture_rect_region(
		texture,
		visible,
		Rect2(source.position + offset * source.size, source.size * fraction),
		tint
	)
