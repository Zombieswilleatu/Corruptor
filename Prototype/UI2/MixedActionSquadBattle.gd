# UI2_MIXED_ACTION_SQUAD_BATTLE_V1
#
# Presentation-only 5v5 stress-test renderer.
#
# Supports TWO temporary animation modes:
#
#   "lpc"
#       Real 13 x 54 LPC slicing for Vulture / Penitent.
#
#   "standin"
#       Irregular Wright / Butcher sheets:
#       auto-extract one visible sprite and animate the whole pose
#       procedurally.
#
# The battle choreography does not care which mode a fighter uses.
extends Control


signal clash_started
signal resolution_started(enemy_survivors, player_survivors)
signal battle_finished(enemy_survivors, player_survivors)


const SHEET_COLUMNS: float = 13.0
const SHEET_ROWS: float = 54.0

const WALK_LEFT_ROW: int = 9
const WALK_RIGHT_ROW: int = 11
const SLASH_LEFT_ROW: int = 13
const SLASH_RIGHT_ROW: int = 15
const HURT_ROW: int = 20

const WALK_FRAME_COUNT: int = 9
const SLASH_FRAME_COUNT: int = 6
const HURT_FRAME_COUNT: int = 6

const WALK_FPS: float = 8.0
const SLASH_FPS: float = 10.0
const HURT_FPS: float = 8.0

const WALK_SPEED: float = 52.0
const DRAW_SIZE: Vector2 = Vector2(42.0, 42.0)

const ENTRY_PAD: float = 8.0
const CLASH_PAUSE_SECONDS: float = 0.24
const AFTER_ATTACK_PAUSE_SECONDS: float = 0.16

const SWING_SECONDS: float = 0.34

# UI2_MIXED_ACTION_CASUALTY_CELEBRATE_V1
const DEATH_SECONDS: float = 1.25
const DEATH_FLASH_SECONDS: float = 0.68
const DEATH_FLASH_COUNT: int = 3
const DEATH_FLASH_DIM_ALPHA: float = 0.16

# Temporary survivor celebration. Replace with a real animation later.
const CELEBRATE_BOUNCE_PX: float = 4.0
const CELEBRATE_JIGGLE_RADIANS: float = 0.075
const CELEBRATE_SPEED: float = 0.009

const DEPTH_SLOTS: int = 5

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


var fighters: Array = []
var standin_region_cache: Dictionary = {}

var phase: Phase = Phase.APPROACH
var phase_clock: float = 0.0
var frame_clock: float = 0.0
var current_frame: int = 0
var completed_swings: int = 0
var attack_swings: int = 3


