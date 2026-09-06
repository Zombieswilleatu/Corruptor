# UI2_LPC_ACTION_SQUAD_BATTLE_V1
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

const WALK_SPEED: float = 48.0
const DRAW_SIZE: Vector2 = Vector2(52.0, 52.0)

const ENTRY_PAD: float = 8.0
const CLASH_GAP: float = 4.0
const CLASH_PAUSE_SECONDS: float = 0.30
const AFTER_ATTACK_PAUSE_SECONDS: float = 0.16

const DEPTH_SLOTS: int = 5


enum Phase {
	APPROACH,
	CLASH_PAUSE,
	ATTACK,
	AFTER_ATTACK_PAUSE,
	RESOLVE,
	HOLD,
}


var fighters: Array = []

var phase: Phase = Phase.APPROACH
var phase_clock: float = 0.0
var frame_clock: float = 0.0
var current_frame: int = 0
var completed_swings: int = 0
var attack_swings: int = 3

var death_animation_complete: bool = false


func setup(
	enemy_specs: Array,
	player_specs: Array,
	swing_count: int = 3
) -> void:
	fighters.clear()
	attack_swings = maxi(1, swing_count)

	for spec in enemy_specs:
		if typeof(spec) == TYPE_DICTIONARY:
			_add_fighter(spec, "enemy")

	for spec in player_specs:
		if typeof(spec) == TYPE_DICTIONARY:
			_add_fighter(spec, "player")

	custom_minimum_size = Vector2(0.0, 72.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_FILL

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	set_process(true)
	call_deferred("_reset_battle")


func _add_fighter(
	spec: Dictionary,
	side: String
) -> void:
	var texture = spec.get("texture", null)
	if texture == null:
		return

	var depth: int = clampi(
		int(spec.get("depth", 2)),
		0,
		DEPTH_SLOTS - 1
	)

	fighters.append({
		"name": String(spec.get("name", "Unit")),
		"texture": texture,
		"side": side,
		"depth": depth,
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
	death_animation_complete = false

	for fighter in fighters:
		var depth: int = int(fighter.get("depth", 2))
		var depth_ratio: float = (
			float(depth)
			/ float(maxi(1, DEPTH_SLOTS - 1))
		)

		# Higher depth value = lower on screen = visually closer.
		var available_y: float = maxf(
			0.0,
			size.y - DRAW_SIZE.y
		)
		fighter["y"] = available_y * depth_ratio

		var depth_x_jitter: float = (
			float(depth - 2) * 4.0
		)
		var center_x: float = size.x * 0.5

		if String(fighter.get("side", "enemy")) == "player":
			fighter["x"] = (
				size.x
				+ ENTRY_PAD
				+ float(depth) * 13.0
			)
			fighter["target_x"] = (
				center_x
				+ CLASH_GAP * 0.5
				+ depth_x_jitter
			)
		else:
			fighter["x"] = (
				-DRAW_SIZE.x
				- ENTRY_PAD
				- float(depth) * 13.0
			)
			fighter["target_x"] = (
				center_x
				- DRAW_SIZE.x
				- CLASH_GAP * 0.5
				+ depth_x_jitter
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
	_advance_frame(delta, WALK_FPS, WALK_FRAME_COUNT)

	var all_arrived: bool = true

	for fighter in fighters:
		var side: String = String(
			fighter.get("side", "enemy")
		)
		var x_pos: float = float(fighter.get("x", 0.0))
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

		if not is_equal_approx(x_pos, target_x):
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

	var counts: Dictionary = _survivor_counts()

	resolution_started.emit(
		int(counts.get("enemy", 0)),
		int(counts.get("player", 0))
	)


func _process_resolution(delta: float) -> void:
	if death_animation_complete:
		return

	var anyone_dies: bool = false
	for fighter in fighters:
		if not bool(fighter.get("survives", false)):
			anyone_dies = true
			break

	if not anyone_dies:
		death_animation_complete = true
		_finish_resolution()
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

	var counts: Dictionary = _survivor_counts()

	battle_finished.emit(
		int(counts.get("enemy", 0)),
		int(counts.get("player", 0))
	)


func _survivor_counts() -> Dictionary:
	var enemy_survivors: int = 0
	var player_survivors: int = 0

	for fighter in fighters:
		if not bool(fighter.get("survives", false)):
			continue

		if String(fighter.get("side", "enemy")) == "player":
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
		# Lower y is farther back and therefore draws first.
		return ay < by

	# Stable-ish tie break so overlapping actors do not flicker.
	return String(a.get("side", "")) < String(b.get("side", ""))


func _draw_fighter(fighter: Dictionary) -> void:
	var texture = fighter.get("texture", null)
	if texture == null:
		return

	var side: String = String(
		fighter.get("side", "enemy")
	)
	var x_pos: float = float(fighter.get("x", 0.0))
	var y_pos: float = float(fighter.get("y", 0.0))
	var survives: bool = bool(
		fighter.get("survives", false)
	)

	var row: int = WALK_RIGHT_ROW
	var frame: int = current_frame
	var dead_pose: bool = false

	match phase:
		Phase.APPROACH:
			row = (
				WALK_LEFT_ROW
				if side == "player"
				else WALK_RIGHT_ROW
			)

		Phase.CLASH_PAUSE:
			row = (
				WALK_LEFT_ROW
				if side == "player"
				else WALK_RIGHT_ROW
			)
			frame = 0

		Phase.ATTACK, Phase.AFTER_ATTACK_PAUSE:
			row = (
				SLASH_LEFT_ROW
				if side == "player"
				else SLASH_RIGHT_ROW
			)

		Phase.RESOLVE, Phase.HOLD:
			if survives:
				row = (
					WALK_LEFT_ROW
					if side == "player"
					else WALK_RIGHT_ROW
				)
				frame = 0
			else:
				row = HURT_ROW
				dead_pose = true

	_draw_actor(
		texture,
		Vector2(x_pos, y_pos),
		row,
		frame,
		dead_pose
	)


func _draw_actor(
	texture: Texture2D,
	position: Vector2,
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

	var shadow_alpha: float = (
		0.16
		if dead_pose
		else 0.31
	)

	draw_circle(
		Vector2(
			position.x + DRAW_SIZE.x * 0.5,
			position.y + DRAW_SIZE.y - 4.0
		),
		13.0,
		Color(0.0, 0.0, 0.0, shadow_alpha)
	)

	draw_texture_rect_region(
		texture,
		Rect2(
			position,
			DRAW_SIZE
		),
		source_rect
	)
