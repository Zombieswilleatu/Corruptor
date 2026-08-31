# UI2_PREVIEW_OVERLAY_NONINFLATING_HOST_V2
# UI2_PREVIEW_STACK_COMPACTION_V1
# UI2_CARD_INTERACTION_STAGING_V2
# UI2_COMMITMENT_CARD_ART_FLOW_V1
# UI2_SUBJECT_DRAG_ART_V1
class_name UI2PlayerBoard
# UI2_CASTLE_GUARD_COMPRESSION_V1
extends HBoxContainer


const LordCardData = preload(
	"res://Prototype/UI2/LordCard.gd"
)
const CastleSpineData = preload(
	"res://Prototype/UI2/CastleSpine.gd"
)
const GuardPipData = preload(
	"res://Prototype/UI2/GuardPip.gd"
)
const ZoneRowData = preload(
	"res://Prototype/UI2/ZoneRow.gd"
)
const SubjectSuitStyleData = preload(
	"res://Prototype/UI2/SubjectSuitStyle.gd"
)
const SubjectCardArtCatalogData = preload(
	"res://Prototype/UI2/SubjectCardArtCatalog.gd"
)
const CastleIntegrityRulesData = preload(
	"res://Scripts/Sim/CastleIntegrityRules.gd"
)


signal staged_guard_clicked(queue_index)
signal deploy_card_dropped(source, card_id, target_zone)
signal castle_payment_card_dropped(card_id, castle_name, action_name)
signal castle_payment_preview_card_clicked(card_id)
signal castle_payment_preview_all_requested
signal ward_card_dropped(card_id, target_zone)
signal ward_preview_card_clicked(card_id)
signal attack_card_dropped(card_id, action_name, target_name)
signal attack_preview_card_clicked(card_id)
signal ward_preview_all_requested
signal attack_preview_all_requested


const CASTLE_ORDER: Array[String] = [
	"Keep",
	"Bastion",
	"SummoningCircle",
	"Stockpile",
	"SiegeEngine",
]


var lord_group: PanelContainer = null
var lord_card = null
var lord_absent_label: Label = null
var lord_sigil: Label = null
var ward_lord_overlay: HBoxContainer = null

var lord_guard_group: PanelContainer = null
var lord_guard_box: VBoxContainer = null

var castle_group: PanelContainer = null
var castle_row: HBoxContainer = null
var castle_guard_box: HBoxContainer = null
var castle_guard_drop_area: HBoxContainer = null
var castle_sigil: Label = null
var ward_castle_overlay: HBoxContainer = null

var _zone_helper = null
var staged_deploy_moves: Array = []
var deploy_drop_enabled: bool = false
var castle_payment_drop_enabled: bool = false
var march_drag_enabled: bool = false
var ward_drop_enabled: bool = false
var attack_drop_enabled: bool = false
var attack_lord_overlay: HBoxContainer = null
var attack_castle_overlays: Dictionary = {}
var castle_payment_overlays: Dictionary = {}
var _preview_click_tokens: Dictionary = {}
# UI2_COMMITMENT_DOUBLE_CLICK_ALL_IN_V1


func _ready() -> void:
	custom_minimum_size = Vector2(
		930,
		300
	)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_FILL
	add_theme_constant_override(
		"separation",
		8
	)

	_zone_helper = ZoneRowData.new()

	_build_lord_group()
	_build_lord_guards()

	# UI2_PROMPT_CASTLE_GUTTER_V1
	# Reserve a small visual lane for the floating decision prompt. Because the
	# Castle group expands into the remaining width, this 64 px gutter moves the
	# centered Castle spine only about half that distance instead of wasting a
	# huge permanent column.
	var prompt_castle_gutter := Control.new()
	prompt_castle_gutter.name = "PromptCastleGutter"
	# UI2_CASTLE_PREVIEW_INTERACTION_GUTTER_V2
	# The 64 px gutter still let the floating prompt nick the first Castle.
	# Give the prompt a real visual lane while retaining the same overall board.
	prompt_castle_gutter.custom_minimum_size = Vector2(112, 0)
	prompt_castle_gutter.size_flags_horizontal = Control.SIZE_FILL
	prompt_castle_gutter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prompt_castle_gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt_castle_gutter)

	_build_castle_group()


func _exit_tree() -> void:
	if (
		_zone_helper != null
		and is_instance_valid(
			_zone_helper
		)
	):
		_zone_helper.free()
		_zone_helper = null


func set_deploy_drop_enabled(
	enabled: bool
) -> void:
	deploy_drop_enabled = enabled

	if lord_guard_group != null:
		lord_guard_group.tooltip_text = (
			"Drop Hand cards here to stage Lord Guards"
			if enabled
			else ""
		)

	if castle_guard_drop_area != null:
		castle_guard_drop_area.tooltip_text = (
			"Drop Hand cards here to stage Castle Guards"
			if enabled
			else ""
		)


func set_castle_payment_drop_enabled(
	enabled: bool
) -> void:
	castle_payment_drop_enabled = enabled


func set_march_drag_enabled(
	enabled: bool
) -> void:
	march_drag_enabled = enabled

	if lord_guard_group != null:
		if enabled:
			lord_guard_group.tooltip_text = (
				"Drag a Lord Guard directly into a marching lane."
			)
		elif not deploy_drop_enabled:
			lord_guard_group.tooltip_text = ""

	if castle_guard_drop_area != null:
		if enabled:
			castle_guard_drop_area.tooltip_text = (
				"Drag a Castle Guard directly into a marching lane."
			)
		elif not deploy_drop_enabled:
			castle_guard_drop_area.tooltip_text = ""


func set_staged_deploy_moves(
	moves: Array
) -> void:
	staged_deploy_moves.clear()

	for move in moves:
		if typeof(move) == TYPE_DICTIONARY:
			staged_deploy_moves.append(
				move.duplicate(
					true
				)
			)


func set_attack_drop_enabled(
	enabled: bool
) -> void:
	attack_drop_enabled = enabled

	if lord_group != null:
		lord_group.tooltip_text = (
			"Drop a Hand card on the enemy Lord to stage a Hunt."
			if enabled
			else ""
		)


