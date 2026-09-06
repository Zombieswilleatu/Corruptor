# UI2_STANDIN_ACTION_DUEL_V1
#
# Temporary presenter for irregular/generated stand-in sprite sheets.
# It intentionally does NOT assume an LPC atlas layout.
#
# Instead it:
#   1. extracts the first visible alpha-connected sprite from each sheet,
#   2. uses that isolated frame as the actor,
#   3. animates movement/lunge/fall procedurally.
#
# This lets placeholder sheets work even when their internal atlases differ.
extends Control


signal clash_started
signal resolution_started(outcome)
signal duel_finished(outcome)


const DRAW_SIZE: Vector2 = Vector2(58.0, 58.0)

const WALK_SPEED: float = 46.0
const ENTRY_PAD: float = 8.0
const CLASH_GAP: float = 6.0

const CLASH_PAUSE_SECONDS: float = 0.28
const SWING_SECONDS: float = 0.34
const AFTER_ATTACK_PAUSE_SECONDS: float = 0.18
const DEATH_SECONDS: float = 0.62

const ALPHA_THRESHOLD: float = 0.04
const REGION_PAD: int = 2
const MAX_FLOOD_PIXELS: int = 250000


enum Phase {
	APPROACH,
	CLASH_PAUSE,
	ATTACK,
	AFTER_ATTACK_PAUSE,
	RESOLVE,
	HOLD,
}


var enemy_texture: Texture2D = null
var player_texture: Texture2D = null

var enemy_region: Rect2 = Rect2()
var player_region: Rect2 = Rect2()

var outcome: String = "both_die"
var attack_swings: int = 3

var phase: Phase = Phase.APPROACH
var phase_clock: float = 0.0
var completed_swings: int = 0

var enemy_x: float = 0.0
var player_x: float = 0.0

var enemy_target_x: float = 0.0
var player_target_x: float = 0.0

var enemy_dead: bool = false
var player_dead: bool = false


func setup(
	enemy_sheet: Texture2D,
	player_sheet: Texture2D,
	resolution_outcome: String = "both_die",
	swing_count: int = 3
) -> void:
	enemy_texture = enemy_sheet
	player_texture = player_sheet
	outcome = _normalized_outcome(resolution_outcome)
	attack_swings = maxi(1, swing_count)

	enemy_region = _first_sprite_region(enemy_texture)
	player_region = _first_sprite_region(player_texture)

	custom_minimum_size = Vector2(0.0, 72.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_FILL

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	set_process(true)
	call_deferred("_reset_duel")


func set_outcome(resolution_outcome: String) -> void:
	outcome = _normalized_outcome(resolution_outcome)


func _normalized_outcome(value: String) -> String:
	var normalized: String = value.to_lower()

	if normalized in [
		"both_die",
		"enemy_survives",
		"player_survives",
		"both_survive",
	]:
		return normalized

	return "both_die"


func _reset_duel() -> void:
	phase = Phase.APPROACH
	phase_clock = 0.0
	completed_swings = 0

	enemy_dead = false
	player_dead = false

	enemy_x = -DRAW_SIZE.x - ENTRY_PAD
	player_x = size.x + ENTRY_PAD

	var center_x: float = size.x * 0.5
	enemy_target_x = (
		center_x
		- DRAW_SIZE.x
		- CLASH_GAP * 0.5
	)
	player_target_x = (
		center_x
		+ CLASH_GAP * 0.5
	)

	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if enemy_texture == null or player_texture == null:
		return

	match phase:
		Phase.APPROACH:
			_process_approach(delta)

		Phase.CLASH_PAUSE:
			phase_clock += delta
			if phase_clock >= CLASH_PAUSE_SECONDS:
				phase = Phase.ATTACK
				phase_clock = 0.0
				completed_swings = 0

		Phase.ATTACK:
			_process_attack(delta)

		Phase.AFTER_ATTACK_PAUSE:
			phase_clock += delta
			if phase_clock >= AFTER_ATTACK_PAUSE_SECONDS:
				_begin_resolution()

		Phase.RESOLVE:
			phase_clock += delta
			if phase_clock >= DEATH_SECONDS:
				phase = Phase.HOLD
				duel_finished.emit(outcome)

		Phase.HOLD:
			pass

	queue_redraw()


func _process_approach(delta: float) -> void:
	enemy_x = minf(
		enemy_target_x,
		enemy_x + WALK_SPEED * delta
	)
	player_x = maxf(
		player_target_x,
		player_x - WALK_SPEED * delta
	)

	if (
		is_equal_approx(enemy_x, enemy_target_x)
		and is_equal_approx(player_x, player_target_x)
	):
		phase = Phase.CLASH_PAUSE
		phase_clock = 0.0
		clash_started.emit()


func _process_attack(delta: float) -> void:
	phase_clock += delta

	if phase_clock >= SWING_SECONDS:
		phase_clock -= SWING_SECONDS
		completed_swings += 1

		if completed_swings >= attack_swings:
			phase = Phase.AFTER_ATTACK_PAUSE
			phase_clock = 0.0


func _begin_resolution() -> void:
	phase = Phase.RESOLVE
	phase_clock = 0.0

	match outcome:
		"enemy_survives":
			enemy_dead = false
			player_dead = true

		"player_survives":
			enemy_dead = true
			player_dead = false

		"both_survive":
			enemy_dead = false
			player_dead = false

		_:
			enemy_dead = true
			player_dead = true

	resolution_started.emit(outcome)

	if not enemy_dead and not player_dead:
		phase = Phase.HOLD
		duel_finished.emit(outcome)


func _draw() -> void:
	if enemy_texture == null or player_texture == null:
		return

	var base_y: float = maxf(
		0.0,
		(size.y - DRAW_SIZE.y) * 0.5
	)

	var enemy_position := Vector2(enemy_x, base_y)
	var player_position := Vector2(player_x, base_y)

	var enemy_rotation: float = 0.0
	var player_rotation: float = 0.0
	var enemy_alpha: float = 1.0
	var player_alpha: float = 1.0

	# Small opposite bob while walking so a single extracted stand-in frame
	# still reads as movement.
	if phase == Phase.APPROACH:
		var bob: float = sin(Time.get_ticks_msec() * 0.016) * 1.5
		enemy_position.y += bob
		player_position.y -= bob

	# Procedural "weapon swing" stand-in: alternating lunge + tilt.
	if phase == Phase.ATTACK:
		var swing_t: float = clampf(
			phase_clock / SWING_SECONDS,
			0.0,
			1.0
		)
		var arc: float = sin(swing_t * PI)
		var alternate: float = (
			1.0
			if (completed_swings % 2) == 0
			else -1.0
		)

		enemy_position.x += arc * 7.0
		player_position.x -= arc * 7.0

		enemy_rotation = arc * 0.18 * alternate
		player_rotation = -arc * 0.18 * alternate

	# Procedural death fall. Survivors stay upright.
	if phase == Phase.RESOLVE or phase == Phase.HOLD:
		var death_t: float = (
			1.0
			if phase == Phase.HOLD
			else clampf(
				phase_clock / DEATH_SECONDS,
				0.0,
				1.0
			)
		)
		var eased: float = smoothstep(0.0, 1.0, death_t)

		if enemy_dead:
			enemy_rotation = eased * 1.45
			enemy_position.y += eased * 13.0
			enemy_alpha = 1.0 - eased * 0.28

		if player_dead:
			player_rotation = -eased * 1.45
			player_position.y += eased * 13.0
			player_alpha = 1.0 - eased * 0.28

	_draw_actor(
		enemy_texture,
		enemy_region,
		enemy_position,
		enemy_rotation,
		enemy_alpha
	)
	_draw_actor(
		player_texture,
		player_region,
		player_position,
		player_rotation,
		player_alpha
	)


func _draw_actor(
	texture: Texture2D,
	region: Rect2,
	position: Vector2,
	rotation_radians: float,
	alpha: float
) -> void:
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		return

	var center := (
		position
		+ DRAW_SIZE * 0.5
	)

	draw_circle(
		Vector2(
			center.x,
			position.y + DRAW_SIZE.y - 5.0
		),
		14.0,
		Color(0.0, 0.0, 0.0, 0.30 * alpha)
	)

	draw_set_transform(
		center,
		rotation_radians,
		Vector2.ONE
	)

	draw_texture_rect_region(
		texture,
		Rect2(
			-DRAW_SIZE * 0.5,
			DRAW_SIZE
		),
		region,
		Color(1.0, 1.0, 1.0, alpha)
	)

	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)


