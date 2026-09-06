# UI2_RESOLUTION_COMPACT_TOTALS_V1
# UI2_CARD_INTERACTION_STAGING_V2
# UI2_COMMITMENT_CARD_ART_FLOW_V1
# UI2_SUBJECT_CARD_ART_SURFACES_V2
class_name UI2ResolutionTheater
extends Control


# UI2_RESOLUTION_THEATER_SCRUM_V1
const MixedActionSquadBattleData = preload(
	"res://Prototype/UI2/MixedActionSquadBattle.gd"
)

var _scrum_overlay_active: bool = false

const SubjectCardArtCatalogData = preload(
	"res://Prototype/UI2/SubjectCardArtCatalog.gd"
)
const SubjectCardHoldPreviewData = preload(
	"res://Prototype/UI2/SubjectCardHoldPreview.gd"
)

# UI2_VESSEL_CASTLE_RESOLUTION_POLISH_V1
const CastleSpineData = preload(
	"res://Prototype/UI2/CastleSpine.gd"
)

const CASTLE_TARGET_NAMES: Array[String] = [
	"Keep",
	"Bastion",
	"SummoningCircle",
	"Stockpile",
	"SiegeEngine",
]


const SubjectSuitStyleData = preload(
	"res://Prototype/UI2/SubjectSuitStyle.gd"
)


var veil: ColorRect = null
var frame: PanelContainer = null
var title_label: Label = null
var subtitle_label: Label = null
var left_name_label: Label = null
var right_name_label: Label = null
var left_cards: HBoxContainer = null
var right_cards: HBoxContainer = null
var clash_label: Label = null
var footer_label: Label = null
var aftermath_button: Button = null
var _aftermath_context: Dictionary = {}
var left_side: VBoxContainer = null
var right_side: VBoxContainer = null
var _last_attack_header: String = ""
var _target_impact_just_played: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	veil = ColorRect.new()
	veil.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	veil.color = Color(0.015, 0.015, 0.02, 0.78)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	frame = PanelContainer.new()
	frame.custom_minimum_size = Vector2(1040, 390)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.pivot_offset = Vector2(520, 195)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.055, 0.065, 0.98)
	style.border_color = Color(0.52, 0.47, 0.34, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	frame.add_theme_stylebox_override("panel", style)
	center.add_child(frame)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	frame.add_child(outer)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 25)
	outer.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 14)
	outer.add_child(subtitle_label)

	var clash_row := HBoxContainer.new()
	clash_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clash_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	clash_row.alignment = BoxContainer.ALIGNMENT_CENTER
	clash_row.add_theme_constant_override("separation", 18)
	outer.add_child(clash_row)

	left_side = _build_side()
	left_name_label = left_side.get_node("Name")
	left_cards = left_side.get_node("Cards")
	clash_row.add_child(left_side)

	clash_label = Label.new()
	clash_label.custom_minimum_size = Vector2(72, 0)
	clash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clash_label.add_theme_font_size_override("font_size", 30)
	clash_label.text = "VS"
	clash_row.add_child(clash_label)

	right_side = _build_side()
	right_name_label = right_side.get_node("Name")
	right_cards = right_side.get_node("Cards")
	clash_row.add_child(right_side)

	footer_label = Label.new()
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer_label.add_theme_font_size_override("font_size", 14)
	outer.add_child(footer_label)

	aftermath_button = Button.new()
	aftermath_button.text = "AS BEFORE, SO AGAIN"
	aftermath_button.visible = false
	aftermath_button.custom_minimum_size = Vector2(0, 46)
	aftermath_button.add_theme_font_size_override("font_size", 15)
	outer.add_child(aftermath_button)


func _build_side() -> VBoxContainer:
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(410, 245)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 7)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	side.add_child(name_label)

	var cards := HBoxContainer.new()
	cards.name = "Cards"
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cards.add_theme_constant_override("separation", -12)
	side.add_child(cards)

	var total_label := Label.new()
	total_label.name = "Total"
	total_label.visible = false
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_font_size_override("font_size", 15)
	side.add_child(total_label)

	return side