func _preview_cards_for_ids(
	player,
	card_ids: Array[String]
) -> Array:
	var result: Array = []

	if player == null or card_ids.is_empty():
		return result

	var remaining_counts: Dictionary = {}

	for card_id in card_ids:
		remaining_counts[card_id] = int(
			remaining_counts.get(
				card_id,
				0
			)
		) + 1

	for card in player.hand:
		var card_id: String = String(
			card.card_id()
		)
		var remaining: int = int(
			remaining_counts.get(
				card_id,
				0
			)
		)

		if remaining <= 0:
			continue

		remaining_counts[card_id] = (
			remaining - 1
		)
		result.append(
			card
		)

	return result


func _configure_preview_stack_spacing(
	destination: HBoxContainer,
	card_count: int,
	normal_separation: int
) -> void:
	if destination == null:
		return

	destination.add_theme_constant_override(
		"separation",
		-48
		if card_count > 4
		else normal_separation
	)


func _add_preview_stack_summary(
	destination: HBoxContainer,
	card_count: int,
	value_label: String,
	total_value: int
) -> void:
	if (
		destination == null
		or card_count <= 4
	):
		return

	# The cards remain individually present and clickable, but at 5+ they
	# flatten into a tight stack. This spacer prevents the summary badge
	# from sitting directly over the final card.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(
		48,
		1
	)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	destination.add_child(
		spacer
	)

	var panel := PanelContainer.new()
	panel.name = "PreviewStackSummary"
	panel.custom_minimum_size = Vector2(
		88,
		54
	)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 20

	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		0.055,
		0.06,
		0.07,
		0.96
	)
	style.border_color = Color(
		0.72,
		0.65,
		0.48,
		0.95
	)
	style.set_border_width_all(
		1
	)
	style.set_corner_radius_all(
		5
	)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override(
		"panel",
		style
	)

	var label := Label.new()
	label.text = (
		"%d CARDS\n%s %d"
		% [
			card_count,
			value_label,
			total_value,
		]
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(
		"font_size",
		11
	)
	label.add_theme_color_override(
		"font_color",
		Color(
			0.96,
			0.91,
			0.78,
			1.0
		)
	)
	label.add_theme_color_override(
		"font_outline_color",
		Color(
			0.0,
			0.0,
			0.0,
			0.95
		)
	)
	label.add_theme_constant_override(
		"outline_size",
		2
	)

	panel.add_child(
		label
	)
	destination.add_child(
		panel
	)


func _preview_printed_total(
	cards: Array
) -> int:
	var total: int = 0

	for card in cards:
		total += int(
			card.value
		)

	return total


func _preview_attack_total(
	attacker,
	cards: Array,
	action_name: String,
	rules_ref
) -> int:
	if attacker == null:
		return 0

	if (
		rules_ref != null
		and attacker.has_method(
			"attack_value"
		)
	):
		return int(
			attacker.attack_value(
				rules_ref,
				action_name == "Siege",
				cards
			)
		)

	return _preview_printed_total(
		cards
	)


func _preview_ward_total(
	player,
	cards: Array,
	rules_ref
) -> int:
	if player == null:
		return 0

	if (
		rules_ref != null
		and player.has_method(
			"duplicate_state"
		)
	):
		var preview_player = (
			player.duplicate_state()
		)

		if (
			preview_player != null
			and preview_player.has_method(
				"ward_reinforcement_value"
			)
		):
			preview_player.action = "Ward"
			preview_player.committed.clear()

			for card in cards:
				preview_player.committed.append(
					card
				)

			return int(
				preview_player.ward_reinforcement_value(
					rules_ref
				)
			)

	if (
		rules_ref != null
		and player.has_method(
			"ward_value"
		)
	):
		return int(
			player.ward_value(
				rules_ref,
				cards
			)
		)

	return _preview_printed_total(
		cards
	)


func set_attack_preview_cards(
	attacker,
	card_ids: Array[String],
	action_name: String,
	target_name: String,
	rules_ref = null
) -> void:
	_clear_children(attack_lord_overlay)

	for overlay in attack_castle_overlays.values():
		_clear_children(overlay)

	if (
		attacker == null
		or action_name not in ["Hunt", "Siege"]
		or card_ids.is_empty()
	):
		return

	var destination: HBoxContainer = null

	if action_name == "Hunt":
		destination = attack_lord_overlay
	elif attack_castle_overlays.has(
		target_name
	):
		destination = (
			attack_castle_overlays[
				target_name
			]
		)

	if destination == null:
		return

	var preview_cards: Array = (
		_preview_cards_for_ids(
			attacker,
			card_ids
		)
	)

	_configure_preview_stack_spacing(
		destination,
		preview_cards.size(),
		-16
	)

	for card in preview_cards:
		var card_id: String = String(
			card.card_id()
		)
		var attack_card := Button.new()
		attack_card.custom_minimum_size = Vector2(
			58,
			83
		)
		attack_card.size_flags_horizontal = (
			Control.SIZE_SHRINK_CENTER
		)
		attack_card.size_flags_vertical = (
			Control.SIZE_SHRINK_CENTER
		)
		attack_card.text = ""

		var attack_art: Texture2D = (
			SubjectCardArtCatalogData.texture_for(
				String(card.suit),
				int(card.value),
				false
			)
		)

		if attack_art != null:
			var attack_art_rect := TextureRect.new()
			attack_art_rect.anchor_right = 1.0
			attack_art_rect.anchor_bottom = 1.0
			attack_art_rect.offset_left = 3.0
			attack_art_rect.offset_top = 3.0
			attack_art_rect.offset_right = -3.0
			attack_art_rect.offset_bottom = -3.0
			attack_art_rect.expand_mode = (
				TextureRect.EXPAND_IGNORE_SIZE
			)
			attack_art_rect.stretch_mode = (
				TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			)
			attack_art_rect.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)
			attack_art_rect.texture = attack_art
			attack_card.add_child(
				attack_art_rect
			)
		else:
			attack_card.text = "%s\n%d · %s" % [
				action_name.to_upper(),
				int(card.value),
				String(card.suit).left(1).to_upper(),
			]

		attack_card.add_theme_font_size_override(
			"font_size",
			9
		)
		attack_card.add_theme_stylebox_override(
			"normal",
			SubjectSuitStyleData.card_style(
				String(card.suit),
				Color(
					0.16,
					0.075,
					0.075,
					0.95
				),
				6
			)
		)
		attack_card.add_theme_stylebox_override(
			"hover",
			SubjectSuitStyleData.card_style(
				String(card.suit),
				Color(
					0.23,
					0.10,
					0.10,
					0.98
				),
				7
			)
		)
		attack_card.tooltip_text = (
			"Click: return this card to Hand."
			+ "\nDouble-click: return the ENTIRE commitment."
		)
		attack_card.gui_input.connect(
			_on_attack_preview_card_gui_input.bind(
				card_id
			)
		)
		_configure_attack_drop_target(
			attack_card,
			action_name,
			target_name
		)
		destination.add_child(
			attack_card
		)

	_add_preview_stack_summary(
		destination,
		preview_cards.size(),
		"STR",
		_preview_attack_total(
			attacker,
			preview_cards,
			action_name,
			rules_ref
		)
	)

