# UI2_SUBJECT_CARD_ART_SURFACES_V2
class_name UI2MarchingLaneView
extends PanelContainer




# UI2_ACTION_MIXED_5V5_V1
const MixedActionSquadBattleData = preload(
	"res://Prototype/UI2/MixedActionSquadBattle.gd"
)

# UI2_ACTION_SCRUM_THEATER_HOOK_V1
var _scrum_theater_demo_sent: bool = false

# UI2_STANDIN_ACTION_DUEL_WIRING_V1
const StandinActionDuelData = preload(
	"res://Prototype/UI2/StandinActionDuel.gd"
)

# UI2_ACTION_AMBIENT_5V5_V1
const LpcActionSquadBattleData = preload(
	"res://Prototype/UI2/LpcActionSquadBattle.gd"
)

# UI2_ACTION_AMBIENT_DUEL_V1
const LpcActionDuelData = preload(
	"res://Prototype/UI2/LpcActionDuel.gd"
)

# UI2_BATTLEFIELD_BLACK_INTERIOR_V8_1

const SubjectCardArtCatalogData = preload(
	"res://Prototype/UI2/SubjectCardArtCatalog.gd"
)
const SubjectCardHoldPreviewData = preload(
	"res://Prototype/UI2/SubjectCardHoldPreview.gd"
)


signal march_guard_dropped(source_zone, card_id, lane_name)


const SubjectSuitStyleData = preload(
	"res://Prototype/UI2/SubjectSuitStyle.gd"
)

# UI2_VULTURE_LPC_ACTION_V6
# UI2_ACTION_FULL_WIDTH_OCCLUSION_V6_1
# UI2_DOMAIN_BATTLEFIELD_CROP_V7
# UI2_BATTLEFIELD_LAYER_STACK_V7_1
# UI2_DOMAIN_REVEAL_V7_2
# UI2_DOMAIN_DRAW_VIEW_V7_3
# UI2_DOMAIN_DIRECT_TEXTURE_V7_4
# UI2_DOMAIN1_SOURCE_FIX_V7_5
# UI2_DOMAIN_TONE_ALIGNMENT_V7_7
# UI2_ACTION_DOMAIN_OVERSCAN_V7_8
# UI2_ACTION_DOMAIN_VERTICAL_PAN_V7_9
# UI2_ACTION_DOMAIN_DESTINATION_SHIFT_V7_10
# UI2_ACTION_TERRAIN_HOST_V7_11
# UI2_ACTION_TERRAIN_RECT_PLACEMENT_V7_15
# UI2_ACTION_TERRAIN_NUDGE_DOWN_V7_16
# UI2_ACTION_TERRAIN_NUDGE_DOWN_V7_17
# UI2_ACTION_TERRAIN_NUDGE_DOWN_V7_18
# UI2_ACTION_TERRAIN_NUDGE_DOWN_V7_19
# UI2_BATTLEFIELD_BLACK_FIELD_V8
# UI2_ACTION_EXPLICIT_CAMERA_V7_12
# UI2_DOMAIN_ALIGNED_CROPS_V7_6
const DOMAIN_ART_PATH: String = "res://ConceptImages/Menus/Domain1.png"

# One shared DOMAIN neighborhood:
# - Action shows the broad upper view.
# - Lord/Castle use the left/right halves of the same terrain.
const DOMAIN_ACTION_CROP := Rect2(0.26, 0.46, 0.48, 0.42)
const DOMAIN_LORD_CROP := Rect2(0.36, 0.10, 0.12, 0.82)
const DOMAIN_CASTLE_CROP := Rect2(0.48, 0.10, 0.12, 0.82)
const LpcActionActorData = preload(
	"res://Prototype/UI2/LpcActionActor.gd"
)
const DomainCropViewData = preload(
	"res://Prototype/UI2/DomainCropView.gd"
)
const VULTURE_LPC_SPRITE_PATH: String = "res://ConceptImages/Sprites/VultureSpriteConcept.png"



# UI2_ACTION_DIRECTIONAL_SPRITES_V1_2
const PENITENT_LPC_SPRITE_PATH: String = (
	"res://ConceptImages/Sprites/PenitentSpriteConcept.png"
)


# UI2_ACTION_MORE_LPC_SPRITES_V1
const WRIGHT_LPC_SPRITE_PATH: String = (
	"res://ConceptImages/Sprites/WrightSpriteConcept.png"
)
const BUTCHER_LPC_SPRITE_PATH: String = (
	"res://ConceptImages/Sprites/ButcherSpriteConcept.png"
)

# UI2_MARCHING_ACTION_WINDOW_V1
# UI2_BATTLEFIELD_SKIN_V5
# UI2_BATTLEFIELD_SKIN_CROP_V5_1
# UI2_BATTLEFIELD_INTERNAL_ALIGNMENT_V5_2
# UI2_BATTLEFIELD_ACTION_ACTOR_CENTER_V5_3
const BATTLEFIELD_SKIN_PATH: String = "res://ConceptImages/Menus/Battlefield.png"
const LEGACY_STEP_COUNT: float = 3.0
const TRACK_TOP: float = 0.13
const TRACK_BOTTOM: float = 0.87
const AMBIENT_SECONDS: float = 12.0
const AMBIENT_ARCHETYPES: Array[String] = ["Butcher", "Penitent", "Vulture", "Wright"]
const AMBIENT_STATES: Array[String] = ["IDLE", "WALK", "WATCH", "WALK"]


const LANES: Array[String] = [
	"Lord",
	"Castle",
]
const STEP_COUNT: int = 3


