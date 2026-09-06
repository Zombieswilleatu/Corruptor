# UI2_SLAVER_THEME_V1_1
# UI2_DIALOGUE_BREACH_OVERHAUL_V1
class_name UI2PhasePrompt
extends PanelContainer

# UI2_DECISION_PANEL_SKIN_V1
const UI2_DECISION_PANEL_TEXTURE: Texture2D = preload(
	"res://ConceptImages/Menus/DecisionPanel.png"
)


const CastleIntegrityRulesData = preload(
	"res://Scripts/Sim/CastleIntegrityRules.gd"
)


signal confirm_requested
signal pass_requested


var eyebrow_label: Label = null
var title_label: Label = null
var copy_label: Label = null
var divider: HSeparator = null
var intro_buttons: HBoxContainer = null
var yes_button: Button = null
var no_button: Button = null
var view_board_button: Button = null
var content_host: VBoxContainer = null
var action_zone = null

var stage_key: String = ""
var detail_open: bool = false
var board_view_collapsed: bool = false
var controller_ref = null
var player_ref = null
var opponent_ref = null
var rules_ref = null
var maintenance_step: String = ""


func _ready() -> void:
	call_deferred("_apply_decision_panel_skin_v1")
	# UI2_DECISION_PHASE_SLOT_READABILITY_V17_1
	# Root-overlay header must follow the final PanelContainer rect.
	if not resized.is_connected(_sync_decision_panel_layout_v4):
		resized.connect(_sync_decision_panel_layout_v4)
	z_index = 60
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

	# UI2_BOARD_FIRST_PROMPT_V1
	# UI2_PROMPT_CASTLE_GUTTER_V1
	# Board state is part of the decision interface. Nudge the prompt slightly
	# right so it clears Lord Guards, while the PlayerBoard reserves a matching
	# gutter before the Castle spine.
	anchor_left = 0.258
	anchor_right = 0.258
	anchor_top = 0.5
	anchor_bottom = 0.5
	# UI2_DECISION_PANEL_FIXED_SIZE_V11
	offset_left = -200.0
	offset_right = 200.0
	offset_top = -265.0
	offset_bottom = 265.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.027, 0.028, 0.034, 0.985)
	style.border_color = Color(0.45, 0.39, 0.26, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 15.0
	style.content_margin_bottom = 16.0
	add_theme_stylebox_override("panel", style)

	var outer := VBoxContainer.new()
	outer.name = "PromptContents"
	outer.add_theme_constant_override("separation", 10)
	add_child(outer)

	var header_row := HBoxContainer.new()
	header_row.name = "PromptHeader"
	header_row.add_theme_constant_override("separation", 8)
	outer.add_child(header_row)

	eyebrow_label = Label.new()
	eyebrow_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	eyebrow_label.add_theme_font_size_override("font_size", 11)
	eyebrow_label.add_theme_color_override(
		"font_color",
		Color(0.61, 0.63, 0.69, 1.0)
	)
	header_row.add_child(eyebrow_label)

	view_board_button = Button.new()
	view_board_button.name = "ViewBoardButton"
	view_board_button.text = "VIEW BOARD"
	view_board_button.custom_minimum_size = Vector2(112, 30)
	view_board_button.tooltip_text = (
		"Collapse this decision temporarily. Current selections stay staged."
	)
	view_board_button.pressed.connect(_on_view_board_pressed)
	header_row.add_child(view_board_button)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override(
		"font_color",
		Color(0.94, 0.87, 0.72, 1.0)
	)
	outer.add_child(title_label)

	copy_label = Label.new()
	copy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy_label.add_theme_font_size_override("font_size", 14)
	copy_label.add_theme_color_override(
		"font_color",
		Color(0.84, 0.85, 0.89, 1.0)
	)
	outer.add_child(copy_label)

	divider = HSeparator.new()
	outer.add_child(divider)

	intro_buttons = HBoxContainer.new()
	intro_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	intro_buttons.add_theme_constant_override("separation", 10)
	outer.add_child(intro_buttons)

	yes_button = Button.new()
	yes_button.custom_minimum_size = Vector2(145, 48)
	yes_button.pressed.connect(_on_yes_pressed)
	intro_buttons.add_child(yes_button)

	no_button = Button.new()
	no_button.custom_minimum_size = Vector2(145, 48)
	no_button.pressed.connect(_on_no_pressed)
	intro_buttons.add_child(no_button)

	content_host = VBoxContainer.new()
	content_host.name = "ActionHost"
	content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_host.visible = false
	outer.add_child(content_host)


func attach_action_zone(zone) -> void:
	action_zone = zone
	if action_zone == null or content_host == null:
		return
	if action_zone.get_parent() != null:
		action_zone.get_parent().remove_child(action_zone)
	content_host.add_child(action_zone)
	action_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_zone.visible = false
	# UI2_DECISION_BOTTOM_ACTIONS_V12_1
	call_deferred("_install_decision_bottom_actions_v12")


func bind_state(
	player,
	opponent,
	rules,
	controller,
	stage_text: String
) -> void:
	player_ref = player
	opponent_ref = opponent
	rules_ref = rules
	controller_ref = controller

	var next_stage: String = stage_text.replace(" ", "_").to_upper()
	var changed: bool = next_stage != stage_key
	stage_key = next_stage

	if changed:
		# Never carry a hidden prompt into a new decision. A new phase/event
		# should announce itself even if the previous prompt was collapsed.
		board_view_collapsed = false
		detail_open = not _uses_intro(stage_key)
		if stage_key == "REPAIR":
			maintenance_step = _first_maintenance_step()
		else:
			maintenance_step = ""

	# UI2_AFTERMATH_WARD_REVEAL_CLEANUP_V1
	# AFTERMATH already summarizes the completed round and owns the continue
	# action. Do not stack a second "round complete" prompt beneath it.
	visible = (
		not stage_key.is_empty()
		and stage_key != "NO_GAME"
	)
	if stage_key == "TERMINAL":
		visible = true

	eyebrow_label.text = _eyebrow(stage_key)
	title_label.text = _title(stage_key)
	copy_label.text = _copy(stage_key)

	_configure_buttons()
	_refresh_mode()


func sync_direct_manipulation(action_name: String = "") -> void:
	# UI2_DIRECT_MANIPULATION_SYNC_V1
	# Direct board interaction is a peer to dialog-first interaction. If the
	# player has already expressed intent spatially, advance the dialog to the
	# detailed/confirmation state instead of asking the same question again.
	if stage_key.is_empty() or stage_key in ["NO_GAME", "TERMINAL", "INVALID"]:
		return

	if stage_key == "REPAIR" and action_name in ["construct", "repair"]:
		maintenance_step = action_name
		title_label.text = _title(stage_key)
		copy_label.text = _copy(stage_key)
		_configure_buttons()

	detail_open = true
	_refresh_mode()

	# Respect an explicit VIEW BOARD collapse. The action state still catches
	# up underneath it, but we do not pop the dialog back over the board while
	# the player is intentionally dragging several cards.
	if board_view_collapsed:
		return

	if action_zone != null and action_zone.has_method("focus_direct_manipulation_end"):
		action_zone.focus_direct_manipulation_end()

func _refresh_mode() -> void:
	var can_view_board: bool = _can_view_board(stage_key)

	if view_board_button != null:
		view_board_button.visible = can_view_board
		view_board_button.text = (
			"RETURN TO DECISION"
			if board_view_collapsed
			else "VIEW BOARD"
		)

	if board_view_collapsed and can_view_board:
		# Collapse to a small persistent decision tab. The ActionZone stays
		# alive, so selected order/target/payment state survives while the
		# player inspects or drags directly on the board.
		title_label.visible = false
		copy_label.visible = false
		divider.visible = false
		intro_buttons.visible = false
		content_host.visible = false
		if action_zone != null:
			action_zone.visible = false

		offset_left = -175.0
		offset_right = 175.0
		offset_top = -34.0
		# UI2_DECISION_BOTTOM_ACTIONS_PARSE_FIX_V12_2
		offset_bottom = 34.0
		call_deferred("_sync_decision_bottom_actions_v12")
		call_deferred("_sync_decision_panel_layout_v4")
		return

	title_label.visible = true
	copy_label.visible = true
	divider.visible = true

	var show_details: bool = detail_open and action_zone != null
	content_host.visible = show_details
	if action_zone != null:
		action_zone.visible = show_details

	# UI2_COMMITMENT_TEXT_WINDOW_EXPAND_V13
	# Use the dead space above the artwork's bottom action windows.
	var commitment_text_window_v13: bool = (
		stage_key == "COMMITMENT"
		and show_details
	)
	var commitment_text_height_v13: float = (
		# UI2_COMMITMENT_TEXT_WINDOW_FILL_V13_1

		# UI2_DECISION_HEADER_GLOBAL_RECT_V16_1
		300.0 if commitment_text_window_v13 else 0.0

	)

	if content_host != null:
		content_host.custom_minimum_size.y = (
			commitment_text_height_v13
		)

	if action_zone != null:
		action_zone.custom_minimum_size.y = (
			commitment_text_height_v13
		)

		var action_scroll_v13 := action_zone.get_node_or_null(
			"ActionScroll"
		) as ScrollContainer
		if action_scroll_v13 != null:
			action_scroll_v13.custom_minimum_size.y = (
				commitment_text_height_v13
			)
	# UI2_SLAVER_VISIBLE_OFFERS_V2_4
	# Use the existing dead space above the artwork buttons.
	if stage_key == "MARKET" and show_details:
		var slaver_detail_height_v2_4: float = 225.0
		if content_host != null:
			content_host.custom_minimum_size.y = (
				slaver_detail_height_v2_4
			)
		if action_zone != null:
			action_zone.custom_minimum_size.y = (
				slaver_detail_height_v2_4
			)
			var slaver_scroll_v2_4 := action_zone.get_node_or_null(
				"ActionScroll"
			) as ScrollContainer
			if slaver_scroll_v2_4 != null:
				slaver_scroll_v2_4.custom_minimum_size.y = (
					slaver_detail_height_v2_4
				)
	intro_buttons.visible = not show_details and _has_buttons(stage_key)

	# UI2_DECISION_PANEL_TRUE_FIXED_SIZE_V12
	# Every expanded decision uses one footprint. No phase jumping.
	offset_left = -200.0
	offset_right = 200.0
	offset_top = -265.0
	offset_bottom = 265.0
	call_deferred("_sync_decision_bottom_actions_v12")
	call_deferred("_sync_decision_panel_layout_v4")


func _on_view_board_pressed() -> void:
	if not _can_view_board(stage_key):
		return
	board_view_collapsed = not board_view_collapsed
	_refresh_mode()


func _can_view_board(stage_name: String) -> bool:
	# Keep terminal/meta prompts explicit. Every live gameplay decision may be
	# collapsed because the board itself can contain information the player
	# needs before answering.
	return stage_name not in [
		"",
		"NO_GAME",
		"TERMINAL",
		"INVALID",
	]


func _configure_buttons() -> void:
	yes_button.visible = true
	no_button.visible = true

	match stage_key:
		"NO_GAME":
			yes_button.text = "BEGIN NEXT ROUND"
			no_button.visible = false
		"DEVELOPMENT_SNARE":
			yes_button.text = "SPRING THE SNARE"
			no_button.text = "HOLD YOUR THREAT"
		"MARKET":
			yes_button.text = "VISIT THE SLAVER"
			no_button.text = "PASS"
		"REPAIR":
			yes_button.text = (
				"CONSTRUCT"
				if maintenance_step == "construct"
				else "REPAIR"
			)
			no_button.text = (
				"SKIP CONSTRUCTION"
				if maintenance_step == "construct"
				else "CONTINUE"
			)
		"DOMINION_RITES":
			yes_button.text = "PERFORM A RITE"
			no_button.text = "CONTINUE"
		"DEPLOY":
			yes_button.text = "MUSTER GUARDS"
			no_button.text = "CONTINUE"
		"MARCH":
			yes_button.text = "ISSUE ORDERS"
			no_button.text = "HOLD POSITION"
		"SUMMON":
			yes_button.text = "CALL FROM THE BREACH"
			no_button.text = "REMAIN BANISHED"
		"SEALED":
			yes_button.text = "REVEAL ORDERS"
			no_button.visible = false
		"REVEALED":
			yes_button.text = "RESOLVE ROUND"
			no_button.visible = false
		"TERMINAL":
			yes_button.visible = false
			no_button.visible = false
		"INVALID":
			yes_button.visible = false
			no_button.visible = false
		_:
			yes_button.text = "CONTINUE"
			no_button.text = "PASS"


func _on_yes_pressed() -> void:
	if _yes_confirms_directly(stage_key):
		confirm_requested.emit()
		return

	detail_open = true
	_refresh_mode()
	call_deferred("_sync_decision_panel_layout_v4")

	if stage_key == "REPAIR" and action_zone != null:
		action_zone.focus_castle_action_mode(maintenance_step)


func _on_no_pressed() -> void:
	if stage_key == "REPAIR" and maintenance_step == "construct":
		if _damaged_castle_count() > 0:
			maintenance_step = "repair"
			detail_open = false
			title_label.text = _title(stage_key)
			copy_label.text = _copy(stage_key)
			_configure_buttons()
			_refresh_mode()
			return

	pass_requested.emit()


func note_controller_result(result: Dictionary) -> void:
	if stage_key != "REPAIR":
		return

	var action_name: String = String(result.get("action", ""))
	if action_name not in ["construct", "repair"]:
		return

	detail_open = false
	maintenance_step = "repair"


func _uses_intro(stage_name: String) -> bool:
	return stage_name in [
		"NO_GAME",
		"DEVELOPMENT_SNARE",
		"MARKET",
		"REPAIR",
		"DOMINION_RITES",
		"DEPLOY",
		"MARCH",
		"SUMMON",
		"SEALED",
		"REVEALED",
	]


func _yes_confirms_directly(stage_name: String) -> bool:
	return stage_name in [
		"NO_GAME",
		"DEVELOPMENT_SNARE",
		"SEALED",
		"REVEALED",
	]


func _has_buttons(stage_name: String) -> bool:
	return stage_name not in [
		"TERMINAL",
		"INVALID",
	]


func _eyebrow(stage_name: String) -> String:
	match stage_name:
		"DEVELOPMENT_SNARE", "MARKET", "REPAIR", "DOMINION_RITES", "DEPLOY", "MARCH", "SUMMON":
			return "DEVELOPMENT"
		"COMMITMENT", "SEALED":
			return "COMMITMENT"
		"KANIFOUS_INVOKE", "KANIFOUS_WRIGHT", "VULTURE_RECON", "REVEALED":
			return "REVEAL"
		"RESOLUTION_HUMBABA_TOLL", "RESOLUTION_ACTION", "RESOLUTION_VESSEL", "RESOLUTION_REFLEX", "RESOLUTION_ODRADEK_BREACH", "RESOLUTION_GREMORY":
			return "RESOLUTION"
		"RESOLUTION_VALAK_PROJECTION":
			return "RESOLUTION"
		"NO_GAME":
			return "ROUND COMPLETE"
		"TERMINAL":
			return "MATCH COMPLETE"
		"INVALID":
			return "MATCH HALTED"
		_:
			return ""


func _title(stage_name: String) -> String:
	match stage_name:
		"NO_GAME":
			return "THE ROUND IS SPENT"
		"DEVELOPMENT_SNARE":
			return "THE STALKER'S SNARE"
		"MARKET":
			return "THE SLAVER"
		"REPAIR":
			return (
				"RAISE THE WALLS"
				if maintenance_step == "construct"
				else "RESTORE THE FORTRESS"
			)
		"DOMINION_RITES":
			return "DOMINION RITES"
		"DEPLOY":
			return "MUSTER THE GUARD"
		"MARCH":
			return "MARCHING ORDERS"
		"SUMMON":
			return "CALL FROM THE BREACH"
		"COMMITMENT":
			return "SEAL YOUR ORDER"
		"SEALED":
			return "ORDERS SEALED"
		"KANIFOUS_INVOKE":
			return "INVOKE"
		"KANIFOUS_WRIGHT":
			return "WRIGHT INVOCATION"
		"VULTURE_RECON":
			return "VULTURE RECON"
		"REVEALED":
			return "ORDERS REVEALED"
		"RESOLUTION_HUMBABA_TOLL":
			return "THE TOLL"
		"RESOLUTION_ACTION":
			return "RESOLVE YOUR ORDER"
		"RESOLUTION_VESSEL":
			return "THE VESSEL"
		"RESOLUTION_REFLEX":
			return "MOMENTUM"
		"RESOLUTION_ODRADEK_BREACH":
			return "PARADOX GEOMETRY"
		"RESOLUTION_VALAK_PROJECTION":
			return "VALAK PROJECTION"
		"RESOLUTION_GREMORY":
			return "INEVITABLE RUIN"
		"TERMINAL":
			return "THE END AND THE BEGINNING ARE ONE"
		"INVALID":
			return "THE ROUND CANNOT CONTINUE"
		_:
			return stage_name.replace("_", " ").capitalize()


func _copy(stage_name: String) -> String:
	match stage_name:
		"NO_GAME":
			return "The aftermath is complete. Begin the next round when you are ready."
		"DEVELOPMENT_SNARE":
			return "Orias can spend 1 Threat to restrict the enemy to one total Guard move during this Development."
		"MARKET":
			return "Exchange one Subject card from your Hand for one offer at the Slaver. New stock daily."
		"REPAIR":
			return _castle_maintenance_copy()
		"DOMINION_RITES":
			return "Optional rites convert opportunity into Dominion pressure. Perform one only if the cost is worth the tempo."
		"DEPLOY":
			return _deploy_copy()
		"MARCH":
			return "Send a deployed Guard into a Marching lane now, or hold your defenses in place."
		"SUMMON":
			return (
				"Call a Lord back during Development, or remain Lordless. "
				+ "Vacant Throne allows two complete Lordless rounds safely; "
				+ "at the end of the third and every later consecutive "
				+ "Lordless round, your opponent gains 1 Soul."
			)
		"COMMITMENT":
			return "Choose one sealed order, its target, and the cards you are willing to commit. Your opponent chooses in secret."
		"SEALED":
			return "Both orders are locked. Reveal them together."
		"KANIFOUS_INVOKE":
			# UI2_PHASE_PROMPT_INVOKE_CONCAT_FIX_V1
			return (
				"Kanifous has revealed two possible Invocations. "
				+ "First choose which revealed card to Invoke. "
				+ "Then click exactly one card in your Hand to discard as the toll. "
				+ "When both are selected, press INVOKE."
			)
		"KANIFOUS_WRIGHT":
			return "Wright Invocation may move up to two Lord Guards into Castle defense."
		"VULTURE_RECON":
			return "Vulture Recon reveals one enemy Guard zone before combat."
		"REVEALED":
			return "The orders are public. Resolve them in initiative order."
		"RESOLUTION_HUMBABA_TOLL":
			return "Humbaba may ruin one of his own Castles to exact the Toll."
		"RESOLUTION_ACTION":
			return "Resolve your sealed order and any optional modifier attached to it."
		"RESOLUTION_VESSEL":
			return "You may offer your Lord as the Vessel if the current state allows it."
		"RESOLUTION_REFLEX":
			return "Momentum grants an extra action after the primary Resolution."
		"RESOLUTION_ODRADEK_BREACH":
			return "While Odradek occupies the Breach, predict the extra action to steal it."
		"RESOLUTION_VALAK_PROJECTION":
			return (
				"Valak may spend stored Life Essence to project force into an "
				+ "enemy Guard zone, or hold it for automatic defense."
			)
		"RESOLUTION_GREMORY":
			return "Gremory may pay for Inevitable Ruin after his Siege damages an Operational Castle and leaves it standing."
		"TERMINAL":
			return "The match has ended."
		"INVALID":
			return "The controller rejected this state. Open History or Developer tools for the exact reason."
		_:
			return "Make the decision that advances the current phase."


func _first_maintenance_step() -> String:
	if _buildable_castle_count() > 0:
		return "construct"
	return "repair"


func _damaged_castle_count() -> int:
	if player_ref == null:
		return 0

	var damaged: int = 0
	for raw_name in CastleIntegrityRulesData.CASTLES:
		var castle_name: String = String(raw_name)
		if not player_ref.castles.has(castle_name):
			continue
		var maximum: int = CastleIntegrityRulesData.max_integrity(castle_name)
		var integrity: int = int(
			player_ref.castle_integrity.get(castle_name, maximum)
		)
		if integrity > 0 and integrity < maximum:
			damaged += 1
	return damaged


func _buildable_castle_count() -> int:
	if (
		player_ref == null
		or rules_ref == null
		or not rules_ref.castle_construction
		or bool(player_ref.castle_action_used_this_round)
	):
		return 0

	var buildable: int = 0
	for raw_name in CastleIntegrityRulesData.CASTLES:
		var castle_name: String = String(raw_name)
		if (
			player_ref.castles.has(castle_name)
			or player_ref.ruined_castles.has(castle_name)
			or player_ref.profaned_castles.has(castle_name)
			or player_ref.lost_castles.has(castle_name)
		):
			continue
		buildable += 1
	return buildable


func _castle_maintenance_copy() -> String:
	var damaged: int = _damaged_castle_count()
	var buildable: int = _buildable_castle_count()

	if maintenance_step == "construct":
		if buildable == 1:
			return "One Castle site remains open. Raise it now, or leave the domain as it stands."
		return "%d Castle sites remain open. Raise a new Castle now, or leave the domain as it stands." % buildable

	if damaged == 1:
		return "One of your Castles is damaged. Restore its Integrity now, or carry the weakness into Commitment."
	if damaged > 1:
		return "%d of your Castles are damaged. Restore Integrity now, or carry those weaknesses into Commitment." % damaged
	return "No damaged Castle needs attention."


func _deploy_copy() -> String:
	if player_ref == null:
		return "Assign cards from Hand or Garrison to defend your Lord and Castles."

	var exposed: Array[String] = []
	if bool(player_ref.alive) and player_ref.lord_guards.is_empty():
		exposed.append("your Lord")
	if player_ref.castle_guards.is_empty():
		exposed.append("your Castles")

	if exposed.size() == 2:
		return "Your Lord and Castle line are both unguarded. Assign cards from Hand or Garrison before Commitment."
	if exposed.size() == 1:
		return "%s %s unguarded. Reinforce that zone now, or keep the cards in reserve." % [
			exposed[0].capitalize(),
			"is" if exposed[0] == "your Lord" else "are",
		]
	return "Your defensive zones already have Guards. Reinforce them further only if the cards are worth committing."



	# UI2_DECISION_PANEL_CROP_FIX_V2

	# UI2_DECISION_PANEL_WHOLE_ART_V3
func _apply_decision_panel_skin_v1() -> void:
	if UI2_DECISION_PANEL_TEXTURE == null:
		return

	if not resized.is_connected(_refresh_decision_panel_art_mode_v3):
		resized.connect(_refresh_decision_panel_art_mode_v3)

	_refresh_decision_panel_art_mode_v3()

	if view_board_button != null:
		_skin_view_board_button_v1(view_board_button)

	# UI2_DECISION_PANEL_LAYOUT_V4
	_install_decision_panel_layout_v4()


# UI2_DECISION_PANEL_BREATHING_ROOM_V6
func _refresh_decision_panel_art_mode_v3() -> void:
	var collapsed_now: bool = size.y <= 100.0
	var previous_mode = get_meta(
		"_ui2_decision_panel_collapsed_v3",
		null
	)

	if previous_mode != null and bool(previous_mode) == collapsed_now:
		return

	set_meta(
		"_ui2_decision_panel_collapsed_v3",
		collapsed_now
	)

	if collapsed_now:
		var collapsed_style := StyleBoxFlat.new()
		collapsed_style.bg_color = Color(0.018, 0.017, 0.016, 0.97)
		collapsed_style.border_color = Color(0.48, 0.37, 0.19, 1.0)
		collapsed_style.set_border_width_all(2)
		collapsed_style.set_corner_radius_all(5)
		collapsed_style.content_margin_left = 12.0
		collapsed_style.content_margin_right = 12.0
		collapsed_style.content_margin_top = 8.0
		collapsed_style.content_margin_bottom = 8.0
		add_theme_stylebox_override(
			"panel",
			collapsed_style
		)
		return

	# The artwork's native composition is approximately 3:4.
	# PhasePrompt is now sized to the same ratio, so the entire image can
	# simply scale as one coherent painting with no nine-slice assembly.
	var panel_style := StyleBoxTexture.new()
	panel_style.texture = UI2_DECISION_PANEL_TEXTURE
	var compact_decision_layout_v10: bool = (
		stage_key == "COMMITMENT"
		or (stage_key == "MARKET" and not detail_open)
	)
	panel_style.content_margin_left = (
		36.0
	)
	panel_style.content_margin_right = (
		36.0
	)
	panel_style.content_margin_top = 92.0
	# UI2_DECISION_BOTTOM_ACTION_AREA_V12
	panel_style.content_margin_bottom = 195.0
	add_theme_stylebox_override(
		"panel",
		panel_style
	)



func _skin_view_board_button_v1(button: Button) -> void:
	if button == null:
		return

	button.custom_minimum_size = Vector2(112.0, 32.0)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override(
		"font_color",
		Color(0.88, 0.84, 0.72, 1.0)
	)
	button.add_theme_color_override(
		"font_hover_color",
		Color(1.0, 0.93, 0.72, 1.0)
	)
	button.add_theme_color_override(
		"font_pressed_color",
		Color(0.76, 0.68, 0.50, 1.0)
	)

	button.add_theme_stylebox_override(
		"normal",
		_decision_panel_button_style_v1(
			Color(0.025, 0.024, 0.022, 0.94),
			Color(0.40, 0.31, 0.16, 1.0),
			1
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_decision_panel_button_style_v1(
			Color(0.065, 0.052, 0.032, 0.98),
			Color(0.68, 0.53, 0.25, 1.0),
			2
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_decision_panel_button_style_v1(
			Color(0.018, 0.017, 0.016, 1.0),
			Color(0.48, 0.36, 0.17, 1.0),
			2
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		StyleBoxEmpty.new()
	)


func _decision_panel_button_style_v1(
	background: Color,
	border: Color,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style



	# UI2_DECISION_PANEL_TINY_TOGGLE_V5
func _install_decision_panel_layout_v4() -> void:
	if view_board_button == null or title_label == null:
		return

	var header_row := view_board_button.get_parent() as Control
	if header_row == null:
		return

	var content_root := header_row.get_parent() as Control
	if content_root == null:
		return

	content_root.name = "DecisionPanelContentV4"

	# IMPORTANT: PhasePrompt is a PanelContainer. Do NOT make the title or
	# button direct children of it; Container layout will stretch them.
	# Instead create a plain Control sibling that is outside container layout.
	var parent_control := get_parent() as Control
	if parent_control == null:
		return

	var overlay := parent_control.get_node_or_null(
		"DecisionPanelOverlayV5"
	) as Control

	if overlay == null:
		overlay = Control.new()
		overlay.name = "DecisionPanelOverlayV5"
		overlay.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.z_index = z_index + 1
		parent_control.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)

	if title_label.get_parent() != overlay:
		title_label.get_parent().remove_child(title_label)
		overlay.add_child(title_label)

	if view_board_button.get_parent() != overlay:
		view_board_button.get_parent().remove_child(view_board_button)
		overlay.add_child(view_board_button)

	title_label.z_index = 2
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override(
		"font_size",
		18
	)
	title_label.add_theme_color_override(
		"font_color",
		Color(0.91, 0.85, 0.68, 1.0)
	)

	view_board_button.z_index = 3
	view_board_button.mouse_filter = Control.MOUSE_FILTER_STOP
	view_board_button.custom_minimum_size = Vector2(88.0, 26.0)
	view_board_button.add_theme_font_size_override(
		"font_size",
		11
	)

	# Capture the exact screen rectangle before the core handler changes the
	# PhasePrompt size/state.
	if not view_board_button.button_down.is_connected(
		_capture_decision_panel_button_rect_v4
	):
		view_board_button.button_down.connect(
			_capture_decision_panel_button_rect_v4
		)

	if not view_board_button.pressed.is_connected(
		_queue_decision_panel_layout_sync_v4
	):
		view_board_button.pressed.connect(
			_queue_decision_panel_layout_sync_v4
		)

	if not resized.is_connected(
		_queue_decision_panel_layout_sync_v4
	):
		resized.connect(
			_queue_decision_panel_layout_sync_v4
		)

	if not visibility_changed.is_connected(
		_queue_decision_panel_layout_sync_v4
	):
		visibility_changed.connect(
			_queue_decision_panel_layout_sync_v4
		)

	_sync_decision_panel_layout_v4()


func _capture_decision_panel_button_rect_v4() -> void:
	if view_board_button == null:
		return

	set_meta(
		"_ui2_decision_button_global_rect_v4",
		view_board_button.get_global_rect()
	)


func _queue_decision_panel_layout_sync_v4() -> void:
	call_deferred("_sync_decision_panel_layout_v4")


func _decision_panel_overlay_v5() -> Control:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return null

	return parent_control.get_node_or_null(
		"DecisionPanelOverlayV5"
	) as Control


func _place_decision_overlay_rect_v5(
	control: Control,
	global_rect: Rect2
) -> void:
	var overlay := _decision_panel_overlay_v5()
	if overlay == null or control == null:
		return

	var local_top_left: Vector2 = (
		overlay.get_global_transform().affine_inverse()
		* global_rect.position
	)

	control.anchor_left = 0.0
	control.anchor_right = 0.0
	control.anchor_top = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = local_top_left.x
	control.offset_top = local_top_left.y
	control.offset_right = (
		local_top_left.x + global_rect.size.x
	)
	control.offset_bottom = (
		local_top_left.y + global_rect.size.y
	)


func _sync_decision_panel_layout_v4() -> void:
	if view_board_button == null or title_label == null:
		return

	var overlay := _decision_panel_overlay_v5()
	if overlay == null:
		return
	# UI2_DECISION_PHASE_STALE_RUNTIME_PURGE_V17_6
	# The retired V15 helper has no active callers. Purge any V15 label
	# that survived in the scene tree before drawing the current V16 slot.
	var stale_phase_v15_live := overlay.get_node_or_null(
		"DecisionPhaseSlotV15"
	) as Control
	if stale_phase_v15_live != null:
		stale_phase_v15_live.visible = false
		stale_phase_v15_live.queue_free()


	var phase_slot_v16 := overlay.get_node_or_null(
		"DecisionPhaseSlotV16"
	) as Label
	# UI2_DECISION_OVERLAY_ORPHAN_LABEL_PURGE_V17_7
	# Runtime census found an unnamed opaque Label stranded directly
	# under DecisionPanelOverlayV5. Only title_label and phase_slot_v16
	# are legitimate direct Label children of this header overlay.
	for overlay_child_v17_7 in overlay.get_children():
		var orphan_label_v17_7 := overlay_child_v17_7 as Label
		if orphan_label_v17_7 == null:
			continue
		if orphan_label_v17_7 == title_label:
			continue
		if orphan_label_v17_7 == phase_slot_v16:
			continue
		orphan_label_v17_7.visible = false
		orphan_label_v17_7.queue_free()


	var content_root := get_node_or_null(
		"DecisionPanelContentV4"
	) as Control

	# Because title/button now live outside PhasePrompt, explicitly mirror the
	# prompt's own visibility.
	if not visible:
		title_label.visible = false
		if phase_slot_v16 != null:
			phase_slot_v16.visible = false
		view_board_button.visible = false
		return

	if board_view_collapsed:
		# Exactly one thing remains: the tiny toggle button.
		if content_root != null:
			content_root.visible = false

		title_label.visible = false
		if phase_slot_v16 != null:
			phase_slot_v16.visible = false
		add_theme_stylebox_override(
			"panel",
			StyleBoxEmpty.new()
		)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = false

		view_board_button.visible = true
		view_board_button.text = "RETURN"
		view_board_button.tooltip_text = "Return to the current decision."

		var captured: Rect2 = get_meta(
			"_ui2_decision_button_global_rect_v4",
			Rect2()
		)

		if captured.size.x > 0.0 and captured.size.y > 0.0:
			_place_decision_overlay_rect_v5(
				view_board_button,
				captured
			)

		return

	# Expanded decision window.
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

	if content_root != null:
		content_root.visible = true

	view_board_button.visible = true
	view_board_button.text = "VIEW BOARD"
	view_board_button.tooltip_text = (
		"Collapse this decision temporarily. Current selections stay staged."
	)

	# Restore the complete painted panel after collapsed mode hid it.
	set_meta(
		"_ui2_decision_panel_collapsed_v3",
		true
	)
	_refresh_decision_panel_art_mode_v3()

	var prompt_rect: Rect2 = get_global_rect()

	# UI2_DECISION_HEADER_GLOBAL_RECT_V16_1
	# Keep the original eyebrow alive for state/layout, but render the
	# phase name in the artwork's dedicated cutout instead.
	# UI2_DECISION_PHASE_DUPLICATE_CLEANUP_V17_2
	# Preserve the legacy eyebrow's layout footprint/text source,
	# but make its glyphs impossible to render in the content VBox.
	if eyebrow_label != null:
		eyebrow_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
		eyebrow_label.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		eyebrow_label.add_theme_color_override(
			"font_color",
			Color(1.0, 1.0, 1.0, 0.0)
		)
		eyebrow_label.add_theme_color_override(
			"font_shadow_color",
			Color(0.0, 0.0, 0.0, 0.0)
		)

	if phase_slot_v16 == null:
		phase_slot_v16 = Label.new()
		phase_slot_v16.name = "DecisionPhaseSlotV16"
		phase_slot_v16.mouse_filter = Control.MOUSE_FILTER_IGNORE
		phase_slot_v16.z_index = 2
		phase_slot_v16.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		phase_slot_v16.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		phase_slot_v16.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		phase_slot_v16.add_theme_font_size_override("font_size", 11)
		phase_slot_v16.add_theme_color_override(
			"font_color",
			Color(0.76, 0.67, 0.48, 1.0)
		)
		phase_slot_v16.add_theme_color_override(
			"font_shadow_color",
			Color(0.0, 0.0, 0.0, 0.88)
		)
		phase_slot_v16.add_theme_constant_override("shadow_offset_x", 1)
		phase_slot_v16.add_theme_constant_override("shadow_offset_y", 1)
		overlay.add_child(phase_slot_v16)

	phase_slot_v16.text = (
		eyebrow_label.text
		if eyebrow_label != null
		else ""
	)
	phase_slot_v16.visible = true

	# UI2_DECISION_PHASE_SLOT_READABILITY_V17_1
	# Normalize to the live panel rectangle so intro/detail views share
	# the exact same painted phase-window position.
	var phase_rect_v17_1 := Rect2(
		prompt_rect.position + Vector2(
			prompt_rect.size.x * 0.065,
			prompt_rect.size.y * 0.118
		),
		Vector2(
			prompt_rect.size.x * 0.260,
			prompt_rect.size.y * 0.052
		)
	)
	_place_decision_overlay_rect_v5(
		phase_slot_v16,
		phase_rect_v17_1
	)

	# Dynamic title in the artwork's top plaque.
	var title_rect := Rect2(
		prompt_rect.position + Vector2(90.0, 20.0),
		Vector2(prompt_rect.size.x - 180.0, 44.0)
	)
	title_label.visible = true
	title_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	title_label.add_theme_font_size_override("font_size", 16)
	_place_decision_overlay_rect_v5(
		title_label,
		title_rect
	)

	# Tiny corner toggle. Because it lives in the overlay rather than the
	# PanelContainer, these dimensions stay exactly 88x26.
	var button_rect := Rect2(
		prompt_rect.position + Vector2(
			prompt_rect.size.x - 102.0,
			66.0
		),
		Vector2(88.0, 26.0)
	)
	_place_decision_overlay_rect_v5(
		view_board_button,
		button_rect
	)


# UI2_DECISION_BOTTOM_ACTIONS_V12_1
#
# DecisionPanel artwork has three action windows:
#   - one wide upper-bottom window for a single action
#   - two smaller lower windows when two choices are available
#
# Existing Buttons are reparented into a plain sibling overlay so:
#   - Container layout cannot stretch them
#   - existing pressed signals remain untouched
#   - action text always occupies the artwork's intended window
func _install_decision_bottom_actions_v12() -> void:
	if action_zone == null:
		return

	var parent_control := get_parent() as Control
	if parent_control == null:
		return

	var overlay := parent_control.get_node_or_null(
		"DecisionPanelActionOverlayV12"
	) as Control

	if overlay == null:
		overlay = Control.new()
		overlay.name = "DecisionPanelActionOverlayV12"
		overlay.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.z_index = z_index + 2
		parent_control.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)

	var intro_layer := overlay.get_node_or_null(
		"DecisionIntroActionsV12"
	) as Control
	if intro_layer == null:
		intro_layer = Control.new()
		intro_layer.name = "DecisionIntroActionsV12"
		intro_layer.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		intro_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(intro_layer)

	var detail_layer := overlay.get_node_or_null(
		"DecisionDetailActionsV12"
	) as Control
	if detail_layer == null:
		detail_layer = Control.new()
		detail_layer.name = "DecisionDetailActionsV12"
		detail_layer.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		detail_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(detail_layer)

	var confirm_raw = action_zone.get("confirm_button")
	var pass_raw = action_zone.get("pass_button")

	if not (confirm_raw is Button) or not (pass_raw is Button):
		push_warning(
			"DecisionPanel v12: ActionZone confirm/pass Buttons were not found."
		)
		return

	var confirm_button := confirm_raw as Button
	var pass_button := pass_raw as Button

	_move_decision_action_button_v12(
		yes_button,
		intro_layer
	)
	_move_decision_action_button_v12(
		no_button,
		intro_layer
	)
	_move_decision_action_button_v12(
		confirm_button,
		detail_layer
	)
	_move_decision_action_button_v12(
		pass_button,
		detail_layer
	)

	for button: Button in [
		yes_button,
		no_button,
		confirm_button,
		pass_button,
	]:
		if not button.visibility_changed.is_connected(
			_queue_decision_bottom_actions_v12
		):
			button.visibility_changed.connect(
				_queue_decision_bottom_actions_v12
			)

	if not resized.is_connected(
		_queue_decision_bottom_actions_v12
	):
		resized.connect(
			_queue_decision_bottom_actions_v12
		)

	if not visibility_changed.is_connected(
		_queue_decision_bottom_actions_v12
	):
		visibility_changed.connect(
			_queue_decision_bottom_actions_v12
		)

	if not overlay.resized.is_connected(
		_queue_decision_bottom_actions_v12
	):
		overlay.resized.connect(
			_queue_decision_bottom_actions_v12
		)

	if (
		view_board_button != null
		and not view_board_button.pressed.is_connected(
			_queue_decision_bottom_actions_v12
		)
	):
		view_board_button.pressed.connect(
			_queue_decision_bottom_actions_v12
		)

	call_deferred("_sync_decision_bottom_actions_v12")


func _move_decision_action_button_v12(
	button: Button,
	layer: Control
) -> void:
	if button == null or layer == null:
		return

	if button.get_parent() != layer:
		var old_parent := button.get_parent()
		if old_parent != null:
			old_parent.remove_child(button)
		layer.add_child(button)

	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.custom_minimum_size = Vector2.ZERO
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	_skin_decision_action_button_v12(button)


func _skin_decision_action_button_v12(
	button: Button
) -> void:
	if button == null:
		return

	var normal := StyleBoxEmpty.new()
	var disabled := StyleBoxEmpty.new()

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.22, 0.13, 0.035, 0.20)
	hover.border_color = Color(0.65, 0.48, 0.20, 0.55)
	hover.set_border_width_all(1)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.09, 0.045, 0.012, 0.34)

	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	focus.border_color = Color(0.70, 0.53, 0.24, 0.72)
	focus.set_border_width_all(1)

	button.add_theme_stylebox_override(
		"normal",
		normal
	)
	button.add_theme_stylebox_override(
		"disabled",
		disabled
	)
	button.add_theme_stylebox_override(
		"hover",
		hover
	)
	button.add_theme_stylebox_override(
		"pressed",
		pressed
	)
	button.add_theme_stylebox_override(
		"focus",
		focus
	)

	button.add_theme_color_override(
		"font_color",
		Color(0.92, 0.88, 0.76, 1.0)
	)
	button.add_theme_color_override(
		"font_hover_color",
		Color(1.0, 0.94, 0.75, 1.0)
	)
	button.add_theme_color_override(
		"font_pressed_color",
		Color(0.86, 0.73, 0.47, 1.0)
	)
	button.add_theme_color_override(
		"font_disabled_color",
		Color(0.48, 0.46, 0.41, 0.78)
	)


func _queue_decision_bottom_actions_v12() -> void:
	call_deferred("_sync_decision_bottom_actions_v12")


func _sync_decision_bottom_actions_v12() -> void:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return

	var overlay := parent_control.get_node_or_null(
		"DecisionPanelActionOverlayV12"
	) as Control
	if overlay == null:
		return

	var intro_layer := overlay.get_node_or_null(
		"DecisionIntroActionsV12"
	) as Control
	var detail_layer := overlay.get_node_or_null(
		"DecisionDetailActionsV12"
	) as Control

	if intro_layer == null or detail_layer == null:
		return

	var confirm_raw = (
		action_zone.get("confirm_button")
		if action_zone != null
		else null
	)
	var pass_raw = (
		action_zone.get("pass_button")
		if action_zone != null
		else null
	)

	var confirm_button := confirm_raw as Button
	var pass_button := pass_raw as Button

	var panel_active: bool = (
		visible
		and not board_view_collapsed
	)

	overlay.visible = panel_active

	if not panel_active:
		return

	var show_details: bool = (
		detail_open
		and action_zone != null
	)

	intro_layer.visible = (
		not show_details
		and _has_buttons(stage_key)
	)
	detail_layer.visible = show_details

	var panel_global := get_global_rect()
	# UI2_DECISION_BOTTOM_ACTIONS_ALIGN_V12_3
	# Slots are defined in global screen space to match the panel art.
	var panel_origin := panel_global.position
	var panel_size := panel_global.size

	# Coordinates are normalized to the new three-slot artwork so the
	# placement remains correct if the panel footprint is tuned later.
	var wide_slot := Rect2(
		panel_origin + Vector2(
			panel_size.x * 0.09,

			# UI2_DECISION_BOTTOM_ACTIONS_SLOT_TUNE_V12_4
			# UI2_DECISION_BOTTOM_ACTIONS_STRING_FIX_V12_5
			panel_size.y * 0.785

		),
		Vector2(
			panel_size.x * 0.82,
			panel_size.y * 0.067
		)
	)

	var left_slot := Rect2(
		panel_origin + Vector2(
			panel_size.x * 0.10,

	panel_size.y * 0.900

		),
		Vector2(
			panel_size.x * 0.38,

	panel_size.y * 0.060

		)
	)

	var right_slot := Rect2(
		panel_origin + Vector2(
			panel_size.x * 0.52,

	panel_size.y * 0.900

		),
		Vector2(
			panel_size.x * 0.38,

	panel_size.y * 0.060

		)
	)

	_layout_decision_action_pair_v12(
		yes_button,
		no_button,
		wide_slot,
		left_slot,
		right_slot
	)

	_layout_decision_action_pair_v12(
		confirm_button,
		pass_button,
		wide_slot,
		left_slot,
		right_slot
	)


func _layout_decision_action_pair_v12(
	primary: Button,
	secondary: Button,
	wide_slot: Rect2,
	left_slot: Rect2,
	right_slot: Rect2
) -> void:
	var primary_visible: bool = (
		primary != null
		and primary.visible
	)
	var secondary_visible: bool = (
		secondary != null
		and secondary.visible
	)

	var visible_count: int = (
		int(primary_visible)
		+ int(secondary_visible)
	)

	if visible_count == 1:
		var single_button: Button = (
			primary
			if primary_visible
			else secondary
		)
		_place_decision_action_button_v12(
			single_button,
			wide_slot,
			true
		)
		return

	if visible_count == 2:
		_place_decision_action_button_v12(
			primary,
			left_slot,
			false
		)
		_place_decision_action_button_v12(
			secondary,
			right_slot,
			false
		)


func _place_decision_action_button_v12(
	button: Button,
	slot: Rect2,
	large: bool
) -> void:
	if button == null:
		return

	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.global_position = slot.position
	button.size = slot.size
	button.add_theme_font_size_override(
		"font_size",
		16 if large else 14
	)


# UI2_DECISION_ALIGNMENT_CLEANUP_V15
# UI2_DECISION_PHASE_V15_RETIRE_V17_5
func _sync_decision_header_slots_v15() -> void:
	# Historical compatibility shim only.
	# Never create/render a second phase label again.
	var overlay := _decision_panel_overlay_v5()
	if overlay == null and title_label != null:
		overlay = title_label.get_parent() as Control

	if overlay == null:
		return

	var stale_phase_v15 := overlay.get_node_or_null(
		"DecisionPhaseSlotV15"
	) as Control

	if stale_phase_v15 != null:
		stale_phase_v15.visible = false
		stale_phase_v15.queue_free()

	return
