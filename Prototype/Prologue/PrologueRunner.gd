# CORRUPTOR_PROLOGUE_CRAWLER_STILLS_V2
extends Control

const TITLE_SCENE: String = "res://Prototype/TitleScreen/TitleScreen.tscn"
const MENU_THEME: String = "res://Music/MenuThemeConcept.mp3"
const CRAWLER_FONT: String = "res://Fonts/Grenze_Gotisch/static/GrenzeGotisch-Regular.ttf"

const CRAWLER_SECONDS: float = 105.0
const CRAWLER_WIDTH_RATIO: float = 0.68
const CRAWLER_FONT_SIZE: int = 41
const CRAWLER_TOP_PAD: float = 45.0
const CRAWLER_BOTTOM_PAD: float = 110.0
# Opening mix.


# Music crossfade.


# Timed against the 105-second crawler. These are deliberately exposed.



const STILL_PATHS: PackedStringArray = [
	"res://ConceptImages/StoryBoard/IdyllicConcept.png",
	"res://ConceptImages/StoryBoard/DeathConcept.png",
	"res://ConceptImages/StoryBoard/ResurrectionConcept.png",
	"res://ConceptImages/StoryBoard/WallConcept.png",
	"res://ConceptImages/StoryBoard/CapitalConcept.png",
	"res://ConceptImages/StoryBoard/SoupConcept.png",
	"res://ConceptImages/StoryBoard/ConfrontationConcept.png",
	"res://ConceptImages/StoryBoard/DespairConcept.png",
]

const STILL_STARTS: PackedFloat32Array = [
	7.0,
	19.0,
	28.0,
	38.0,
	50.0,
	58.0,
	66.0,
	84.0,
]

const STILL_FADE_INS: PackedFloat32Array = [
	2.0,
	2.0,
	2.5,
	2.0,
	2.0,
	2.0,
	3.0,
	2.8,
]

const STILL_FADE_OUT_STARTS: PackedFloat32Array = [
	20.0,
	29.0,
	39.0,
	50.5,
	58.5,
	66.5,
	85.5,
	98.0,
]

const STILL_ENDS: PackedFloat32Array = [
	23.5,
	32.5,
	42.5,
	54.0,
	62.0,
	70.0,
	89.0,
	105.0,
]

# Most images are intentionally modest and a little crooked.
# Resurrection is centered/larger. Confrontation dominates the final beat.
const STILL_WIDTHS: PackedFloat32Array = [
	0.36,
	0.39,
	0.56,
	0.42,
	0.47,
	0.45,
	0.76,
	0.58,
]

const STILL_X: PackedFloat32Array = [
	0.035,
	0.205,
	0.220,
	0.055,
	0.490,
	0.135,
	0.110,
	0.230,
]

const STILL_Y: PackedFloat32Array = [
	0.070,
	0.150,
	0.155,
	0.215,
	0.110,
	0.190,
	0.075,
	0.120,
]

const STILL_ROTATIONS: PackedFloat32Array = [
	-2.0,
	1.7,
	0.0,
	-1.3,
	1.2,
	-1.5,
	0.0,
	0.0,
]

const STILL_OPACITY: PackedFloat32Array = [
	0.76,
	0.80,
	0.90,
	0.78,
	0.80,
	0.82,
	0.92,
	0.98,
]