func flash_attack_target(
	action_name: String,
	target_name: String
) -> void:
	var target: Control = null
	if action_name == "Hunt":
		target = lord_group
	elif action_name == "Siege":
		target = attack_castle_overlays.get(target_name, null)

	if target == null:
		return

	target.modulate = Color(1.35, 1.08, 1.08, 1.0)
	var flash = target.create_tween()
	flash.set_trans(Tween.TRANS_SINE)
	flash.set_ease(Tween.EASE_OUT)
	flash.tween_property(target, "modulate", Color.WHITE, 0.45)


func set_ward_drop_enabled(
	enabled: bool
) -> void:
	ward_drop_enabled = enabled

	for overlay in [
		ward_lord_overlay,
		ward_castle_overlay,
	]:
		if overlay == null:
			continue
		overlay.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if enabled
			else Control.MOUSE_FILTER_IGNORE
		)

	if ward_lord_overlay != null:
		ward_lord_overlay.tooltip_text = (
			"Drop a Hand card here to Ward your Lord."
			if enabled
			else ""
		)

	if ward_castle_overlay != null:
		ward_castle_overlay.tooltip_text = (
			"Drop a Hand card here to Ward your Castle zone."
			if enabled
			else ""
		)


func set_ward_preview_cards(
	player,
	card_ids: Array[String],
	target_zone: String,
	rules_ref = null
) -> void:
	_clear_children(ward_lord_overlay)
	_clear_children(ward_castle_overlay)

	if (
		player == null
		or target_zone not in ["Lord", "Castle"]
		or card_ids.is_empty()
	):
		return

	var destination: HBoxContainer = (
		ward_lord_overlay
		if target_zone == "Lord"
		else ward_castle_overlay
	)

	if destination == null:
		return

	var preview_cards: Array = (
		_preview_cards_for_ids(
			player,
			card_ids
		)
	)

	_configure_preview_stack_spacing(
		destination,
		preview_cards.size(),
		-12
	)

	for card in preview_cards:
		var card_id: String = String(
			card.card_id()
		)
		var ward_card := Button.new()
		ward_card.custom_minimum_size = Vector2(
			58,
			83
		)
		ward_card.size_flags_horizontal = (
			Control.SIZE_SHRINK_CENTER
		)
		ward_card.size_flags_vertical = (
			Control.SIZE_SHRINK_CENTER
		)
		ward_card.text = ""

		var ward_art: Texture2D = (
			SubjectCardArtCatalogData.texture_for(
				String(card.suit),
				int(card.value),
				false
			)
		)

		if ward_art != null:
			var ward_art_rect := TextureRect.new()
			ward_art_rect.anchor_right = 1.0
			ward_art_rect.anchor_bottom = 1.0
			ward_art_rect.offset_left = 3.0
			ward_art_rect.offset_top = 3.0
			ward_art_rect.offset_right = -3.0
			ward_art_rect.offset_bottom = -3.0
			ward_art_rect.expand_mode = (
				TextureRect.EXPAND_IGNORE_SIZE
			)
			ward_art_rect.stretch_mode = (
				TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			)
			ward_art_rect.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)
			ward_art_rect.texture = ward_art
			ward_card.add_child(
				ward_art_rect
			)
		else:
			ward_card.text = "WARD\n%d · %s" % [
				int(card.value),
				String(card.suit).left(1).to_upper(),
			]

		ward_card.add_theme_font_size_override(
			"font_size",
			10
		)
		ward_card.add_theme_stylebox_override(
			"normal",
			SubjectSuitStyleData.card_style(
				String(card.suit),
				Color(
					0.10,
					0.12,
					0.16,
					0.94
				),
				6
			)
		)
		ward_card.add_theme_stylebox_override(
			"hover",
			SubjectSuitStyleData.card_style(
				String(card.suit),
				Color(
					0.16,
					0.18,
					0.23,
					0.98
				),
				7
			)
		)
		ward_card.tooltip_text = (
			"Click: return this card to Hand."
			+ "\nDouble-click: return the ENTIRE commitment."
		)
		ward_card.gui_input.connect(
			_on_ward_preview_card_gui_input.bind(
				card_id
			)
		)
		_configure_ward_drop_target(
			ward_card,
			target_zone
		)
		destination.add_child(
			ward_card
		)

	_add_preview_stack_summary(
		destination,
		preview_cards.size(),
		"WARD",
		_preview_ward_total(
			player,
			preview_cards,
			rules_ref
		)
	)

	ward_drop_enabled = true

func flash_ward_target(
	target_zone: String
) -> void:
	var target: Control = (
		lord_group
		if target_zone == "Lord"
		else castle_group
	)
	if target == null:
		return

	target.modulate = Color(1.25, 1.30, 1.45, 1.0)
	var flash = target.create_tween()
	flash.set_trans(Tween.TRANS_SINE)
	flash.set_ease(Tween.EASE_OUT)
	flash.tween_property(
		target,
		"modulate",
		Color.WHITE,
		0.45
	)


