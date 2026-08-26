# UI2_RESOLUTION_COMPACT_TOTALS_V1
# UI2_CARD_INTERACTION_STAGING_V2
# UI2_COMMITMENT_CARD_ART_FLOW_V1
# UI2_SUBJECT_DRAG_ART_V1
# UI2_SUBJECT_CARD_ART_V1
# UI2_SUBJECT_CARD_ART_SURFACES_V2
class_name UI2HandView
extends PanelContainer


const SubjectCardArtCatalogData = preload(
	"res://Prototype/UI2/SubjectCardArtCatalog.gd"
)
const SubjectCardHoldPreviewData = preload(
	"res://Prototype/UI2/SubjectCardHoldPreview.gd"
)




const SubjectSuitStyleData = preload(
	"res://Prototype/UI2/SubjectSuitStyle.gd"
)


signal selection_changed(card_ids)


var title_label: Label = null
var hand_box: HBoxContainer = null
var card_buttons: Array[Button] = []
var staged_deploy_moves: Array = []
var deploy_drag_enabled: bool = false
var repair_drag_enabled: bool = false
var ward_drag_enabled: bool = false
var attack_drag_enabled: bool = false
var _last_commitment_click_instance: int = 0
var _last_commitment_click_ms: int = -1000
# UI2_COMMITMENT_DOUBLE_CLICK_ALL_IN_V1


func _ready() -> void:
	custom_minimum_size = Vector2(0,220)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override(
		"separation",
		6
	)
	add_child(outer)

	title_label = Label.new()
	title_label.text = "YOUR HAND"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override(
		"font_size",
		15
	)
	outer.add_child(title_label)

	hand_box = HBoxContainer.new()
	hand_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_box.add_theme_constant_override("separation",-52)
	hand_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(hand_box)


func set_deploy_drag_enabled(
	enabled: bool
) -> void:
	deploy_drag_enabled = enabled


func set_repair_drag_enabled(
	enabled: bool
) -> void:
	repair_drag_enabled = enabled


func set_ward_drag_enabled(
	enabled: bool
) -> void:
	ward_drag_enabled = enabled


func set_attack_drag_enabled(
	enabled: bool
) -> void:
	attack_drag_enabled = enabled


func set_staged_deploy_moves(
	moves: Array
) -> void:
	staged_deploy_moves.clear()
	for move in moves:
		if typeof(move) == TYPE_DICTIONARY:
			staged_deploy_moves.append(move.duplicate(true))