# CORRUPTOR_PROLOGUE_CRAWLER_TEXT_REVISION_V1_1
const CRAWLER_TEXT: String = """THE BREACH

There was a kingdom once. Not a good one. But the cruelties were small, and the harvests were usually enough.

A man named Aldric loved his wife.

That is the entire catastrophe.

The fever took their two children first. Then it took her.

First he turned to prayer. Then medicine.

Then to something darker.

He read a text he should not have read. A list of names, a copy of a copy of a copy of something ancient and long since forgotten, and among them, he found a name he should not have known.

And in a cottage at the edge of a village that no longer exists, he spoke that name into the silence where her breathing used to be.

Kanifous.

There was no devil at the door. No sulfur or bargain or maniacal laughter.

Only a feeling, like a lock turning somewhere beneath the world.

Then Aldric's wife opened her eyes. She breathed. She sat up. She called his name.

For three days, Aldric believed he had succeeded.

On the first day, a guard abandoned his post and walked to an empty hillside. He stood there all night, guarding nothing.

On the second day, a mother left her child and began carrying stones to that same hill. One stone. Then another.

On the third day, a farmer stopped his plow in the middle of a field, took up an old spear, and walked away.

Through quiet whispers and untold pacts, people found new purposes. Some built. Some guarded. Some marched.

Some just followed.

They were still themselves, but their priorities had been...rearranged.

On the fourth day, the sky above the capital split open, and the Lords came through.

Aldric ran home to find that his wife was gone.

There were no signs of struggle.  A bowl of soup still steamed on the table.

The stones on the hillside had become a keep.

Aldric went there carrying the old book. He called the name into the open field.

Nothing answered.

A breeze stirred through the grass. Then a gust. Then a torrent.

And in that gale came Kanifous.

Not because Aldric had called it. It had been coming already.

Kanifous towered above the keep, occupied with some vast design of its own. Lines and symbols were carved into the earth beneath it. The keep. The roads. The cottage. The people.

Aldric shouted again.

Kanifous did not threaten him. It did not mock him. It didn't even look down.

Aldric had opened a door. That did not mean anything on the other side knew his name.

He stood beneath Kanifous, calling for his wife.

A weeping man screaming into a storm, waiting for an answer that would never come.
"""
# CORRUPTOR_PROLOGUE_CRAWLER_TEXT_REVISION_V3
# CORRUPTOR_PROLOGUE_CRAWLER_TEXT_REVISION_V2

var _crawler_root: Control
var _still_layer: Control
var _text_scrim: ColorRect
var _crawler_text: RichTextLabel
var _crawl_tween: Tween
var _music: AudioStreamPlayer

var _crawler_active: bool = true
var _transitioning: bool = false
var _crawl_elapsed: float = 0.0
var _stills: Array[TextureRect] = []


# CORRUPTOR_SEPARATE_SPLASH_TRANSITION_CLEANUP_V1
# CORRUPTOR_MURDER_PROCEDURAL_WIND_WHOLESALE_V1
func _ready() -> void:
	_crawler_active = true
	_crawl_elapsed = 0.0
	_start_menu_music()
	_build_crawler()
	if not get_viewport().size_changed.is_connected(_layout_stills):
		get_viewport().size_changed.connect(_layout_stills)
	set_process(true)
	call_deferred("_start_crawl")


func _process(delta: float) -> void:
	if not _crawler_active:
		return

	_crawl_elapsed = minf(
		_crawl_elapsed + delta,
		CRAWLER_SECONDS
	)
	_update_still_opacity()


func _start_menu_music() -> void:
	_music = AudioStreamPlayer.new()
	_music.name = "MenuThemeMusic"

	var stream: AudioStream = load(MENU_THEME) as AudioStream
	if stream == null:
		push_error("PrologueRunner: could not load menu theme: %s" % MENU_THEME)
		return

	_music.stream = stream
	add_child(_music)
	_music.play()