func play_reveal(
	human,
	bot
) -> void:
	if human == null or bot == null:
		return

	visible = true
	_last_attack_header = ""
	var both_ward: bool = (
		String(human.action) == "Ward"
		and String(bot.action) == "Ward"
	)
	title_label.text = "ORDERS REVEALED"
	if both_ward:
		# UI2_AFTERMATH_WARD_REVEAL_CLEANUP_V1
		subtitle_label.text = "BOTH SIDES WARD · NO COLLISION"
		clash_label.text = "◇"
		footer_label.text = "Both Sigils rise. No attack crosses the field."
	else:
		subtitle_label.text = "ENEMY LEFT  ·  PLAYER RIGHT"
		clash_label.text = "◆"
		footer_label.text = "Committed cards are now public."

	# Match the permanent HUD: enemy always lives on the left and
	# the human player always lives on the right.
	_set_player_side(
		left_name_label,
		left_cards,
		bot,
		"ENEMY"
	)
	_set_player_side(
		right_name_label,
		right_cards,
		human,
		"PLAYER"
	)

	frame.modulate = Color(1, 1, 1, 0)
	frame.scale = Vector2(0.96, 0.96)
	var intro = create_tween().set_parallel(true)
	intro.tween_property(
		frame,
		"modulate",
		Color.WHITE,
		0.22
	)
	intro.tween_property(
		frame,
		"scale",
		Vector2.ONE,
		0.28
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await intro.finished

	await get_tree().create_timer(1.05).timeout
	if both_ward:
		footer_label.text = "Both defensive orders stand. Resolution continues."
	else:
		footer_label.text = "Resolution order is about to begin."
	await get_tree().create_timer(0.55).timeout
	visible = false


func play_action(
	attacker,
	defender,
	action_name: String,
	target_name: String,
	show_defender_commitment: bool = false
) -> void:
	if attacker == null or defender == null:
		return

	var player_is_attacker: bool = int(attacker.pid) == 0
	var attack_header: String = (
		"PLAYER ATTACK"
		if player_is_attacker
		else "ENEMY ATTACK"
	)
	var target_context: String = _attack_target_context(
		action_name,
		target_name,
		player_is_attacker
	)

	visible = true
	_last_attack_header = attack_header
	title_label.text = attack_header
	subtitle_label.text = target_context
	footer_label.text = (
		"Your commitment drives from right to left."
		if player_is_attacker
		else "Enemy commitment drives from left to right."
	)
	clash_label.text = "←" if player_is_attacker else "→"

	_clear_children(left_cards)
	_clear_children(right_cards)

	if player_is_attacker:
		_set_defense_side(
			left_name_label,
			left_cards,
			defender,
			"ENEMY",
			target_name,
			show_defender_commitment
		)
		_set_attack_side(
			right_name_label,
			right_cards,
			attacker,
			"PLAYER",
			action_name
		)
	else:
		_set_attack_side(
			left_name_label,
			left_cards,
			attacker,
			"ENEMY",
			action_name
		)
		_set_defense_side(
			right_name_label,
			right_cards,
			defender,
			"PLAYER",
			target_name,
			show_defender_commitment
		)

	await get_tree().process_frame
	var left_home: Vector2 = left_side.position
	var right_home: Vector2 = right_side.position

	left_side.position = left_home + Vector2(-70, 0)
	right_side.position = right_home + Vector2(70, 0)
	left_side.modulate = Color(1, 1, 1, 0)
	right_side.modulate = Color(1, 1, 1, 0)

	var enter = create_tween().set_parallel(true)
	enter.tween_property(
		left_side,
		"position:x",
		left_side.position.x + 70,
		0.20
	)
	enter.tween_property(
		right_side,
		"position:x",
		right_side.position.x - 70,
		0.20
	)
	enter.tween_property(
		left_side,
		"modulate",
		Color.WHITE,
		0.17
	)
	enter.tween_property(
		right_side,
		"modulate",
		Color.WHITE,
		0.17
	)
	await enter.finished

	await get_tree().create_timer(0.22).timeout

	clash_label.text = "✦"
	clash_label.scale = Vector2.ONE
	clash_label.pivot_offset = clash_label.size * 0.5

	# The attacker moves farther; left/right identity never changes.
	var left_travel: float = 30.0 if player_is_attacker else 72.0
	var right_travel: float = 72.0 if player_is_attacker else 30.0

	var slam = create_tween().set_parallel(true)
	slam.set_trans(Tween.TRANS_BACK)
	slam.set_ease(Tween.EASE_IN)
	slam.tween_property(
		left_side,
		"position:x",
		left_side.position.x + left_travel,
		0.24
	)
	slam.tween_property(
		right_side,
		"position:x",
		right_side.position.x - right_travel,
		0.24
	)
	slam.tween_property(
		clash_label,
		"scale",
		Vector2(1.8, 1.8),
		0.24
	)
	await slam.finished

	frame.modulate = Color(1.28, 1.22, 1.05, 1.0)
	var impact = create_tween()
	impact.tween_property(
		frame,
		"modulate",
		Color.WHITE,
		0.20
	)
	await impact.finished
	await get_tree().create_timer(0.14).timeout
	left_side.position = left_home
	right_side.position = right_home
	clash_label.scale = Vector2.ONE
	visible = false


func play_interposition(
	interposer_name: String,
	defender_role: String,
	detail_text: String,
	target_player = null
) -> void:
	if interposer_name.is_empty():
		return

	var enemy_defense: bool = defender_role == "ENEMY"
	var defense_side: VBoxContainer = (
		left_side
		if enemy_defense
		else right_side
	)
	var defense_name_label: Label = (
		left_name_label
		if enemy_defense
		else right_name_label
	)
	var defense_cards: HBoxContainer = (
		left_cards
		if enemy_defense
		else right_cards
	)
	var other_name_label: Label = (
		right_name_label
		if enemy_defense
		else left_name_label
	)
	var other_cards: HBoxContainer = (
		right_cards
		if enemy_defense
		else left_cards
	)

	visible = true
	title_label.text = "%s INTERPOSES" % interposer_name.to_upper()
	subtitle_label.text = "%s DEFENSE" % defender_role
	footer_label.text = detail_text
	clash_label.text = "◆"

	_clear_children(defense_cards)
	_clear_children(other_cards)
	defense_name_label.text = "%s · %s" % [
		defender_role,
		interposer_name.to_upper(),
	]
	other_name_label.text = ""
	if target_player != null and _is_castle_target(interposer_name):
		_add_castle_target_card(
			defense_cards,
			target_player,
			interposer_name,
			Vector2(150, 225)
		)
	else:
		_add_target_card(
			defense_cards,
			interposer_name
		)

	await get_tree().process_frame
	var home: Vector2 = defense_side.position
	var edge_offset: float = -115.0 if enemy_defense else 115.0
	var center_push: float = 48.0 if enemy_defense else -48.0

	defense_side.position = home + Vector2(edge_offset, 0)
	defense_side.modulate = Color(1, 1, 1, 0)

	var enter = create_tween().set_parallel(true)
	enter.set_trans(Tween.TRANS_BACK)
	enter.set_ease(Tween.EASE_OUT)
	enter.tween_property(
		defense_side,
		"position:x",
		home.x + center_push,
		0.24
	)
	enter.tween_property(
		defense_side,
		"modulate",
		Color.WHITE,
		0.16
	)
	await enter.finished

	frame.modulate = Color(1.30, 1.18, 0.92, 1.0)
	var impact = create_tween()
	impact.tween_property(
		frame,
		"modulate",
		Color.WHITE,
		0.18
	)
	await impact.finished
	await get_tree().create_timer(0.48).timeout

	defense_side.position = home
	defense_side.modulate = Color.WHITE
	visible = false


func play_target_impact(
	target_name: String,
	defender_role: String,
	stat_name: String,
	value_before: int,
	value_after: int,
	damage: int,
	destroyed: bool = false,
	target_player = null
) -> void:
	if target_name.is_empty():
		return

	var enemy_target: bool = defender_role == "ENEMY"
	var target_side: VBoxContainer = left_side if enemy_target else right_side
	var force_side: VBoxContainer = right_side if enemy_target else left_side
	var target_name_label: Label = left_name_label if enemy_target else right_name_label
	var force_name_label: Label = right_name_label if enemy_target else left_name_label
	var target_cards: HBoxContainer = left_cards if enemy_target else right_cards
	var force_cards: HBoxContainer = right_cards if enemy_target else left_cards

	visible = true
	_target_impact_just_played = true
	title_label.text = "IMPACT"
	subtitle_label.text = "%s · %s" % [defender_role, target_name.to_upper()]
	clash_label.text = "←" if enemy_target else "→"

	_clear_children(target_cards)
	_clear_children(force_cards)

	target_name_label.text = "%s · %s" % [defender_role, target_name.to_upper()]
	force_name_label.text = "REMAINING FORCE"

	var force_card := PanelContainer.new()
	force_card.custom_minimum_size = Vector2(126, 126)
	force_card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var force_style := StyleBoxFlat.new()
	force_style.bg_color = Color(0.10, 0.075, 0.075, 1.0)
	force_style.border_color = Color(0.72, 0.24, 0.20, 1.0)
	force_style.set_border_width_all(3)
	force_card.add_theme_stylebox_override("panel", force_style)

	var force_label := Label.new()
	force_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	force_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	force_label.text = "%d\nFORCE" % maxi(0, damage)
	force_label.add_theme_font_size_override("font_size", 22)
	force_card.add_child(force_label)
	force_cards.add_child(force_card)

	var target = null
	var value_label: Label = null
	var target_is_castle_card: bool = (
		target_player != null
		and stat_name.to_lower() == "integrity"
		and _is_castle_target(target_name)
	)

	if target_is_castle_card:
		target = _add_castle_target_card(
			target_cards,
			target_player,
			target_name,
			Vector2(150, 225)
		)
		value_label = target.integrity_label
		value_label.text = str(value_before)
		value_label.add_theme_font_size_override("font_size", 18)
		if target.state_label != null:
			target.state_label.text = "UNDER ATTACK"
	else:
		var target_panel := PanelContainer.new()
		target_panel.custom_minimum_size = Vector2(184, 132)
		target_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target = target_panel

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.075, 0.075, 0.09, 1.0)
		style.border_color = (
			Color(0.72, 0.18, 0.16, 1.0)
			if destroyed
			else Color(0.62, 0.58, 0.40, 1.0)
		)
		style.set_border_width_all(3)
		target_panel.add_theme_stylebox_override("panel", style)

		var stack := VBoxContainer.new()
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", 5)
		target_panel.add_child(stack)

		var object_label := Label.new()
		object_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		object_label.text = target_name.to_upper()
		object_label.add_theme_font_size_override("font_size", 15)
		stack.add_child(object_label)

		var stat_label := Label.new()
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_label.text = stat_name.to_upper()
		stat_label.add_theme_font_size_override("font_size", 11)
		stack.add_child(stat_label)

		value_label = Label.new()
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.text = str(value_before)
		value_label.add_theme_font_size_override("font_size", 34)
		stack.add_child(value_label)
		target_cards.add_child(target_panel)

	var crack_label := Label.new()
	crack_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crack_label.text = "╱   ╲\n  ╲ ╱"
	crack_label.add_theme_font_size_override("font_size", 31)
	crack_label.modulate = Color(1.0, 0.72, 0.65, 0.0)
	crack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(crack_label)
	footer_label.text = "%d FORCE REACHES %s" % [
		maxi(0, damage),
		target_name.to_upper(),
	]

	await get_tree().process_frame

	var target_home: Vector2 = target_side.position
	var force_home: Vector2 = force_side.position
	var force_offset: float = -78.0 if enemy_target else 78.0

	var slam = create_tween()
	slam.set_trans(Tween.TRANS_QUAD)
	slam.set_ease(Tween.EASE_IN)
	slam.tween_property(
		force_side,
		"position:x",
		force_home.x + force_offset,
		0.18
	)
	await slam.finished

	clash_label.text = "✦"
	crack_label.modulate = Color(1.0, 0.72, 0.65, 1.0)

	frame.modulate = Color(1.34, 1.10, 1.06, 1.0)
	var flash = create_tween()
	flash.tween_property(
		frame,
		"modulate",
		Color.WHITE,
		0.16
	)

	var shake = create_tween()
	shake.tween_property(target_side, "position:x", target_home.x + 11, 0.038)
	shake.tween_property(target_side, "position:x", target_home.x - 9, 0.038)
	shake.tween_property(target_side, "position:x", target_home.x + 7, 0.035)
	shake.tween_property(target_side, "position:x", target_home.x - 5, 0.035)
	shake.tween_property(target_side, "position:x", target_home.x, 0.045)
	await shake.finished

	var current_value: int = value_before
	var total_steps: int = maxi(0, value_before - value_after)
	var step_delay: float = 0.055 if total_steps > 6 else 0.080

	while current_value > value_after:
		current_value -= 1
		value_label.text = str(current_value)
		value_label.scale = Vector2(1.12, 1.12)

		var punch = create_tween()
		punch.tween_property(
			value_label,
			"scale",
			Vector2.ONE,
			step_delay
		)
		await punch.finished

	if target_is_castle_card and target_player != null:
		# Restore the real post-impact Castle state after the count-down.
		target.call("bind_castle", target_player, target_name)
		value_label = target.integrity_label

	if destroyed:
		if not target_is_castle_card:
			value_label.text = "RUINED"
			value_label.add_theme_font_size_override("font_size", 22)
		title_label.text = "%s RUINED" % target_name.to_upper()
	else:
		title_label.text = "TARGET DAMAGED"

	footer_label.text = "%s %d → %d" % [
		stat_name.to_upper(),
		value_before,
		value_after,
	]
	if damage > 0:
		footer_label.text += " · %d DAMAGE" % damage

	await get_tree().create_timer(0.34).timeout

	target_side.position = target_home
	force_side.position = force_home
	visible = false


