extends Node2D

signal flee_started
@export var flee_sound: AudioStream
var flee_audio: AudioStreamPlayer
var bite_field: Array = []
const FLEE_SOUND_PATH: String = "res://Sounds/Wilhelm.wav"
const RoutVisuals = preload("res://Prototype/U13/U13RoutVisuals.gd")
var flee_ghosts = RoutVisuals.new()

const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const TICK_SECONDS: float = 6.0 / 200.0
const SHEET_PATH: String = "res://ConceptImages/Sprites/Kroni/KroniSprite.png"
# Explicit atlas cuts: the uploaded sheet has padding and uneven row heights.
# Nothing is repainted or rescaled in the source asset.
const ROWS: Array = [
	[Rect2(15, 260, 186, 210), Rect2(201, 260, 179, 210), Rect2(380, 260, 179, 210), Rect2(559, 260, 176, 210), Rect2(735, 260, 179, 210), Rect2(914, 260, 190, 210)],
	[Rect2(10, 473, 188, 183), Rect2(198, 473, 181, 183), Rect2(379, 473, 179, 183), Rect2(558, 473, 184, 183), Rect2(742, 473, 185, 183), Rect2(927, 473, 184, 183)],
	[Rect2(10, 660, 184, 186), Rect2(194, 660, 186, 186), Rect2(380, 660, 179, 186), Rect2(559, 660, 180, 186), Rect2(739, 660, 187, 186), Rect2(926, 660, 188, 186)],
	[Rect2(8, 857, 189, 243), Rect2(197, 857, 183, 243), Rect2(380, 857, 182, 243), Rect2(562, 857, 181, 243), Rect2(743, 857, 185, 243), Rect2(928, 857, 190, 243)]
]
var sheet: Texture2D
var chits: Texture2D
var battlefield
var field_rect := Rect2(0, 0, 600, 900)
var frames: Array = []
var bites: Array = []
var bite_index: int = 0
var bite: Dictionary = {}
var bite_elapsed: float = 0.0
var chomp_seconds: float = 0.55
var frame_rate: float = 10.0
var show_footprint: bool = false
var clock: float = 0.0
var actors: Array = []


func _ready() -> void:
	sheet = Art.texture(SHEET_PATH)
	chits = Art.texture("res://ConceptImages/Sprites/Chits.png")
	z_index = 45
	flee_audio = AudioStreamPlayer.new()
	add_child(flee_audio)
	if flee_sound == null and FileAccess.file_exists(FLEE_SOUND_PATH):
		flee_sound = AudioStreamWAV.load_from_file(FLEE_SOUND_PATH)


func clear() -> void:
	flee_ghosts.clear()
	_restore_bite_field()
	if flee_audio != null:
		flee_audio.stop()
	frames = []
	bites = []
	bite = {}
	bite_index = 0
	actors = []
	clock = 0.0
	queue_redraw()


func load_tape(events: Array) -> void:
	clear()
	for event in events:
		if event.type == "KRONI_ACTORS_STARTED":
			frames.append({"at": 0.0, "actors": event.data.actors.duplicate(true)})
		elif event.type == "KRONI_ACTOR_TICK":
			frames.append({"at": (float(event.data.tick) + 1.0) * TICK_SECONDS, "actors": event.data.actors.duplicate(true)})
		elif event.type == "MARCHER_DEVOURED":
			bites.append({"at": (float(event.data.tick) + 1.0) * TICK_SECONDS, "data": event.data.duplicate(true)})
	show_time(0.0)


func busy() -> bool:
	return not bite.is_empty()


func limit_delta(at: float, delta: float) -> float:
	return minf(delta, maxf(0.0, float(bites[bite_index].at) - at)) if bite_index < bites.size() else delta


func show_time(at: float) -> void:
	clock = at
	actors = []
	if not frames.is_empty():
		var index: int = 0
		while index + 1 < frames.size() and frames[index + 1].at <= at:
			index += 1
		var left: Dictionary = frames[index]
		var right: Dictionary = frames[mini(index + 1, frames.size() - 1)]
		var amount: float = clampf((at - float(left.at)) / maxf(0.00001, float(right.at) - float(left.at)), 0.0, 1.0)
		actors = left.actors.duplicate(true)
		for actor in actors:
			for next_actor in right.actors:
				if actor.id == next_actor.id:
					actor["visual_x"] = lerpf(float(actor.x_fp), float(next_actor.x_fp), amount)
					actor["visual_y"] = lerpf(float(actor.y_fp), float(next_actor.y_fp), amount)
	if not busy() and bite_index < bites.size() and float(bites[bite_index].at) <= at + 0.00001:
		bite = bites[bite_index].data
		bite_index += 1
		bite_elapsed = 0.0
		if is_instance_valid(battlefield):
			bite_field = battlefield._units.duplicate(true)
			battlefield._units = flee_frame(bite_field)
			battlefield.queue_redraw()
		if not bite.get("flee", []).is_empty():
			flee_ghosts.clear()
			for change in bite.flee:
				flee_ghosts.subjects[change.before.id] = {"effect": "kroni_flee", "age": 0.0, "phase": PI}
			flee_ghosts.advance(0.0)
			flee_started.emit()
			if flee_sound != null:
				# One voice per event, never one voice per fleeing unit.
				flee_audio.stream = flee_sound
				flee_audio.play()
	queue_redraw()


func advance_bite(delta: float) -> void:
	if not busy():
		return
	bite_elapsed += delta
	flee_ghosts.advance(delta)
	if is_instance_valid(battlefield):
		battlefield._units = flee_frame(bite_field)
		battlefield.queue_redraw()
	if bite_elapsed >= chomp_seconds:
		flee_ghosts.clear()
		_restore_bite_field()
		bite = {}
		show_time(clock)
	queue_redraw()


