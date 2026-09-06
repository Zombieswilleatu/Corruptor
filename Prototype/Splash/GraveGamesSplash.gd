# CORRUPTOR_SEPARATE_GRAVE_GAMES_SPLASH_V1_1
extends Control

const PROLOGUE_SCENE: String = "res://Prototype/Prologue/PrologueRunner.tscn"
const SPLASH_LOGO: String = "res://ConceptImages/Splash/Logo1.png"

const FADE_IN_SECONDS: float = 0.70
const HOLD_SECONDS: float = 1.80
const FADE_OUT_SECONDS: float = 0.70


var _transitioning: bool = false


# CORRUPTOR_MURDER_PROCEDURAL_WIND_WHOLESALE_V1
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	_build_black_background()
	call_deferred("_play_logo")


func _build_black_background() -> void:
	var black := ColorRect.new()
	black.name = "SplashBlack"
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)


func _play_logo() -> void:
	var logo_image := Image.new()
	var logo_error: Error = logo_image.load(SPLASH_LOGO)

	if logo_error != OK:
		push_error(
			"GraveGamesSplash: could not load splash PNG: %s (error %d)"
			% [SPLASH_LOGO, int(logo_error)]
		)
		_go_to_prologue()
		return

	var logo_texture := ImageTexture.create_from_image(logo_image)
	if logo_texture == null:
		push_error(
			"GraveGamesSplash: could not create texture: %s"
			% SPLASH_LOGO
		)
		_go_to_prologue()
		return

	var logo := TextureRect.new()
	logo.name = "GraveGamesLogo"
	logo.texture = logo_texture
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.anchor_left = 0.17
	logo.anchor_top = 0.10
	logo.anchor_right = 0.83
	logo.anchor_bottom = 0.90
	logo.offset_left = 0.0
	logo.offset_top = 0.0
	logo.offset_right = 0.0
	logo.offset_bottom = 0.0
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.modulate.a = 0.0
	add_child(logo)

	var fade_in := create_tween()
	fade_in.tween_property(
		logo,
		"modulate:a",
		1.0,
		FADE_IN_SECONDS
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_in.finished

	await get_tree().create_timer(HOLD_SECONDS).timeout

	var fade_out := create_tween()
	fade_out.tween_property(
		logo,
		"modulate:a",
		0.0,
		FADE_OUT_SECONDS
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_out.finished

	_go_to_prologue()


func _go_to_prologue() -> void:
	if _transitioning:
		return

	_transitioning = true
	get_tree().change_scene_to_file(PROLOGUE_SCENE)