var title_label: Label = null
var subtitle_label: Label = null
var lanes_box: HBoxContainer = null
var march_drop_enabled: bool = false
var forced_march_lane: String = ""
var action_mode_label: Label = null
var action_actor_row: HBoxContainer = null
var action_caption: Label = null
var ambient_timer: Timer = null
var _last_human = null
var _last_bot = null
var _ambient_candidates: Array[Dictionary] = []
var _ambient_index: int = -1
var _action_event_active: bool = false
var _battlefield_skin_active: bool = false
var _domain_texture: Texture2D = null


func _ready() -> void:
	custom_minimum_size = Vector2(290, 0)
	size_flags_horizontal = Control.SIZE_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.008, 0.008, 0.010, 1.0)
	panel_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	panel_style.set_border_width_all(0)
	panel_style.set_corner_radius_all(0)
	panel_style.content_margin_left = 0
	panel_style.content_margin_right = 0
	panel_style.content_margin_top = 0
	panel_style.content_margin_bottom = 0
	add_theme_stylebox_override("panel", panel_style)

	var skin_texture := load(BATTLEFIELD_SKIN_PATH) as Texture2D
	_battlefield_skin_active = skin_texture != null
	_domain_texture = load(DOMAIN_ART_PATH) as Texture2D
	if _domain_texture != null:
		print(
			"DOMAIN battlefield texture loaded: ",
			_domain_texture.get_width(),
			"x",
			_domain_texture.get_height(),
			" from ",
			DOMAIN_ART_PATH
		)
	else:
		push_error(
			"DOMAIN battlefield texture FAILED to load: "
			+ DOMAIN_ART_PATH
		)

	if _battlefield_skin_active:
		# UI2_BATTLEFIELD_SKIN_CROP_V5_1
		# The generated Battlefield source has large baked black gutters on
		# both sides. Crop those before scaling so the ornate frame actually
		# occupies the full 290px rail instead of shrinking inside it.
		var source_size := Vector2(
			float(skin_texture.get_width()),
			float(skin_texture.get_height())
		)
		var crop_left: float = source_size.x * 0.105
		var crop_width: float = source_size.x * 0.790

		var cropped_skin := AtlasTexture.new()
		cropped_skin.atlas = skin_texture
		cropped_skin.region = Rect2(
			Vector2(crop_left, 0.0),
			Vector2(crop_width, source_size.y)
		)

		var skin := TextureRect.new()
		skin.name = "BattlefieldSkin"
		skin.texture = cropped_skin
		skin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		skin.stretch_mode = TextureRect.STRETCH_SCALE
		skin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(skin)

	var content_frame := MarginContainer.new()
	content_frame.name = "BattlefieldContentFrame"
	content_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_frame.add_theme_constant_override("margin_left", 10)
	content_frame.add_theme_constant_override("margin_right", 10)
	content_frame.add_theme_constant_override("margin_top", 8)
	content_frame.add_theme_constant_override("margin_bottom", 8)
	add_child(content_frame)

	var outer := VBoxContainer.new()
	outer.name = "MarchingContents"
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 4)
	content_frame.add_child(outer)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)

	if _battlefield_skin_active:
		var title_spacer := Control.new()
		title_spacer.name = "BattlefieldPaintedTitleSpacer"
		title_spacer.custom_minimum_size.y = 48
		title_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outer.add_child(title_spacer)
		title_label.text = ""
		title_label.visible = false
	else:
		title_label.text = "THE BATTLEFIELD"
		outer.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "ENEMY ↓   ·   ↑ YOU"
	subtitle_label.custom_minimum_size.y = 20
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 9)
	subtitle_label.add_theme_color_override(
		"font_color",
		Color(0.67, 0.62, 0.53, 1.0)
	)
	outer.add_child(subtitle_label)

	# UI2_MARCHING_ACTION_WINDOW_TOP_V2
	outer.add_child(_build_action_window())

	lanes_box = HBoxContainer.new()
	lanes_box.name = "LaneTracks"
	lanes_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lanes_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lanes_box.add_theme_constant_override("separation", 5)
	outer.add_child(lanes_box)

	# UI2_MARCHING_BOTTOM_SAFE_AREA_V3
	var bottom_safe := Control.new()
	bottom_safe.name = "BottomSafeArea"
	bottom_safe.custom_minimum_size.y = 14
	bottom_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(bottom_safe)

	if _battlefield_skin_active:
		_install_battlefield_black_field()
		_install_battlefield_black_interior()
		_install_battlefield_frame_overlay(
			skin_texture
		)

	ambient_timer = Timer.new()
	ambient_timer.wait_time = AMBIENT_SECONDS
	ambient_timer.one_shot = false
	ambient_timer.autostart = true
	ambient_timer.timeout.connect(_on_ambient_timer_timeout)
	add_child(ambient_timer)
	_refresh_ambient_window()


func set_march_drop_enabled(
	enabled: bool,
	forced_lane: String = ""
) -> void:
	march_drop_enabled = enabled
	forced_march_lane = forced_lane


func bind_players(
	human,
	bot
) -> void:
	if lanes_box == null:
		return

	_last_human = human
	_last_bot = bot

	for child in lanes_box.get_children():
		lanes_box.remove_child(child)
		child.queue_free()

	subtitle_label.text = "%s ↓   ·   ↑ %s" % [
		String(bot.lord).to_upper() if bot != null else "ENEMY",
		String(human.lord).to_upper() if human != null else "YOU",
	]

	for lane_name: String in LANES:
		lanes_box.add_child(_build_lane(lane_name, human, bot))

	_rebuild_ambient_candidates()
	if not _action_event_active:
		_refresh_ambient_window()