func bind_player(
	player,
	reveal_all_guards: bool
) -> void:
	if player == null:
		return

	lord_card.bind_player(
		player,
		reveal_all_guards
	)
	lord_card.visible = bool(player.alive)
	if lord_absent_label != null:
		# UI2_THEATER_PROMPT_VESSEL_TRUTH_V1
		lord_absent_label.visible = not bool(player.alive)
		if not bool(player.alive):
			var current_lord: String = String(player.lord)
			var vessel_lord: String = String(player.vessel_offered_lord)
			if (
				not vessel_lord.is_empty()
				and vessel_lord == current_lord
			):
				lord_absent_label.text = "OFFERED AS VESSEL"
				lord_absent_label.tooltip_text = (
					"This Lord was offered as the Vessel. Vessel removal is not "
					+ "Banishment, so it does not occupy the shared Breach."
				)
			else:
				lord_absent_label.text = "IN THE BREACH"
				lord_absent_label.tooltip_text = (
					"This Lord is banished and occupies the shared Breach."
				)
	if lord_sigil != null:
		lord_sigil.visible = bool(player.alive)

	if attack_drop_enabled and bool(player.alive):
		_configure_attack_drop_root(
			lord_group,
			"Hunt",
			"Lord"
		)

	var lord_staged: Array = _staged_entries_for_zone(
		player,
		"Lord"
	)

	_bind_guards(
		lord_guard_box,
		player.lord_guards,
		_guard_slot_count(
			player,
			"Lord",
			player.lord_guards.size()
			+ lord_staged.size()
		),
		reveal_all_guards,
		true,
		lord_staged
	)

	_clear_children(castle_row)
	attack_castle_overlays.clear()
	castle_payment_overlays.clear()

	for castle_name: String in CASTLE_ORDER:
		var castle = CastleSpineData.new()
		castle_row.add_child(castle)
		castle.bind_castle(
			player,
			castle_name
		)
		# Preview HBoxes must not contribute their minimum width to
		# CastleSpine (a PanelContainer), or the target card stretches.
		# A plain Control acts as a layout firewall.
		var preview_overlay_host := Control.new()
		preview_overlay_host.name = "PreviewOverlayHost"
		preview_overlay_host.custom_minimum_size = Vector2.ZERO
		preview_overlay_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview_overlay_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
		preview_overlay_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_overlay_host.clip_contents = false
		castle.add_child(preview_overlay_host)

		var attack_overlay := HBoxContainer.new()
		attack_overlay.name = "AttackOverlay"
		attack_overlay.alignment = BoxContainer.ALIGNMENT_CENTER
		attack_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		attack_overlay.z_index = 6
		attack_overlay.add_theme_constant_override("separation", -16)
		preview_overlay_host.add_child(attack_overlay)
		attack_overlay.anchor_left = 0.5
		attack_overlay.anchor_top = 0.5
		attack_overlay.anchor_right = 0.5
		attack_overlay.anchor_bottom = 0.5
		attack_overlay.offset_left = 0.0
		attack_overlay.offset_top = 0.0
		attack_overlay.offset_right = 0.0
		attack_overlay.offset_bottom = 0.0
		attack_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
		attack_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
		attack_castle_overlays[castle_name] = attack_overlay


		var payment_overlay := HBoxContainer.new()
		payment_overlay.name = "CastlePaymentOverlay"
		payment_overlay.alignment = BoxContainer.ALIGNMENT_CENTER
		payment_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		payment_overlay.add_theme_constant_override("separation", -18)
		payment_overlay.z_index = 6
		preview_overlay_host.add_child(payment_overlay)
		payment_overlay.anchor_left = 0.5
		payment_overlay.anchor_top = 0.5
		payment_overlay.anchor_right = 0.5
		payment_overlay.anchor_bottom = 0.5
		payment_overlay.offset_left = 0.0
		payment_overlay.offset_top = 0.0
		payment_overlay.offset_right = 0.0
		payment_overlay.offset_bottom = 0.0
		payment_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
		payment_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
		castle_payment_overlays[castle_name] = payment_overlay

		if attack_drop_enabled and player.castles.has(castle_name):
			_configure_attack_drop_root(
				castle,
				"Siege",
				castle_name
			)
		else:
			_configure_castle_payment_drop_target(
				castle,
				player,
				castle_name
			)

	var castle_staged: Array = _staged_entries_for_zone(
		player,
		"Castle"
	)

	_bind_guards(
		castle_guard_box,
		player.castle_guards,
		_guard_slot_count(
			player,
			"Castle",
			player.castle_guards.size()
			+ castle_staged.size()
		),
		reveal_all_guards,
		false,
		castle_staged
	)

	_bind_sigil(
		lord_sigil,
		player,
		"Lord"
	)

	_bind_sigil(
		castle_sigil,
		player,
		"Castle"
	)


func _build_lord_group() -> void:
	lord_group = PanelContainer.new()
	lord_group.name = "LordGroup"
	lord_group.custom_minimum_size = Vector2(
		180,
		0
	)
	lord_group.size_flags_horizontal = Control.SIZE_FILL
	lord_group.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(lord_group)

	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(
		"separation",
		6
	)
	lord_group.add_child(column)

	column.add_child(
		_header_label(
			"LORD"
		)
	)

	lord_card = LordCardData.new()
	lord_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lord_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_child(lord_card)

	lord_absent_label = Label.new()
	lord_absent_label.text = "IN THE BREACH"
	lord_absent_label.visible = false
	lord_absent_label.custom_minimum_size = Vector2(188, 282)
	lord_absent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lord_absent_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lord_absent_label.add_theme_font_size_override("font_size", 14)
	lord_absent_label.add_theme_color_override(
		"font_color",
		Color(0.54, 0.48, 0.66, 1.0)
	)
	column.add_child(lord_absent_label)

	lord_sigil = _sigil_badge()
	lord_sigil.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(lord_sigil)

	ward_lord_overlay = HBoxContainer.new()
	ward_lord_overlay.name = "WardLordOverlay"
	ward_lord_overlay.alignment = BoxContainer.ALIGNMENT_CENTER
	ward_lord_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ward_lord_overlay.add_theme_constant_override("separation", -12)
	lord_group.add_child(ward_lord_overlay)
	_configure_ward_drop_target(
		ward_lord_overlay,
		"Lord"
	)

	attack_lord_overlay = HBoxContainer.new()
	attack_lord_overlay.name = "AttackLordOverlay"
	attack_lord_overlay.alignment = BoxContainer.ALIGNMENT_CENTER
	attack_lord_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attack_lord_overlay.z_index = 6
	attack_lord_overlay.add_theme_constant_override("separation", -16)
	lord_group.add_child(attack_lord_overlay)