func _build_crawler() -> void:
	_crawler_root = Control.new()
	_crawler_root.name = "Crawler"
	_crawler_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crawler_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crawler_root)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.0, 0.0, 0.0, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crawler_root.add_child(background)

	_still_layer = Control.new()
	_still_layer.name = "Stills"
	_still_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_still_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crawler_root.add_child(_still_layer)

	_build_stills()
	_build_text_scrim()

	_crawler_text = RichTextLabel.new()
	_crawler_text.name = "Text"
	_crawler_text.visible = false
	_crawler_text.bbcode_enabled = true
	_crawler_text.fit_content = true
	_crawler_text.scroll_active = false
	_crawler_text.selection_enabled = false
	_crawler_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crawler_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var font: Font = load(CRAWLER_FONT) as Font
	if font == null:
		push_error("PrologueRunner: could not load crawler font: %s" % CRAWLER_FONT)
	else:
		_crawler_text.add_theme_font_override("normal_font", font)
		_crawler_text.add_theme_font_override("bold_font", font)

	_crawler_text.add_theme_font_size_override(
		"normal_font_size",
		CRAWLER_FONT_SIZE
	)
	_crawler_text.add_theme_font_size_override(
		"bold_font_size",
		CRAWLER_FONT_SIZE + 9
	)
	_crawler_text.add_theme_color_override(
		"default_color",
		Color(0.82, 0.77, 0.68, 1.0)
	)
	_crawler_text.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 1.0)
	)
	_crawler_text.add_theme_constant_override("shadow_offset_x", 2)
	_crawler_text.add_theme_constant_override("shadow_offset_y", 2)
	_crawler_text.add_theme_color_override(
		"font_outline_color",
		Color(0.0, 0.0, 0.0, 0.92)
	)
	_crawler_text.add_theme_constant_override("outline_size", 2)

	var viewport_size: Vector2 = get_viewport_rect().size
	var text_width: float = viewport_size.x * CRAWLER_WIDTH_RATIO

	_crawler_text.position.x = (viewport_size.x - text_width) * 0.5
	_crawler_text.size.x = text_width
	_crawler_text.text = (
		"[center][font_size=%d]THE BREACH[/font_size][/center]\n\n"
		% (CRAWLER_FONT_SIZE + 16)
		+ _without_heading(CRAWLER_TEXT)
	)
	_crawler_root.add_child(_crawler_text)

	var skip_hint := Label.new()
	skip_hint.name = "SkipHint"
	skip_hint.text = "PRESS ANY KEY TO SKIP"
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_hint.offset_left = -330.0
	skip_hint.offset_top = -52.0
	skip_hint.offset_right = -28.0
	skip_hint.offset_bottom = -18.0
	if font != null:
		skip_hint.add_theme_font_override("font", font)
	skip_hint.add_theme_font_size_override("font_size", 17)
	skip_hint.add_theme_color_override(
		"font_color",
		Color(0.47, 0.44, 0.39, 0.82)
	)
	_crawler_root.add_child(skip_hint)


func _build_stills() -> void:
	_stills.clear()

	for index: int in range(STILL_PATHS.size()):
		var texture: Texture2D = load(STILL_PATHS[index]) as Texture2D
		if texture == null:
			push_error(
				"PrologueRunner: missing storyboard still: %s"
				% STILL_PATHS[index]
			)
			continue

		var still := TextureRect.new()
		still.name = "Still%02d" % (index + 1)
		still.texture = texture
		still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		still.mouse_filter = Control.MOUSE_FILTER_IGNORE
		still.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_still_layer.add_child(still)
		_stills.append(still)

	_layout_stills()
	_update_still_opacity()


# CORRUPTOR_TEXT_SCRIM_V2
func _build_text_scrim() -> void:
	_text_scrim = ColorRect.new()
	_text_scrim.name = "TextScrim"
	_text_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_scrim.color = Color.WHITE

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float core_width : hint_range(0.0, 1.0) = 0.70;
uniform float feather : hint_range(0.0, 0.5) = 0.10;

