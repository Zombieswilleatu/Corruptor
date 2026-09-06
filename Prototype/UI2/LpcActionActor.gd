# UI2_LPC_ACTION_ACTOR_V1
# UI2_LPC_ACTION_ACTOR_FULL_PASS_V1
# UI2_ACTION_FULL_WIDTH_OCCLUSION_V6_1
extends Control


const SHEET_COLUMNS: float = 13.0
const SHEET_ROWS: float = 54.0

# Standard LPC directional walk row in the 13 x 54 universal sheet.
# UI2_LPC_DIRECTIONAL_WALK_V1_2
const WALK_LEFT_ROW: int = 9
const WALK_RIGHT_ROW: int = 11
const WALK_FRAME_COUNT: int = 9

const WALK_FPS: float = 8.0
const WALK_SPEED: float = 34.0
const DRAW_SIZE: Vector2 = Vector2(60.0, 60.0)

const ENTRY_PAD: float = 8.0
const EXIT_PAD: float = 8.0


var sheet: Texture2D = null
var current_frame: int = 0
var frame_clock: float = 0.0
var walker_x: float = 0.0
var walk_side: String = "enemy"
var _pass_complete: bool = false


func setup(
	texture: Texture2D,
	side: String = "enemy"
) -> void:
	sheet = texture
	walk_side = side.to_lower()

	custom_minimum_size = Vector2(0.0, 72.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_FILL

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)
	call_deferred("_reset_position")

func _reset_position() -> void:
	current_frame = 0
	frame_clock = 0.0
	_pass_complete = false

	if walk_side == "player":
		walker_x = size.x + ENTRY_PAD
	else:
		walker_x = -DRAW_SIZE.x - ENTRY_PAD

	visible = true
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if sheet == null or _pass_complete:
		return

	frame_clock += delta
	var frame_seconds: float = 1.0 / WALK_FPS

	while frame_clock >= frame_seconds:
		frame_clock -= frame_seconds
		current_frame = (
			current_frame + 1
		) % WALK_FRAME_COUNT

	if walk_side == "player":
		walker_x -= WALK_SPEED * delta

		if walker_x <= -DRAW_SIZE.x - EXIT_PAD:
			_pass_complete = true
			visible = false
			set_process(false)
	else:
		walker_x += WALK_SPEED * delta

		if walker_x >= size.x + EXIT_PAD:
			_pass_complete = true
			visible = false
			set_process(false)

	queue_redraw()

func _draw() -> void:
	if sheet == null or _pass_complete:
		return

	var cell_size := Vector2(
		float(sheet.get_width()) / SHEET_COLUMNS,
		float(sheet.get_height()) / SHEET_ROWS
	)

	var walk_row: int = (
		WALK_LEFT_ROW
		if walk_side == "player"
		else WALK_RIGHT_ROW
	)

	var source_rect := Rect2(
		Vector2(
			float(current_frame) * cell_size.x,
			float(walk_row) * cell_size.y
		),
		cell_size
	)

	var draw_y: float = maxf(
		0.0,
		(size.y - DRAW_SIZE.y) * 0.5
	)

	var shadow_center_x: float = (
		walker_x
		+ DRAW_SIZE.x * 0.5
	)

	# UI2_LPC_ACTION_ACTOR_READABILITY_V2
	draw_circle(
		Vector2(
			shadow_center_x,
			draw_y + DRAW_SIZE.y * 0.52
		),
		24.0,
		Color(
			0.0,
			0.0,
			0.0,
			0.22
		)
	)

	draw_circle(
		Vector2(
			shadow_center_x,
			draw_y + DRAW_SIZE.y - 5.0
		),
		15.0,
		Color(0.0, 0.0, 0.0, 0.34)
	)

	draw_texture_rect_region(
		sheet,
		Rect2(
			Vector2(walker_x, draw_y),
			DRAW_SIZE
		),
		source_rect
	)