func _build_lord_guards() -> void:
	lord_guard_group = PanelContainer.new()
	lord_guard_group.name = "LordGuards"
	lord_guard_group.custom_minimum_size = Vector2(
		90,
		0
	)
	lord_guard_group.size_flags_horizontal = Control.SIZE_FILL
	lord_guard_group.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(lord_guard_group)

	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(
		"separation",
		4
	)
	lord_guard_group.add_child(column)

	column.add_child(
		_header_label(
			"LORD\nGUARDS"
		)
	)

	lord_guard_box = VBoxContainer.new()
	lord_guard_box.alignment = BoxContainer.ALIGNMENT_CENTER
	lord_guard_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lord_guard_box.add_theme_constant_override(
		"separation",
		4
	)
	column.add_child(lord_guard_box)

	_configure_deploy_drop_target(
		lord_guard_group,
		"Lord"
	)
	_configure_deploy_drop_target(
		column,
		"Lord"
	)
	_configure_deploy_drop_target(
		lord_guard_box,
		"Lord"
	)


func _build_castle_group() -> void:
	castle_group = PanelContainer.new()
	castle_group.name = "CastleGroup"
	castle_group.custom_minimum_size = Vector2(
		660,
		0
	)
	castle_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	castle_group.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(castle_group)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(
		"separation",
		5
	)
	castle_group.add_child(column)

	column.add_child(
		_header_label(
			"CASTLES"
		)
	)

	castle_row = HBoxContainer.new()
	castle_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	castle_row.alignment = BoxContainer.ALIGNMENT_CENTER
	castle_row.add_theme_constant_override(
		"separation",
		8
	)
	column.add_child(castle_row)

	column.add_child(
		_header_label(
			"CASTLE GUARDS"
		)
	)

	castle_guard_drop_area = HBoxContainer.new()
	castle_guard_drop_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	castle_guard_drop_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	castle_guard_drop_area.add_theme_constant_override(
		"separation",
		8
	)
	column.add_child(castle_guard_drop_area)

	# Equal reserve opposite the real Sigil keeps Guards truly centered.
	var sigil_balance := Control.new()
	sigil_balance.custom_minimum_size = Vector2(70, 0)
	castle_guard_drop_area.add_child(sigil_balance)

	castle_guard_box = HBoxContainer.new()
	castle_guard_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	castle_guard_box.alignment = BoxContainer.ALIGNMENT_CENTER
	castle_guard_box.add_theme_constant_override(
		"separation",
		8
	)
	castle_guard_drop_area.add_child(castle_guard_box)

	castle_sigil = _sigil_badge()
	castle_sigil.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	castle_guard_drop_area.add_child(castle_sigil)

	_configure_deploy_drop_target(
		castle_guard_drop_area,
		"Castle"
	)
	_configure_deploy_drop_target(
		castle_guard_box,
		"Castle"
	)

	ward_castle_overlay = HBoxContainer.new()
	ward_castle_overlay.name = "WardCastleOverlay"
	ward_castle_overlay.alignment = BoxContainer.ALIGNMENT_CENTER
	ward_castle_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ward_castle_overlay.add_theme_constant_override("separation", -12)
	castle_group.add_child(ward_castle_overlay)
	_configure_ward_drop_target(
		ward_castle_overlay,
		"Castle"
	)


func _bind_guards(
	box,
	guards: Array,
	slot_count: int,
	reveal_all_guards: bool,
	compact_vertical: bool,
	staged_entries: Array = []
) -> void:
	_clear_children(box)

	# Castle Guards share a fixed visual budget. Large defensive piles
	# compress inward instead of forcing the whole PlayerBoard wider.
	if not compact_vertical and box is HBoxContainer:
		var castle_separation: int = 4
		if slot_count >= 9:
			castle_separation = -20
		elif slot_count >= 7:
			castle_separation = -16
		elif slot_count >= 5:
			castle_separation = -10
		(box as HBoxContainer).add_theme_constant_override(
			"separation",
			castle_separation
		)

	for guard_index: int in range(slot_count):
		var guard = null
		var staged_entry: Dictionary = {}

		if guard_index < guards.size():
			guard = guards[guard_index]
		else:
			var staged_index: int = (
				guard_index - guards.size()
			)
			if (
				staged_index >= 0
				and staged_index < staged_entries.size()
			):
				staged_entry = staged_entries[
					staged_index
				]
				guard = staged_entry.get(
					"card",
					null
				)

		var pip = GuardPipData.new()
		pip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(pip)

		var guard_zone: String = (
			"Lord"
			if compact_vertical
			else "Castle"
		)

		if guard_index < guards.size() and guard != null:
			pip.set_meta(
				"march_source_zone",
				guard_zone
			)
			pip.set_meta(
				"march_card_id",
				String(guard.card_id())
			)
			pip.set_meta(
				"march_card_suit",
				String(guard.suit)
			)
			pip.set_meta(
				"march_card_value",
				int(guard.value)
			)

		_configure_deploy_drop_target(
			pip,
			guard_zone
		)

		var guard_size := Vector2(58, 72)

		if not compact_vertical:
			if slot_count >= 9:
				guard_size = Vector2(40, 56)
			elif slot_count >= 7:
				guard_size = Vector2(44, 61)
			elif slot_count >= 5:
				guard_size = Vector2(50, 69)
			else:
				guard_size = Vector2(58, 80)

		pip.custom_minimum_size = guard_size

		var staged: bool = not staged_entry.is_empty()
		var revealed: bool = staged

		if guard != null and not staged:
			revealed = (
				reveal_all_guards
				or bool(guard.guard_revealed)
			)

		pip.bind_guard(
			guard,
			revealed
		)

		if (
			march_drag_enabled
			and guard_index < guards.size()
			and guard != null
		):
			_set_mouse_ignore_recursive(pip)
			pip.mouse_filter = Control.MOUSE_FILTER_STOP
			pip.mouse_default_cursor_shape = Control.CURSOR_DRAG
			pip.tooltip_text += (
				"\nDrag into a marching lane to launch this Guard."
			)

		if staged and guard != null:
			_decorate_staged_guard(
				pip,
				guard,
				staged_entry
			)


func _configure_attack_drop_root(
	control: Control,
	action_name: String,
	target_name: String
) -> void:
	if control == null:
		return

	control.mouse_filter = Control.MOUSE_FILTER_STOP
	_configure_attack_drop_target(
		control,
		action_name,
		target_name
	)
	_set_attack_drop_descendants_ignore(control)


func _set_attack_drop_descendants_ignore(
	node: Node
) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_attack_drop_descendants_ignore(child)


func _configure_attack_drop_target(
	control: Control,
	action_name: String,
	target_name: String
) -> void:
	if control == null:
		return

	control.set_drag_forwarding(
		Callable(),
		_can_drop_attack_data.bind(action_name, target_name),
		_drop_attack_data.bind(action_name, target_name)
	)


