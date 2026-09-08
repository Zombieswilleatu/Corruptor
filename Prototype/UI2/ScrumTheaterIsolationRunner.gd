# UI2_SCRUM_THEATER_ISOLATION_RUNNER_V1
#
# Standalone visual test. It does NOT load PlayableUI2 and does NOT touch
# MarchingLaneView or production startup.
extends SceneTree


const ResolutionTheaterData = preload(
	"res://Prototype/UI2/ResolutionTheater.gd"
)
const MixedActionSquadBattleData = preload(
	"res://Prototype/UI2/MixedActionSquadBattle.gd"
)

# UI2_SCRUM_THEATER_CLEAN_DOMAIN_STAGE_V1
const DomainCropViewData = preload(
	"res://Prototype/UI2/DomainCropView.gd"
)

const VULTURE_PATH: String = (
	"res://ConceptImages/Sprites/VultureSpriteConcept.png"
)
const PENITENT_PATH: String = (
	"res://ConceptImages/Sprites/PenitentSpriteConcept.png"
)
const WRIGHT_PATH: String = (
	"res://ConceptImages/Sprites/WrightSpriteConcept.png"
)
const BUTCHER_PATH: String = (
	"res://ConceptImages/Sprites/ButcherSpriteConcept.png"
)

# UI2_SCRUM_THEATER_MATCH_REAL_FRAME_V1
# Keep the proven compact logical battle timing, then scale its rendered
# output to occupy the real Resolution Theater frame.
const LOGICAL_BATTLE_SIZE: Vector2 = Vector2(
	400.0,
	100.0
)
const BIG_SCREEN_SCALE: float = 2.25
const WATCHDOG_SECONDS: float = 18.0
const CELEBRATION_HOLD_SECONDS: float = 2.0


var _root_control: Control = null
var _status_label: Label = null
var _watchdog: Timer = null
var _finished: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("")
	print("==============================================")
	print("UI2 SCRUM THEATER ISOLATION RUNNER")
	print("==============================================")
	print("Production PlayableUI2 is NOT being loaded.")
	print("MarchingLaneView is NOT being loaded.")
	print("")

	_root_control = Control.new()
	_root_control.name = "ScrumTheaterIsolationRoot"
	_root_control.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	root.add_child(_root_control)

	await process_frame

	var theater = ResolutionTheaterData.new()
	theater.name = "ResolutionTheater"
	theater.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_root_control.add_child(theater)

	await process_frame

	# ResolutionTheater normally manages its own visibility while playing
	# reveal/result sequences. This isolated test simply uses it as the
	# existing full-screen presentation host.
	theater.visible = true

	var overlay := Control.new()
	overlay.name = "IsolationScrumOverlay"
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 4096
	theater.add_child(overlay)

	var scrim := ColorRect.new()
	scrim.name = "IsolationScrim"
	scrim.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	scrim.color = Color(
		0.0,
		0.0,
		0.0,
		0.92
	)
	overlay.add_child(scrim)

	# ResolutionTheater already draws the correct outer modal frame.
	# This is intentionally a transparent content layer, not another panel.
	var screen := Control.new()
	screen.name = "IsolationTheaterContent"
	screen.set_anchors_preset(
		Control.PRESET_CENTER
	)
	screen.offset_left = -520.0
	screen.offset_top = -195.0
	screen.offset_right = 520.0
	screen.offset_bottom = 195.0
	overlay.add_child(screen)

	var kicker := Label.new()
	kicker.text = "RESOLUTION THEATER"
	kicker.position = Vector2(
		28.0,
		17.0
	)
	kicker.size = Vector2(
		984.0,
		20.0
	)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_size_override(
		"font_size",
		13
	)
	kicker.add_theme_color_override(
		"font_color",
		Color(
			0.62,
			0.57,
			0.49,
			1.0
		)
	)
	screen.add_child(kicker)

	var headline := Label.new()
	headline.text = "THE BATTLEFIELD"
	headline.position = Vector2(
		28.0,
		41.0
	)
	headline.size = Vector2(
		984.0,
		32.0
	)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_font_size_override(
		"font_size",
		25
	)
	headline.add_theme_color_override(
		"font_color",
		Color(
			0.92,
			0.89,
			0.82,
			1.0
		)
	)
	screen.add_child(headline)

	# UI2_SCRUM_THEATER_CLEAN_DOMAIN_STAGE_V1
	# Plain stage: no opaque PanelContainer can cover the terrain.
	var stage := Control.new()
	stage.name = "IsolationBattleStage"
	stage.position = Vector2(
		68.0,
		86.0
	)
	stage.size = Vector2(
		904.0,
		232.0
	)
	stage.clip_contents = true
	screen.add_child(stage)

	# Same production background component used by the little ACTION viewer.
	var domain_texture := load(
		"res://ConceptImages/Menus/Domain1.png"
	) as Texture2D

	var terrain = DomainCropViewData.new()
	terrain.name = "ActionDomainBackdrop"
	terrain.position = Vector2.ZERO
	terrain.size = stage.size
	terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	terrain.z_index = 0
	stage.add_child(terrain)

	if domain_texture != null:
		terrain.setup_camera(
			domain_texture,
			Vector2(
				0.5,
				0.7
			),
			2.2
		)

	# Slight dim, matching the idea of the little ACTION viewer.
	var terrain_scrim := ColorRect.new()
	terrain_scrim.name = "ActionDomainReadabilityScrim"
	terrain_scrim.position = Vector2.ZERO
	terrain_scrim.size = stage.size
	terrain_scrim.color = Color(
		0.0,
		0.0,
		0.0,
		0.10
	)
	terrain_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	terrain_scrim.z_index = 1
	stage.add_child(terrain_scrim)

	var battle_view = MixedActionSquadBattleData.new()
	battle_view.name = "IsolationMixed5v5"
	battle_view.position = Vector2.ZERO
	battle_view.size = LOGICAL_BATTLE_SIZE
	battle_view.z_index = 10

	# Keep the proven compact logical timing; only scale the rendered result.
	battle_view.scale = Vector2(
		BIG_SCREEN_SCALE,
		BIG_SCREEN_SCALE
	)
	stage.add_child(battle_view)

	# Border only; transparent center.
	var stage_border := Panel.new()
	stage_border.name = "IsolationBattleStageBorder"
	stage_border.position = Vector2.ZERO
	stage_border.size = stage.size
	stage_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_border.z_index = 20

	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color(
		0.0,
		0.0,
		0.0,
		0.0
	)
	border_style.border_color = Color(
		0.20,
		0.18,
		0.16,
		1.0
	)
	border_style.set_border_width_all(1)
	stage_border.add_theme_stylebox_override(
		"panel",
		border_style
	)
	stage.add_child(stage_border)

	var textures: Dictionary = _load_textures()

	if textures.is_empty():
		print("ISOLATION FAIL — one or more sprite textures failed to load.")
		quit(2)
		return

	var enemy_specs: Array = [
		{
			"name": "Vulture",
			"texture": textures["vulture"],
			"mode": "lpc",
			"depth": 0,
			"survives": false,
		},
		{
			"name": "Butcher",
			"texture": textures["butcher"],
			"mode": "standin",
			"depth": 2,
			"survives": true,
		},
		{
			"name": "Vulture",
			"texture": textures["vulture"],
			"mode": "lpc",
			"depth": 4,
			"survives": false,
		},
		{
			"name": "Wright",
			"texture": textures["wright"],
			"mode": "standin",
			"depth": 1,
			"survives": false,
		},
		{
			"name": "Butcher",
			"texture": textures["butcher"],
			"mode": "standin",
			"depth": 3,
			"survives": true,
		},
	]

	var player_specs: Array = [
		{
			"name": "Penitent",
			"texture": textures["penitent"],
			"mode": "lpc",
			"depth": 1,
			"survives": true,
		},
		{
			"name": "Wright",
			"texture": textures["wright"],
			"mode": "standin",
			"depth": 3,
			"survives": false,
		},
		{
			"name": "Penitent",
			"texture": textures["penitent"],
			"mode": "lpc",
			"depth": 0,
			"survives": false,
		},
		{
			"name": "Butcher",
			"texture": textures["butcher"],
			"mode": "standin",
			"depth": 4,
			"survives": true,
		},
		{
			"name": "Wright",
			"texture": textures["wright"],
			"mode": "standin",
			"depth": 2,
			"survives": false,
		},
	]

	battle_view.battle_finished.connect(
		_on_battle_finished
	)

	_status_label = Label.new()
	_status_label.text = "5 v 5 · SCRUM IN PROGRESS"
	_status_label.position = Vector2(
		28.0,
		336.0
	)
	_status_label.size = Vector2(
		984.0,
		20.0
	)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override(
		"font_size",
		11
	)
	_status_label.add_theme_color_override(
		"font_color",
		Color(
			0.55,
			0.53,
			0.49,
			1.0
		)
	)
	screen.add_child(_status_label)

	_watchdog = Timer.new()
	_watchdog.name = "IsolationWatchdog"
	_watchdog.one_shot = true
	_watchdog.wait_time = WATCHDOG_SECONDS
	_watchdog.timeout.connect(
		_on_watchdog_timeout
	)
	_root_control.add_child(_watchdog)
	_watchdog.start()

	await process_frame

	battle_view.setup(
		enemy_specs,
		player_specs,
		3
	)

	print(
		"Isolation scrum started. "
		+ "Watchdog = %.1f seconds." % WATCHDOG_SECONDS
	)