func set_aftermath_context(
	context: Dictionary
) -> void:
	_aftermath_context = context.duplicate(true)


func play_result(
	result_text: String
) -> void:
	# Per-action calls no longer open AFTERMATH. It belongs to the completed round.
	if not bool(
		_aftermath_context.get(
			"round_complete",
			false
		)
	):
		return

	visible = true
	_target_impact_just_played = false
	title_label.text = "AFTERMATH"
	subtitle_label.text = "THE FIELD REMEMBERS"

	left_name_label.text = ""
	right_name_label.text = ""
	_clear_children(left_cards)
	_clear_children(right_cards)

	left_side.visible = false
	right_side.visible = false
	clash_label.visible = false

	frame.custom_minimum_size = Vector2(880, 500)
	footer_label.custom_minimum_size = Vector2(0, 300)
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	footer_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	footer_label.add_theme_font_size_override("font_size", 15)
	footer_label.text = _compose_aftermath_text(result_text)

	aftermath_button.visible = false
	aftermath_button.text = (
		"RETURN TO FINAL BOARD"
		if bool(_aftermath_context.get("match_complete", false))
		else "BEGIN NEXT ROUND"
	)

	frame.modulate = Color(1.18, 1.16, 1.05, 1.0)
	frame.scale = Vector2(0.985, 0.985)

	var settle = create_tween().set_parallel(true)
	settle.tween_property(
		frame,
		"modulate",
		Color.WHITE,
		0.22
	)
	settle.tween_property(
		frame,
		"scale",
		Vector2.ONE,
		0.22
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await settle.finished

	aftermath_button.visible = true
	aftermath_button.grab_focus()
	await aftermath_button.pressed

	aftermath_button.visible = false
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_label.custom_minimum_size = Vector2.ZERO
	footer_label.add_theme_font_size_override("font_size", 14)
	frame.custom_minimum_size = Vector2(1040, 390)

	left_side.visible = true
	right_side.visible = true
	clash_label.visible = true
	visible = false


func _compose_aftermath_text(
	result_text: String
) -> String:
	var lines: Array[String] = []

	var enemy_lord: String = String(
		_aftermath_context.get("enemy_lord", "ENEMY")
	)
	var enemy_action: String = String(
		_aftermath_context.get("enemy_action", "UNKNOWN")
	)
	var enemy_target: String = String(
		_aftermath_context.get("enemy_target", "TARGET")
	)
	var enemy_outcome: String = String(
		_aftermath_context.get(
			"enemy_outcome",
			"AWAITING RESOLUTION"
		)
	)

	var player_lord: String = String(
		_aftermath_context.get("player_lord", "PLAYER")
	)
	var player_action: String = String(
		_aftermath_context.get("player_action", "UNKNOWN")
	)
	var player_target: String = String(
		_aftermath_context.get("player_target", "TARGET")
	)
	var player_outcome: String = String(
		_aftermath_context.get(
			"player_outcome",
			"AWAITING RESOLUTION"
		)
	)

	lines.append("ENEMY ACTION")
	lines.append(
		"%s · %s → %s"
		% [
			enemy_lord.to_upper(),
			enemy_action.to_upper(),
			enemy_target.to_upper(),
		]
	)
	lines.append(enemy_outcome)
	lines.append("")

	lines.append("YOUR ACTION")
	lines.append(
		"%s · %s → %s"
		% [
			player_lord.to_upper(),
			player_action.to_upper(),
			player_target.to_upper(),
		]
	)
	lines.append(player_outcome)
	lines.append("")

	var human_before: int = int(
		_aftermath_context.get("human_souls_before", 0)
	)
	var human_after: int = int(
		_aftermath_context.get(
			"human_souls_after",
			human_before
		)
	)
	var bot_before: int = int(
		_aftermath_context.get("bot_souls_before", 0)
	)
	var bot_after: int = int(
		_aftermath_context.get(
			"bot_souls_after",
			bot_before
		)
	)

	lines.append("SOULS")
	lines.append(
		"YOU     %d → %d  (%s)"
		% [
			human_before,
			human_after,
			_signed_delta(human_after - human_before),
		]
	)
	lines.append(
		"ENEMY   %d → %d  (%s)"
		% [
			bot_before,
			bot_after,
			_signed_delta(bot_after - bot_before),
		]
	)

	if (
		not result_text.is_empty()
		and result_text != enemy_outcome
		and result_text != player_outcome
	):
		lines.append("")
		lines.append("LATEST RESOLUTION")
		lines.append(result_text)

	return "\n".join(lines)


func _signed_delta(
	value: int
) -> String:
	if value > 0:
		return "+%d" % value
	return str(value)


func _set_player_side(
	name_label: Label,
	card_row: HBoxContainer,
	player,
	role_name: String
) -> void:
	name_label.text = "%s · %s · %s" % [
		role_name,
		String(player.lord).to_upper(),
		String(player.action).to_upper(),
	]
	_clear_children(card_row)
	_add_cards(
		card_row,
		player.committed
	)


func _set_attack_side(
	name_label: Label,
	card_row: HBoxContainer,
	player,
	role_name: String,
	action_name: String
) -> void:
	name_label.text = "%s · %s · %s" % [
		role_name,
		String(player.lord).to_upper(),
		action_name.to_upper(),
	]
	_add_cards(card_row, player.committed)


func _set_defense_side(
	name_label: Label,
	card_row: HBoxContainer,
	player,
	role_name: String,
	target_name: String,
	show_commitment: bool
) -> void:
	var defense_name: String = (
		"WARD"
		if String(player.action) == "Ward" and show_commitment
		else "DEFENSE"
	)
	name_label.text = "%s · %s · %s" % [
		role_name,
		String(player.lord).to_upper(),
		defense_name,
	]

	var castle_target: bool = _is_castle_target(target_name)
	if castle_target:
		_add_castle_target_card(
			card_row,
			player,
			target_name,
			Vector2(92, 138)
		)

	if String(player.action) == "Ward" and show_commitment:
		# Leave room for the actual Castle card beside any Ward cards.
		_add_cards(
			card_row,
			player.committed,
			4 if castle_target else 5
		)

	if card_row.get_child_count() == 0:
		_add_target_card(card_row, target_name)


func _attack_target_context(
	action_name: String,
	target_name: String,
	player_is_attacker: bool
) -> String:
	var owner_text: String = "ENEMY" if player_is_attacker else "YOUR"
	match action_name:
		"Hunt":
			return "HUNT · %s LORD" % owner_text
		"Siege":
			return "SIEGE · %s %s" % [
				owner_text,
				target_name.to_upper(),
			]
		_:
			return "%s · %s" % [
				action_name.to_upper(),
				target_name.to_upper(),
			]


func _add_cards(
	card_row: HBoxContainer,
	cards: Array,
	max_visible: int = 5
) -> void:
	var count: int = cards.size()
	var shown_count: int = mini(count, maxi(1, max_visible))
	var card_size := Vector2(112, 160)

	if shown_count >= 4:
		card_size = Vector2(88, 126)
	elif shown_count == 3:
		card_size = Vector2(100, 143)

	var total_value: int = 0
	for card in cards:
		total_value += int(card.value)

	var total_label = card_row.get_parent().get_node_or_null("Total")
	if total_label != null:
		total_label.visible = count > 1
		if count > 1:
			total_label.text = (
				"%d CARDS · TOTAL %d"
				% [
					count,
					total_value,
				]
			)
			if count > shown_count:
				total_label.text += (
					" · SHOWING %d/%d"
					% [
						shown_count,
						count,
					]
				)

	for index: int in range(shown_count):
		var card = cards[index]
		var suit_name: String = String(card.suit)
		var card_value: int = int(card.value)
		var card_art: Texture2D = (
			SubjectCardArtCatalogData.texture_for(
				suit_name,
				card_value,
				false
			)
		)

		var card_panel := PanelContainer.new()
		card_panel.custom_minimum_size = card_size
		card_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card_panel.clip_contents = true
		card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		card_panel.add_theme_stylebox_override(
			"panel",
			SubjectSuitStyleData.card_style(
				suit_name,
				Color(0.085, 0.085, 0.095, 1.0),
				4
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
			card_panel.add_child(art)

			var preview = SubjectCardHoldPreviewData.new()
			card_panel.add_child(preview)
			preview.configure(
				card_panel,
				card_art
			)
		else:
			var label := Label.new()
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override(
				"font_size",
				13
			)
			label.text = "%d\n%s" % [
				card_value,
				suit_name.to_upper(),
			]
			card_panel.add_child(label)

		card_row.add_child(card_panel)

func _is_castle_target(target_name: String) -> bool:
	return target_name in CASTLE_TARGET_NAMES


func _add_castle_target_card(
	card_row: HBoxContainer,
	player,
	target_name: String,
	card_size: Vector2 = Vector2(92, 138)
):
	if player == null or not _is_castle_target(target_name):
		return null

	var castle_card = CastleSpineData.new()
	castle_card.name = "Resolution%s" % target_name
	card_row.add_child(castle_card)
	castle_card.bind_castle(player, target_name)
	castle_card.custom_minimum_size = card_size
	castle_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	castle_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return castle_card


func _add_target_card(
	card_row: HBoxContainer,
	target_name: String
) -> void:
	var target := PanelContainer.new()
	target.custom_minimum_size = Vector2(118, 96)
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.105, 1.0)
	style.border_color = Color(0.56, 0.56, 0.62, 1.0)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	target.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = target_name.to_upper()
	label.add_theme_font_size_override("font_size", 14)
	target.add_child(label)
	card_row.add_child(target)


func _clear_children(
	node: Node
) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

# UI2_RESOLUTION_THEATER_SCRUM_V1
# Generic large-screen host for marching-battle presentations.
func play_scrum(
	enemy_specs: Array,
	player_specs: Array,
	swing_count: int = 3
) -> void:
	if _scrum_overlay_active:
		return

	if enemy_specs.is_empty() and player_specs.is_empty():
		return

	_scrum_overlay_active = true

	var was_visible: bool = visible
	visible = true

	var overlay := Control.new()
	overlay.name = "MarchScrumResolutionOverlay"
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1000
	add_child(overlay)

	var scrim := ColorRect.new()
	scrim.name = "ScrumScrim"
	scrim.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	scrim.color = Color(
		0.0,
		0.0,
		0.0,
		0.88
	)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(scrim)

	var stage := PanelContainer.new()
	stage.name = "ScrumBigScreen"
	stage.set_anchors_preset(
		Control.PRESET_FULL_RECT
	)
	stage.anchor_left = 0.07
	stage.anchor_top = 0.15
	stage.anchor_right = 0.93
	stage.anchor_bottom = 0.84
	stage.offset_left = 0.0
	stage.offset_top = 0.0
	stage.offset_right = 0.0
	stage.offset_bottom = 0.0
	overlay.add_child(stage)

	var stage_style := StyleBoxFlat.new()
	stage_style.bg_color = Color(
		0.035,
		0.035,
		0.04,
		0.98
	)
	stage_style.border_color = Color(
		0.38,
		0.34,
		0.28,
		1.0
	)
	stage_style.set_border_width_all(2)
	stage_style.set_corner_radius_all(8)
	stage.add_theme_stylebox_override(
		"panel",
		stage_style
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		28
	)
	margin.add_theme_constant_override(
		"margin_right",
		28
	)
	margin.add_theme_constant_override(
		"margin_top",
		18
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		18
	)
	stage.add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(
		"separation",
		10
	)
	margin.add_child(column)

	var kicker := Label.new()
	kicker.text = "RESOLUTION THEATER"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_size_override(
		"font_size",
		13
	)
	kicker.add_theme_color_override(
		"font_color",
		Color(
			0.65,
			0.60,
			0.52,
			1.0
		)
	)
	column.add_child(kicker)

	var headline := Label.new()
	headline.text = "THE BATTLEFIELD"
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_font_size_override(
		"font_size",
		24
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
	column.add_child(headline)

	var rule := HSeparator.new()
	column.add_child(rule)

	var battle_view = MixedActionSquadBattleData.new()
	battle_view.name = "ResolutionScrumBattle"
	battle_view.setup(
		enemy_specs,
		player_specs,
		swing_count
	)

	battle_view.set_presentation_scale(1.85)
	battle_view.custom_minimum_size = Vector2(
		0.0,
		250.0
	)
	battle_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(battle_view)

	var footer := Label.new()
	footer.text = "MARCHERS COLLIDE"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override(
		"font_size",
		11
	)
	footer.add_theme_color_override(
		"font_color",
		Color(
			0.55,
			0.53,
			0.49,
			1.0
		)
	)
	column.add_child(footer)

	await battle_view.battle_finished

	await get_tree().create_timer(
		1.55
	).timeout

	if is_instance_valid(overlay):
		overlay.queue_free()
		await get_tree().process_frame

	visible = was_visible
	_scrum_overlay_active = false