func _can_drop_attack_data(
	_at_position: Vector2,
	data,
	action_name: String,
	target_name: String
) -> bool:
	return (
		attack_drop_enabled
		and action_name in ["Hunt", "Siege"]
		and not target_name.is_empty()
		and typeof(data) == TYPE_DICTIONARY
		and String(data.get("ui2_type", "")) == "commitment_hand_card"
		and String(data.get("source", "")) == "Hand"
		and not String(data.get("card", "")).is_empty()
	)


func _drop_attack_data(
	at_position: Vector2,
	data,
	action_name: String,
	target_name: String
) -> void:
	if not _can_drop_attack_data(
		at_position,
		data,
		action_name,
		target_name
	):
		return

	attack_card_dropped.emit(
		String(data.get("card", "")),
		action_name,
		target_name
	)


func _on_attack_preview_card_gui_input(
	event: InputEvent,
	card_id: String
) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if (
		mouse_event.button_index != MOUSE_BUTTON_LEFT
		or not mouse_event.pressed
	):
		return

	var key: String = "attack|" + card_id
	var token: int = int(_preview_click_tokens.get(key, 0)) + 1
	_preview_click_tokens[key] = token

	if mouse_event.double_click:
		_preview_click_tokens[key] = token + 1
		attack_preview_all_requested.emit()
		get_viewport().set_input_as_handled()
		return

	_emit_preview_single_after_delay(
		"attack",
		card_id,
		key,
		token
	)



func _emit_preview_single_after_delay(
	kind: String,
	card_id: String,
	key: String,
	token: int
) -> void:
	await get_tree().create_timer(0.26).timeout

	if int(_preview_click_tokens.get(key, -1)) != token:
		return

	_preview_click_tokens.erase(key)

	if kind == "ward":
		ward_preview_card_clicked.emit(card_id)
	elif kind == "attack":
		attack_preview_card_clicked.emit(card_id)

func _configure_ward_drop_target(
	control: Control,
	target_zone: String
) -> void:
	if control == null:
		return

	control.set_drag_forwarding(
		Callable(),
		_can_drop_ward_data.bind(target_zone),
		_drop_ward_data.bind(target_zone)
	)


func _can_drop_ward_data(
	_at_position: Vector2,
	data,
	target_zone: String
) -> bool:
	return (
		ward_drop_enabled
		and target_zone in ["Lord", "Castle"]
		and typeof(data) == TYPE_DICTIONARY
		and String(data.get("ui2_type", "")) == "commitment_hand_card"
		and String(data.get("source", "")) == "Hand"
		and not String(data.get("card", "")).is_empty()
	)


func _drop_ward_data(
	at_position: Vector2,
	data,
	target_zone: String
) -> void:
	if not _can_drop_ward_data(
		at_position,
		data,
		target_zone
	):
		return

	ward_card_dropped.emit(
		String(data.get("card", "")),
		target_zone
	)


func _on_ward_preview_card_gui_input(
	event: InputEvent,
	card_id: String
) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if (
		mouse_event.button_index != MOUSE_BUTTON_LEFT
		or not mouse_event.pressed
	):
		return

	var key: String = "ward|" + card_id
	var token: int = int(_preview_click_tokens.get(key, 0)) + 1
	_preview_click_tokens[key] = token

	if mouse_event.double_click:
		_preview_click_tokens[key] = token + 1
		ward_preview_all_requested.emit()
		get_viewport().set_input_as_handled()
		return

	_emit_preview_single_after_delay(
		"ward",
		card_id,
		key,
		token
	)


func _configure_castle_payment_drop_target(
	castle: Control,
	player,
	castle_name: String
) -> void:
	if castle == null:
		return

	var action_name: String = _castle_payment_action(
		player,
		castle_name
	)
	if castle_payment_drop_enabled and not action_name.is_empty():
		castle.mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
		castle.tooltip_text += (
			"\nDrop a Hand card here to %s and add it to payment."
			% action_name
		)

	_set_mouse_ignore_recursive(
		castle
	)
	castle.mouse_filter = Control.MOUSE_FILTER_STOP

	castle.set_drag_forwarding(
		Callable(),
		_can_drop_castle_payment_data.bind(
			player,
			castle_name
		),
		_drop_castle_payment_data.bind(
			player,
			castle_name
		)
	)


func _castle_payment_action(
	player,
	castle_name: String
) -> String:
	if player == null:
		return ""

	var maximum: int = CastleIntegrityRulesData.max_integrity(
		castle_name
	)
	if player.castles.has(castle_name):
		var current: int = int(
			player.castle_integrity.get(
				castle_name,
				maximum
			)
		)
		if current > 0 and current < maximum:
			return "repair"
		return ""

	if (
		not player.ruined_castles.has(castle_name)
		and not player.profaned_castles.has(castle_name)
		and not player.lost_castles.has(castle_name)
	):
		return "construct"

	return ""


func _can_drop_castle_payment_data(
	_at_position: Vector2,
	data,
	player,
	castle_name: String
) -> bool:
	if (
		not castle_payment_drop_enabled
		or typeof(data) != TYPE_DICTIONARY
		or String(data.get("ui2_type", "")) != "castle_payment_hand_card"
		or String(data.get("source", "")) != "Hand"
		or String(data.get("card", "")).is_empty()
	):
		return false

	return not _castle_payment_action(
		player,
		castle_name
	).is_empty()


func _drop_castle_payment_data(
	at_position: Vector2,
	data,
	player,
	castle_name: String
) -> void:
	if not _can_drop_castle_payment_data(
		at_position,
		data,
		player,
		castle_name
	):
		return

	castle_payment_card_dropped.emit(
		String(data.get("card", "")),
		castle_name,
		_castle_payment_action(
			player,
			castle_name
		)
	)


