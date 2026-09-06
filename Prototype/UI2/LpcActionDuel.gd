# UI2_LPC_ACTION_DUEL_V1
extends Control


signal clash_started
signal resolution_started(outcome)
signal duel_finished(outcome)


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

const WALK_SPEED: float = 44.0
const DRAW_SIZE: Vector2 = Vector2(60.0, 60.0)

const ENTRY_PAD: float = 8.0
const CLASH_GAP: float = 8.0
const CLASH_PAUSE_SECONDS: float = 0.35
const AFTER_ATTACK_PAUSE_SECONDS: float = 0.18


enum Phase {
	APPROACH,
	CLASH_PAUSE,
	ATTACK,
	AFTER_ATTACK_PAUSE,
	RESOLVE,
	HOLD,
}


var enemy_sheet: Texture2D = null
var player_sheet: Texture2D = null

var outcome: String = "both_die"
var attack_swings: int = 3

var phase: Phase = Phase.APPROACH
var phase_clock: float = 0.0
var frame_clock: float = 0.0
var current_frame: int = 0
var completed_swings: int = 0

var enemy_x: float = 0.0
var player_x: float = 0.0

var enemy_dead: bool = false
var player_dead: bool = false
var death_animation_complete: bool = false


func setup(
	enemy_texture: Texture2D,
	player_texture: Texture2D,
	resolution_outcome: String = "both_die",
	swing_count: int = 3
) -> void:
	enemy_sheet = enemy_texture
	player_sheet = player_texture
	outcome = _normalized_outcome(resolution_outcome)
	attack_swings = maxi(1, swing_count)

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
	frame_clock = 0.0
	current_frame = 0
	completed_swings = 0

	enemy_dead = false
	player_dead = false
	death_animation_complete = false

	enemy_x = -DRAW_SIZE.x - ENTRY_PAD
	player_x = size.x + ENTRY_PAD

	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if enemy_sheet == null or player_sheet == null:
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
	_advance_frame(delta, WALK_FPS, WALK_FRAME_COUNT)

	var center_x: float = size.x * 0.5
	var enemy_target: float = (
		center_x
		- DRAW_SIZE.x
		- CLASH_GAP * 0.5
	)
	var player_target: float = (
		center_x
		+ CLASH_GAP * 0.5
	)

	enemy_x = minf(
		enemy_target,
		enemy_x + WALK_SPEED * delta
	)
	player_x = maxf(
		player_target,
		player_x - WALK_SPEED * delta
	)

	if (
		is_equal_approx(enemy_x, enemy_target)
		and is_equal_approx(player_x, player_target)
	):
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
	var frame_seconds: float = 1.0 / SLASH_FPS

	while frame_clock >= frame_seconds:
		frame_clock -= frame_seconds
		current_frame += 1

		if current_frame >= SLASH_FRAME_COUNT:
			current_frame = 0
			completed_swings += 1

			if completed_swings >= attack_swings:
				phase = Phase.AFTER_ATTACK_PAUSE
				phase_clock = 0.0
				current_frame = SLASH_FRAME_COUNT - 1
				return


func _begin_resolution() -> void:
	phase = Phase.RESOLVE
	phase_clock = 0.0
	frame_clock = 0.0
	current_frame = 0
	death_animation_complete = false

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
		_finish_resolution()


func _process_resolution(delta: float) -> void:
	if death_animation_complete:
		return

	frame_clock += delta
	var frame_seconds: float = 1.0 / HURT_FPS

	while frame_clock >= frame_seconds:
		frame_clock -= frame_seconds
		current_frame += 1

		if current_frame >= HURT_FRAME_COUNT:
			current_frame = HURT_FRAME_COUNT - 1
			death_animation_complete = true
			_finish_resolution()
			return


func _finish_resolution() -> void:
	phase = Phase.HOLD
	phase_clock = 0.0
	frame_clock = 0.0
	duel_finished.emit(outcome)


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
	if enemy_sheet == null or player_sheet == null:
		return

	match phase:
		Phase.APPROACH:
			_draw_actor(
				enemy_sheet,
				enemy_x,
				WALK_RIGHT_ROW,
				current_frame,
				false
			)
			_draw_actor(
				player_sheet,
				player_x,
				WALK_LEFT_ROW,
				current_frame,
				false
			)

		Phase.CLASH_PAUSE:
			_draw_actor(
				enemy_sheet,
				enemy_x,
				WALK_RIGHT_ROW,
				0,
				false
			)
			_draw_actor(
				player_sheet,
				player_x,
				WALK_LEFT_ROW,
				0,
				false
			)

		Phase.ATTACK, Phase.AFTER_ATTACK_PAUSE:
			_draw_actor(
				enemy_sheet,
				enemy_x,
				SLASH_RIGHT_ROW,
				current_frame,
				false
			)
			_draw_actor(
				player_sheet,
				player_x,
				SLASH_LEFT_ROW,
				current_frame,
				false
			)

		Phase.RESOLVE, Phase.HOLD:
			_draw_resolution_actor(
				enemy_sheet,
				enemy_x,
				enemy_dead,
				WALK_RIGHT_ROW
			)
			_draw_resolution_actor(
				player_sheet,
				player_x,
				player_dead,
				WALK_LEFT_ROW
			)


func _draw_resolution_actor(
	texture: Texture2D,
	x_pos: float,
	is_dead: bool,
	survivor_walk_row: int
) -> void:
	if is_dead:
		_draw_actor(
			texture,
			x_pos,
			HURT_ROW,
			current_frame,
			true
		)
	else:
		_draw_actor(
			texture,
			x_pos,
			survivor_walk_row,
			0,
			false
		)


func _draw_actor(
	texture: Texture2D,
	x_pos: float,
	row: int,
	frame: int,
	dead_pose: bool
) -> void:
	var cell_size := Vector2(
		float(texture.get_width()) / SHEET_COLUMNS,
		float(texture.get_height()) / SHEET_ROWS
	)

	var safe_frame: int = clampi(
		frame,
		0,
		int(SHEET_COLUMNS) - 1
	)

	var source_rect := Rect2(
		Vector2(
			float(safe_frame) * cell_size.x,
			float(row) * cell_size.y
		),
		cell_size
	)

	var draw_y: float = maxf(
		0.0,
		(size.y - DRAW_SIZE.y) * 0.5
	)

	var shadow_alpha: float = (
		0.18
		if dead_pose
		else 0.34
	)

	draw_circle(
		Vector2(
			x_pos + DRAW_SIZE.x * 0.5,
			draw_y + DRAW_SIZE.y - 5.0
		),
		15.0,
		Color(0.0, 0.0, 0.0, shadow_alpha)
	)

	draw_texture_rect_region(
		texture,
		Rect2(
			Vector2(x_pos, draw_y),
			DRAW_SIZE
		),
		source_rect
	)