func _build_lane(
	lane_name: String,
	human,
	bot
) -> Control:
	var lane_panel := PanelContainer.new()
	lane_panel.name = "%sLane" % lane_name
	lane_panel.custom_minimum_size = Vector2(132, 0)
	lane_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lane_panel.clip_contents = true

	var lane_accepts_drop: bool = (
		march_drop_enabled
		and (
			forced_march_lane.is_empty()
			or forced_march_lane == lane_name
		)
	)

	var lane_style := StyleBoxFlat.new()
	lane_style.bg_color = (
		Color(0.0, 0.0, 0.0, 0.0)
		if _battlefield_skin_active
		else Color(0.045, 0.045, 0.052, 1.0)
	)
	lane_style.border_color = (
		Color(0.38, 0.62, 0.96, 1.0)
		if lane_accepts_drop
		else Color(0.0, 0.0, 0.0, 0.0)
		if _battlefield_skin_active
		else Color(0.17, 0.18, 0.21, 1.0)
	)
	lane_style.set_border_width_all(
		2
		if lane_accepts_drop
		else 0
		if _battlefield_skin_active
		else 1
	)
	lane_style.set_corner_radius_all(4)
	lane_style.content_margin_left = 4
	lane_style.content_margin_right = 4
	lane_style.content_margin_top = 2
	lane_style.content_margin_bottom = 4
	lane_panel.add_theme_stylebox_override(
		"panel",
		lane_style
	)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	lane_panel.add_child(column)

	var lane_title := Label.new()
	lane_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lane_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lane_title.custom_minimum_size.y = (
		30
		if _battlefield_skin_active
		else 0
	)
	lane_title.text = (
		""
		if _battlefield_skin_active
		else lane_name.to_upper()
	)
	lane_title.add_theme_font_size_override("font_size", 12)
	column.add_child(lane_title)

	var track := PanelContainer.new()
	track.name = "ContinuousTrack"
	track.custom_minimum_size.y = 260
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track.clip_contents = true

	var track_style := StyleBoxFlat.new()
	track_style.bg_color = (
		Color(0.0, 0.0, 0.0, 0.10)
		if _battlefield_skin_active
		else Color(0.032, 0.032, 0.039, 1.0)
	)
	track_style.border_color = (
		Color(0.0, 0.0, 0.0, 0.0)
		if _battlefield_skin_active
		else Color(0.11, 0.12, 0.14, 1.0)
	)
	track_style.set_border_width_all(
		0
		if _battlefield_skin_active
		else 1
	)
	track_style.set_corner_radius_all(3)
	track.add_theme_stylebox_override("panel", track_style)
	column.add_child(track)

	var lane_domain_region: Rect2 = (
		DOMAIN_LORD_CROP
		if lane_name == "Lord"
		else DOMAIN_CASTLE_CROP
	)

	if _domain_texture != null:
		var lane_domain_host := MarginContainer.new()
		lane_domain_host.name = "Domain%sBackdropHost" % lane_name
		lane_domain_host.z_index = 30
		lane_domain_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lane_domain_host.add_theme_constant_override("margin_left", 3)
		lane_domain_host.add_theme_constant_override("margin_right", 3)
		lane_domain_host.add_theme_constant_override("margin_top", 3)
		lane_domain_host.add_theme_constant_override("margin_bottom", 4)
		track.add_child(lane_domain_host)
		lane_domain_host.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)

		var lane_domain = DomainCropViewData.new()
		lane_domain.name = "Domain%sBackdrop" % lane_name
		lane_domain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lane_domain_host.add_child(lane_domain)
		lane_domain.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		lane_domain.setup(
			_domain_texture,
			lane_domain_region,
			0.46,
			0.76,
			0.66,
			0.26,
			0.10
		)

	var field := Control.new()
	field.name = "Field"
	field.z_index = 50
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(field)
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_track_furniture(field)

	var bot_marchers: Array = _marchers_in_lane(bot, lane_name)
	var human_marchers: Array = _marchers_in_lane(human, lane_name)

	for index: int in range(bot_marchers.size()):
		_add_marcher_chit(
			field,
			bot_marchers[index],
			true,
			index
		)

	for index: int in range(human_marchers.size()):
		_add_marcher_chit(
			field,
			human_marchers[index],
			false,
			index
		)

	if march_drop_enabled:
		lane_panel.tooltip_text = (
			"Drop a Lord or Castle Guard here to launch it into the %s lane."
			% lane_name
			if lane_accepts_drop
			else "Reactive March is restricted to the %s lane."
			% forced_march_lane
		)
		if lane_accepts_drop:
			lane_panel.mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
	else:
		lane_panel.tooltip_text = (
			"%s lane · continuous battlefield track"
			% lane_name
		)

	_configure_lane_drop_recursive(lane_panel, lane_name)
	return lane_panel


func _configure_lane_drop_recursive(
	node: Node,
	lane_name: String
) -> void:
	if node is Control:
		var control := node as Control
		control.set_drag_forwarding(
			Callable(),
			_can_drop_march_data.bind(
				lane_name
			),
			_drop_march_data.bind(
				lane_name
			)
		)

	for child in node.get_children():
		_configure_lane_drop_recursive(
			child,
			lane_name
		)


func _can_drop_march_data(
	_at_position: Vector2,
	data,
	lane_name: String
) -> bool:
	if (
		not march_drop_enabled
		or typeof(data) != TYPE_DICTIONARY
		or String(data.get("ui2_type", "")) != "march_guard"
		or String(data.get("source_zone", "")) not in ["Lord", "Castle"]
		or String(data.get("card", "")).is_empty()
	):
		return false

	if (
		not forced_march_lane.is_empty()
		and forced_march_lane != lane_name
	):
		return false

	return lane_name in LANES


func _drop_march_data(
	at_position: Vector2,
	data,
	lane_name: String
) -> void:
	if not _can_drop_march_data(
		at_position,
		data,
		lane_name
	):
		return

	march_guard_dropped.emit(
		String(data.get("source_zone", "")),
		String(data.get("card", "")),
		lane_name
	)