func setup(
	enemy_specs: Array,
	player_specs: Array,
	swing_count: int = 3
) -> void:
	fighters.clear()
	standin_region_cache.clear()

	attack_swings = maxi(1, swing_count)

	var enemy_index: int = 0
	for spec in enemy_specs:
		if typeof(spec) == TYPE_DICTIONARY:
			_add_fighter(
				spec,
				"enemy",
				enemy_index
			)
			enemy_index += 1

	var player_index: int = 0
	for spec in player_specs:
		if typeof(spec) == TYPE_DICTIONARY:
			_add_fighter(
				spec,
				"player",
				player_index
			)
			player_index += 1

	custom_minimum_size = Vector2(0.0, 88.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_FILL

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	set_process(true)
	call_deferred("_reset_battle")


func _add_fighter(
	spec: Dictionary,
	side: String,
	formation_index: int
) -> void:
	var texture = spec.get("texture", null)
	if texture == null:
		return

	var mode: String = String(
		spec.get("mode", "lpc")
	).to_lower()

	if mode != "standin":
		mode = "lpc"

	var depth: int = clampi(
		int(spec.get("depth", formation_index)),
		0,
		DEPTH_SLOTS - 1
	)

	var region := Rect2()

	if mode == "standin":
		region = _cached_standin_region(texture)

	fighters.append({
		"name": String(spec.get("name", "Unit")),
		"texture": texture,
		"mode": mode,
		"region": region,
		"side": side,
		"depth": depth,
		"formation_index": formation_index,
		"survives": bool(spec.get("survives", false)),
		"x": 0.0,
		"y": 0.0,
		"target_x": 0.0,
	})


func _reset_battle() -> void:
	phase = Phase.APPROACH
	phase_clock = 0.0
	frame_clock = 0.0
	current_frame = 0
	completed_swings = 0

	var available_y: float = maxf(
		0.0,
		size.y - DRAW_SIZE.y
	)
	var center_x: float = size.x * 0.5

	for fighter in fighters:
		var depth: int = int(
			fighter.get("depth", 2)
		)
		var index: int = int(
			fighter.get("formation_index", 0)
		)
		var side: String = String(
			fighter.get("side", "enemy")
		)

		var depth_ratio: float = (
			float(depth)
			/ float(maxi(1, DEPTH_SLOTS - 1))
		)

		# DEPTH RULE:
		# larger Y = visually nearer = rendered later / in front.
		fighter["y"] = available_y * depth_ratio

		# Small per-row X staggering makes a scrum rather than a wall.
		var row_jitter: float = (
			float(depth - 2) * 4.5
			+ float((index % 2) * 3)
		)

		if side == "player":
			fighter["x"] = (
				size.x
				+ ENTRY_PAD
				+ float(index) * 10.0
			)
			fighter["target_x"] = (
				center_x
				- DRAW_SIZE.x * 0.30
				- row_jitter
			)
		else:
			fighter["x"] = (
				-DRAW_SIZE.x
				- ENTRY_PAD
				- float(index) * 10.0
			)
			fighter["target_x"] = (
				center_x
				- DRAW_SIZE.x * 0.70
				+ row_jitter
			)

	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if fighters.is_empty():
		return

	match phase:
		Phase.APPROACH:
			_process_approach(delta)

		Phase.CLASH_PAUSE:
			phase_clock += delta

			if phase_clock >= CLASH_PAUSE_SECONDS:
				_begin_attack()

		Phase.ATTACK:
			_process_attack(delta)

		Phase.AFTER_ATTACK_PAUSE:
			phase_clock += delta

			if phase_clock >= AFTER_ATTACK_PAUSE_SECONDS:
				_begin_resolution()

		Phase.RESOLVE:
			_process_resolution(delta)

		Phase.HOLD:
			pass

	queue_redraw()


func _process_approach(delta: float) -> void:
	_advance_frame(
		delta,
		WALK_FPS,
		WALK_FRAME_COUNT
	)

	var all_arrived: bool = true

	for fighter in fighters:
		var side: String = String(
			fighter.get("side", "enemy")
		)
		var x_pos: float = float(
			fighter.get("x", 0.0)
		)
		var target_x: float = float(
			fighter.get("target_x", 0.0)
		)

		if side == "player":
			x_pos = maxf(
				target_x,
				x_pos - WALK_SPEED * delta
			)
		else:
			x_pos = minf(
				target_x,
				x_pos + WALK_SPEED * delta
			)

		fighter["x"] = x_pos

		if not is_equal_approx(
			x_pos,
			target_x
		):
			all_arrived = false

	if all_arrived:
		phase = Phase.CLASH_PAUSE
		phase_clock = 0.0
		frame_clock = 0.0
		current_frame = 0
		clash_started.emit()


func _begin_attack() -> void:
	phase = Phase.ATTACK
	phase_clock = 0.0
	frame_clock = 0.0
	current_frame = 0
	completed_swings = 0


func _process_attack(delta: float) -> void:
	frame_clock += delta
	phase_clock += delta

	var frame_seconds: float = 1.0 / SLASH_FPS

	while frame_clock >= frame_seconds:
		frame_clock -= frame_seconds
		current_frame = (
			current_frame + 1
		) % SLASH_FRAME_COUNT

	while phase_clock >= SWING_SECONDS:
		phase_clock -= SWING_SECONDS
		completed_swings += 1

		if completed_swings >= attack_swings:
			phase = Phase.AFTER_ATTACK_PAUSE
			phase_clock = 0.0
			frame_clock = 0.0
			return


func _begin_resolution() -> void:
	phase = Phase.RESOLVE
	phase_clock = 0.0
	frame_clock = 0.0
	current_frame = 0

	var counts: Dictionary = _survivor_counts()

	resolution_started.emit(
		int(counts.get("enemy", 0)),
		int(counts.get("player", 0))
	)


func _process_resolution(delta: float) -> void:
	phase_clock += delta

	_advance_frame(
		delta,
		HURT_FPS,
		HURT_FRAME_COUNT
	)

	if phase_clock >= DEATH_SECONDS:
		phase = Phase.HOLD
		phase_clock = DEATH_SECONDS

		var counts: Dictionary = _survivor_counts()

		battle_finished.emit(
			int(counts.get("enemy", 0)),
			int(counts.get("player", 0))
		)


func _survivor_counts() -> Dictionary:
	var enemy_survivors: int = 0
	var player_survivors: int = 0

	for fighter in fighters:
		if not bool(
			fighter.get("survives", false)
		):
			continue

		if String(
			fighter.get("side", "enemy")
		) == "player":
			player_survivors += 1
		else:
			enemy_survivors += 1

	return {
		"enemy": enemy_survivors,
		"player": player_survivors,
	}


func _advance_frame(
	delta: float,
	fps: float,
	frame_count: int
) -> void:
	frame_clock += delta

	var frame_seconds: float = 1.0 / fps

	while frame_clock >= frame_seconds:
		frame_clock -= frame_seconds
		current_frame = (
			current_frame + 1
		) % frame_count


func _draw() -> void:
	if fighters.is_empty():
		return

	var draw_order: Array = fighters.duplicate()
	draw_order.sort_custom(_fighter_behind)

	for fighter in draw_order:
		_draw_fighter(fighter)


func _fighter_behind(
	a: Dictionary,
	b: Dictionary
) -> bool:
	var ay: float = float(a.get("y", 0.0))
	var by: float = float(b.get("y", 0.0))

	if not is_equal_approx(ay, by):
		# Smaller Y is farther away, so draw it first.
		return ay < by

	var ax: float = float(a.get("x", 0.0))
	var bx: float = float(b.get("x", 0.0))

	return ax < bx


func _draw_fighter(fighter: Dictionary) -> void:
	var texture = fighter.get("texture", null)

	if texture == null:
		return

	var side: String = String(
		fighter.get("side", "enemy")
	)
	var mode: String = String(
		fighter.get("mode", "lpc")
	)
	var survives: bool = bool(
		fighter.get("survives", false)
	)

	var position := Vector2(
		float(fighter.get("x", 0.0)),
		float(fighter.get("y", 0.0))
	)

	if mode == "standin":
		_draw_standin(
			fighter,
			position,
			side,
			survives
		)
	else:
		_draw_lpc(
			fighter,
			position,
			side,
			survives
		)


func _dead_visibility_alpha() -> float:
	if phase == Phase.HOLD:
		return 0.0

	if phase != Phase.RESOLVE:
		return 1.0

	if phase_clock < DEATH_FLASH_SECONDS:
		var flash_step: int = int(
			floor(
				(
					phase_clock
					/ DEATH_FLASH_SECONDS
				)
				* float(DEATH_FLASH_COUNT * 2)
			)
		)

		return (
			1.0
			if (flash_step % 2) == 0
			else DEATH_FLASH_DIM_ALPHA
		)

	var fade_t: float = clampf(
		(
			phase_clock - DEATH_FLASH_SECONDS
		)
		/ maxf(
			0.001,
			DEATH_SECONDS - DEATH_FLASH_SECONDS
		),
		0.0,
		1.0
	)

	return 1.0 - fade_t


func _celebration_values(
	fighter: Dictionary
) -> Dictionary:
	var index: int = int(
		fighter.get(
			"formation_index",
			0
		)
	)

	var phase_offset: float = float(index) * 0.85
	var t: float = (
		float(Time.get_ticks_msec())
		* CELEBRATE_SPEED
		+ phase_offset
	)

	return {
		"bounce": sin(t) * CELEBRATE_BOUNCE_PX,
		"jiggle": (
			sin(t * 1.7)
			* CELEBRATE_JIGGLE_RADIANS
		),
	}


func _draw_lpc(
	fighter: Dictionary,
	position: Vector2,
	side: String,
	survives: bool
) -> void:
	var texture = fighter.get("texture", null)
	if texture == null:
		return

	if phase == Phase.HOLD and not survives:
		return

	var row: int = (
		WALK_LEFT_ROW
		if side == "player"
		else WALK_RIGHT_ROW
	)
	var frame: int = current_frame
	var dead_pose: bool = false
	var rotation_radians: float = 0.0
	var alpha: float = 1.0

	match phase:
		Phase.APPROACH:
			pass

		Phase.CLASH_PAUSE:
			frame = 0

		Phase.ATTACK, Phase.AFTER_ATTACK_PAUSE:
			row = (
				SLASH_LEFT_ROW
				if side == "player"
				else SLASH_RIGHT_ROW
			)

			var offset: int = int(
				fighter.get(
					"formation_index",
					0
				)
			) % SLASH_FRAME_COUNT

			frame = (
				current_frame
				+ offset
			) % SLASH_FRAME_COUNT

		Phase.RESOLVE:
			if survives:
				frame = 0
			else:
				row = HURT_ROW
				frame = mini(
					current_frame,
					HURT_FRAME_COUNT - 1
				)
				dead_pose = true
				alpha = _dead_visibility_alpha()

		Phase.HOLD:
			if survives:
				frame = 0

				var celebration: Dictionary = (
					_celebration_values(fighter)
				)

				position.y += float(
					celebration.get(
						"bounce",
						0.0
					)
				)

				rotation_radians = float(
					celebration.get(
						"jiggle",
						0.0
					)
				)

	var cell_size := Vector2(
		float(texture.get_width())
		/ SHEET_COLUMNS,
		float(texture.get_height())
		/ SHEET_ROWS
	)

	var source_rect := Rect2(
		Vector2(
			float(frame) * cell_size.x,
			float(row) * cell_size.y
		),
		cell_size
	)

	_draw_region_actor(
		texture,
		source_rect,
		position,
		rotation_radians,
		alpha,
		Vector2.ONE,
		dead_pose
	)

func _draw_standin(
	fighter: Dictionary,
	position: Vector2,
	side: String,
	survives: bool
) -> void:
	var texture = fighter.get("texture", null)
	if texture == null:
		return

	if phase == Phase.HOLD and not survives:
		return

	var region: Rect2 = fighter.get(
		"region",
		Rect2()
	)

	if region.size.x <= 0.0:
		return

	var index: int = int(
		fighter.get(
			"formation_index",
			0
		)
	)

	var rotation_radians: float = 0.0
	var alpha: float = 1.0

	var flip_x: float = (
		-1.0
		if side == "player"
		else 1.0
	)

	var scale := Vector2(
		flip_x,
		1.0
	)

	if phase == Phase.APPROACH:
		var bob_phase: float = (
			Time.get_ticks_msec() * 0.014
			+ float(index) * 0.9
		)

		position.y += sin(bob_phase) * 1.4

	if phase == Phase.ATTACK:
		var swing_t: float = clampf(
			phase_clock / SWING_SECONDS,
			0.0,
			1.0
		)

		var stagger: float = float(index) * 0.42
		var arc: float = abs(
			sin(
				swing_t * PI
				+ stagger
			)
		)

		if side == "player":
			position.x -= arc * 6.0
			rotation_radians = -arc * 0.17
		else:
			position.x += arc * 6.0
			rotation_radians = arc * 0.17

	if phase == Phase.RESOLVE and not survives:
		var death_t: float = clampf(
			phase_clock / DEATH_SECONDS,
			0.0,
			1.0
		)

		var eased: float = smoothstep(
			0.0,
			1.0,
			death_t
		)

		rotation_radians = (
			eased * 1.35
			if side == "enemy"
			else -eased * 1.35
		)

		position.y += eased * 9.0
		alpha = _dead_visibility_alpha()

	if phase == Phase.HOLD and survives:
		var celebration: Dictionary = (
			_celebration_values(fighter)
		)

		position.y += float(
			celebration.get(
				"bounce",
				0.0
			)
		)

		rotation_radians = float(
			celebration.get(
				"jiggle",
				0.0
			)
		)

	_draw_region_actor(
		texture,
		region,
		position,
		rotation_radians,
		alpha,
		scale,
		not survives
		and phase == Phase.RESOLVE
	)

func _draw_region_actor(
	texture: Texture2D,
	region: Rect2,
	position: Vector2,
	rotation_radians: float,
	alpha: float,
	scale: Vector2,
	dead_pose: bool
) -> void:
	var center := (
		position
		+ DRAW_SIZE * 0.5
	)

	var shadow_alpha: float = (
		0.15
		if dead_pose
		else 0.29
	)

	draw_circle(
		Vector2(
			center.x,
			position.y + DRAW_SIZE.y - 4.0
		),
		11.5,
		Color(
			0.0,
			0.0,
			0.0,
			shadow_alpha * alpha
		)
	)

	draw_set_transform(
		center,
		rotation_radians,
		scale
	)

	draw_texture_rect_region(
		texture,
		Rect2(
			-DRAW_SIZE * 0.5,
			DRAW_SIZE
		),
		region,
		Color(
			1.0,
			1.0,
			1.0,
			alpha
		)
	)

	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)


