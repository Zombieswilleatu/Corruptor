extends Control

# A presentation-only overlay. The owning theater supplies its clock so pause,
# skip and playback speed also control the fracture. No timers or simulation RNG.
var _progress: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	if _progress <= 0.0:
		return
	var paths: Array = [
		[Vector2(0.56, 0.01), Vector2(0.43, 0.23), Vector2(0.58, 0.40), Vector2(0.41, 0.57), Vector2(0.53, 0.75), Vector2(0.36, 0.99)],
		[Vector2(0.58, 0.40), Vector2(0.78, 0.34), Vector2(0.99, 0.47)],
		[Vector2(0.41, 0.57), Vector2(0.22, 0.66), Vector2(0.01, 0.60)]
	]
	for index in range(paths.size()):
		var path: Array = paths[index]
		var progress: float = _progress if index == 0 else clampf((_progress - 0.35) / 0.65, 0.0, 1.0)
		var distance: float = progress * float(path.size() - 1)
		for segment in range(path.size() - 1):
			var fraction: float = clampf(distance - float(segment), 0.0, 1.0)
			if fraction <= 0.0: break
			var a: Vector2 = path[segment] * size
			var b: Vector2 = Vector2(path[segment]).lerp(path[segment + 1], fraction) * size
			draw_line(a + Vector2(1, 0), b + Vector2(1, 0), Color(0.92, 0.77, 0.54), 3.5, true)
			draw_line(a, b, Color(0.08, 0.05, 0.04), 2.2, true)
