extends RefCounted

# Presentation only. Seconds in, grounded pose out. No gameplay side effects.
# All movement is in units of body height, so inspection and board scale agree.
static func pose(motion: String, time: float, phase: float = 0.0) -> Dictionary:
	var result := {"offset": Vector2.ZERO, "angle": 0.0, "height": 1.0, "alpha": 1.0, "flash": 0.0, "impact": 0.0}
	match motion:
		"Idle":
			result.height = 1.0 + sin((time + phase) * TAU / 3.2) * 0.002
		"March":
			var step := fmod(time * 1.5 + phase, 1.0)
			result.offset = Vector2(0, -sin(step * PI) * 0.006)
			result.angle = sin(step * TAU) * 0.006
		"Attack":
			# Slow anticipation, fast committed strike, restrained recovery.
			var windup := smoothstep(0.0, 0.26, time)
			var strike := smoothstep(0.26, 0.36, time)
			var recover := smoothstep(0.43, 0.88, time)
			result.offset = Vector2((-0.025 * windup + 0.11 * strike) * (1.0 - recover), 0)
			result.angle = (-0.025 * windup + 0.085 * strike) * (1.0 - recover)
			result.impact = maxf(0.0, 1.0 - absf(time - 0.36) / 0.07)
		"Hit":
			var recoil := smoothstep(0.0, 0.06, time) * (1.0 - smoothstep(0.09, 0.43, time))
			result.offset = Vector2(-0.045 * recoil, 0)
			result.angle = -0.04 * recoil
			result.flash = 1.0 - smoothstep(0.035, 0.13, time)
		"Death":
			var fall := smoothstep(0.08, 0.7, time)
			result.offset = Vector2(-0.03 * fall, 0.065 * fall)
			result.angle = -0.22 * fall
			result.alpha = 1.0 - smoothstep(0.55, 1.25, time)
	return result

static func paint(canvas: CanvasItem, texture: Texture2D, feet: Vector2, height: float,
		face_left: bool, motion: String, time: float, phase: float) -> void:
	var state := pose(motion, time, phase)
	var direction := -1.0 if face_left else 1.0
	var alpha: float = state.alpha
	if alpha <= 0.0:
		return
	# Ground shadow stays fixed while the body leans about its feet.
	canvas.draw_set_transform(feet, 0.0, Vector2(height * 0.24, height * 0.045))
	canvas.draw_circle(Vector2.ZERO, 1.0, Color(0, 0, 0, 0.28 * alpha))
	var offset: Vector2 = state.offset * height
	offset.x *= direction
	canvas.draw_set_transform(feet + offset, state.angle * direction,
		Vector2(direction, state.height))
	var dimensions := texture.get_size() * (height / texture.get_height())
	var anchor := Vector2(dimensions.x * 0.43, dimensions.y)
	var light: float = 1.0 + state.flash * 1.8
	canvas.draw_texture_rect(texture, Rect2(-anchor, dimensions), false, Color(light, light, light, alpha))
	canvas.draw_set_transform(Vector2.ZERO)
	if state.impact > 0.0:
		var point := feet + Vector2(direction * height * 0.39, -height * 0.43)
		canvas.draw_line(point + Vector2(-2, -3), point + Vector2(2, 3), Color(0.8, 0.7, 0.5, state.impact), 1.0)