void fragment() {
	float left_edge = (1.0 - core_width) * 0.5;
	float right_edge = 1.0 - left_edge;

	float left_fade = smoothstep(
		left_edge - feather,
		left_edge,
		UV.x
	);

	float right_fade = 1.0 - smoothstep(
		right_edge,
		right_edge + feather,
		UV.x
	);

	float band = left_fade * right_fade;
	COLOR = vec4(0.0, 0.0, 0.0, band * strength);
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("strength", 0.0)
	material.set_shader_parameter(
		"core_width",
		minf(CRAWLER_WIDTH_RATIO + 0.02, 0.92)
	)
	material.set_shader_parameter("feather", 0.10)

	_text_scrim.material = material

	# _still_layer is already in the crawler tree. add_sibling() places the
	# scrim immediately above it, while the crawl text is added afterward.
	_still_layer.add_sibling(_text_scrim)


func _layout_stills() -> void:
	if _stills.is_empty():
		return

	var viewport_size: Vector2 = get_viewport_rect().size

	for index: int in range(_stills.size()):
		var still: TextureRect = _stills[index]
		var texture: Texture2D = still.texture
		if texture == null:
			continue

		var target_width: float = viewport_size.x * STILL_WIDTHS[index]
		var tex_size: Vector2 = texture.get_size()
		var aspect: float = 1.5
		if tex_size.y > 0.0:
			aspect = tex_size.x / tex_size.y

		var target_height: float = target_width / aspect

		still.size = Vector2(target_width, target_height)
		still.position = Vector2(
			viewport_size.x * STILL_X[index],
			viewport_size.y * STILL_Y[index]
		)
		still.pivot_offset = still.size * 0.5
		still.rotation = deg_to_rad(STILL_ROTATIONS[index])




# CORRUPTOR_PROLOGUE_STORYBOARD_CHAPTER_CADENCE_V1
# CORRUPTOR_PROLOGUE_STORYBOARD_CHAPTER_CADENCE_V1_1
# CORRUPTOR_PROLOGUE_STORYBOARD_ORIGINAL_PLUS3_V1
# CORRUPTOR_PROLOGUE_STORYBOARD_DESPAIR_SLOWFADE_V1_1
func _storyboard_chapter_window_for_path(path: String) -> PackedFloat32Array:
	match path.get_file():
		"IdyllicConcept.png":
			return PackedFloat32Array([10.0, 12.0, 23.0, 26.5])
		"DeathConcept.png":
			return PackedFloat32Array([22.0, 24.0, 32.0, 35.5])
		"ResurrectionConcept.png":
			return PackedFloat32Array([31.0, 33.5, 42.0, 45.5])
		"WallConcept.png":
			return PackedFloat32Array([41.0, 43.0, 53.5, 57.0])
		"CapitalConcept.png":
			return PackedFloat32Array([53.0, 55.0, 61.5, 65.0])
		"SoupConcept.png":
			return PackedFloat32Array([61.0, 63.0, 69.5, 73.0])
		"ConfrontationConcept.png":
			return PackedFloat32Array([69.0, 72.0, 88.5, 92.0])
		"DespairConcept.png":
			return PackedFloat32Array([87.0, 89.8, 97.0, 105.0])
		_:
			return PackedFloat32Array()


func _update_still_opacity() -> void:
	var strongest_visible_image: float = 0.0

	for index: int in range(_stills.size()):
		var alpha: float = _alpha_for_still(index, _crawl_elapsed)
		var opacity: float = STILL_OPACITY[index] * alpha
		_stills[index].modulate = Color(1.0, 1.0, 1.0, opacity)

		strongest_visible_image = maxf(
			strongest_visible_image,
			opacity
		)

	if _text_scrim != null:
		var material := _text_scrim.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter(
				"strength",
				strongest_visible_image * 0.34
			)


func _alpha_for_still(index: int, elapsed: float) -> float:
	if index < 0 or index >= STILL_PATHS.size():
		return 0.0

	var chapter_window: PackedFloat32Array = (
		_storyboard_chapter_window_for_path(STILL_PATHS[index])
	)

	if chapter_window.size() == 4:
		var fade_in_start: float = chapter_window[0]
		var full_start: float = chapter_window[1]
		var fade_out_start: float = chapter_window[2]
		var end_time: float = chapter_window[3]

		if elapsed < fade_in_start or elapsed >= end_time:
			return 0.0

		if elapsed < full_start:
			return smoothstep(
				fade_in_start,
				full_start,
				elapsed
			)

		if elapsed >= fade_out_start:
			return 1.0 - smoothstep(
				fade_out_start,
				end_time,
				elapsed
			)

		return 1.0

	# Unknown/additional stills keep their existing legacy timed-array behavior.
	if (
		index >= STILL_STARTS.size()
		or index >= STILL_FADE_INS.size()
		or index >= STILL_FADE_OUT_STARTS.size()
		or index >= STILL_ENDS.size()
	):
		return 0.0

	var start: float = STILL_STARTS[index]
	var fade_in: float = STILL_FADE_INS[index]
	var fade_out_start: float = STILL_FADE_OUT_STARTS[index]
	var end_time: float = STILL_ENDS[index]

	if elapsed < start or elapsed >= end_time:
		return 0.0

	if elapsed < start + fade_in:
		return clampf(
			(elapsed - start) / maxf(fade_in, 0.001),
			0.0,
			1.0
		)

	if elapsed >= fade_out_start:
		var fade_out: float = maxf(end_time - fade_out_start, 0.001)
		return clampf(
			1.0 - ((elapsed - fade_out_start) / fade_out),
			0.0,
			1.0
		)

	return 1.0



func _without_heading(text: String) -> String:
	var prefix := "THE BREACH\n\n"
	if text.begins_with(prefix):
		return text.substr(prefix.length())
	return text


func _start_crawl() -> void:
	if not _crawler_active or _crawler_text == null:
		return

	await get_tree().process_frame

	if not _crawler_active or _crawler_text == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var content_height: float = maxf(
		float(_crawler_text.get_content_height()) + 36.0,
		viewport_size.y
	)

	_crawler_text.size.y = content_height
	_crawler_text.position.y = viewport_size.y + CRAWLER_TOP_PAD
	_crawler_text.visible = true

	var end_y: float = -content_height - CRAWLER_BOTTOM_PAD

	_crawl_tween = create_tween()
	_crawl_tween.tween_property(
		_crawler_text,
		"position:y",
		end_y,
		CRAWLER_SECONDS
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

	_crawl_tween.finished.connect(_enter_title)


func _unhandled_input(event: InputEvent) -> void:
	if not _crawler_active or _transitioning:
		return

	if not _is_skip_input(event):
		return

	get_viewport().set_input_as_handled()
	_enter_title()


func _is_skip_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.is_echo()

	if event is InputEventMouseButton:
		return event.pressed

	if event is InputEventJoypadButton:
		return event.pressed

	return false


func _enter_title() -> void:
	if _transitioning:
		return

	_transitioning = true
	_crawler_active = false

	if _crawl_tween != null:
		_crawl_tween.kill()
		_crawl_tween = null

	var packed: PackedScene = load(TITLE_SCENE) as PackedScene
	if packed == null:
		_transitioning = false
		_crawler_active = true
		set_process(true)
		push_error("PrologueRunner: could not load title scene: %s" % TITLE_SCENE)
		return

	set_process(false)

	var title: Node = packed.instantiate()
	add_child(title)

	if title is Control:
		var title_control: Control = title as Control
		title_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if _crawler_root != null:
		_crawler_root.queue_free()
		_crawler_root = null

	await get_tree().process_frame
	_suppress_duplicate_menu_music()

	_transitioning = false


func _suppress_duplicate_menu_music() -> void:
	if _music == null:
		return

	var nodes: Array[Node] = []
	_collect_nodes(get_tree().root, nodes)

	for node: Node in nodes:
		if node == _music:
			continue
		if not (node is AudioStreamPlayer):
			continue

		var player: AudioStreamPlayer = node as AudioStreamPlayer
		if player.stream == null:
			continue

		if player.stream.resource_path == MENU_THEME and player.playing:
			player.stop()


func _collect_nodes(node: Node, out: Array[Node]) -> void:
	out.append(node)
	for child: Node in node.get_children():
		_collect_nodes(child, out)