func _add_track_furniture(field: Control) -> void:
	# Direction now lives on each marcher chit, not in a center divider.
	# The lane is one shared piece of ground: units may spread or stack
	# horizontally regardless of owner.
	var enemy_gate := Label.new()
	enemy_gate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_gate.text = "▼ ENEMY"
	enemy_gate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_gate.add_theme_font_size_override("font_size", 9)
	enemy_gate.add_theme_color_override(
		"font_color",
		Color(0.63, 0.37, 0.39, 0.90)
	)
	enemy_gate.anchor_right = 1.0
	enemy_gate.offset_top = 5.0
	enemy_gate.offset_bottom = 22.0
	field.add_child(enemy_gate)

	var human_gate := Label.new()
	human_gate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	human_gate.text = "YOU ▲"
	human_gate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	human_gate.add_theme_font_size_override("font_size", 9)
	human_gate.add_theme_color_override(
		"font_color",
		Color(0.39, 0.55, 0.78, 0.92)
	)
	human_gate.anchor_top = 1.0
	human_gate.anchor_bottom = 1.0
	human_gate.anchor_right = 1.0
	human_gate.offset_top = -34.0
	human_gate.offset_bottom = -16.0
	field.add_child(human_gate)


func _add_marcher_chit(
	field: Control,
	marcher,
	enemy_side: bool,
	index: int
) -> void:
	var suit_name: String = _marcher_suit_name(marcher)
	var accent: Color = _marcher_color(suit_name)
	var progress: float = _marcher_progress(marcher)
	var y_anchor: float = (
		lerpf(TRACK_TOP, TRACK_BOTTOM, progress)
		if enemy_side
		else lerpf(TRACK_BOTTOM, TRACK_TOP, progress)
	)

	# Both armies share the same lane width. Ownership is communicated by
	# the directional pointer on the leading edge of the chit.
	var spread_column: int = index % 3
	var depth_row: int = int(index / 3)
	var x_anchor: float = (
		0.5
		+ float(spread_column - 1) * 0.105
	)
	var depth_nudge: float = (
		float(depth_row)
		* 0.014
		* (1.0 if enemy_side else -1.0)
	)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(30, 34)
	holder.anchor_left = clampf(
		x_anchor,
		0.18,
		0.82
	)
	holder.anchor_right = holder.anchor_left
	holder.anchor_top = clampf(
		y_anchor + depth_nudge,
		TRACK_TOP,
		TRACK_BOTTOM
	)
	holder.anchor_bottom = holder.anchor_top
	holder.offset_left = -15.0
	holder.offset_right = 15.0
	holder.offset_top = -17.0
	holder.offset_bottom = 17.0
	holder.mouse_filter = Control.MOUSE_FILTER_STOP

	var body := PanelContainer.new()
	body.custom_minimum_size = Vector2(24, 24)
	body.anchor_left = 0.5
	body.anchor_right = 0.5
	body.anchor_top = 0.5
	body.anchor_bottom = 0.5
	body.offset_left = -12.0
	body.offset_right = 12.0
	body.offset_top = -12.0
	body.offset_bottom = 12.0
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = accent.darkened(0.58)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	body.add_theme_stylebox_override(
		"panel",
		style
	)
	holder.add_child(body)

	var glyph := Label.new()
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.text = _marcher_glyph(suit_name)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override(
		"font_size",
		10
	)
	glyph.add_theme_color_override(
		"font_color",
		accent.lightened(0.38)
	)
	body.add_child(glyph)

	var pointer := Label.new()
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.text = "▼" if enemy_side else "▲"
	pointer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pointer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pointer.anchor_left = 0.5
	pointer.anchor_right = 0.5
	pointer.anchor_top = 0.5
	pointer.anchor_bottom = 0.5
	pointer.offset_left = -7.0
	pointer.offset_right = 7.0

	if enemy_side:
		pointer.offset_top = 9.0
		pointer.offset_bottom = 24.0
	else:
		pointer.offset_top = -24.0
		pointer.offset_bottom = -9.0

	pointer.add_theme_font_size_override(
		"font_size",
		11
	)
	pointer.add_theme_color_override(
		"font_color",
		accent
	)
	holder.add_child(pointer)

	holder.tooltip_text = (
		"%s · %s · %d%% across the lane"
		% [
			suit_name,
			"moving down" if enemy_side else "moving up",
			int(round(progress * 100.0)),
		]
	)

	field.add_child(holder)


func _marchers_in_lane(player, lane_name: String) -> Array:
	var result: Array = []
	if player == null:
		return result
	for marcher in player.marchers:
		if String(marcher.get("lane", "")) == lane_name:
			result.append(marcher)
	return result


func _marcher_progress(marcher) -> float:
	if typeof(marcher) != TYPE_DICTIONARY:
		return 0.0
	if marcher.has("progress"):
		return clampf(float(marcher.get("progress", 0.0)), 0.0, 1.0)
	var legacy_pos: float = float(marcher.get("pos", 0.0))
	return clampf(legacy_pos / maxf(1.0, LEGACY_STEP_COUNT - 1.0), 0.0, 1.0)


func _marcher_suit_name(marcher) -> String:
	if typeof(marcher) != TYPE_DICTIONARY:
		return "Unknown"
	if marcher.has("suit") and not String(marcher.get("suit", "")).is_empty():
		return String(marcher.get("suit", ""))
	var card = marcher.get("card", null)
	return String(card.suit) if card != null else "Unknown"