func bind_player(
	player,
	interactive: bool = false
) -> void:
	if player == null:
		return

	var staged_counts_by_id: Dictionary = {}
	var staged_hand_count: int = 0

	for move in staged_deploy_moves:
		if String(move.get("source", "")) != "Hand":
			continue

		var staged_card_id: String = String(move.get("card", ""))
		staged_counts_by_id[staged_card_id] = (
			int(staged_counts_by_id.get(staged_card_id, 0)) + 1
		)
		staged_hand_count += 1

	var available_hand_count: int = maxi(
		0,
		player.hand.size() - staged_hand_count
	)

	title_label.text = "YOUR HAND · %d AVAILABLE" % available_hand_count
	if staged_hand_count > 0:
		title_label.text += " · %d IN DEPLOY" % staged_hand_count

	for child in hand_box.get_children():
		hand_box.remove_child(
			child
		)
		child.queue_free()

	card_buttons.clear()

	if available_hand_count <= 0:
		var empty := Label.new()
		empty.text = (
			"All Hand cards are staged for Deploy"
			if staged_hand_count > 0
			else "No cards in Hand"
		)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hand_box.add_child(empty)
		return

	var visible_card_index: int = 0

	for card_index: int in range(player.hand.size()):
		var card = player.hand[card_index]
		var card_identifier: String = String(card.card_id())
		var staged_remaining: int = int(
			staged_counts_by_id.get(card_identifier, 0)
		)

		if staged_remaining > 0:
			staged_counts_by_id[card_identifier] = staged_remaining - 1
			continue

		var button := Button.new()
		# UI2_SUBJECT_CARD_ART_HAND
		var card_art: Texture2D = (
			SubjectCardArtCatalogData.texture_for(
				String(card.suit),
				int(card.value),
				false
			)
		)
		button.custom_minimum_size = Vector2(140,200)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.toggle_mode = true

		button.disabled = not interactive
		button.text = "%d\n%s" % [
			int(card.value),
			String(card.suit).to_upper(),
		]
		button.add_theme_font_size_override(
			"font_size",
			16
		)
		button.set_meta(
			"card_suit",
			String(card.suit)
		)
		button.set_meta(
			"card_value",
			int(card.value)
		)
		button.set_meta(
			"fan_index",
			visible_card_index
		)
		_apply_subject_card_style(
			button,
			String(card.suit)
		)
		button.tooltip_text = String(
			card.card_id()
		)
		button.set_meta(
			"card_id",
			String(card.card_id())
		)

		if deploy_drag_enabled or repair_drag_enabled or ward_drag_enabled or attack_drag_enabled:
			button.mouse_default_cursor_shape = (
				Control.CURSOR_DRAG
			)
			if deploy_drag_enabled:
				button.tooltip_text += (
					"\nClick: stage to the selected destination."
					+ "\nDrag: drop directly onto Lord or Castle Guards."
				)
			elif repair_drag_enabled:
				button.tooltip_text += (
					"\nDrag onto a damaged or unbuilt Castle to target it"
					+ " and add this card to its payment."
				)
			elif ward_drag_enabled or attack_drag_enabled:
				button.tooltip_text += (
					"\nDrag onto your Lord/Castles to Ward."
					+ " Drag onto the enemy Lord to Hunt or a specific enemy Castle to Siege."
				)
			button.set_drag_forwarding(
				_get_hand_card_drag_data.bind(
					button
				),
				Callable(),
				Callable()
			)

		if repair_drag_enabled or ward_drag_enabled or attack_drag_enabled:
			button.tooltip_text += "\nDouble-click: ALL IN — stage the whole Hand."
		button.toggled.connect(
			_on_card_toggled.bind(button)
		)
		button.pressed.connect(
			_on_commitment_hand_card_pressed.bind(button)
		)
		if card_art != null:
			button.text = ""
			button.icon = null
			button.set_meta("subject_art_present", true)

			var card_art_rect := TextureRect.new()
			card_art_rect.name = "SubjectCardArt"
			card_art_rect.anchor_right = 1.0
			card_art_rect.anchor_bottom = 1.0
			card_art_rect.offset_left = 5.0
			card_art_rect.offset_top = 5.0
			card_art_rect.offset_right = -5.0
			card_art_rect.offset_bottom = -5.0
			card_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			card_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			card_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_art_rect.texture = card_art
			button.add_child(card_art_rect)

			button.tooltip_text += "\nHold still to inspect card art."

		var art_preview = SubjectCardHoldPreviewData.new()
		button.add_child(art_preview)
		art_preview.configure(
			button,
			card_art
		)

		hand_box.add_child(button)

		# Light fan around the Hand center. Negative separation saves width.
		var fan_center: float = float(available_hand_count - 1) / 2.0
		var fan_delta: float = float(visible_card_index) - fan_center
		button.pivot_offset = Vector2(
			button.custom_minimum_size.x * 0.5,
			button.custom_minimum_size.y
		)
		button.rotation = deg_to_rad(fan_delta * 2.5)
		button.z_index = visible_card_index
		_refresh_card_selection_visual(
			button
		)

		card_buttons.append(button)
		visible_card_index += 1



