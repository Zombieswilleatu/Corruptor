extends RefCounted

# Presentation only. Seconds in, grounded pose out. No gameplay side effects.
# All movement is in units of body height, so inspection and board scale agree.
static func pose(motion: String, time: float, phase: float = 0.0, character: String = "Penitent", rooted: bool = false) -> Dictionary:
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
	# Creature-specific restraint: heavy bodies settle, flyers hover, small
	# predators move quickly. These are still-image gestures, not limb rigs.
	var heavy := character in ["Butcher", "BottleTree", "Lemek"]
	var flying := character == "Pixie"
	var spectral := character in ["Sinodek", "Wraith"]
	var predator := character in ["Batboy", "Dogger", "Ratton"]
	if motion in ["Idle", "March"]:
		if heavy:
			result.offset *= 0.45
			result.angle *= 0.45
			result.height = 1.0 + sin((time + phase) * TAU / 4.5) * 0.0015
		elif flying or spectral:
			var wave := sin((time + phase) * TAU / (2.8 if flying else 4.0))
			result.offset = Vector2(0, wave * (0.016 if flying else 0.008))
			result.angle = wave * (0.006 if flying else 0.002)
			result.height = 1.0
		elif predator and motion == "March":
			var rate := 3.2 if character == "Batboy" else (3.5 if character == "Ratton" else 2.4)
			var step := fmod(time * rate + phase, 1.0)
			var lift := 0.0 if character == "Batboy" else 0.005
			result.offset = Vector2(sin(step * TAU) * 0.008, -sin(step * PI) * lift)
			result.angle = sin(step * TAU) * 0.009
		elif character == "Sooge":
			result.offset = Vector2.ZERO
			result.angle = 0.0
			result.height = 1.0 + sin((time + phase) * TAU / 2.6) * 0.008
		elif character in ["Kopita", "Vulture"]:
			result.offset *= 0.6
			result.angle *= 0.5
	if motion == "Attack":
		if heavy:
			result.offset *= 0.6
			result.angle *= 0.6
		elif predator:
			result.offset *= 1.35
		elif character in ["Vulture", "Kopita", "Sinodek", "Wraith", "Pixie"]:
			result.offset *= 0.25
			result.angle *= 0.35
		elif character == "Wright":
			result.angle *= 0.8
	if motion == "Death" and (spectral or character == "Sooge"):
		result.angle = 0.0
		result.offset.x = 0.0
	if rooted:
		result.offset = Vector2.ZERO
		result.angle = 0.0
		if motion == "Attack":
			result.height = 1.0 - result.impact * 0.025
	return result

static func paint(canvas: CanvasItem, texture: Texture2D, feet: Vector2, height: float,
		face_left: bool, motion: String, time: float, phase: float,
		ground: Vector2, body_height: float, mirror: bool,
		character: String = "Penitent", rooted: bool = false) -> void:
	var state := pose(motion, time, phase, character, rooted)
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
		Vector2(-1.0 if mirror else 1.0, state.height))
	var factor := height / body_height
	var dimensions := texture.get_size() * factor
	var anchor := ground * factor
	var light: float = 1.0 + state.flash * 1.8
	canvas.draw_texture_rect(texture, Rect2(-anchor, dimensions), false, Color(light, light, light, alpha))
	canvas.draw_set_transform(Vector2.ZERO)
	if state.impact > 0.0:
		var point := feet + Vector2(direction * height * 0.39, -height * 0.43)
		canvas.draw_line(point + Vector2(-2, -3), point + Vector2(2, 3), Color(0.8, 0.7, 0.5, state.impact), 1.0)