func _load_textures() -> Dictionary:
	var vulture := load(
		VULTURE_PATH
	) as Texture2D
	var penitent := load(
		PENITENT_PATH
	) as Texture2D
	var wright := load(
		WRIGHT_PATH
	) as Texture2D
	var butcher := load(
		BUTCHER_PATH
	) as Texture2D

	if (
		vulture == null
		or penitent == null
		or wright == null
		or butcher == null
	):
		return {}

	return {
		"vulture": vulture,
		"penitent": penitent,
		"wright": wright,
		"butcher": butcher,
	}


func _on_battle_finished(
	enemy_survivors: int,
	player_survivors: int
) -> void:
	if _finished:
		return

	_finished = true

	if _watchdog != null:
		_watchdog.stop()

	print(
		"ISOLATION PASS — battle_finished emitted. "
		+ "enemy_survivors=%d player_survivors=%d"
		% [
			enemy_survivors,
			player_survivors,
		]
	)

	if _status_label != null:
		_status_label.text = (
			"RESOLVED · ENEMY %d · PLAYER %d · CELEBRATE"
			% [
				enemy_survivors,
				player_survivors,
			]
		)

	var exit_timer := Timer.new()
	exit_timer.name = "IsolationSuccessExit"
	exit_timer.one_shot = true
	exit_timer.wait_time = CELEBRATION_HOLD_SECONDS
	exit_timer.timeout.connect(
		_on_success_exit
	)
	_root_control.add_child(exit_timer)
	exit_timer.start()


func _on_success_exit() -> void:
	print(
		"Isolation demo complete — closing after survivor celebration."
	)
	quit(0)


func _on_watchdog_timeout() -> void:
	if _finished:
		return

	print("")
	print(
		"ISOLATION FAIL — battle_finished was not emitted within "
		+ "%.1f seconds." % WATCHDOG_SECONDS
	)
	print(
		"This runner will exit instead of hanging."
	)
	quit(3)
