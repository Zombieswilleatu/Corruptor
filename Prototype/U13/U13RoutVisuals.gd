extends RefCounted

const Rout = preload("res://Scripts/Sim/U13Rout.gd")
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const PATH: String = "res://ConceptImages/Sprites/Rout/Rout.png"
const PERIOD: float = 2.4
var texture: Texture2D
var subjects: Dictionary = {}


# Presentation reads the same round predicates as movement. Recovery is still
# an affected round, so the mark remains until Rout ends or the actor disappears.
func sync(units: Array, round_number: int) -> void:
	var next: Dictionary = {}
	for unit in units:
		var attributes: Dictionary = unit.attributes
		if (
			not Rout.retreating(attributes, round_number)
			and not Rout.recovering(attributes, round_number)
		):
			continue
		var effect: String = String(attributes.get("rout_effect_id", ""))
		var prior: Dictionary = subjects.get(unit.id, {})
		if prior.get("effect") == effect:
			next[unit.id] = prior
		else:
			# Cosmetic phase only. Never consume simulation RNG or mutate the actor.
			var digest: PackedByteArray = String(unit.id).sha256_buffer()
			next[unit.id] = {"effect": effect, "age": 0.0, "phase": float(digest[0]) / 256.0 * TAU}
	subjects = next


func advance(delta: float) -> void:
	if subjects.is_empty():
		return
	if texture == null:
		texture = Art.texture(PATH)
	for subject in subjects.values():
		subject.age += maxf(0.0, delta)


func opacity(entity_id: String) -> float:
	if not subjects.has(entity_id):
		return 0.0
	var subject: Dictionary = subjects[entity_id]
	var wave: float = 0.5 - 0.5 * cos(float(subject.age) * TAU / PERIOD + float(subject.phase))
	return (0.80 * wave) * clampf(float(subject.age) / 0.35, 0.0, 1.0)


func draw_chit(
	canvas: CanvasItem, entity_id: String, center: Vector2, scale_factor: float = 1.0
) -> void:
	if texture == null or not subjects.has(entity_id):
		return
	# One static image, anchored above the chit. No movement, scale animation,
	# physics, tweens, or per-actor nodes; only opacity changes.
	canvas.draw_texture_rect(
		texture,
		Rect2(center + Vector2(-30, -69) * scale_factor, Vector2(60, 60) * scale_factor),
		false,
		Color(1, 1, 1, opacity(entity_id))
	)


func clear() -> void:
	subjects.clear()