func set_castle_payment_preview_cards(
	player,
	card_ids: Array[String],
	action_name: String,
	castle_name: String,
	rules_ref = null
) -> void:
	for overlay in castle_payment_overlays.values():
		_clear_children(overlay)

	if (
		player == null
		or action_name not in ["repair", "construct"]
		or castle_name.is_empty()
		or card_ids.is_empty()
		or not castle_payment_overlays.has(
			castle_name
		)
	):
		return

	var destination: HBoxContainer = (
		castle_payment_overlays[
			castle_name
		]
	)

	var preview_cards: Array = (
		_preview_cards_for_ids(
			player,
			card_ids
		)
	)

	_configure_preview_stack_spacing(
		destination,
		preview_cards.size(),
		-18
	)

	for card in preview_cards:
		var card_id: String = String(
			card.card_id()
		)

		var payment_card := Button.new()
		payment_card.custom_minimum_size = Vector2(
			58,
			83
		)
		payment_card.size_flags_horizontal = (
			Control.SIZE_SHRINK_CENTER
		)
		payment_card.size_flags_vertical = (
			Control.SIZE_SHRINK_CENTER
		)
		payment_card.text = ""
		payment_card.tooltip_text = (
			"STAGED %s PAYMENT · %s"
			% [
				action_name.to_upper(),
				card_id,
			]
		)

		var suit_name: String = String(
			card.suit
		)
		var card_value: int = int(
			card.value
		)
		var card_art: Texture2D = (
			SubjectCardArtCatalogData.texture_for(
				suit_name,
				card_value,
				false
			)
		)

		payment_card.add_theme_stylebox_override(
			"normal",
			SubjectSuitStyleData.card_style(
				suit_name,
				Color(
					0.09,
					0.11,
					0.10,
					0.96
				),
				6
			)
		)
		payment_card.add_theme_stylebox_override(
			"hover",
			SubjectSuitStyleData.card_style(
				suit_name,
				Color(
					0.14,
					0.17,
					0.15,
					0.99
				),
				7
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
			art.expand_mode = (
				TextureRect.EXPAND_IGNORE_SIZE
			)
			art.stretch_mode = (
				TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			)
			art.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)
			art.texture = card_art
			payment_card.add_child(
				art
			)
		else:
			payment_card.text = "%d\n%s" % [
				card_value,
				suit_name.left(1).to_upper(),
			]

		payment_card.gui_input.connect(
			_on_castle_payment_preview_gui_input.bind(
				card_id
			)
		)
		_configure_castle_payment_drop_target(
			payment_card,
			player,
			castle_name
		)
		destination.add_child(
			payment_card
		)

	_add_preview_stack_summary(
		destination,
		preview_cards.size(),
		"PAY",
		_preview_printed_total(
			preview_cards
		)
	)

func _on_castle_payment_preview_gui_input(
	event: InputEvent,
	card_id: String
) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if (
		mouse_event.button_index != MOUSE_BUTTON_LEFT
		or not mouse_event.pressed
	):
		return

	var key: String = "payment|" + card_id
	var token: int = int(
		_preview_click_tokens.get(key, 0)
	) + 1
	_preview_click_tokens[key] = token

	if mouse_event.double_click:
		_preview_click_tokens[key] = token + 1
		castle_payment_preview_all_requested.emit()
		get_viewport().set_input_as_handled()
		return

	_emit_castle_payment_single_after_delay(
		card_id,
		key,
		token
	)


func _emit_castle_payment_single_after_delay(
	card_id: String,
	key: String,
	token: int
) -> void:
	await get_tree().create_timer(0.26).timeout

	if int(
		_preview_click_tokens.get(key, -1)
	) != token:
		return

	_preview_click_tokens.erase(key)
	castle_payment_preview_card_clicked.emit(card_id)

func flash_castle_action_target(
	castle_name: String
) -> void:
	if castle_row == null:
		return

	for castle in castle_row.get_children():
		if String(castle.castle_name) != castle_name:
			continue
		castle.modulate = Color(1.35, 1.35, 1.35, 1.0)
		var flash = castle.create_tween()
		flash.set_trans(Tween.TRANS_SINE)
		flash.set_ease(Tween.EASE_OUT)
		flash.tween_property(castle, "modulate", Color.WHITE, 0.45)
		return


func _configure_deploy_drop_target(
	control: Control,
	target_zone: String
) -> void:
	if control == null:
		return

	control.set_drag_forwarding(
		_get_march_guard_drag_data.bind(
			control
		),
		_can_drop_deploy_data.bind(
			target_zone
		),
		_drop_deploy_data.bind(
			target_zone
		)
	)


func _get_march_guard_drag_data(
	_at_position: Vector2,
	control: Control
):
	if (
		not march_drag_enabled
		or control == null
	):
		return null

	var source_zone: String = String(
		control.get_meta(
			"march_source_zone",
			""
		)
	)
	var card_id: String = String(
		control.get_meta(
			"march_card_id",
			""
		)
	)

	if (
		source_zone not in ["Lord", "Castle"]
		or card_id.is_empty()
	):
		return null

	var suit_name: String = String(
		control.get_meta(
			"march_card_suit",
			"?"
		)
	)
	var card_value: int = int(
		control.get_meta(
			"march_card_value",
			0
		)
	)

	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(96, 137)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_theme_stylebox_override(
		"panel",
		SubjectSuitStyleData.card_style(
			suit_name,
			Color(0.08, 0.08, 0.09, 0.98),
			5
		)
	)

	var card_art: Texture2D = (
		SubjectCardArtCatalogData.texture_for(
			suit_name,
			card_value,
			false
		)
	)

	if card_art != null:
		var art := TextureRect.new()
		art.anchor_right = 1.0
		art.anchor_bottom = 1.0
		art.offset_left = 4.0
		art.offset_top = 4.0
		art.offset_right = -4.0
		art.offset_bottom = -4.0
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.texture = card_art
		preview.add_child(art)
	else:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 13)
		label.text = "%d\n%s\n→ LANE" % [
			card_value,
			suit_name.to_upper(),
		]
		preview.add_child(label)

	control.set_drag_preview(preview)

	return {
		"ui2_type": "march_guard",
		"source_zone": source_zone,
		"card": card_id,
	}

func _can_drop_deploy_data(
	_at_position: Vector2,
	data,
	target_zone: String
) -> bool:
	if (
		not deploy_drop_enabled
		or target_zone not in [
			"Lord",
			"Castle",
		]
		or typeof(data) != TYPE_DICTIONARY
	):
		return false

	return (
		String(data.get("ui2_type", ""))
		== "deploy_hand_card"
		and String(data.get("source", ""))
		== "Hand"
		and not String(data.get("card", "")).is_empty()
	)


