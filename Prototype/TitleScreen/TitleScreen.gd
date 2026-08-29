# TITLE_SCREEN_ALIENS_WIPE_V1
extends Control

const NEXT_SCENE: String = "res://CorruptorMain.tscn"
const FINAL_PROGRESS: float = 1.2
const REVEAL_SECONDS: float = 7.5
const LIVING_LEAD_SECONDS: float = REVEAL_SECONDS
const LOGO_RISE_PX: float = 0.0
# TITLE_SCREEN_COLLIDING_CORRUPTION_TIMING_V13
# Logo motion now lives in shader TIME; prompt breathing remains here.
const PROMPT_FADE_SECONDS: float = 2.35
const PROMPT_ALPHA_LOW: float = 0.18
const PROMPT_ALPHA_HIGH: float = 0.82

@onready var logo: TextureRect = $Logo
@onready var prompt: Label = $Prompt

var _revealing: bool = true
var _starting_game: bool = false
var _tween: Tween
var _prompt_tween: Tween
var _living_start_tween: Tween
var _living_started: bool = false
var _living_elapsed: float = 0.0
var _shader_material: ShaderMaterial
var _logo_start_y: float = 0.0


func _ready() -> void:
    _logo_start_y = logo.position.y
    prompt.modulate.a = 0.0

    _shader_material = logo.material as ShaderMaterial

    if _shader_material == null:
        push_error("TitleScreen: Logo is missing its ShaderMaterial.")
        _revealing = false
        prompt.modulate.a = 1.0
        return

    _shader_material.set_shader_parameter(
        "progress",
        0.0
    )

    # TITLE_SCREEN_ROT_TIMING_V4
    # New procedural infection map every launch.
    var rng := RandomNumberGenerator.new()
    rng.randomize()

    _shader_material.set_shader_parameter(
        "run_seed",
        rng.randf_range(
            1.0,
            10000.0
        )
    )

    _shader_material.set_shader_parameter(
        "living_enabled",
        0.0
    )

    _shader_material.set_shader_parameter(
        "living_time",
        0.0
    )

    # Continuous creep: no chunks, no staged bursts, no logo lift.
    _tween = create_tween()

    _tween.tween_property(
        _shader_material,
        "shader_parameter/progress",
        FINAL_PROGRESS,
        REVEAL_SECONDS
    ).set_trans(
        Tween.TRANS_LINEAR
    ).set_ease(
        Tween.EASE_IN_OUT
    )

    _tween.finished.connect(
        _on_reveal_done
    )

    # V13: wake the living corruption immediately.
    # LIVING_LEAD_SECONDS == REVEAL_SECONDS, so this interval resolves to 0.
    # The corruption therefore evolves underneath the reveal from frame zero.
    _living_start_tween = create_tween()

    _living_start_tween.tween_interval(
        max(
            0.0,
            REVEAL_SECONDS - LIVING_LEAD_SECONDS
        )
    )

    _living_start_tween.tween_callback(
        _start_logo_pulse
    )



func _process(
    delta: float
) -> void:
    if not _living_started:
        return

    if _shader_material == null:
        return

    _living_elapsed += delta

    _shader_material.set_shader_parameter(
        "living_time",
        _living_elapsed
    )


func _on_reveal_done() -> void:
    if not _revealing:
        return

    _revealing = false

    _start_logo_pulse()
    _start_prompt_breathe()


func _unhandled_input(
    event: InputEvent
) -> void:
    if _starting_game:
        return

    if not _is_confirm(
        event
    ):
        return

    get_viewport().set_input_as_handled()

    if _revealing:
        _finish_reveal_immediately()
        return

    _start_game()


func _finish_reveal_immediately() -> void:
    if _tween != null:
        _tween.kill()

    if _shader_material != null:
        _shader_material.set_shader_parameter(
            "progress",
            FINAL_PROGRESS
        )

    logo.position.y = (
        _logo_start_y
        - LOGO_RISE_PX
    )

    _on_reveal_done()


func _start_logo_pulse() -> void:
    if _shader_material == null:
        return

    if _living_started:
        return

    _living_started = true
    _living_elapsed = 0.0

    _shader_material.set_shader_parameter(
        "living_time",
        0.0
    )

    _shader_material.set_shader_parameter(
        "living_enabled",
        1.0
    )


func _start_prompt_breathe() -> void:
    if _prompt_tween != null:
        _prompt_tween.kill()

    prompt.modulate.a = PROMPT_ALPHA_LOW

    _prompt_tween = create_tween().set_loops()

    _prompt_tween.tween_property(
        prompt,
        "modulate:a",
        PROMPT_ALPHA_HIGH,
        PROMPT_FADE_SECONDS
    ).set_trans(
        Tween.TRANS_SINE
    ).set_ease(
        Tween.EASE_IN_OUT
    )

    _prompt_tween.tween_property(
        prompt,
        "modulate:a",
        PROMPT_ALPHA_LOW,
        PROMPT_FADE_SECONDS
    ).set_trans(
        Tween.TRANS_SINE
    ).set_ease(
        Tween.EASE_IN_OUT
    )


func _stop_prompt_breathe() -> void:
    if _prompt_tween != null:
        _prompt_tween.kill()
        _prompt_tween = null


func _stop_logo_pulse() -> void:
    _living_started = false
    _living_elapsed = 0.0

    if _living_start_tween != null:
        _living_start_tween.kill()
        _living_start_tween = null

    if _shader_material != null:
        _shader_material.set_shader_parameter(
            "living_enabled",
            0.0
        )

        _shader_material.set_shader_parameter(
            "living_time",
            0.0
        )


func _is_confirm(
    event: InputEvent
) -> bool:
    if event is InputEventKey:
        return (
            event.pressed
            and not event.is_echo()
        )

    if event is InputEventMouseButton:
        return event.pressed

    if event is InputEventJoypadButton:
        return event.pressed

    return false


func _start_game() -> void:
    if _starting_game:
        return

    _starting_game = true

    _stop_logo_pulse()
    _stop_prompt_breathe()

    var error: int = get_tree().change_scene_to_file(
        NEXT_SCENE
    )

    if error != OK:
        _starting_game = false
        push_error(
            "TitleScreen: could not load next scene %s (error %d)."
            % [
                NEXT_SCENE,
                int(error),
            ]
        )
