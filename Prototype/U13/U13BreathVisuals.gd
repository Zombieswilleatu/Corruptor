extends RefCounted

# Cosmetic clock only. The persistent registry decides when healing exists.
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const FLOWERS: int = 14
const DEATH_WINDOW: float = 10.0
const DEATH_DURATION: float = 0.8
const GROW_FRAME: float = 0.22
const PATH: String = "res://ConceptImages/Sprites/BreathOfLife/"
var textures: Array = []
var groups: Dictionary = {}
var _last_round: int = 0


# One cached texture per frame during setup, never one image per flower.
func warm_next() -> void:
	if textures.size() < 5:
		var file: String = (
			"Flower%d.png" % (textures.size() + 1) if textures.size() < 4 else "HealEffect.png"
		)
		textures.append(Art.texture(PATH + file))


func clear() -> void:
	groups.clear()
	_last_round = 0


func sync(records: Array, round_number: int) -> void:
	if round_number < _last_round:
		clear()
	_last_round = round_number
	var seen: Dictionary = {}
	for row in records:
		if (
			row.get("declaration", {}).get("power_id") != "BreathOfLife"
			or not row.get("payload", {}).has("lane_aura")
		):
			continue
		if int(row.activated_round) + row.stages.size() <= round_number:
			continue
		seen[row.effect_id] = true
		if not groups.has(row.effect_id):
			groups[row.effect_id] = _group(
				row.effect_id, row.declaration.player_id, row.target.lane
			)
		elif groups[row.effect_id].retired >= 0.0:
			# A restored active instance revives its own group; no new random layout.
			groups[row.effect_id].retired = -1.0
	for id in groups:
		if not seen.has(id) and groups[id].retired < 0.0:
			groups[id].retired = groups[id].age
	# Rapidly skipping rounds can overlap several visual tails. Keep a bounded
	# number, dropping only the oldest retired group, never an active aura.
	while groups.size() > 6:
		var removed: bool = false
		for id in groups.keys():
			if groups[id].retired >= 0.0:
				groups.erase(id)
				removed = true
				break
		if not removed:
			break


static func _group(id: String, owner: int, lane: String) -> Dictionary:
	var flowers: Array = []
	for index in range(FLOWERS):
		var digest: PackedByteArray = (id + ":flower:" + str(index)).sha256_buffer()
		flowers.append(
			{
				"position":
				Vector2(
					0.12 + 0.76 * float(digest[0]) / 255.0, 0.10 + 0.80 * float(digest[1]) / 255.0
				),
				"variant": int(digest[2]) % 4,
				"size": 32.0 + 18.0 * float(digest[3]) / 255.0,
				"grow_at": 2.5 * float(digest[4]) / 255.0,
				"die_after": (DEATH_WINDOW - DEATH_DURATION) * float(digest[5]) / 255.0
			}
		)
	flowers.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.position.y < b.position.y
	)
	return {"owner": owner, "lane": lane, "age": 0.0, "retired": -1.0, "flowers": flowers}


func advance(delta: float) -> void:
	for id in groups.keys():
		var group: Dictionary = groups[id]
		group.age += maxf(0.0, delta)
		if group.retired >= 0.0 and group.age - group.retired >= DEATH_WINDOW:
			groups.erase(id)


static func flower_frame(group: Dictionary, flower: Dictionary) -> int:
	if group.retired >= 0.0:
		var dying: float = group.age - group.retired - flower.die_after
		if dying >= DEATH_DURATION:
			return -1
		if dying >= 0.0:
			return 4 if dying < DEATH_DURATION * 0.5 else 5
	var growing: float = group.age - flower.grow_at
	return -1 if growing < 0.0 else mini(3, int(floor(growing / GROW_FRAME)))


func draw_lane(canvas: CanvasItem, bounds: Rect2, lane: String, scale_factor: float = 1.0) -> void:
	if textures.size() < 5:
		return
	for group in groups.values():
		if group.lane != lane:
			continue
		# Tile across the lane's width; travel along its length. Current board
		# lanes run vertically, so the sweep follows the Marchers' direction.
		if group.retired < 0.0:
			var tile: float = 64.0 * scale_factor
			var phase: float = fposmod(float(group.age) / 4.0, 1.0)
			if group.owner == 0:
				phase = 1.0 - phase
			var y: float = bounds.position.y - tile + phase * (bounds.size.y + tile * 2.0)
			var opacity: float = 0.22 + 0.10 * (0.5 + 0.5 * sin(float(group.age) * TAU / 1.8))
			var frame: int = int(floor(float(group.age) * 6.0)) % 6
			for column in range(int(ceil(bounds.size.x / tile)) + 1):
				_draw_frame(
					canvas,
					textures[4],
					frame,
					Rect2(bounds.position.x + float(column) * tile, y, tile, tile),
					bounds,
					opacity
				)
		for flower in group.flowers:
			var frame: int = flower_frame(group, flower)
			if frame < 0:
				continue
			var opacity: float = 0.85
			if frame == 5:
				var elapsed: float = group.age - group.retired - flower.die_after
				opacity *= clampf((DEATH_DURATION - elapsed) / 0.25, 0.0, 1.0)
			var extent: float = flower.size * scale_factor
			var anchor: Vector2 = bounds.position + flower.position * bounds.size
			_draw_frame(
				canvas,
				textures[flower.variant],
				frame,
				Rect2(anchor - Vector2(extent * 0.5, extent), Vector2.ONE * extent),
				bounds,
				opacity
			)


static func _draw_frame(
	canvas: CanvasItem,
	texture: Texture2D,
	frame: int,
	destination: Rect2,
	bounds: Rect2,
	opacity: float
) -> void:
	if texture == null:
		return
	var visible: Rect2 = destination.intersection(bounds)
	if not visible.has_area():
		return
	var cell: Vector2 = texture.get_size() / Vector2(3.0, 2.0)
	var origin := Vector2(float(frame % 3), floor(float(frame) / 3.0)) * cell
	var region := Rect2(
		origin + (visible.position - destination.position) / destination.size * cell,
		visible.size / destination.size * cell
	)
	canvas.draw_texture_rect_region(texture, visible, region, Color(1, 1, 1, opacity))
