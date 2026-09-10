extends Node2D

# Presentation only. The match adapter supplies charge totals and effect targets;
# preview absorption/projection helpers do not define U13 gameplay rules.
signal charges_changed(value: int)
signal orb_arrived
signal projection_arrived(destination: Vector2)

const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const ROOT: String = "res://ConceptImages/Sprites/Valak/"
const ENERGY: Array = ["Energy1.png", "Energy2.png", "Energy3.png", "Energy4.png", "energy5.png"]
# The sheets are NOT uniform grids. Keep the original pixels and use explicit
# cells plus nucleus anchors to prevent drifting or clipping neighboring frames.
const FLIGHT_CUTS: Array = [0, 322, 684, 1028, 1366, 1712, 2048]
const FLIGHT_CENTERS: Array = [Vector2(209, 340), Vector2(563, 340), Vector2(916, 340), Vector2(1254, 340), Vector2(1589, 340), Vector2(1931, 340)]
const FORM_CUTS: Array = [0, 443, 829, 1186, 1511, 1807, 2048]
const FORM_CENTERS: Array = [Vector2(227, 361), Vector2(638, 361), Vector2(1000, 361), Vector2(1350, 361), Vector2(1660, 361), Vector2(1926, 373)]
const ROTATE_CUTS: Array = [0, 220, 464, 734, 1048, 1357, 1699, 2048]
const ROTATE_CENTERS: Array = [Vector2(113, 352), Vector2(331, 352), Vector2(595, 352), Vector2(899, 352), Vector2(1196, 352), Vector2(1514, 352), Vector2(1856, 352)]

var staff_position := Vector2.ZERO
var hover_position := Vector2.ZERO
var charges: int = 0
var clock: float = 0.0
var flight_seconds: float = 0.8
var formation_seconds: float = 0.8
var rotation_fps: float = 9.0
var orb_size: float = 140.0
var energy_size: float = 54.0
var hover_amount: float = 5.0
var phase: String = "idle"
var phase_time: float = 0.0
var origin := Vector2.ZERO
var target := Vector2.ZERO
var absorptions: Array = []
var projections: Array = []
var energy_textures: Array = []
var flight_texture: Texture2D
var form_texture: Texture2D
var rotate_texture: Texture2D


func _ready() -> void:
	for path in ENERGY:
		energy_textures.append(Art.texture(ROOT + path))
	flight_texture = Art.texture(ROOT + "OrbFlight.png")
	form_texture = Art.texture(ROOT + "OrbSingularity.png")
	rotate_texture = Art.texture(ROOT + "OrbRotate.png")
	z_index = 45


func set_charges(value: int) -> void:
	charges = maxi(0, value)
	charges_changed.emit(charges)
	queue_redraw()


func hover_point() -> Vector2:
	return hover_position + Vector2(sin(clock * 1.3) * hover_amount * 0.4, sin(clock * 1.9) * hover_amount)


func cast(destination: Vector2) -> void:
	origin = staff_position
	target = destination
	phase = "flight"
	phase_time = 0.0
	queue_redraw()


func absorb_charge(source: Vector2) -> void:
	absorptions.append({"origin": source, "age": 0.0})


func project(destination: Vector2) -> bool:
	if charges <= 0:
		return false
	projections.append({"origin": hover_point(), "target": destination, "charges": charges, "age": 0.0})
	set_charges(0)
	return true


func clear() -> void:
	phase = "idle"
	phase_time = 0.0
	clock = 0.0
	absorptions.clear()
	projections.clear()
	set_charges(0)


func advance(delta: float) -> void:
	var step: float = maxf(0.0, delta)
	clock += step
	if phase != "idle":
		phase_time += step
		# Preserve time overflow, including frames that cross both transitions.
		if phase == "flight" and phase_time >= maxf(0.01, flight_seconds):
			phase_time -= maxf(0.01, flight_seconds)
			phase = "singularity"
			orb_arrived.emit()
		if phase == "singularity" and phase_time >= maxf(0.01, formation_seconds):
			phase_time -= maxf(0.01, formation_seconds)
			phase = "rotate"
	var pending: Array = []
	for absorption in absorptions:
		absorption.age += step
		if absorption.age + 0.00000001 >= 0.65:
			set_charges(charges + 1)
		else:
			pending.append(absorption)
	absorptions = pending
	pending = []
	for projection in projections:
		projection.age += step
		if projection.age >= maxf(0.01, flight_seconds):
			projection_arrived.emit(projection.target)
		else:
			pending.append(projection)
	projections = pending
	queue_redraw()


func frame_index() -> int:
	if phase == "flight":
		return int(floor(phase_time * 12.0)) % 6
	if phase == "singularity":
		return clampi(int(floor(phase_time / maxf(0.01, formation_seconds) * 6.0)), 0, 5)
	if phase == "rotate":
		var frame: int = int(floor(phase_time * maxf(0.1, rotation_fps)))
		# The first two frames expand the singularity. Only the five full-size
		# frames loop, avoiding a shrink/pop each time the sheet wraps.
		return frame if frame < 2 else 2 + (frame - 2) % 5
	return 0


func orb_point() -> Vector2:
	if phase == "flight":
		return origin.lerp(target, clampf(phase_time / maxf(0.01, flight_seconds), 0.0, 1.0))
	return target


func _sheet(texture: Texture2D, cuts: Array, centers: Array, frame: int, center: Vector2, factor: float, angle: float = 0.0) -> void:
	if texture == null:
		return
	var source := Rect2(float(cuts[frame]), 0, float(cuts[frame + 1] - cuts[frame]), 682)
	var anchor: Vector2 = centers[frame] - source.position
	draw_set_transform(center, angle)
	draw_texture_rect_region(texture, Rect2(-anchor * factor, source.size * factor), source)
	draw_set_transform(Vector2.ZERO)


func _energy(center: Vector2, count: int, factor: float = 1.0) -> void:
	if energy_textures.is_empty() or count <= 0:
		return
	# Every absorbed charge adds a layer. Beyond the supplied five pieces,
	# reuse the outer ring; this renderer imposes no gameplay charge cap.
	for index in range(count):
		var texture: Texture2D = energy_textures[mini(index, ENERGY.size() - 1)]
		if texture == null:
			continue
		var side: float = (energy_size + float(index) * 18.0) * factor
		var direction: float = 1.0 if index % 2 == 0 else -1.0
		var angle: float = clock * direction * (0.16 + float(index) * 0.045)
		draw_set_transform(center, angle)
		draw_texture_rect(texture, Rect2(-Vector2.ONE * side * 0.5, Vector2.ONE * side), false)
	draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	_energy(hover_point(), charges)
	for absorption in absorptions:
		var amount: float = smoothstep(0.0, 1.0, float(absorption.age) / 0.65)
		_energy(absorption.origin.lerp(hover_point(), amount), 1, lerpf(0.45, 0.65, amount))
	for projection in projections:
		var amount: float = clampf(float(projection.age) / maxf(0.01, flight_seconds), 0.0, 1.0)
		_energy(projection.origin.lerp(projection.target, amount), int(projection.charges))
	var frame: int = frame_index()
	if phase == "flight":
		_sheet(flight_texture, FLIGHT_CUTS, FLIGHT_CENTERS, frame, orb_point(), orb_size / 450.0, (target - origin).angle())
	elif phase == "singularity":
		_sheet(form_texture, FORM_CUTS, FORM_CENTERS, frame, target, orb_size / 550.0)
	elif phase == "rotate":
		_sheet(rotate_texture, ROTATE_CUTS, ROTATE_CENTERS, frame, target, orb_size / 400.0)
