extends RefCounted

# Cosmetic fire only. Scorch's authoritative pulses remain at their hooks.
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const PATH: String = "res://ConceptImages/Sprites/Scorch/"
const FLAMES: int = 12
const FPS: float = 6.0
const MAX_STAMPS: int = 160
var textures: Array = []
var groups: Dictionary = {}


func warm_next() -> void:
	if textures.size() < 3:
		textures.append(
			Art.texture(PATH + ["Fire1.png", "Fire2.png", "GroundFire.png"][textures.size()])
		)


func sync(records: Array, kind: String, player_id: int = -1) -> void:
	var seen: Dictionary = {}
	for record in records:
		if (
			record.get("fire_round", 0) != 0
			or record.get("remaining", 0) <= 0
			or not record.has("id")
		):
			continue
		if record.target.kind != kind or (kind == "guard" and record.target.player_id != player_id):
			continue
		seen[record.id] = true
		if not groups.has(record.id):
			groups[record.id] = _group(record.id, record.target)
		groups[record.id]["intensity"] = int(record.intensity)
		if groups[record.id].target != record.target:
			# Relocation keeps the visual phase but updates the real target.
			groups[record.id].target = record.target.duplicate(true)
	for id in groups.keys():
		if not seen.has(id):
			groups.erase(id)


static func _group(id: String, target: Dictionary) -> Dictionary:
	var flames: Array = []
	for index in range(FLAMES):
		var digest: PackedByteArray = (id + ":scorch-flame:" + str(index)).sha256_buffer()
		# Stratified coverage, then jitter: twelve distinct patches, not a pile.
		flames.append(
			{
				"position":
				Vector2(
					(float(index % 3) + 0.25 + 0.5 * float(digest[0]) / 255.0) / 3.0,
					(floor(float(index) / 3.0) + 0.35 + 0.5 * float(digest[1]) / 255.0) / 4.0
				),
				"phase": int(digest[2]) % 5,
				"choice_key": id + ":scorch-flame:" + str(index),
				"choice_loop": -1,
				"choice_sheet": 0,
				"height": 45.0 + 19.0 * float(digest[3]) / 255.0
			}
		)
	flames.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.position.y < b.position.y
	)
	return {
		"id": id,
		"target": target.duplicate(true),
		"age": 0.0,
		"flames": flames,
		"ground_size": Vector2.ZERO,
		"ground": null,
		"intensity": 1,
		"burst_age": -1.0
	}


static func flame_frame(age: float, flame: Dictionary) -> Dictionary:
	var tick: int = int(floor(maxf(0.0, age) * FPS)) + int(flame.phase)
	var loop: int = int(floor(float(tick) / 5.0))
	if int(flame.choice_loop) != loop:
		# One independent 1-in-4 cosmetic choice per completed five-frame loop.
		# Cache it: drawing cannot reroll mid-loop. Keys also make skipped frames
		# and relocation harmless, without touching the simulation RNG.
		var digest: PackedByteArray = (
			(String(flame.choice_key) + ":loop:" + str(loop)).sha256_buffer()
		)
		flame.choice_sheet = 1 if int(digest[0]) % 4 == 0 else 0
		flame.choice_loop = loop
	return {"sheet": int(flame.choice_sheet), "frame": tick % 5}


func advance(delta: float) -> void:
	for group in groups.values():
		group.age += maxf(0.0, delta)
		if group.burst_age >= 0.0:
			group.burst_age += maxf(0.0, delta)
			if group.burst_age >= 1.0:
				group.burst_age = -1.0


func flash(effect_id: String) -> void:
	if groups.has(effect_id):
		groups[effect_id].burst_age = 0.0


static func strength(group: Dictionary) -> Dictionary:
	var burst: float = 0.0
	if group.burst_age >= 0.0:
		burst = (
			smoothstep(0.0, 0.10, float(group.burst_age))
			* (1.0 - smoothstep(0.65, 1.0, float(group.burst_age)))
		)
	var hotter: bool = int(group.intensity) == 2
	return {
		"scale": (1.12 if hotter else 1.0) * (1.0 + 0.30 * burst),
		"light": (1.15 if hotter else 1.0) * (1.0 + 0.70 * burst),
		"alpha": lerpf(0.72 if hotter else 0.62, 1.0, burst)
	}