func _drop_deploy_data(
	at_position: Vector2,
	data,
	target_zone: String
) -> void:
	if not _can_drop_deploy_data(
		at_position,
		data,
		target_zone
	):
		return

	deploy_card_dropped.emit(
		String(data.get("source", "Hand")),
		String(data.get("card", "")),
		target_zone
	)


func _staged_entries_for_zone(
	player,
	zone_name: String
) -> Array:
	var entries: Array = []

	for queue_index: int in range(
		staged_deploy_moves.size()
	):
		var move = staged_deploy_moves[
			queue_index
		]

		if String(
			move.get(
				"target",
				""
			)
		) != zone_name:
			continue

		var card = _card_for_staged_move(
			player,
			queue_index
		)
		if card == null:
			continue

		entries.append({
			"queue_index": queue_index,
			"move": move,
			"card": card,
		})

	return entries


func _card_for_staged_move(
	player,
	queue_index: int
):
	if (
		player == null
		or queue_index < 0
		or queue_index >= staged_deploy_moves.size()
	):
		return null

	var move = staged_deploy_moves[
		queue_index
	]
	var source: String = String(
		move.get(
			"source",
			""
		)
	)
	var card_id: String = String(
		move.get(
			"card",
			""
		)
	)

	var pool: Array = []
	if source == "Hand":
		pool = player.hand
	elif source == "Garrison":
		pool = player.garrison
	else:
		return null

	var occurrence: int = 0

	for prior_index: int in range(
		queue_index
	):
		var prior = staged_deploy_moves[
			prior_index
		]
		if (
			String(
				prior.get(
					"source",
					""
				)
			) == source
			and String(
				prior.get(
					"card",
					""
				)
			) == card_id
		):
			occurrence += 1

	for card in pool:
		if String(
			card.card_id()
		) != card_id:
			continue

		if occurrence <= 0:
			return card

		occurrence -= 1

	return null


func _decorate_staged_guard(
	pip,
	card,
	entry: Dictionary
) -> void:
	var suit_name: String = String(
		card.suit
	)

	pip.set_meta("subject_click_inspect", false)

	pip.add_theme_stylebox_override(
		"panel",
		SubjectSuitStyleData.card_style(
			suit_name,
			Color(
				0.15,
				0.15,
				0.17,
				1.0
			),
			6
		)
	)

	if pip.suit_label != null:
		pip.suit_label.text = "STAGED"
		pip.suit_label.add_theme_font_size_override(
			"font_size",
			8
		)
		pip.suit_label.add_theme_color_override(
			"font_color",
			Color(
				1.0,
				0.95,
				0.72,
				1.0
			)
		)

	var move: Dictionary = entry.get(
		"move",
		{}
	)
	pip.tooltip_text = (
		"STAGED · %s → %s Guards · click to return"
		% [
			String(move.get("source", "")),
			String(move.get("target", "")),
		]
	)
	_set_mouse_ignore_recursive(
		pip
	)
	pip.mouse_filter = Control.MOUSE_FILTER_STOP
	pip.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	pip.gui_input.connect(
		_on_staged_guard_gui_input.bind(
			int(
				entry.get(
					"queue_index",
					-1
				)
			)
		)
	)

	pip.modulate = Color(
		1.35,
		1.35,
		1.35,
		1.0
	)
	var flash = pip.create_tween()
	flash.set_trans(
		Tween.TRANS_SINE
	)
	flash.set_ease(
		Tween.EASE_OUT
	)
	flash.tween_property(
		pip,
		"modulate",
		Color.WHITE,
		0.55
	)


func _set_mouse_ignore_recursive(
	node: Node
) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)
		_set_mouse_ignore_recursive(
			child
		)


func _on_staged_guard_gui_input(
	event: InputEvent,
	queue_index: int
) -> void:
	if not (
		event is InputEventMouseButton
	):
		return

	var mouse_event := (
		event as InputEventMouseButton
	)

	if (
		mouse_event.button_index
		!= MOUSE_BUTTON_LEFT
		or not mouse_event.pressed
	):
		return

	staged_guard_clicked.emit(
		queue_index
	)


func flash_sigil(
	zone_name: String
) -> void:
	var label: Label = (
		lord_sigil
		if zone_name == "Lord"
		else castle_sigil
	)

	if label == null:
		return

	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE
	label.modulate = Color.WHITE

	var flash = label.create_tween()
	flash.set_trans(Tween.TRANS_SINE)
	flash.set_ease(Tween.EASE_OUT)
	flash.tween_property(
		label,
		"modulate",
		Color(1.55, 1.35, 0.72, 1.0),
		0.10
	)
	flash.parallel().tween_property(
		label,
		"scale",
		Vector2(1.45, 1.45),
		0.10
	)
	flash.tween_property(
		label,
		"modulate",
		Color.WHITE,
		0.18
	)
	flash.parallel().tween_property(
		label,
		"scale",
		Vector2.ONE,
		0.18
	)
	flash.tween_property(
		label,
		"modulate",
		Color(1.45, 1.28, 0.70, 1.0),
		0.09
	)
	flash.parallel().tween_property(
		label,
		"scale",
		Vector2(1.30, 1.30),
		0.09
	)
	flash.tween_property(
		label,
		"modulate",
		Color.WHITE,
		0.16
	)
	flash.parallel().tween_property(
		label,
		"scale",
		Vector2.ONE,
		0.16
	)


func _bind_sigil(
	label: Label,
	player,
	zone_name: String
) -> void:
	var sigil_state: String = String(
		player.sigils.get(
			zone_name,
			""
		)
	)

	var sigil_value: int = int(
		_zone_helper.call(
			"_sigil_value",
			sigil_state
		)
	)

	label.text = "◈%s" % (
		str(sigil_value)
		if sigil_value > 0
		else "—"
	)

	label.tooltip_text = (
		"%s Sigil: %s"
		% [
			zone_name,
			sigil_state if not sigil_state.is_empty() else "none",
		]
	)


func _guard_slot_count(
	player,
	zone_name: String,
	occupied_slots: int
) -> int:
	return int(
		_zone_helper.call(
			"_guard_slot_count",
			player,
			zone_name,
			occupied_slots
		)
	)


func _header_label(
	text_value: String
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(
		"font_size",
		11
	)
	return label


func _sigil_badge() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(
		70,
		28
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = "◈—"
	return label


func _clear_children(
	node: Node
) -> void:
	for child in node.get_children():
		node.remove_child(
			child
		)
		child.queue_free()
