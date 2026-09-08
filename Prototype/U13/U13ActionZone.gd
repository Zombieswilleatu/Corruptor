# Extracted UI2 ActionZone controls; U13 binding replaces rules/forecast methods.
# UI2_SLAVER_THEME_V1_1
# CONSTRUCTION_PAYMENT_CAP_HARD_CEILING_V1
# UI2_ZERO_CARD_WARD_CLEAN_V4
# UI2_ZERO_CARD_WARD_KRONI_HUNGER_V3
# UI2_CARD_INTERACTION_STAGING_V2
class_name U13ActionZone
# UI2_SIEGE_SUMMARY_OPTION_COPY_FIX_V2
extends PanelContainer

# UI2_DOMINION_RITE_ENGINE_PRELOAD_HOTFIX_V1

const CASTLE_ORDER: Array[String] = [
	"Keep",
	"Bastion",
	"SummoningCircle",
	"Stockpile",
	"SiegeEngine",
]

signal action_selected(action_name)
signal target_changed(target_name)
signal confirm_requested
signal pass_requested
signal deploy_unstage_requested(queue_index)

var title_label: Label = null
var phase_label: Label = null
var phase_panel: Label = null
var payment_label: Label = null
var scope_label: Label = null
var action_box: VBoxContainer = null
var primary_label: Label = null
var primary_select: OptionButton = null
var market_offer_list_v2_4: ItemList = null
var market_trade_summary_v2_4: Label = null
var secondary_label: Label = null
var secondary_select: OptionButton = null
var option_toggle: CheckButton = null
var rite_help_label: Label = null
var aux_label: Label = null
var aux_list: ItemList = null
var deploy_staged_label: Label = null
var deploy_staged_list: ItemList = null
var forecast_label: Label = null
var status_label: Label = null
var confirm_button: Button = null
var pass_button: Button = null

var action_buttons: Dictionary = {}
var selected_action: String = ""
var selected_card_count: int = 0
var selected_hand_card_ids: Array[String] = []
var stage_key: String = ""
var staged_deploy_moves: Array = []

var player_ref = null
var opponent_ref = null
var rules_ref = null
var controller_ref = null
var dialog_mode: bool = false

var _forecast_cache: Dictionary = {}
var _forecast_cache_ready: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(300, 0)
	clip_contents = true

	var scroll := ScrollContainer.new()
	scroll.name = "ActionScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var outer := VBoxContainer.new()
	outer.name = "ActionContents"
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 7)
	scroll.add_child(outer)

	title_label = Label.new()
	title_label.text = "YOUR ACTION"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 17)
	outer.add_child(title_label)

	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(phase_label)

	phase_panel = Label.new()
	phase_panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phase_panel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_panel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_panel.custom_minimum_size = Vector2(0, 72)
	outer.add_child(phase_panel)

	payment_label = Label.new()
	payment_label.visible = false
	payment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	payment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	payment_label.add_theme_font_size_override("font_size", 14)
	outer.add_child(payment_label)

	scope_label = Label.new()
	scope_label.text = "FORECAST · WHOLE HAND"
	scope_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scope_label.tooltip_text = (
		"Forecast uses the entire current Hand; " + "card selection does not change reachability."
	)
	outer.add_child(scope_label)

	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 5)
	outer.add_child(action_box)

	_add_action("Siege", "Attack an enemy Castle.")
	_add_action("Ward", "Defend your Lord or Castle zone.")
	_add_action("Powers Only", "Skip combat and resolve queued Lord powers.")

	primary_label = Label.new()
	primary_label.visible = false
	outer.add_child(primary_label)

	primary_select = OptionButton.new()
	primary_select.visible = false
	primary_select.fit_to_longest_item = false
	primary_select.clip_text = true
	primary_select.item_selected.connect(_on_primary_selected)
	outer.add_child(primary_select)
	# UI2_SLAVER_VISIBLE_OFFERS_V2_4
	# The hidden OptionButton remains authoritative.
	market_offer_list_v2_4 = ItemList.new()
	market_offer_list_v2_4.name = "SlaverOfferListV2_4"
	market_offer_list_v2_4.visible = false
	market_offer_list_v2_4.select_mode = ItemList.SELECT_SINGLE
	market_offer_list_v2_4.custom_minimum_size = Vector2(0, 92)
	market_offer_list_v2_4.item_selected.connect(_on_market_offer_selected_v2_4)
	outer.add_child(market_offer_list_v2_4)

	market_trade_summary_v2_4 = Label.new()
	market_trade_summary_v2_4.name = "SlaverTradeSummaryV2_4"
	market_trade_summary_v2_4.visible = false
	market_trade_summary_v2_4.horizontal_alignment = (HORIZONTAL_ALIGNMENT_CENTER)
	market_trade_summary_v2_4.autowrap_mode = (TextServer.AUTOWRAP_WORD_SMART)
	market_trade_summary_v2_4.add_theme_font_size_override("font_size", 13)
	market_trade_summary_v2_4.custom_minimum_size.y = 30
	outer.add_child(market_trade_summary_v2_4)

	secondary_label = Label.new()
	secondary_label.visible = false
	outer.add_child(secondary_label)

	secondary_select = OptionButton.new()
	secondary_select.visible = false
	secondary_select.fit_to_longest_item = false
	secondary_select.clip_text = true
	secondary_select.item_selected.connect(_on_secondary_selected)
	outer.add_child(secondary_select)

	option_toggle = CheckButton.new()
	option_toggle.visible = false
	option_toggle.toggled.connect(_on_option_toggled)
	outer.add_child(option_toggle)

	# UI2_DOMINION_RITE_EXPLANATIONS_V1
	rite_help_label = Label.new()
	rite_help_label.name = "RiteHelp"
	rite_help_label.visible = false
	rite_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rite_help_label.add_theme_font_size_override("font_size", 13)
	rite_help_label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74, 1.0))
	outer.add_child(rite_help_label)

	aux_label = Label.new()
	aux_label.visible = false
	outer.add_child(aux_label)

	aux_list = ItemList.new()
	aux_list.visible = false
	aux_list.select_mode = ItemList.SELECT_MULTI
	aux_list.custom_minimum_size = Vector2(0, 108)
	aux_list.item_selected.connect(_on_aux_item_selected)
	aux_list.multi_selected.connect(_on_aux_multi_selected)
	outer.add_child(aux_list)

	deploy_staged_label = Label.new()
	deploy_staged_label.visible = false
	deploy_staged_label.text = "DEPLOY STAGING · click a card to return it"
	deploy_staged_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(deploy_staged_label)

	deploy_staged_list = ItemList.new()
	deploy_staged_list.visible = false
	deploy_staged_list.select_mode = ItemList.SELECT_SINGLE
	deploy_staged_list.custom_minimum_size = Vector2(0, 122)
	deploy_staged_list.item_selected.connect(_on_deploy_staged_selected)
	outer.add_child(deploy_staged_list)

	forecast_label = Label.new()
	forecast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	forecast_label.text = "Choose an order to show reachability bands."
	outer.add_child(forecast_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(status_label)

	# UI2_COMMITMENT_DIALOG_CLEANUP_V14_1
	var spacer := Control.new()
	spacer.name = "ActionSpacerV14"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(spacer)

	confirm_button = Button.new()
	confirm_button.text = "CONFIRM"
	confirm_button.pressed.connect(_on_confirm_pressed)
	outer.add_child(confirm_button)

	pass_button = Button.new()
	pass_button.text = "PASS"
	pass_button.visible = false
	pass_button.pressed.connect(_on_pass_pressed)
	outer.add_child(pass_button)


func _add_action(action_name: String, description: String) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 60)
	button.toggle_mode = true
	button.text = "%s\n%s" % [action_name.to_upper(), description]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.disabled = true
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(_on_action_pressed.bind(action_name))
	action_box.add_child(button)
	action_buttons[action_name] = button