func _marcher_color(suit_name: String) -> Color:
	match suit_name.to_lower():
		"butcher":
			return Color(0.72, 0.18, 0.22, 1.0)
		"penitent":
			return Color(0.24, 0.46, 0.76, 1.0)
		"vulture":
			return Color(0.48, 0.25, 0.68, 1.0)
		"wright":
			return Color(0.78, 0.61, 0.18, 1.0)
		_:
			return SubjectSuitStyleData.accent(suit_name)


func _marcher_glyph(suit_name: String) -> String:
	match suit_name.to_lower():
		"butcher": return "B"
		"penitent": return "P"
		"vulture": return "V"
		"wright": return "W"
		_: return "?"


# UI2_BATTLEFIELD_BLACK_FIELD_V8
func _install_battlefield_black_field() -> void:
	var black_field := ColorRect.new()
	black_field.name = "BattlefieldBlackField"
	black_field.color = Color.BLACK
	black_field.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Above the gray/base Battlefield painting, below all Domain scenery.
	black_field.z_index = 20

	add_child(black_field)
	black_field.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


# UI2_BATTLEFIELD_BLACK_INTERIOR_V8_1
func _install_battlefield_black_interior() -> void:
	var black_fill := ColorRect.new()
	black_fill.name = "BattlefieldBlackInterior"
	black_fill.color = Color.BLACK
	black_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black_fill.z_index = 20

	add_child(black_fill)
	black_fill.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


# UI2_BATTLEFIELD_KEY_OUT_GRAY_V8_2
func _install_battlefield_frame_overlay(
	skin_texture: Texture2D
) -> void:
	if skin_texture == null:
		return

	var source_size := Vector2(
		float(skin_texture.get_width()),
		float(skin_texture.get_height())
	)

	var crop_left: float = source_size.x * 0.105
	var crop_width: float = source_size.x * 0.790

	var cropped_skin := AtlasTexture.new()
	cropped_skin.atlas = skin_texture
	cropped_skin.region = Rect2(
		Vector2(crop_left, 0.0),
		Vector2(crop_width, source_size.y)
	)

	var overlay := TextureRect.new()
	overlay.name = "BattlefieldFrameOverlay"
	overlay.texture = cropped_skin
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 40

	var shader := Shader.new()
	shader.code = (
		"shader_type canvas_item;\n"
		+ "\n"
		+ "void fragment() {\n"
		+ "\tvec4 c = texture(TEXTURE, UV);\n"
		+ "\tfloat luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));\n"
		+ "\tfloat warm = max(0.0, c.r - c.b);\n"
		+ "\tfloat bright_keep = smoothstep(0.62, 0.82, luma);\n"
		+ "\tfloat bronze_keep = smoothstep(0.045, 0.15, warm);\n"
		+ "\tfloat keyed_alpha = max(bright_keep, bronze_keep) * c.a;\n"
		+ "\tCOLOR = vec4(c.rgb, keyed_alpha);\n"
		+ "}\n"
	)

	var material := ShaderMaterial.new()
	material.shader = shader
	overlay.material = material

	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


func _domain_crop_texture(
	normalized_region: Rect2
) -> Texture2D:
	if _domain_texture == null:
		return null

	var source_size := Vector2(
		float(_domain_texture.get_width()),
		float(_domain_texture.get_height())
	)

	var crop := AtlasTexture.new()
	crop.atlas = _domain_texture
	crop.region = Rect2(
		Vector2(
			normalized_region.position.x * source_size.x,
			normalized_region.position.y * source_size.y
		),
		Vector2(
			normalized_region.size.x * source_size.x,
			normalized_region.size.y * source_size.y
		)
	)

	return crop


