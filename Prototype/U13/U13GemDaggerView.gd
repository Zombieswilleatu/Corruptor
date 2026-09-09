extends Control

const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const FLIGHT_SECONDS: float = 0.70
const BURST_SECONDS: float = 0.32
signal impact(shot: Dictionary)
var _shots: Array = []
var _index: int = 0
var _elapsed: float = 0.0
var _impacted: bool = false
var _sides: Array = []
var _sprite: Sprite2D
var _texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 89
	_sprite = Sprite2D.new()
	_sprite.rotation = PI / 2.0
	_sprite.region_enabled = true
	add_child(_sprite)
	_sprite.hide()


# Consume the player's already-redacted event view. A single triggering Guard
# yields one drop even though Gem Dagger emits a draw event for each player.
static func collect(events: Array) -> Array:
	var result: Array = []
	var trigger: Dictionary = {}
	for event in events:
		if event.get("type") == "GUARD_DEFEATED":
			trigger = event.data.duplicate(true)
		elif event.get("type") == "GEM_DAGGER" and trigger.has("guard"):
			if result.is_empty() or result.back().event_id != trigger.event_id:
				result.append(
					{
						"event_id": trigger.event_id,
						"guard": trigger.guard.duplicate(true),
						"rewards": []
					}
				)
			result.back().rewards.append(event.duplicate(true))
	return result


func play_events(events: Array, sides: Array) -> void:
	clear()
	_shots = collect(events)
	_sides = sides


func active() -> bool:
	return _index < _shots.size()


# Return a presentation copy with pending rewards and their triggering Guard
# held until impact. This never changes the match or reconstructs hidden cards.
func mask_view(view: Dictionary) -> Dictionary:
	var result: Dictionary = view.duplicate(true)
	for index in range(_index, _shots.size()):
		if index == _index and _impacted:
			continue
		var shot: Dictionary = _shots[index]
		var guard: Dictionary = shot.guard
		var visible: Array = []
		for entity in result.world.entities:
			if entity.id != guard.id:
				visible.append(entity)
		visible.append(guard.duplicate(true))
		result.world.entities = visible
		for reward in shot.rewards:
			if not reward.data.get("drawn", false):
				continue
			if reward.data.player_id == 0 and reward.data.has("card_id"):
				result.world.hand.erase(reward.data.card_id)
			elif reward.data.player_id == 1:
				result.world.opponent_hand_count = maxi(
					0, int(result.world.opponent_hand_count) - 1
				)
		if result.has("events"):
			result.events = result.events.filter(
				func(event: Dictionary) -> bool: return event not in shot.rewards
			)
	return result


func advance(delta: float) -> bool:
	if not active():
		return false
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= FLIGHT_SECONDS and not _impacted:
		_impacted = true
		impact.emit(_shots[_index].duplicate(true))
	if _elapsed >= FLIGHT_SECONDS + BURST_SECONDS:
		_index += 1
		_elapsed = 0.0
		_impacted = false
		if _sprite != null:
			_sprite.hide()
		return true
	if _sprite != null:
		_draw_drop()
	return true


func _draw_drop() -> void:
	if _texture == null:
		_texture = Art.texture("res://ConceptImages/Sprites/GemDagger/GemDagger.png")
		_sprite.texture = _texture
	if _texture == null:
		return
	var end: Vector2 = _guard_center(_shots[_index].guard)
	var picture: Dictionary = pose(_elapsed, end)
	var width: float = _texture.get_width() / 5.0
	_sprite.region_rect = Rect2(float(picture.frame) * width, 0, width, _texture.get_height())
	_sprite.scale = Vector2.ONE * 0.22
	var origin: float = (
		width * (0.95 if picture.frame < 3 else (0.75 if picture.frame == 3 else 0.5))
	)
	_sprite.position = picture.position - Vector2(0, (origin - width * 0.5) * 0.22)
	_sprite.show()


static func pose(elapsed: float, end: Vector2) -> Dictionary:
	if elapsed < FLIGHT_SECONDS:
		var t: float = clampf(elapsed / FLIGHT_SECONDS, 0.0, 1.0)
		return {
			"position": Vector2(end.x, lerpf(-100.0, end.y, t * t)),
			"frame": int(floor(maxf(0.0, elapsed) * 12.0)) % 3
		}
	return {"position": end, "frame": 3 if elapsed < FLIGHT_SECONDS + BURST_SECONDS * 0.5 else 4}


func _guard_center(guard: Dictionary) -> Vector2:
	for side in _sides:
		if side.lord_card.input_surface.get_meta("owner_id", -1) != guard.owner:
			continue
		var box = side.lord_guard_box if guard.attributes.lane == "Lord" else side.castle_guard_box
		var slot: int = int(guard.attributes.slot)
		var target: Control = (
			box.get_child(slot) if slot >= 0 and slot < box.get_child_count() else box
		)
		return get_global_transform().affine_inverse() * target.get_global_rect().get_center()
	return size * 0.5


func clear() -> void:
	_shots = []
	_sides = []
	_index = 0
	_elapsed = 0.0
	_impacted = false
	if _sprite != null:
		_sprite.hide()