func point(forward: float, lateral: float) -> Vector2:
	if is_instance_valid(battlefield):
		var lane: String = "Castle" if lateral >= 600.0 else "Lord"
		var rect: Rect2 = battlefield.travel_rect(lane)
		var p := Vector2(rect.position.x + rect.size.x * (lateral - (600.0 if lane == "Castle" else 0.0)) / 600.0, rect.end.y - rect.size.y * forward / 2400.0)
		return get_global_transform().affine_inverse() * battlefield.get_global_transform() * p
	return Vector2(field_rect.position.x + field_rect.size.x * lateral / 1200.0, field_rect.end.y - field_rect.size.y * forward / 2400.0)


static func facing(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return 2 if direction.x > 0 else 1
	return 0 if direction.y >= 0 else 3


func extent(actor: Dictionary) -> Vector2:
	var center: Vector2 = point(float(actor.x_fp), float(actor.y_fp))
	var r: float = float(actor.radius_fp)
	return Vector2(absf(point(float(actor.x_fp), float(actor.y_fp) + r).x - center.x), absf(point(float(actor.x_fp) + r, float(actor.y_fp)).y - center.y)) * 2.0


func _draw() -> void:
	if busy():
		var fleeing_units: Array = []
		for change in bite.get("flee", []):
			fleeing_units.append(change.after)
		for unit in flee_frame(fleeing_units):
			var a: Dictionary = unit.attributes
			flee_ghosts.draw_chit(self, String(unit.id), point(float(a.x_fp), float(a.y_fp) + (600.0 if a.lane == "Castle" else 0.0)))
	if sheet == null:
		return
	var shown: Array = actors.duplicate(true)
	if busy():
		shown = shown.filter(func(a: Dictionary) -> bool: return a.id != bite.actor_id)
		shown.append(bite.actor)
	for actor in shown:
		var chomping: bool = busy() and actor.id == bite.actor_id
		if not actor.active and not chomping:
			continue
		var center: Vector2 = point(float(actor.get("visual_x", actor.x_fp)), float(actor.get("visual_y", actor.y_fp)))
		var direction := Vector2(float(actor.vy_fp), -float(actor.vx_fp))
		var victim_position := Vector2.ZERO
		if chomping:
			var a: Dictionary = bite.before.attributes
			victim_position = point(float(a.x_fp), float(a.y_fp) + (600.0 if a.lane == "Castle" else 0.0))
			direction = victim_position - center
		var row: int = facing(direction)
		# The back view has no visible mouth: turn side-on for a northward bite.
		if chomping and row == 3:
			row = 1 if direction.x < 0 else 2
		var size_value: Vector2 = extent(actor)
		# Two complete chomp cycles per pause (~22 FPS at the default 0.55s).
		# Walking keeps its own frame rate; the preview pause scales both bites.
		var animation_frame: float = minf(bite_elapsed / maxf(chomp_seconds, 0.001), 0.99999) * 12.0 if chomping else clock * frame_rate
		var frame_index: int = int(floor(animation_frame)) % 6
		if show_footprint:
			draw_set_transform(center, 0.0, size_value * 0.5)
			draw_arc(Vector2.ZERO, 1.0, 0.0, TAU, 64, Color("eac16c"), 0.015, true)
			draw_set_transform(Vector2.ZERO)
		draw_texture_rect_region(sheet, Rect2(center - size_value * 0.5, size_value), ROWS[row][frame_index])
		if chomping and chits != null:
			var progress: float = clampf(bite_elapsed / chomp_seconds, 0.0, 1.0)
			var anchors: Array = [Vector2(0, 0.08), Vector2(-0.30, -0.07), Vector2(0.30, -0.07), Vector2.ZERO]
			var mouth: Vector2 = center + anchors[row] * size_value
			var p: Vector2 = victim_position.lerp(mouth, smoothstep(0.08, 0.78, progress))
			var side: float = 44.0 * (1.0 - smoothstep(0.20, 0.82, progress))
			var column: int = ["Butcher", "Penitent", "Vulture", "Wright"].find(bite.before.attributes.suit)
			var cell: Vector2 = chits.get_size() / Vector2(4.0, 2.0)
			draw_texture_rect_region(chits, Rect2(p - Vector2.ONE * side * 0.5, Vector2.ONE * side), Rect2(Vector2(float(column), float(bite.before.owner)) * cell, cell))


func _restore_bite_field() -> void:
	if is_instance_valid(battlefield) and not bite_field.is_empty():
		battlefield._units = bite_field
		battlefield.queue_redraw()
	bite_field = []


func flee_frame(units: Array) -> Array:
	if not busy() or bite.get("flee", []).is_empty():
		return units
	var shown: Array = units.duplicate(true)
	var progress: float = clampf(bite_elapsed / chomp_seconds, 0.0, 1.0)
	for change in bite.flee:
		for unit in shown:
			if unit.id != change.before.id:
				continue
			var a: Dictionary = change.before.attributes
			var b: Dictionary = change.after.attributes
			var lateral: float = lerpf(float(a.y_fp) + (600.0 if a.lane == "Castle" else 0.0), float(b.y_fp) + (600.0 if b.lane == "Castle" else 0.0), progress)
			unit.attributes.x_fp = lerpf(float(a.x_fp), float(b.x_fp), progress)
			unit.attributes.lane = "Lord" if lateral < 600.0 else "Castle"
			unit.attributes.y_fp = lateral - (600.0 if lateral >= 600.0 else 0.0)
	return shown