func _apply_subject_card_style(
	button: Button,
	suit_name: String
) -> void:
	button.add_theme_color_override(
		"font_color",
		Color(0.92, 0.92, 0.94, 1.0)
	)
	button.add_theme_color_override(
		"font_hover_color",
		Color(1.0, 1.0, 1.0, 1.0)
	)
	button.add_theme_color_override(
		"font_pressed_color",
		Color(1.0, 1.0, 1.0, 1.0)
	)

	button.add_theme_stylebox_override(
		"normal",
		SubjectSuitStyleData.card_style(
			suit_name,
			Color(0.065, 0.065, 0.072, 1.0),
			3
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		SubjectSuitStyleData.card_style(
			suit_name,
			Color(0.085, 0.085, 0.095, 1.0),
			3
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		SubjectSuitStyleData.card_style(
			suit_name,
			Color(0.16, 0.16, 0.18, 1.0),
			7
		)
	)
	button.add_theme_stylebox_override(
		"disabled",
		SubjectSuitStyleData.card_style(
			suit_name,
			Color(0.055, 0.055, 0.060, 1.0),
			3
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		SubjectSuitStyleData.card_style(
			suit_name,
			Color(0.13, 0.13, 0.145, 1.0),
			6
		)
	)


func _refresh_card_selection_visual(
	button: Button
) -> void:
	if button == null:
		return

	var selected: bool = button.button_pressed
	var staging_mode: bool = (
		repair_drag_enabled
		or ward_drag_enabled
		or attack_drag_enabled
	)
	var hide_token: int = int(
		button.get_meta("ui2_stage_hide_token", 0)
	) + 1
	button.set_meta("ui2_stage_hide_token", hide_token)
	button.visible = true

	if staging_mode and selected:
		_hide_staged_hand_card_after_delay(
			button,
			hide_token
		)
	var card_value: int = int(
		button.get_meta(
			"card_value",
			0
		)
	)
	var suit_name: String = String(
		button.get_meta(
			"card_suit",
			""
		)
	)
	var fan_index: int = int(
		button.get_meta(
			"fan_index",
			0
		)
	)

	button.z_index = (
		100 + fan_index
		if selected
		else fan_index
	)

	if bool(button.get_meta("subject_art_present", false)):
		button.text = ""
	else:
		button.text = (
			"✓ SELECTED\n%d · %s"
			% [
				card_value,
				suit_name.to_upper(),
			]
			if selected
			else "%d\n%s" % [
				card_value,
				suit_name.to_upper(),
			]
		)

	_refresh_commitment_hand_title()


func _get_hand_card_drag_data(
	_at_position: Vector2,
	button: Button
):
	if (
		(
			not deploy_drag_enabled
			and not repair_drag_enabled
			and not ward_drag_enabled
			and not attack_drag_enabled
		)
		or button == null
		or button.disabled
	):
		return null

	var card_id: String = String(
		button.get_meta(
			"card_id",
			""
		)
	)
	if card_id.is_empty():
		return null

	var suit_name: String = String(
		button.get_meta(
			"card_suit",
			""
		)
	)
	var card_value: int = int(
		button.get_meta(
			"card_value",
			0
		)
	)

	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(112, 160)
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
		label.add_theme_font_size_override(
			"font_size",
			15
		)
		label.text = "%d\n%s" % [
			card_value,
			suit_name.to_upper(),
		]
		preview.add_child(label)

	button.set_drag_preview(
		preview
	)

	var drag_type: String = "commitment_hand_card"
	if deploy_drag_enabled:
		drag_type = "deploy_hand_card"
	elif repair_drag_enabled:
		drag_type = "castle_payment_hand_card"

	return {
		"ui2_type": drag_type,
		"source": "Hand",
		"card": card_id,
	}

func select_card_id(
	card_id: String,
	append_selection: bool = true
) -> bool:
	if card_id.is_empty():
		return false

	if not append_selection:
		for candidate in card_buttons:
			if is_instance_valid(candidate):
				candidate.set_pressed_no_signal(false)
				_refresh_card_selection_visual(candidate)

	for button in card_buttons:
		if (
			not is_instance_valid(button)
			or button.disabled
			or String(button.get_meta("card_id", "")) != card_id
			or button.button_pressed
		):
			continue

		button.set_pressed_no_signal(true)
		_refresh_card_selection_visual(button)
		selection_changed.emit(selected_card_ids())
		return true

	return false


func deselect_card_id(
	card_id: String
) -> bool:
	if card_id.is_empty():
		return false

	for button in card_buttons:
		if (
			not is_instance_valid(button)
			or String(button.get_meta("card_id", "")) != card_id
			or not button.button_pressed
		):
			continue

		button.set_pressed_no_signal(false)
		_refresh_card_selection_visual(button)
		selection_changed.emit(selected_card_ids())
		return true

	return false



func select_all_cards() -> bool:
	var changed: bool = false

	for button in card_buttons:
		if (
			not is_instance_valid(button)
			or button.disabled
		):
			continue

		if not button.button_pressed:
			changed = true

		button.set_pressed_no_signal(true)
		_refresh_card_selection_visual(button)

	if changed:
		selection_changed.emit(selected_card_ids())

	return changed


func _on_commitment_hand_card_pressed(
	button: Button
) -> void:
	if (
		not (repair_drag_enabled or ward_drag_enabled or attack_drag_enabled)
		or button == null
		or button.disabled
	):
		return

	var now_ms: int = int(Time.get_ticks_msec())
	var instance_id: int = int(button.get_instance_id())
	var double_click: bool = (
		instance_id == _last_commitment_click_instance
		and now_ms - _last_commitment_click_ms <= 360
	)

	_last_commitment_click_instance = instance_id
	_last_commitment_click_ms = now_ms

	if not double_click:
		return

	_last_commitment_click_instance = 0
	_last_commitment_click_ms = -1000
	select_all_cards()



func _hide_staged_hand_card_after_delay(
	button: Button,
	token: int
) -> void:
	# The ALL IN gesture is a double-click on the same Button. Keep the first
	# selected card visible just past the 360 ms double-click window, then hide
	# it if it is still staged. Normal single-click staging still feels instant.
	await get_tree().create_timer(0.38).timeout

	if (
		not is_instance_valid(button)
		or int(
			button.get_meta(
				"ui2_stage_hide_token",
				-1
			)
		) != token
		or not button.button_pressed
		or not (
			repair_drag_enabled
			or ward_drag_enabled
			or attack_drag_enabled
		)
	):
		return

	button.visible = false

func _refresh_commitment_hand_title() -> void:
	if (
		title_label == null
		or not (
			repair_drag_enabled
			or ward_drag_enabled
			or attack_drag_enabled
		)
	):
		return

	var available_count: int = 0
	var staged_count: int = 0
	var staged_total: int = 0

	for candidate in card_buttons:
		if not is_instance_valid(candidate):
			continue

		if candidate.button_pressed:
			staged_count += 1
			staged_total += int(
				candidate.get_meta(
					"card_value",
					0
				)
			)
		else:
			available_count += 1

	title_label.text = (
		"YOUR HAND · %d AVAILABLE"
		% available_count
	)

	if staged_count > 0:
		title_label.text += (
			" · %d %s"
			% [
				staged_count,
				(
					"PAYMENT STAGED"
					if repair_drag_enabled
					else "COMMITTED"
				),
			]
		)

	# A commitment of two or more cards should never require mental addition.
	# Repair/Construction already has its own effective-payment readout, so the
	# consolidated value here is reserved for actual sealed commitments.
	if (
		staged_count > 1
		and not repair_drag_enabled
	):
		title_label.text += (
			" · TOTAL %d"
			% staged_total
		)

func selected_card_ids() -> Array[String]:
	var ids: Array[String] = []

	for button in card_buttons:
		if not button.button_pressed:
			continue

		ids.append(
			String(
				button.get_meta(
					"card_id",
					""
				)
			)
		)

	return ids


func clear_selection() -> void:
	for button in card_buttons:
		button.set_pressed_no_signal(
			false
		)
		_refresh_card_selection_visual(
			button
		)

	selection_changed.emit(
		selected_card_ids()
	)


func selected_card_value_total() -> int:
	var total: int = 0

	for button in card_buttons:
		if not button.button_pressed:
			continue
		total += int(
			button.get_meta(
				"card_value",
				0
			)
		)

	return total


func _on_card_toggled(
	_pressed: bool,
	_button: Button
) -> void:
	_refresh_card_selection_visual(
		_button
	)
	selection_changed.emit(
		selected_card_ids()
	)