func _build_action_window() -> Control:
	var panel := PanelContainer.new()
	panel.name = "ActionWindow"
	panel.custom_minimum_size.y = 202
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(0.0, 0.0, 0.0, 0.0)
		if _battlefield_skin_active
		else Color(0.022, 0.022, 0.028, 1.0)
	)
	style.border_color = (
		Color(0.0, 0.0, 0.0, 0.0)
		if _battlefield_skin_active
		else Color(0.18, 0.19, 0.22, 1.0)
	)
	style.set_border_width_all(
		0
		if _battlefield_skin_active
		else 1
	)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 3)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = (
		46
		if _battlefield_skin_active
		else 0
	)
	outer.add_child(header)

	var title := Label.new()
	title.text = (
		""
		if _battlefield_skin_active
		else "ACTION WINDOW"
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 11)
	header.add_child(title)

	action_mode_label = Label.new()
	action_mode_label.text = "AMBIENT"
	action_mode_label.visible = not _battlefield_skin_active
	action_mode_label.add_theme_font_size_override("font_size", 8)
	action_mode_label.add_theme_color_override(
		"font_color",
		Color(0.66, 0.62, 0.54, 0.92)
	)
	header.add_child(action_mode_label)

	# The painted ACTION opening is not a separate image asset, but it IS a
	# real UI region. This stage is the clip mask for that opening.
	var stage := PanelContainer.new()
	stage.name = "SpriteStage"
	stage.custom_minimum_size.y = 124
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true

	var stage_style := StyleBoxFlat.new()
	stage_style.bg_color = (
		Color(0.0, 0.0, 0.0, 0.0)
		if _battlefield_skin_active
		else Color(0.038, 0.038, 0.045, 1.0)
	)
	stage_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	stage_style.set_border_width_all(0)
	stage_style.set_corner_radius_all(3)
	stage.add_theme_stylebox_override("panel", stage_style)
	var stage_slot := Control.new()
	stage_slot.name = "ActionStageSlot"
	stage_slot.custom_minimum_size.y = 124
	stage_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(stage_slot)

	# SpriteStage stays put for the sprite/caption layer.
	stage_slot.add_child(stage)
	stage.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	stage.offset_left = 0.0
	stage.offset_right = 0.0
	stage.offset_top = 0.0
	stage.offset_bottom = 0.0

	# Overscan the terrain behind the painted opening. We no longer try to
	# make the source crop fit the frame exactly; the clip mask does that.
	if _domain_texture != null:
		# UI2_ACTION_TERRAIN_HOST_V7_11
		# SpriteStage is a PanelContainer, so it is allowed to size this
		# host. The host itself is a plain Control, therefore the oversized
		# / shifted terrain child below keeps the offsets we assign.
		var terrain_clip := Control.new()
		terrain_clip.name = "ActionTerrainClip"
		terrain_clip.z_index = 30
		terrain_clip.clip_contents = true
		terrain_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage_slot.add_child(terrain_clip)
		terrain_clip.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		# UI2_ACTION_TERRAIN_RECT_PLACEMENT_V7_15
		# The terrain viewport itself was too high and too short.
		terrain_clip.offset_left = 0.0
		terrain_clip.offset_right = 0.0
		terrain_clip.offset_top = 19.0
		terrain_clip.offset_bottom = 45.0

		var action_domain = DomainCropViewData.new()
		action_domain.name = "DomainActionBackdrop"
		# UI2_DOMAIN_CAMERA_DIAGNOSTIC_V7_13
		action_domain.modulate = Color(1.0, 0.18, 0.18, 1.0)
		action_domain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		terrain_clip.add_child(action_domain)

		# Oversize and physically shift the rendered scene DOWN. Because
		# this child now belongs to a plain Control, these offsets are no
		# longer rewritten by PanelContainer.
		action_domain.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		action_domain.offset_left = 0.0
		action_domain.offset_right = 0.0
		action_domain.offset_top = 0.0
		action_domain.offset_bottom = 0.0

		# UI2_ACTION_EXPLICIT_CAMERA_V7_12
		# Two knobs now control composition:
		#   pan.y moves the camera vertically through Domain1
		#   zoom changes how much source terrain is visible
		action_domain.setup_camera(
			_domain_texture,
			Vector2(
				0.50,
				0.70
			),
			2.20,
			0.56,
			0.78,
			0.72,
			0.12,
			0.00
		)

	# Live sprite/caption layer stays above terrain.
	var stage_inner := MarginContainer.new()
	stage_inner.z_index = 50
	stage_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_inner.add_theme_constant_override("margin_left", 6)
	stage_inner.add_theme_constant_override("margin_right", 6)
	stage_inner.add_theme_constant_override(
		"margin_top",
		8 if _battlefield_skin_active else 6
	)
	stage_inner.add_theme_constant_override("margin_bottom", 6)
	stage.add_child(stage_inner)

	var performer_stack := VBoxContainer.new()
	performer_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	performer_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	performer_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	performer_stack.add_theme_constant_override("separation", 4)
	stage_inner.add_child(performer_stack)

	action_actor_row = HBoxContainer.new()
	action_actor_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_actor_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_actor_row.custom_minimum_size = Vector2(0, 76)
	action_actor_row.clip_contents = true
	performer_stack.add_child(action_actor_row)

	action_caption = Label.new()
	action_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_caption.add_theme_font_size_override("font_size", 9)
	action_caption.add_theme_color_override(
		"font_color",
		Color(0.64, 0.61, 0.55, 1.0)
	)
	performer_stack.add_child(action_caption)

	return panel


func _action_actor_standin(
	suit_name: String,
	side_text: String = ""
) -> Control:
	var normalized_suit: String = suit_name.to_lower()
	var sprite_path: String = ""

	match normalized_suit:
		"vulture":
			sprite_path = VULTURE_LPC_SPRITE_PATH
		"penitent":
			sprite_path = PENITENT_LPC_SPRITE_PATH
		"wright":
			sprite_path = WRIGHT_LPC_SPRITE_PATH
		"butcher":
			sprite_path = BUTCHER_LPC_SPRITE_PATH

	if not sprite_path.is_empty():
		var sprite_texture := load(
			sprite_path
		) as Texture2D

		if sprite_texture != null:
			var lpc_actor = LpcActionActorData.new()
			lpc_actor.name = (
				"%sLpcActor" % suit_name.capitalize()
			)

			var actor_side: String = side_text.to_lower()
			if actor_side != "player":
				actor_side = "enemy"

			lpc_actor.setup(
				sprite_texture,
				actor_side
			)
			lpc_actor.tooltip_text = (
				"%s marcher · LPC walk preview"
				% suit_name.capitalize()
			)
			return lpc_actor

	var actor := PanelContainer.new()
	actor.custom_minimum_size = Vector2(48, 58)
	var accent: Color = _marcher_color(suit_name)
	var style := StyleBoxFlat.new()
	style.bg_color = accent.darkened(0.72)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	actor.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	actor.add_child(box)

	var glyph := Label.new()
	glyph.text = _marcher_glyph(suit_name)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	glyph.add_theme_font_size_override("font_size", 22)
	glyph.add_theme_color_override(
		"font_color",
		accent.lightened(0.34)
	)
	box.add_child(glyph)

	if not side_text.is_empty():
		var side := Label.new()
		side.text = side_text
		side.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		side.add_theme_font_size_override("font_size", 8)
		box.add_child(side)

	return actor

func _clear_action_actors() -> void:
	if action_actor_row == null:
		return
	for child in action_actor_row.get_children():
		action_actor_row.remove_child(child)
		child.queue_free()