func focus_direct_manipulation_end() -> void:
	# UI2_DIRECT_MANIPULATION_SYNC_V1
	# A board-first action should land the dialog on the useful end-state,
	# not force the player to replay the same choice through dropdowns/pages.
	call_deferred("_scroll_direct_manipulation_end")


func _scroll_direct_manipulation_end() -> void:
	var scroll := get_node_or_null("ActionScroll") as ScrollContainer
	if scroll == null:
		return

	# UI2_DECISION_ALIGNMENT_CLEANUP_V15
	# Fixed dialog actions make the old scroll-to-confirm behavior obsolete.
	if dialog_mode:
		return

	# Deliberately overshoot; ScrollContainer clamps to its legal maximum.
	# This keeps the live payment/status/confirm controls in view after the
	# PhasePrompt expands and its layout settles.
	scroll.scroll_vertical = 1000000


func set_dialog_mode(enabled: bool) -> void:
	dialog_mode = enabled
	custom_minimum_size = Vector2(0, 0) if enabled else Vector2(300, 0)
	if title_label != null:
		title_label.visible = not enabled
	if phase_panel != null:
		phase_panel.visible = not enabled

	# PhasePrompt owns the visible bottom action window in dialog mode.
	# Do not let ActionZone's legacy flex spacer consume dialog height.
	var spacer_v14 := get_node_or_null("ActionScroll/ActionContents/ActionSpacerV14") as Control
	if spacer_v14 != null:
		spacer_v14.visible = not enabled

	if enabled:
		call_deferred("_reset_dialog_scroll_top_v14")
	call_deferred("_refresh_confirm_state")


func _reset_dialog_scroll_top_v14() -> void:
	var scroll := get_node_or_null("ActionScroll") as ScrollContainer
	if scroll == null:
		return

	scroll.scroll_vertical = 0


# UI2_DECISION_CONFIRM_RELIABILITY_V17


func configure_u13() -> void:
	set_dialog_mode(true)
	for control in [scope_label, forecast_label, phase_label]:
		control.hide()
	pass_button.show()
	pass_button.text = "PASS ROUND"
	pass_button.tooltip_text = "Skip combat and cancel all queued Lord powers. No cards are spent."
	for button in action_buttons.values():
		button.disabled = false


func _on_action_pressed(action_name: String) -> void:
	selected_action = action_name
	for key in action_buttons:
		action_buttons[key].set_pressed_no_signal(key == selected_action)
	action_selected.emit(action_name)


func _on_primary_selected(_index: int) -> void:
	target_changed.emit("")


func _on_secondary_selected(_index: int) -> void:
	target_changed.emit("")


func _on_confirm_pressed() -> void:
	if not confirm_button.disabled:
		confirm_requested.emit()


func _on_pass_pressed() -> void:
	if not pass_button.disabled:
		pass_requested.emit()


func _refresh_confirm_state() -> void:
	# U13 owner preview supplies availability; no UI2 forecast or legality calls.
	pass


func _on_market_offer_selected_v2_4(_index: int) -> void:
	pass


func _on_option_toggled(_pressed: bool) -> void:
	pass


func _on_aux_item_selected(_index: int) -> void:
	pass


func _on_aux_multi_selected(_index: int, _selected: bool) -> void:
	pass


func _on_deploy_staged_selected(_index: int) -> void:
	pass