func _first_sprite_region(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()

	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return Rect2(
			0.0,
			0.0,
			float(texture.get_width()),
			float(texture.get_height())
		)

	var width: int = image.get_width()
	var height: int = image.get_height()

	var seed := Vector2i(-1, -1)

	for y in range(height):
		for x in range(width):
			if image.get_pixel(x, y).a > ALPHA_THRESHOLD:
				seed = Vector2i(x, y)
				break

		if seed.x >= 0:
			break

	if seed.x < 0:
		return Rect2(
			0.0,
			0.0,
			float(width),
			float(height)
		)

	var visited: Dictionary = {}
	var stack: Array[Vector2i] = [seed]

	var min_x: int = seed.x
	var max_x: int = seed.x
	var min_y: int = seed.y
	var max_y: int = seed.y

	var processed: int = 0

	while not stack.is_empty():
		var point: Vector2i = stack.pop_back()

		if (
			point.x < 0
			or point.y < 0
			or point.x >= width
			or point.y >= height
		):
			continue

		var key: int = point.y * width + point.x
		if visited.has(key):
			continue

		visited[key] = true

		if image.get_pixel(point.x, point.y).a <= ALPHA_THRESHOLD:
			continue

		min_x = mini(min_x, point.x)
		max_x = maxi(max_x, point.x)
		min_y = mini(min_y, point.y)
		max_y = maxi(max_y, point.y)

		stack.append(Vector2i(point.x + 1, point.y))
		stack.append(Vector2i(point.x - 1, point.y))
		stack.append(Vector2i(point.x, point.y + 1))
		stack.append(Vector2i(point.x, point.y - 1))

		processed += 1
		if processed >= MAX_FLOOD_PIXELS:
			break

	min_x = maxi(0, min_x - REGION_PAD)
	min_y = maxi(0, min_y - REGION_PAD)
	max_x = mini(width - 1, max_x + REGION_PAD)
	max_y = mini(height - 1, max_y + REGION_PAD)

	return Rect2(
		float(min_x),
		float(min_y),
		float(max_x - min_x + 1),
		float(max_y - min_y + 1)
	)