func _rebuild_ambient_candidates() -> void:
	_ambient_candidates.clear()

	for lane_name: String in LANES:
		for marcher in _marchers_in_lane(
			_last_bot,
			lane_name
		):
			_ambient_candidates.append({
				"suit": _marcher_suit_name(marcher),
				"lane": lane_name,
				"side": "ENEMY",
			})

		for marcher in _marchers_in_lane(
			_last_human,
			lane_name
		):
			_ambient_candidates.append({
				"suit": _marcher_suit_name(marcher),
				"lane": lane_name,
				"side": "YOU",
			})

	# Until the battlefield contains real marchers, showcase the one
	# production-format sprite currently available instead of cycling fake
	# placeholder archetypes.
	if _ambient_candidates.is_empty():
		_ambient_candidates.append({
			"suit": "Vulture",
			"lane": "",
			"side": "",
		})

	if _ambient_index >= _ambient_candidates.size():
		_ambient_index = -1


func _refresh_ambient_window() -> void:
	if (
		action_actor_row == null
		or action_caption == null
		or action_mode_label == null
	):
		return

	if _ambient_candidates.is_empty():
		_rebuild_ambient_candidates()

	if _ambient_candidates.is_empty():
		return

	_ambient_index = (
		_ambient_index + 1
	) % _ambient_candidates.size()

	var entry: Dictionary = (
		_ambient_candidates[_ambient_index]
	)
	var suit_name: String = String(
		entry.get("suit", "Unknown")
	)
	var lane_name: String = String(
		entry.get("lane", "")
	)
	var side_name: String = String(
		entry.get("side", "")
	)

	# Temporary ambient sprite cycle.
	# enemy -> right; player -> left.
	if (_ambient_index % 2) == 0:
		suit_name = "Vulture"
		side_name = "enemy"
	else:
		suit_name = "Penitent"
		side_name = "player"

	var state_name: String = "WALK"
	# UI2_ACTION_AMBIENT_FORCE_PENITENT_V1
	# Current visual demo: player Penitent marches RIGHT -> LEFT.
	suit_name = "Penitent"
	side_name = "player"
	state_name = "WALK"

	_clear_action_actors()
	# UI2_ACTION_MIXED_5V5_V1
	var vulture_texture := load(
		VULTURE_LPC_SPRITE_PATH
	) as Texture2D
	var penitent_texture := load(
		PENITENT_LPC_SPRITE_PATH
	) as Texture2D
	var wright_texture := load(
		WRIGHT_LPC_SPRITE_PATH
	) as Texture2D
	var butcher_texture := load(
		BUTCHER_LPC_SPRITE_PATH
	) as Texture2D

	if (
		vulture_texture != null
		and penitent_texture != null
		and wright_texture != null
		and butcher_texture != null
	):
		var battle = MixedActionSquadBattleData.new()
		battle.name = "AmbientMixed5v5"

		# LPC guys use their actual sheet animation.
		# Wright/Butcher use the goofy whole-body stand-in mode.
		# Individual survives flags stress-test post-melee wiring.
		var enemy_specs: Array = [
			{
				"name": "Vulture",
				"texture": vulture_texture,
				"mode": "lpc",
				"depth": 0,
				"survives": false,
			},
			{
				"name": "Butcher",
				"texture": butcher_texture,
				"mode": "standin",
				"depth": 2,
				"survives": true,
			},
			{
				"name": "Vulture",
				"texture": vulture_texture,
				"mode": "lpc",
				"depth": 4,
				"survives": false,
			},
			{
				"name": "Wright",
				"texture": wright_texture,
				"mode": "standin",
				"depth": 1,
				"survives": false,
			},
			{
				"name": "Butcher",
				"texture": butcher_texture,
				"mode": "standin",
				"depth": 3,
				"survives": true,
			},
		]

		var player_specs: Array = [
			{
				"name": "Penitent",
				"texture": penitent_texture,
				"mode": "lpc",
				"depth": 1,
				"survives": true,
			},
			{
				"name": "Wright",
				"texture": wright_texture,
				"mode": "standin",
				"depth": 3,
				"survives": false,
			},
			{
				"name": "Penitent",
				"texture": penitent_texture,
				"mode": "lpc",
				"depth": 0,
				"survives": false,
			},
			{
				"name": "Butcher",
				"texture": butcher_texture,
				"mode": "standin",
				"depth": 4,
				"survives": true,
			},
			{
				"name": "Wright",
				"texture": wright_texture,
				"mode": "standin",
				"depth": 2,
				"survives": false,
			},
		]

		battle.setup(
			enemy_specs,
			player_specs,
			3
		)

		action_actor_row.add_child(battle)


	battle.battle_finished.connect(
		_on_ui2_ambient_scrum_finished_for_theater.bind(
			enemy_specs,
			player_specs,
			3
		)
	)

		suit_name = "5v5 mixed melee"
		state_name = "SCRUM"
	else:
		action_actor_row.add_child(
			_action_actor_standin(
				"Butcher",
				"enemy"
			)
		)

	action_mode_label.text = (
		"AMBIENT · %s" % lane_name.to_upper()
		if not lane_name.is_empty()
		else "AMBIENT"
	)

	action_caption.text = "%s · %s" % [
		suit_name.to_upper(),
		state_name,
	]


func _on_ambient_timer_timeout() -> void:
	if not _action_event_active:
		_refresh_ambient_window()


func show_action_event(
	lane_name: String,
	suit_name: String,
	headline: String,
	side_text: String = "enemy"
) -> void:
	_action_event_active = true
	if ambient_timer != null:
		ambient_timer.stop()

	_clear_action_actors()
	action_actor_row.add_child(
		_action_actor_standin(
			suit_name,
			side_text
		)
	)

	action_mode_label.text = (
		"ACTION · %s" % lane_name.to_upper()
		if not lane_name.is_empty()
		else "ACTION"
	)
	action_caption.text = headline

func clear_action_event() -> void:
	_action_event_active = false
	if ambient_timer != null:
		ambient_timer.start()
	_refresh_ambient_window()