func _cached_standin_region(
	texture: Texture2D
) -> Rect2:
	var key: String = texture.resource_path

	if key.is_empty():
		key = str(texture.get_instance_id())

	if standin_region_cache.has(key):
		return standin_region_cache[key]

	var region: Rect2 = _first_sprite_region(texture)
	standin_region_cache[key] = region
	return region


func _first_sprite_region(
	texture: Texture2D
) -> Rect2:
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
			if (
				image.get_pixel(x, y).a
				> ALPHA_THRESHOLD
			):
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

		var key: int = (
			point.y * width
			+ point.x
		)

		if visited.has(key):
			continue

		visited[key] = true

		if (
			image.get_pixel(
				point.x,
				point.y
			).a
			<= ALPHA_THRESHOLD
		):
			continue

		min_x = mini(min_x, point.x)
		max_x = maxi(max_x, point.x)
		min_y = mini(min_y, point.y)
		max_y = maxi(max_y, point.y)

		stack.append(
			Vector2i(
				point.x + 1,
				point.y
			)
		)
		stack.append(
			Vector2i(
				point.x - 1,
				point.y
			)
		)
		stack.append(
			Vector2i(
				point.x,
				point.y + 1
			)
		)
		stack.append(
			Vector2i(
				point.x,
				point.y - 1
			)
		)

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