func clear() -> void:
	groups.clear()


func draw_area(canvas: CanvasItem, bounds: Rect2, lane: String) -> void:
	if textures.size() < 3 or not bounds.has_area():
		return
	for group in groups.values():
		if group.target.lane != lane:
			continue
		var heat: Dictionary = strength(group)
		if group.ground == null or group.ground_size != bounds.size:
			group.ground = ground_mesh(bounds.size, group.id)
			group.ground_size = bounds.size
		if textures[2] != null:
			canvas.draw_mesh(
				group.ground,
				textures[2],
				Transform2D(0.0, bounds.position),
				Color(heat.light, heat.light, heat.light, 1.0)
			)
		for flame in group.flames:
			var animation: Dictionary = flame_frame(group.age, flame)
			var height: float = minf(float(flame.height) * float(heat.scale), bounds.size.y * 0.8)
			var width: float = height * 0.6
			var anchor: Vector2 = bounds.position + flame.position * bounds.size
			_draw_flame(
				canvas,
				textures[animation.sheet],
				animation.frame,
				Rect2(anchor - Vector2(width * 0.5, height), Vector2(width, height)),
				bounds,
				Color(heat.light, heat.light, heat.light, heat.alpha)
			)


static func _draw_flame(
	canvas: CanvasItem,
	texture: Texture2D,
	frame: int,
	destination: Rect2,
	bounds: Rect2,
	tint: Color
) -> void:
	if texture == null:
		return
	var clipped: Rect2 = destination.intersection(bounds)
	if not clipped.has_area():
		return
	var cell: Vector2 = texture.get_size() / Vector2(5.0, 1.0)
	var source := Rect2(
		(
			Vector2(float(frame) * cell.x, 0)
			+ (clipped.position - destination.position) / destination.size * cell
		),
		clipped.size / destination.size * cell
	)
	canvas.draw_texture_rect_region(texture, clipped, source, tint)


# Radial alpha is vertex color: center light, rim transparent. Overlapping small
# brush stamps share ONE cached mesh draw, with six GroundFire atlas variants.
# No image editing, offscreen render target, per-stamp node or per-frame rebuild.
static func ground_mesh(extent: Vector2, layout_key: String) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var columns: int = clampi(int(ceil(extent.x / 24.0)), 2, 16)
	var rows: int = clampi(
		int(ceil(extent.y / 24.0)), 2, maxi(2, int(floor(float(MAX_STAMPS) / float(columns))))
	)
	var step := Vector2(extent.x / float(columns), extent.y / float(rows))
	for y_index in range(rows):
		for x_index in range(columns):
			var digest: PackedByteArray = (
				(layout_key + ":ground:" + str(x_index) + ":" + str(y_index)).sha256_buffer()
			)
			var center := Vector2(
				(float(x_index) + 0.4 + 0.2 * float(digest[0]) / 255.0) * step.x,
				(float(y_index) + 0.4 + 0.2 * float(digest[1]) / 255.0) * step.y
			)
			var radius: float = minf(minf(step.x, step.y) * 0.95, 25.0)
			var alpha: float = 0.24 + 0.10 * float(digest[2]) / 255.0
			var frame: float = float(int(digest[3]) % 6)
			for wedge in range(8):
				var first := Vector2(cos(float(wedge) * TAU / 8.0), sin(float(wedge) * TAU / 8.0))
				var second := Vector2(
					cos(float(wedge + 1) * TAU / 8.0), sin(float(wedge + 1) * TAU / 8.0)
				)
				for point in [Vector2.ZERO, first, second]:
					var position: Vector2 = center + point * radius
					# Crop only at the target boundary; fire cannot bleed into the other lane.
					position = position.clamp(Vector2.ZERO, extent)
					vertices.append(Vector3(position.x, position.y, 0))
					colors.append(Color(1, 1, 1, alpha if point == Vector2.ZERO else 0.0))
					uv.append(Vector2((frame + 0.5 + point.x * 0.49) / 6.0, 0.52 + point.y * 0.29))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