func _side_header(
	bot,
	human
) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(
		"separation",
		5
	)

	var enemy_label := Label.new()
	enemy_label.text = (
		String(bot.lord).to_upper()
		if bot != null
		else "ENEMY"
	)
	enemy_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_label.add_theme_font_size_override(
		"font_size",
		10
	)
	enemy_label.add_theme_color_override(
		"font_color",
		Color(0.82, 0.36, 0.38, 1.0)
	)
	row.add_child(enemy_label)

	var step_label := Label.new()
	step_label.text = "STEP"
	step_label.custom_minimum_size.x = 28
	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_label.add_theme_font_size_override(
		"font_size",
		9
	)
	row.add_child(step_label)

	var human_label := Label.new()
	human_label.text = (
		String(human.lord).to_upper()
		if human != null
		else "YOU"
	)
	human_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	human_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	human_label.add_theme_font_size_override(
		"font_size",
		10
	)
	human_label.add_theme_color_override(
		"font_color",
		Color(0.34, 0.58, 0.88, 1.0)
	)
	row.add_child(human_label)

	return row


func _build_step(
	visual_index: int,
	bot_marcher,
	human_marcher
) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size.y = 70
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.075, 0.075, 0.084, 0.80)
	row_style.border_color = Color(0.15, 0.16, 0.18, 1.0)
	row_style.set_border_width_all(1)
	row.add_theme_stylebox_override("panel", row_style)

	var row_box := HBoxContainer.new()
	row_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row_box.add_theme_constant_override("separation", 5)
	row.add_child(row_box)

	var bot_here: bool = (
		bot_marcher != null
		and int(bot_marcher.get("pos", 0)) == visual_index
	)

	var human_visual_pos: int = -1
	if human_marcher != null:
		human_visual_pos = (
			STEP_COUNT
			- 1
			- int(human_marcher.get("pos", 0))
		)

	var human_here: bool = (
		human_marcher != null
		and human_visual_pos == visual_index
	)

	row_box.add_child(
		_marcher_slot(
			bot_marcher if bot_here else null,
			true
		)
	)

	var step_label := Label.new()
	step_label.text = str(STEP_COUNT - visual_index)
	step_label.custom_minimum_size.x = 18
	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_label.add_theme_font_size_override("font_size", 11)
	row_box.add_child(step_label)

	row_box.add_child(
		_marcher_slot(
			human_marcher if human_here else null,
			false
		)
	)

	return row


func _gate_label(
	owner_name: String,
	direction_text: String
) -> Label:
	var label := Label.new()
	label.text = "%s\n%s" % [
		owner_name,
		direction_text,
	]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	return label


func _marcher_slot(
	marcher,
	enemy_side: bool
) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(44, 54)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4

	if marcher == null:
		style.bg_color = Color(0.04, 0.04, 0.045, 0.45)
		style.border_color = Color(0.18, 0.19, 0.21, 1.0)
		slot.add_theme_stylebox_override("panel", style)
		return slot

	var card = marcher.get("card", null)
	var suit_name: String = (
		String(card.suit)
		if card != null
		else "?"
	)
	var printed_value: int = (
		int(card.value)
		if card != null
		else int(marcher.get("value", 0))
	)
	var accent: Color = SubjectSuitStyleData.accent(suit_name)

	style.bg_color = (
		Color(0.12, 0.06, 0.065, 1.0)
		if enemy_side
		else Color(0.055, 0.075, 0.11, 1.0)
	)
	style.border_color = accent
	style.set_border_width_all(3)
	slot.add_theme_stylebox_override("panel", style)

	var card_art: Texture2D = (
		SubjectCardArtCatalogData.texture_for(
			suit_name,
			printed_value,
			false
		)
	)

	if card_art != null:
		var art := TextureRect.new()
		art.anchor_right = 1.0
		art.anchor_bottom = 1.0
		art.offset_left = 3.0
		art.offset_top = 3.0
		art.offset_right = -3.0
		art.offset_bottom = -3.0
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.texture = card_art
		slot.add_child(art)

		var preview = SubjectCardHoldPreviewData.new()
		slot.add_child(preview)
		preview.configure(slot, card_art)
	else:
		var label := Label.new()
		label.text = "%s\\n%d" % [
			suit_name.left(1).to_upper(),
			int(marcher.get("value", 0)),
		]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", accent)
		slot.add_child(label)

	slot.tooltip_text = (
		"%s marcher · force %d · progress %d"
		% [
			suit_name,
			int(marcher.get("value", 0)),
			int(marcher.get("pos", 0)),
		]
	)

	return slot

func _marcher_in_lane(
	player,
	lane_name: String
):
	if player == null:
		return null

	for marcher in player.marchers:
		if String(marcher.get("lane", "")) == lane_name:
			return marcher

	return null

# UI2_ACTION_SCRUM_THEATER_HOOK_V1
# Temporary one-shot proof of the generic small-screen -> Theater hook.
func _on_ui2_ambient_scrum_finished_for_theater(
	_enemy_survivors: int,
	_player_survivors: int,
	enemy_specs: Array,
	player_specs: Array,
	swing_count: int
) -> void:
	if _scrum_theater_demo_sent:
		return

	_scrum_theater_demo_sent = true

	var theater = get_tree().root.find_child(
		"ResolutionTheater",
		true,
		false
	)

	if theater == null:
		push_warning(
			"UI2 scrum Theater hook could not find ResolutionTheater."
		)
		return

	if not theater.has_method("play_scrum"):
		push_warning(
			"UI2 ResolutionTheater does not expose play_scrum()."
		)
		return

	theater.call_deferred(
		"play_scrum",
		enemy_specs,
		player_specs,
		swing_count
	)
