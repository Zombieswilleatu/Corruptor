# CONSTRUCTION_PAYMENT_CAP_HARD_CEILING_V1
# UI2_ZERO_CARD_WARD_CLEAN_V4
# UI2_ZERO_CARD_WARD_KRONI_HUNGER_V3
# UI2_CARD_INTERACTION_STAGING_V2
class_name UI2ActionZone
# UI2_SIEGE_SUMMARY_OPTION_COPY_FIX_V2
extends PanelContainer


const CastleIntegrityRulesData = preload(
    "res://Scripts/Sim/CastleIntegrityRules.gd"
)
const RoundEngineData = preload(
    "res://Scripts/Sim/RoundEngine.gd"
)
const ActionForecastData = preload(
    "res://Scripts/Sim/ActionForecast.gd"
)
# UI2_DOMINION_RITE_ENGINE_PRELOAD_HOTFIX_V1
const DominionRiteEngineData = preload(
    "res://Scripts/Sim/DominionRiteEngine.gd"
)


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
        "Forecast uses the entire current Hand; "
        + "card selection does not change reachability."
    )
    outer.add_child(scope_label)

    action_box = VBoxContainer.new()
    action_box.add_theme_constant_override("separation", 5)
    outer.add_child(action_box)

    _add_action("Hunt", "Attack the enemy Lord.")
    _add_action("Siege", "Attack an enemy Castle.")
    _add_action("Ward", "Defend your Lord or Castle zone.")
    _add_action("Profane", "Sacrifice a full-Integrity Castle.")

    primary_label = Label.new()
    primary_label.visible = false
    outer.add_child(primary_label)

    primary_select = OptionButton.new()
    primary_select.visible = false
    primary_select.fit_to_longest_item = false
    primary_select.clip_text = true
    primary_select.item_selected.connect(_on_primary_selected)
    outer.add_child(primary_select)

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
    rite_help_label.add_theme_color_override(
        "font_color",
        Color(0.88, 0.84, 0.74, 1.0)
    )
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

    var spacer := Control.new()
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


func focus_direct_manipulation_end() -> void:
    # UI2_DIRECT_MANIPULATION_SYNC_V1
    # A board-first action should land the dialog on the useful end-state,
    # not force the player to replay the same choice through dropdowns/pages.
    call_deferred("_scroll_direct_manipulation_end")


func _scroll_direct_manipulation_end() -> void:
    var scroll := get_node_or_null("ActionScroll") as ScrollContainer
    if scroll == null:
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


func focus_castle_action_mode(action_name: String) -> void:
    if stage_key != "REPAIR" or action_name not in ["repair", "construct"]:
        return

    for index: int in range(primary_select.item_count):
        if String(primary_select.get_item_metadata(index)) != action_name:
            continue
        primary_select.select(index)
        _refresh_castle_action_targets()
        primary_label.visible = false
        primary_select.visible = false
        pass_button.text = "CONTINUE DEVELOPMENT"
        return


func bind_state(
    player,
    opponent,
    rules,
    controller,
    stage_text: String
) -> void:
    if player == null:
        return

    var next_stage: String = stage_text.replace(" ", "_").to_upper()
    var stage_changed: bool = next_stage != stage_key

    player_ref = player
    opponent_ref = opponent
    rules_ref = rules
    controller_ref = controller
    stage_key = next_stage


    if stage_changed:
        _invalidate_forecast_cache()
        if stage_key == "COMMITMENT":
            _build_forecast_cache()
    if stage_changed:
        selected_action = ""
        selected_card_count = 0
        selected_hand_card_ids.clear()
        status_label.text = ""
        _clear_action_toggles()

    title_label.text = _friendly_phase_name(stage_key)
    phase_label.text = ""
    phase_panel.text = _phase_copy(stage_key)
    title_label.visible = not dialog_mode
    phase_panel.visible = not dialog_mode

    _reset_stage_controls()
    _configure_stage()
    _refresh_action_copy()
    _refresh_rite_help()
    _refresh_payment_feedback()
    _refresh_forecast()
    _refresh_confirm_state()


func set_deploy_staged_moves(moves: Array) -> void:
    staged_deploy_moves.clear()
    for move in moves:
        if typeof(move) == TYPE_DICTIONARY:
            staged_deploy_moves.append(move.duplicate(true))

    if stage_key == "DEPLOY":
        _refresh_deploy_garrison_choices()
        _refresh_confirm_state()


func set_castle_action_target(
    action_name: String,
    castle_name: String
) -> void:
    if (
        stage_key != "REPAIR"
        or action_name not in ["repair", "construct"]
        or primary_select == null
        or secondary_select == null
    ):
        return

    var found_action: bool = false
    for index: int in range(primary_select.item_count):
        if String(primary_select.get_item_metadata(index)) != action_name:
            continue
        primary_select.select(index)
        _refresh_castle_action_targets()
        found_action = true
        break

    if not found_action:
        return

    for index: int in range(secondary_select.item_count):
        if String(secondary_select.get_item_metadata(index)) != castle_name:
            continue
        secondary_select.select(index)
        _on_secondary_selected(index)
        return


func set_deploy_target(
    target_zone: String
) -> void:
    if (
        stage_key != "DEPLOY"
        or primary_select == null
        or target_zone not in [
            "Lord",
            "Castle",
        ]
    ):
        return

    for index: int in range(
        primary_select.item_count
    ):
        if String(
            primary_select.get_item_metadata(
                index
            )
        ) != target_zone:
            continue

        primary_select.select(
            index
        )
        _on_primary_selected(
            index
        )
        return


func set_selected_card_count(count: int) -> void:
    selected_card_count = maxi(count, 0)
    _refresh_confirm_state()


func set_selected_hand_cards(
    card_ids
) -> void:
    selected_hand_card_ids.clear()

    for raw_id in card_ids:
        selected_hand_card_ids.append(
            String(raw_id)
        )

    selected_card_count = selected_hand_card_ids.size()
    _refresh_rite_help()
    _refresh_payment_feedback()
    _refresh_confirm_state()


func set_commitment_action_target(
    action_name: String,
    target_name: String
) -> void:
    if (
        stage_key != "COMMITMENT"
        or action_name not in [
            "Hunt",
            "Siege",
            "Ward",
            "Profane",
        ]
    ):
        return

    _on_action_pressed(
        action_name
    )

    if primary_select == null:
        return

    for index: int in range(
        primary_select.item_count
    ):
        if String(
            primary_select.get_item_metadata(
                index
            )
        ) != target_name:
            continue

        primary_select.select(
            index
        )
        _on_primary_selected(
            index
        )
        return

func get_selected_action() -> String:
    return selected_action


func get_selected_target() -> String:
    if stage_key == "COMMITMENT" and selected_action == "Hunt":
        return "Lord"
    return get_primary_value()


func get_primary_value() -> String:
    return _selected_metadata(primary_select)


func get_secondary_value() -> String:
    return _selected_metadata(secondary_select)


func get_option_enabled() -> bool:
    return option_toggle != null and option_toggle.visible and option_toggle.button_pressed


func get_aux_selected_values() -> Array[String]:
    var result: Array[String] = []
    if aux_list == null:
        return result
    for index in aux_list.get_selected_items():
        result.append(String(aux_list.get_item_metadata(index)))
    return result


func clear_aux_selection() -> void:
    if aux_list != null:
        aux_list.deselect_all()
    _refresh_confirm_state()


func set_status(text: String) -> void:
    status_label.text = text


func _clear_action_toggles() -> void:
    for action_name in action_buttons.keys():
        var button: Button = action_buttons.get(
            action_name,
            null
        )
        if button != null:
            button.set_pressed_no_signal(
                false
            )


func _reset_stage_controls() -> void:
    payment_label.visible = false
    payment_label.text = ""
    scope_label.visible = false
    action_box.visible = false
    primary_label.visible = false
    primary_select.visible = false
    primary_select.clear()
    secondary_label.visible = false
    secondary_select.visible = false
    secondary_select.clear()
    option_toggle.visible = false
    option_toggle.button_pressed = false
    rite_help_label.visible = false
    rite_help_label.text = ""
    aux_label.visible = false
    aux_list.visible = false
    aux_list.clear()
    deploy_staged_label.visible = false
    deploy_staged_list.visible = false
    deploy_staged_list.clear()
    forecast_label.visible = false
    confirm_button.visible = false
    confirm_button.disabled = false
    pass_button.visible = false
    pass_button.disabled = false

    for action_name in action_buttons.keys():
        var button: Button = action_buttons[action_name]
        button.disabled = true
        button.modulate.a = 0.48


func _configure_stage() -> void:
    match stage_key:
        "NO_GAME":
            title_label.text = "ROUND COMPLETE"
            confirm_button.visible = true
            confirm_button.text = "NEXT ROUND"

        "DEVELOPMENT_SNARE":
            confirm_button.visible = true
            confirm_button.text = "ACTIVATE SNARE"
            pass_button.visible = true
            pass_button.text = "PASS SNARE"

        "MARKET":
            phase_label.text = "Select one Hand card to give."
            _show_primary("Trade for:")
            if controller_ref != null and controller_ref.game != null:
                for card in controller_ref.game.market:
                    _add_option(primary_select, _card_id(card), _card_id(card))
            confirm_button.visible = true
            confirm_button.text = "TRADE"
            pass_button.visible = true
            pass_button.text = "PASS MARKET"

        "REPAIR":
            phase_label.text = "Repair and Construction are separate choices. Hand + Garrison may pay."
            payment_label.visible = true
            _show_primary("Castle action:")
            _populate_castle_action_modes()
            _show_secondary("Castle:")
            _refresh_castle_action_targets()
            _populate_garrison_aux("Garrison payment:")
            confirm_button.visible = true
            pass_button.visible = true
            pass_button.text = "PASS CASTLE ACTION"

        "DOMINION_RITES":
            phase_label.text = "Choose a Rite. Selecting it explains exactly what it does and what it costs."
            _show_primary("Defile the Ruins:")
            _add_option(primary_select, "Do not Defile a Ruin", "")
            for castle_name in player_ref.ruined_castles:
                _add_option(primary_select, String(castle_name), String(castle_name))
            option_toggle.visible = true
            option_toggle.text = "Perform Cataclysmic Invocation"
            rite_help_label.visible = true
            confirm_button.visible = true
            confirm_button.text = "PERFORM SELECTED RITES"
            pass_button.visible = true
            pass_button.text = "CONTINUE WITHOUT RITES"

        "DEPLOY":
            phase_label.text = "Click a Hand card to use the selected destination, or drag it directly onto Lord / Castle Guards. STAGED Guards remain reversible."
            _show_primary("Guard destination:")
            _add_option(primary_select, "Lord Guards", "Lord")
            _add_option(primary_select, "Castle Guards", "Castle")
            _populate_garrison_aux("Garrison cards · select then stage:")
            confirm_button.visible = true
            confirm_button.text = "STAGE GARRISON"
            pass_button.visible = true
            pass_button.text = "FINISH DEPLOY"

        "MARCH":
            phase_label.text = "Drag a Guard from its zone directly into a lane, or use the controls below."
            _show_primary("Guard zone:")
            _add_option(primary_select, "Lord Guards", "Lord")
            _add_option(primary_select, "Castle Guards", "Castle")
            _show_secondary("March lane:")
            var reactive_lane: String = ""
            if controller_ref != null:
                reactive_lane = controller_ref.human_reactive_march_lane()
            if reactive_lane.is_empty():
                _add_option(secondary_select, "Lord lane", "Lord")
                _add_option(secondary_select, "Castle lane", "Castle")
            else:
                _add_option(secondary_select, "%s lane · Reactive" % reactive_lane, reactive_lane)
            _populate_march_guards()
            confirm_button.visible = true
            confirm_button.text = "LAUNCH GUARD"
            pass_button.visible = true
            pass_button.text = "PASS MARCH"

        "SUMMON":
            phase_label.text = "Select Hand cards to pay. Cost %d." % (
                controller_ref.human_summon_cost() if controller_ref != null else 0
            )
            confirm_button.visible = true
            confirm_button.text = "RESUMMON"
            pass_button.visible = true
            pass_button.text = "STAY BANISHED"

        "REFLEX_BID":
            phase_label.text = "Select any Hand cards to bid."
            confirm_button.visible = true
            confirm_button.text = "SUBMIT BID"
            pass_button.visible = true
            pass_button.text = "BID ZERO"

        "COMMITMENT":
            title_label.text = "YOUR ACTION"
            phase_label.text = "%d cards available" % player_ref.hand.size()
            scope_label.visible = true
            forecast_label.visible = true
            _enable_action_mode(true)
            confirm_button.visible = true
            confirm_button.text = "SEAL ORDER"
            if not selected_action.is_empty():
                _refresh_action_targets()

        "SEALED":
            confirm_button.visible = true
            confirm_button.text = "REVEAL ORDERS"

        "KANIFOUS_INVOKE":
            phase_label.text = (
                "1. Choose the revealed Invocation below.\n"
                + "2. Click exactly one Hand card to discard as its toll.\n"
                + "3. Press INVOKE."
            )
            _show_primary("Invoke revealed card:")
            if controller_ref != null:
                for card_id in controller_ref.kanifous_preview_cards:
                    _add_option(primary_select, String(card_id), String(card_id))
            confirm_button.visible = true
            confirm_button.text = "INVOKE"

        "KANIFOUS_WRIGHT":
            _populate_wright_guards()
            confirm_button.visible = true
            confirm_button.text = "MOVE SELECTED GUARDS"
            pass_button.visible = true
            pass_button.text = "MOVE NONE"

        "VULTURE_RECON":
            _show_primary("Scout enemy Guards:")
            _populate_recon_targets()
            confirm_button.visible = true
            confirm_button.text = "RECON"

        "REVEALED":
            confirm_button.visible = true
            confirm_button.text = "RESOLVE ROUND"

        "RESOLUTION_HUMBABA_TOLL":
            _show_primary("Ruin your Castle:")
            for castle_name in player_ref.castles:
                _add_option(primary_select, String(castle_name), String(castle_name))
            confirm_button.visible = true
            confirm_button.text = "PAY TOLL"
            pass_button.visible = true
            pass_button.text = "PASS TOLL"

        "RESOLUTION_ACTION":
            _show_primary("Modifier:")
            _populate_resolution_action_options()
            confirm_button.visible = true
            confirm_button.text = (
                "RESOLVE %s"
                % String(player_ref.action).to_upper()
            )

        "RESOLUTION_VESSEL":
            title_label.text = "THE VESSEL"
            phase_label.text = "ONCE PER MATCH · AFTER YOUR ACTION"
            phase_panel.text = (
                "The Veil does not open for the dead. It opens for what is "
                + "willingly surrendered. You may offer your living Lord as "
                + "the Vessel — abandoning the ruler of your domain for one "
                + "final pull upon the abyss.\n\n"
                + "Offering the Vessel immediately grants you 1 Tear, while "
                + "your opponent gains 1 Soul. Every Lord Guard is destroyed "
                + "and your Lord leaves play as OFFERED AS VESSEL rather than "
                + "entering the Breach. If that Lord is summoned again later, "
                + "it returns at Threat 2. Because the Tear is gained at once, "
                + "this sacrifice can complete Dominion immediately."
            )
            _show_primary("Choose your fate:")
            _add_option(primary_select, "KEEP LORD · no effect", "pass")
            _add_option(
                primary_select,
                "OFFER LORD · +1 Tear · opponent +1 Soul",
                "offer"
            )
            confirm_button.visible = true
            confirm_button.text = "CONFIRM VESSEL CHOICE"

        "RESOLUTION_REFLEX":
            title_label.text = "MOMENTUM ACTION"
            phase_label.text = "Choose Hunt, Siege, or Ward; Hand cards are the commitment."
            _enable_action_mode(false)
            confirm_button.visible = true
            confirm_button.text = "RESOLVE MOMENTUM"
            pass_button.visible = true
            pass_button.text = "PASS MOMENTUM"
            if not selected_action.is_empty():
                _refresh_action_targets()

        "RESOLUTION_ODRADEK_BREACH":
            title_label.text = "ODRADEK BREACH"
            phase_label.text = "Predict the opponent, then choose the stolen action."
            _show_primary("Predict:")
            _add_option(primary_select, "Hunt", "Hunt")
            _add_option(primary_select, "Siege", "Siege")
            _add_option(primary_select, "Ward", "Ward")
            _add_option(primary_select, "Pass", "Pass")
            _enable_action_mode(false)
            confirm_button.visible = true
            confirm_button.text = "INTERFERE"
            pass_button.visible = true
            pass_button.text = "DO NOT INTERFERE"
            if not selected_action.is_empty():
                _refresh_action_targets()

        "RESOLUTION_GREMORY":
            phase_label.text = "Pay exactly two Hand/Garrison cards, or pass."
            _populate_garrison_aux("Garrison payment:")
            confirm_button.visible = true
            confirm_button.text = "INEVITABLE RUIN"
            pass_button.visible = true
            pass_button.text = "PASS"

        "TERMINAL":
            title_label.text = "MATCH COMPLETE"
            if controller_ref != null and controller_ref.game != null:
                phase_panel.text = "Winner %s · %s" % [
                    str(controller_ref.game.winner),
                    String(controller_ref.game.win_by),
                ]

        "INVALID":
            title_label.text = "MATCH HALTED"

        _:
            pass_button.visible = false


func _enable_action_mode(include_profane: bool) -> void:
    action_box.visible = true
    for action_name in action_buttons.keys():
        var button: Button = action_buttons[action_name]
        var enabled: bool = _action_is_legal(String(action_name), include_profane)
        button.disabled = not enabled
        button.modulate.a = 1.0 if enabled else 0.42
    if not include_profane:
        var profane: Button = action_buttons.get("Profane", null)
        if profane != null:
            profane.disabled = true
            profane.modulate.a = 0.28


func _action_is_legal(action_name: String, include_profane: bool) -> bool:
    if player_ref == null or opponent_ref == null:
        return false
    match action_name:
        "Hunt":
            if stage_key == "RESOLUTION_REFLEX":
                return player_ref.alive and opponent_ref.alive and player_ref.threat < rules_ref.max_threat
            return player_ref.alive and opponent_ref.alive
        "Siege":
            return not opponent_ref.castles.is_empty() and (
                player_ref.alive or stage_key != "COMMITMENT"
            )
        "Ward":
            return true
        "Profane":
            return include_profane and player_ref.alive and _has_profanable_castle()
    return false


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


func _on_action_pressed(action_name: String) -> void:
    selected_action = action_name
    for candidate in action_buttons.keys():
        var button: Button = action_buttons[candidate]
        button.set_pressed_no_signal(String(candidate) == action_name)
    _refresh_action_targets()
    _refresh_action_copy()
    _refresh_forecast()
    status_label.text = ""
    _refresh_confirm_state()
    action_selected.emit(action_name)


func _on_primary_selected(_index: int) -> void:
    if stage_key == "MARCH":
        _populate_march_guards()
    elif stage_key == "REPAIR":
        _refresh_castle_action_targets()
    _refresh_rite_help()
    _refresh_payment_feedback()
    _refresh_forecast()
    _refresh_confirm_state()
    target_changed.emit(
        get_primary_value()
    )


func _on_secondary_selected(_index: int) -> void:
    _refresh_confirm_state()

    if stage_key == "REPAIR":
        target_changed.emit(
            get_secondary_value()
        )


func _on_option_toggled(_pressed: bool) -> void:
    _refresh_rite_help()
    _refresh_payment_feedback()
    _refresh_confirm_state()


func _on_aux_item_selected(_index: int) -> void:
    _refresh_payment_feedback()
    _refresh_confirm_state()


func _on_aux_multi_selected(
    _index: int,
    _selected: bool
) -> void:
    _refresh_payment_feedback()
    _refresh_confirm_state()


func _on_confirm_pressed() -> void:
    if confirm_button.disabled:
        return
    confirm_requested.emit()


func _on_pass_pressed() -> void:
    pass_requested.emit()


func _refresh_action_targets() -> void:
    if stage_key == "RESOLUTION_ODRADEK_BREACH":
        secondary_label.visible = true
        secondary_label.text = "Stolen target:"
        secondary_select.visible = true
        secondary_select.clear()
        _populate_reflex_targets(secondary_select)
        return

    _show_primary("Target:")
    primary_select.clear()

    if stage_key == "COMMITMENT":
        match selected_action:
            "Hunt":
                primary_label.text = "Target:"
                _add_option(primary_select, "Opponent Lord", "Lord")
                primary_select.disabled = true
            "Siege":
                primary_label.text = "Castle:"
                for castle_name in opponent_ref.castles:
                    _add_option(primary_select, String(castle_name), String(castle_name))
            "Ward":
                primary_label.text = "Zone:"
                if player_ref.alive and (
                    not rules_ref.ward_anti_repeat or player_ref.prev_ward_target != "Lord"
                ):
                    _add_option(primary_select, "Lord", "Lord")
                if not rules_ref.ward_anti_repeat or player_ref.prev_ward_target != "Castle":
                    _add_option(primary_select, "Castle", "Castle")
                if not player_ref.alive:
                    primary_select.clear()
                    _add_option(primary_select, "Castle", "Castle")
            "Profane":
                primary_label.text = "Sacrifice:"
                for castle_name in player_ref.castles:
                    if _castle_profane_eligible(String(castle_name)):
                        _add_option(primary_select, String(castle_name), String(castle_name))
        primary_select.disabled = primary_select.item_count <= 1
        return

    if stage_key == "RESOLUTION_REFLEX":
        _populate_reflex_targets(primary_select)


func _populate_reflex_targets(control: OptionButton) -> void:
    control.clear()
    match selected_action:
        "Hunt":
            _add_option(control, "Opponent Lord · Fracture Subjects", "Lord|0|subjects")
            _add_option(control, "Opponent Lord · Fracture Infrastructure", "Lord|0|infrastructure")
            _add_option(control, "Opponent Lord · Consume · Fracture Subjects", "Lord|1|subjects")
            _add_option(control, "Opponent Lord · Consume · Fracture Infrastructure", "Lord|1|infrastructure")
        "Siege":
            var allow_consume: bool = bool(rules_ref.consume_the_siege)
            var allow_inferno: bool = player_ref.alive and String(player_ref.lord) == "Kalligan"
            for castle_name in opponent_ref.castles:
                _add_option(control, "%s · normal" % castle_name, "%s|0|0" % castle_name)
                if allow_consume:
                    _add_option(control, "%s · Consume" % castle_name, "%s|1|0" % castle_name)
                if allow_inferno:
                    _add_option(control, "%s · Inferno" % castle_name, "%s|0|1" % castle_name)
                if allow_consume and allow_inferno:
                    _add_option(control, "%s · Consume + Inferno" % castle_name, "%s|1|1" % castle_name)
        "Ward":
            _add_option(control, "Lord", "Lord")
            _add_option(control, "Castle", "Castle")
    control.disabled = control.item_count <= 1


func _populate_castle_action_modes() -> void:
    primary_select.clear()

    var has_repair: bool = false
    var has_construct: bool = false

    for castle_name in CASTLE_ORDER:
        var maximum: int = CastleIntegrityRulesData.max_integrity(castle_name)
        if player_ref.castles.has(castle_name):
            var current: int = int(
                player_ref.castle_integrity.get(castle_name, maximum)
            )
            if current > 0 and current < maximum:
                has_repair = true
        elif _castle_type_is_buildable(castle_name):
            has_construct = true

    if has_repair:
        _add_option(
            primary_select,
            "REPAIR · damaged Castle",
            "repair"
        )
    if has_construct:
        _add_option(
            primary_select,
            "CONSTRUCT · new Castle",
            "construct"
        )

    primary_select.disabled = primary_select.item_count <= 1


func _refresh_castle_action_targets() -> void:
    if stage_key != "REPAIR":
        return

    secondary_select.clear()
    secondary_select.visible = true
    secondary_label.visible = true
    secondary_label.text = "Castle:"

    var action_name: String = get_primary_value()

    for castle_name in CASTLE_ORDER:
        var maximum: int = CastleIntegrityRulesData.max_integrity(castle_name)

        if action_name == "repair" and player_ref.castles.has(castle_name):
            var current: int = int(
                player_ref.castle_integrity.get(castle_name, maximum)
            )
            if current > 0 and current < maximum:
                _add_option(
                    secondary_select,
                    "%s · %d/%d Integrity" % [
                        castle_name,
                        current,
                        maximum,
                    ],
                    castle_name
                )

        elif action_name == "construct" and _castle_type_is_buildable(castle_name):
            var progress: int = int(
                player_ref.castle_construction_progress.get(castle_name, 0)
            )
            _add_option(
                secondary_select,
                "%s · %d/%d progress" % [
                    castle_name,
                    progress,
                    maximum,
                ],
                castle_name
            )

    secondary_select.disabled = secondary_select.item_count <= 1

    var repairing: bool = action_name == "repair"
    option_toggle.visible = repairing
    option_toggle.text = "Use Repair token"
    option_toggle.disabled = (
        not repairing
        or int(player_ref.repair_token) <= 0
    )
    if not repairing:
        option_toggle.set_pressed_no_signal(false)

    if action_name.is_empty():
        confirm_button.text = "NO CASTLE ACTION"
    else:
        confirm_button.text = (
            "RESOLVE REPAIR"
            if repairing
            else "ADD CONSTRUCTION"
        )

    _refresh_payment_feedback()
    _refresh_confirm_state()


func _populate_garrison_aux(label_text: String) -> void:
    aux_label.visible = true
    aux_label.text = label_text
    aux_list.visible = true
    aux_list.clear()
    aux_list.select_mode = ItemList.SELECT_MULTI

    var staged_counts: Dictionary = {}
    if stage_key == "DEPLOY":
        for move in staged_deploy_moves:
            if String(move.get("source", "")) != "Garrison":
                continue
            var staged_id: String = String(move.get("card", ""))
            staged_counts[staged_id] = int(staged_counts.get(staged_id, 0)) + 1

    for card in player_ref.garrison:
        var card_id: String = _card_id(card)
        var staged_remaining: int = int(staged_counts.get(card_id, 0))
        if staged_remaining > 0:
            staged_counts[card_id] = staged_remaining - 1
            continue

        var index: int = aux_list.item_count
        aux_list.add_item("%s · %d" % [card_id, int(card.value)])
        aux_list.set_item_metadata(index, "Garrison|%s" % card_id)


func _refresh_deploy_garrison_choices() -> void:
    if stage_key != "DEPLOY" or player_ref == null:
        return
    _populate_garrison_aux("Garrison cards · select then stage:")


func _refresh_deploy_staged_list() -> void:
    if deploy_staged_label != null:
        deploy_staged_label.visible = false

    if deploy_staged_list != null:
        deploy_staged_list.visible = false
        deploy_staged_list.clear()


func _on_deploy_staged_selected(index: int) -> void:
    if stage_key != "DEPLOY":
        return
    if index < 0 or index >= deploy_staged_list.item_count:
        return
    if deploy_staged_list.is_item_disabled(index):
        return

    var queue_index: int = int(deploy_staged_list.get_item_metadata(index))
    deploy_unstage_requested.emit(queue_index)


func _populate_march_guards() -> void:
    aux_label.visible = true
    aux_label.text = "Guard to launch:"
    aux_list.visible = true
    aux_list.clear()
    aux_list.select_mode = ItemList.SELECT_SINGLE
    var source_zone: String = get_primary_value()
    var guards: Array = player_ref.lord_guards if source_zone == "Lord" else player_ref.castle_guards
    for guard in guards:
        var card_id: String = _card_id(guard)
        var index: int = aux_list.item_count
        aux_list.add_item("%s · %d" % [card_id, int(guard.value)])
        aux_list.set_item_metadata(index, card_id)


func _populate_wright_guards() -> void:
    aux_label.visible = true
    aux_label.text = "Lord Guards · select up to two:"
    aux_list.visible = true
    aux_list.select_mode = ItemList.SELECT_MULTI
    aux_list.clear()
    for guard_index in range(player_ref.lord_guards.size()):
        var index: int = aux_list.item_count
        aux_list.add_item("Lord Guard %d" % (guard_index + 1))
        aux_list.set_item_metadata(index, str(guard_index))


func _populate_recon_targets() -> void:
    if controller_ref == null or opponent_ref == null:
        return
    var lord_unknown: int = 0
    var castle_unknown: int = 0
    for card in opponent_ref.lord_guards:
        if not controller_ref.is_guard_revealed(card):
            lord_unknown += 1
    for card in opponent_ref.castle_guards:
        if not controller_ref.is_guard_revealed(card):
            castle_unknown += 1
    if lord_unknown > 0:
        _add_option(primary_select, "Lord Guards · %d unknown" % lord_unknown, "Lord")
    if castle_unknown > 0:
        _add_option(primary_select, "Castle Guards · %d unknown" % castle_unknown, "Castle")
    primary_select.disabled = primary_select.item_count <= 1


func _populate_resolution_action_options() -> void:
    var action_name: String = String(player_ref.action)
    match action_name:
        "Hunt":
            _add_option(primary_select, "No Consume · Fracture Subjects", "hunt:0:subjects")
            _add_option(primary_select, "No Consume · Fracture Infrastructure", "hunt:0:infrastructure")
            _add_option(primary_select, "Consume · Fracture Subjects", "hunt:1:subjects")
            _add_option(primary_select, "Consume · Fracture Infrastructure", "hunt:1:infrastructure")
        "Siege":
            var allow_consume: bool = bool(rules_ref.consume_the_siege)
            var allow_inferno: bool = player_ref.alive and String(player_ref.lord) == "Kalligan"
            _add_option(primary_select, "No modifier", "siege:0:0")
            if allow_consume:
                _add_option(primary_select, "Consume", "siege:1:0")
            if allow_inferno:
                _add_option(primary_select, "Inferno", "siege:0:1")
            if allow_consume and allow_inferno:
                _add_option(primary_select, "Consume + Inferno", "siege:1:1")
        _:
            _add_option(primary_select, "Resolve sealed action", "default")
    primary_select.disabled = primary_select.item_count <= 1
    if primary_select.item_count <= 1:
        primary_label.visible = false
        primary_select.visible = false


func _show_primary(label_text: String) -> void:
    primary_label.visible = true
    primary_label.text = label_text
    primary_select.visible = true
    primary_select.disabled = false


func _show_secondary(label_text: String) -> void:
    secondary_label.visible = true
    secondary_label.text = label_text
    secondary_select.visible = true
    secondary_select.disabled = false


func _add_option(control: OptionButton, label: String, value: String) -> void:
    var index: int = control.item_count
    control.add_item(label)
    control.set_item_metadata(index, value)


func _selected_metadata(control: OptionButton) -> String:
    # UI2_CENTERED_PAYMENT_STAGING_FIX_V1
    # Dialog mode intentionally hides controls whose choice was already made by the
    # phase prompt. Hidden is presentation state, not "no semantic selection".
    if control == null or control.item_count <= 0 or control.selected < 0:
        return ""
    return String(control.get_item_metadata(control.selected))


func _invalidate_forecast_cache() -> void:
    _forecast_cache.clear()
    _forecast_cache_ready = false


func _build_forecast_cache() -> void:
    if (
        stage_key != "COMMITMENT"
        or controller_ref == null
        or controller_ref.game == null
        or rules_ref == null
        or player_ref == null
    ):
        return

    _forecast_cache = ActionForecastData.forecast_all(
        controller_ref.game,
        rules_ref,
        int(player_ref.pid)
    )
    _forecast_cache_ready = true


func _refresh_forecast() -> void:
    if forecast_label == null:
        return

    if (
        stage_key != "COMMITMENT"
        or controller_ref == null
        or controller_ref.game == null
        or rules_ref == null
        or player_ref == null
    ):
        return

    if selected_action.is_empty():
        forecast_label.text = "Choose an order to show reachability bands."
        return

    if selected_action == "Ward":
        forecast_label.text = (
            "WARD · defensive order\n"
            + "Offensive reachability bands apply to Hunt and Siege."
        )
        return

    if selected_action == "Profane":
        forecast_label.text = (
            "PROFANE · deterministic board eligibility\n"
            + "No hidden-combat reachability roll."
        )
        return

    if not _forecast_cache_ready:
        forecast_label.text = "FORECAST · cache unavailable"
        return

    var report: Dictionary = {}

    if selected_action == "Hunt":
        report = _forecast_cache.get("hunt", {})
    elif selected_action == "Siege":
        var castle_name: String = get_primary_value()
        if castle_name.is_empty():
            forecast_label.text = "SIEGE · choose a Castle to forecast."
            return
        var siege_targets: Dictionary = _forecast_cache.get(
            "siege_targets",
            {}
        )
        report = siege_targets.get(castle_name, {})
    else:
        forecast_label.text = "No forecast available."
        return

    if not bool(report.get("available", false)):
        forecast_label.text = (
            "%s · forecast unavailable\n%s"
            % [
                selected_action.to_upper(),
                String(report.get("reason", "unknown")).replace("_", " "),
            ]
        )
        return

    var lines: Array[String] = []

    if selected_action == "Hunt":
        lines.append(
            _forecast_objective_line(
                "PRESSURE",
                report.get("pressure", {})
            )
        )
        lines.append(
            _forecast_objective_line(
                "BANISH",
                report.get("banish", {})
            )
        )
    else:
        lines.append(
            _forecast_objective_line(
                "DAMAGE",
                report.get("damage", {})
            )
        )
        lines.append(
            _forecast_objective_line(
                "RUIN",
                report.get("ruin", {})
            )
        )

    lines.append("◇ = no Ward · ◈ = Ward / Sigil")
    lines.append(
        "%d hidden Guard%s · opponent Hand %d"
        % [
            int(report.get("hidden_guard_count", 0)),
            "" if int(report.get("hidden_guard_count", 0)) == 1 else "s",
            int(report.get("opponent_hand_count", 0)),
        ]
    )

    forecast_label.text = "\n".join(lines)


func _forecast_objective_line(
    label_text: String,
    objective_value
) -> String:
    if typeof(objective_value) != TYPE_DICTIONARY:
        return "%s · —" % label_text

    var objective: Dictionary = objective_value
    var open_value = objective.get("open", {})
    var open_band: String = "IMPOSSIBLE"

    if typeof(open_value) == TYPE_DICTIONARY:
        open_band = String(
            open_value.get(
                "band",
                "IMPOSSIBLE"
            )
        )

    var ward_range = objective.get(
        "warded_range",
        {}
    )

    if (
        typeof(ward_range) != TYPE_DICTIONARY
        or not bool(ward_range.get("available", false))
    ):
        return "%s\n◇ %s   ·   ◈ —" % [
            label_text,
            open_band,
        ]

    var min_band: String = String(
        ward_range.get(
            "min_band",
            open_band
        )
    )
    var max_band: String = String(
        ward_range.get(
            "max_band",
            open_band
        )
    )
    var ward_text: String = (
        min_band
        if min_band == max_band
        else "%s → %s" % [
            min_band,
            max_band,
        ]
    )

    return "%s\n◇ %s   ·   ◈ %s" % [
        label_text,
        open_band,
        ward_text,
    ]


func _refresh_rite_help() -> void:
    # UI2_PROFANE_SOUL_LIVE_BRANCH_SYNC_V1
    if rite_help_label == null:
        return

    if stage_key != "DOMINION_RITES":
        rite_help_label.visible = false
        rite_help_label.text = ""
        return

    rite_help_label.visible = true

    if player_ref == null or rules_ref == null:
        rite_help_label.text = "Rite details unavailable."
        return

    var invocation_cost: int = int(
        DominionRiteEngineData.INVOCATION_PAYMENT_THRESHOLD
    )
    var invocation_gate: int = int(rules_ref.invocation_gate)
    var veil: int = 0

    if controller_ref != null and controller_ref.game != null:
        veil = int(
            controller_ref.game.calculate_veil_total()
        )

    var invocation_selected: bool = (
        option_toggle != null
        and option_toggle.button_pressed
    )

    var profane_castle: String = get_primary_value()
    var ruined_count: int = int(
        player_ref.ruined_castles.size()
    )
    var ruined_required: int = int(
        rules_ref.profane_ruins_req
    )
    var profane_soul_cost: int = maxi(
        0,
        int(rules_ref.profane_ruins_cost)
    )
    var souls_available: int = int(
        player_ref.souls
    )

    var invocation_state: String = "AVAILABLE"

    if (
        not bool(rules_ref.invocation_repeatable)
        and bool(player_ref.cataclysmic_used)
    ):
        invocation_state = "USED"
    elif veil < invocation_gate:
        invocation_state = "LOCKED · VEIL %d/%d" % [
            veil,
            invocation_gate,
        ]

    var profane_state: String = "AVAILABLE"

    if bool(player_ref.profane_ruins_used_this_round):
        profane_state = "USED THIS ROUND"
    elif ruined_count < ruined_required:
        profane_state = "LOCKED · RUINS %d/%d" % [
            ruined_count,
            ruined_required,
        ]
    elif souls_available < profane_soul_cost:
        profane_state = "LOCKED · SOULS %d/%d" % [
            souls_available,
            profane_soul_cost,
        ]

    var selected_total: int = 0

    for card in _selected_payment_cards():
        selected_total += int(card.value)

    var invocation_selection_copy: String = (
        "Toggle it above to select this Rite."
    )

    if invocation_selected:
        invocation_selection_copy = (
            "SELECTED · Hand payment %d/%d."
            % [
                selected_total,
                invocation_cost,
            ]
        )

    var profane_selection_copy: String = (
        "Choose a Ruined Castle above to select this Rite."
    )

    if not profane_castle.is_empty():
        profane_selection_copy = (
            "SELECTED · %s will be Profaned."
            % profane_castle
        )

    var lines: Array[String] = []

    lines.append(
        (
            "CATACLYSMIC INVOCATION · %s\n"
            + "At Veil %d+, pay at least %d total Hand value to gain 1 Tear. %s"
        ) % [
            invocation_state,
            invocation_gate,
            invocation_cost,
            invocation_selection_copy,
        ]
    )

    lines.append(
        (
            "DEFILE THE RUINS · %s\n"
            + "Choose one of your Ruined Castles to Defile and gain 1 Tear. "
            + "Requires at least %d Ruined Castles and %d Souls. "
            + "You have %d Souls. %s"
        ) % [
            profane_state,
            ruined_required,
            profane_soul_cost,
            souls_available,
            profane_selection_copy,
        ]
    )

    if invocation_selected:
        lines.append(
            "INVOCATION HAND PAYMENT · %d/%d selected value%s"
            % [
                selected_total,
                invocation_cost,
                " · READY"
                if selected_total >= invocation_cost
                else " · SHORT",
            ]
        )

    if not profane_castle.is_empty():
        lines.append(
            "DEFILE · SOULS %d/%d%s"
            % [
                souls_available,
                profane_soul_cost,
                " · READY"
                if souls_available >= profane_soul_cost
                else " · SHORT",
            ]
        )

    if (
        invocation_selected
        and not profane_castle.is_empty()
    ):
        lines.append(
            "PAYMENTS ARE SEPARATE · Hand cards pay only for Cataclysmic Invocation. "
            + "Defile the Ruins spends Souls directly."
        )

    rite_help_label.text = "\n\n".join(lines)

func _refresh_payment_feedback() -> void:
    if payment_label == null:
        return

    if stage_key != "REPAIR":
        payment_label.visible = false
        payment_label.text = ""
        return

    payment_label.visible = true

    var action_name: String = get_primary_value()
    var castle_name: String = get_secondary_value()

    if action_name.is_empty() or castle_name.is_empty():
        payment_label.text = "PAYMENT · choose an action and Castle."
        return
    var selected_cards: Array = _selected_payment_cards()

    if action_name == "repair":
        var maximum: int = CastleIntegrityRulesData.max_integrity(
            castle_name
        )
        var before: int = int(
            player_ref.castle_integrity.get(
                castle_name,
                maximum
            )
        )
        var needed: int = maxi(
            0,
            maximum - before
        )
        var effective_paid: int = 0

        for card in selected_cards:
            effective_paid += RoundEngineData.effective_repair_value(
                card,
                rules_ref
            )

        var bonus: int = _repair_bonus()
        var total_restore: int = effective_paid + bonus
        var remaining: int = maxi(
            0,
            needed - total_restore
        )

        payment_label.text = (
            "REPAIR PAYMENT · %d effective · WRIGHT = full; other suits = printed − 1 (min 1)"
            % effective_paid
        )

        if bonus > 0:
            payment_label.text += " + %d bonus" % bonus

        payment_label.text += " · need %d" % needed

        if remaining > 0:
            payment_label.text += " · %d short" % remaining
        else:
            payment_label.text += " · READY"

        return

    if action_name == "construct":
        var maximum: int = CastleIntegrityRulesData.max_integrity(
            castle_name
        )
        var before: int = int(
            player_ref.castle_construction_progress.get(
                castle_name,
                0
            )
        )
        var selected_value: int = 0

        for card in selected_cards:
            selected_value += int(card.value)

        var remaining_before: int = maxi(
            0,
            maximum - before
        )
        var applied: int = selected_value
        var cap: int = int(
            rules_ref.construction_action_cap
        )

        if (
            cap > 0
            and selected_value > cap
        ):
            payment_label.text = (
                "CONSTRUCTION PAYMENT · %d selected · CAP %d · OVER CAP BY %d — remove payment."
                % [
                    selected_value,
                    cap,
                    selected_value - cap,
                ]
            )
            return

        if cap > 0:
            applied = mini(
                applied,
                cap
            )

        applied = mini(
            applied,
            remaining_before
        )

        var remaining_after: int = maxi(
            0,
            remaining_before - applied
        )

        payment_label.text = (
            "CONSTRUCTION PAYMENT · %d selected · %d applies · SUIT DOES NOT MATTER"
            % [
                selected_value,
                applied,
            ]
        )

        if cap > 0:
            payment_label.text += " (cap %d)" % cap

        payment_label.text += " · %d remains" % remaining_after
        return

    payment_label.text = "PAYMENT · choose Repair or Construction, then a Castle."


func _repair_bonus() -> int:
    if player_ref == null or rules_ref == null:
        return 0

    var bonus: int = 0

    if (
        option_toggle != null
        and option_toggle.visible
        and option_toggle.button_pressed
    ):
        bonus += int(
            rules_ref.repair_token_integrity
        )

    if (
        String(player_ref.lord) == "Kalligan"
        and bool(player_ref.alive)
    ):
        bonus += int(
            rules_ref.master_builder_integrity
        )

    if (
        controller_ref != null
        and controller_ref.game != null
        and String(controller_ref.game.breach) == "Kalligan"
    ):
        bonus += int(
            rules_ref.rapid_construction_integrity
        )

    return bonus


func _selected_payment_cards() -> Array:
    var result: Array = []

    if player_ref == null:
        return result

    _append_selected_cards_by_id(
        result,
        player_ref.hand,
        selected_hand_card_ids
    )

    var garrison_ids: Array[String] = []

    for raw_value in get_aux_selected_values():
        var value: String = String(raw_value)
        var parts: PackedStringArray = value.split(
            "|",
            false,
            1
        )

        if (
            parts.size() == 2
            and parts[0] == "Garrison"
        ):
            garrison_ids.append(
                parts[1]
            )

    _append_selected_cards_by_id(
        result,
        player_ref.garrison,
        garrison_ids
    )

    return result


func _append_selected_cards_by_id(
    output: Array,
    pool: Array,
    requested_ids: Array[String]
) -> void:
    var used_indices: Dictionary = {}

    for requested_id in requested_ids:
        for pool_index: int in range(
            pool.size()
        ):
            if used_indices.has(pool_index):
                continue

            var card = pool[pool_index]

            if _card_id(card) != requested_id:
                continue

            output.append(card)
            used_indices[pool_index] = true
            break


func _refresh_action_copy() -> void:
    if opponent_ref == null:
        return
    var hunt: Button = action_buttons.get("Hunt", null)
    if hunt != null:
        hunt.text = "HUNT %s\nAttack the enemy Lord.\nCurrent Lord DEF %d" % [
            String(opponent_ref.lord).to_upper(),
            int(opponent_ref.derived_lord_def),
        ]


func _refresh_confirm_state() -> void:
    if confirm_button == null or not confirm_button.visible:
        return

    confirm_button.disabled = false

    if stage_key == "COMMITMENT":
        if selected_action.is_empty():
            confirm_button.disabled = true
            return
        if selected_action != "Hunt" and get_primary_value().is_empty():
            confirm_button.disabled = true
            return
        # Ward and Profane are legal zero-card orders. Only attacks need Subjects.
        if (
            selected_action in ["Hunt", "Siege"]
            and selected_card_count <= 0
        ):
            confirm_button.disabled = true
            return

    if stage_key == "MARKET":
        confirm_button.disabled = get_primary_value().is_empty() or selected_card_count != 1
    elif stage_key == "REPAIR":
        var payment_cards: Array = _selected_payment_cards()

        confirm_button.disabled = (
            get_primary_value().is_empty()
            or get_secondary_value().is_empty()
            or payment_cards.is_empty()
        )

        if (
            not confirm_button.disabled
            and get_primary_value() == "construct"
        ):
            var construction_cap: int = int(
                rules_ref.construction_action_cap
            )

            if construction_cap > 0:
                var selected_value: int = 0

                for card in payment_cards:
                    selected_value += int(
                        card.value
                    )

                confirm_button.disabled = (
                    selected_value
                    > construction_cap
                )
    elif stage_key == "DOMINION_RITES":
        var invocation_selected: bool = (
            option_toggle != null
            and option_toggle.button_pressed
        )
        var profane_castle: String = get_primary_value()
        var profane_selected: bool = (
            not profane_castle.is_empty()
        )

        confirm_button.disabled = (
            not invocation_selected
            and not profane_selected
        )

        if (
            not confirm_button.disabled
            and invocation_selected
        ):
            var invocation_value: int = 0

            for card in _selected_payment_cards():
                invocation_value += int(card.value)

            if (
                (
                    not bool(rules_ref.invocation_repeatable)
                    and bool(player_ref.cataclysmic_used)
                )
                or controller_ref == null
                or controller_ref.game == null
                or int(
                    controller_ref.game.calculate_veil_total()
                ) < int(rules_ref.invocation_gate)
                or invocation_value
                < int(
                    DominionRiteEngineData.INVOCATION_PAYMENT_THRESHOLD
                )
            ):
                confirm_button.disabled = true

        if (
            not confirm_button.disabled
            and profane_selected
        ):
            if (
                bool(player_ref.profane_ruins_used_this_round)
                or int(
                    player_ref.ruined_castles.size()
                ) < int(rules_ref.profane_ruins_req)
                or not player_ref.ruined_castles.has(
                    profane_castle
                )
                or int(player_ref.souls)
                < maxi(
                    0,
                    int(rules_ref.profane_ruins_cost)
                )
            ):
                confirm_button.disabled = true

    elif stage_key == "DEPLOY":
        confirm_button.disabled = get_aux_selected_values().is_empty()
    elif stage_key == "KANIFOUS_INVOKE":
        confirm_button.disabled = get_primary_value().is_empty() or selected_card_count != 1
    elif stage_key == "MARCH":
        confirm_button.disabled = get_primary_value().is_empty() or get_secondary_value().is_empty() or get_aux_selected_values().size() != 1
    elif stage_key == "KANIFOUS_WRIGHT":
        confirm_button.disabled = get_aux_selected_values().size() > 2
    elif stage_key == "VULTURE_RECON":
        confirm_button.disabled = get_primary_value().is_empty()
    elif stage_key == "RESOLUTION_HUMBABA_TOLL":
        confirm_button.disabled = get_primary_value().is_empty()
    elif stage_key == "RESOLUTION_REFLEX":
        confirm_button.disabled = selected_action.is_empty()
    elif stage_key == "RESOLUTION_ODRADEK_BREACH":
        confirm_button.disabled = (
            selected_action.is_empty()
            or get_primary_value().is_empty()
            or get_secondary_value().is_empty()
        )


func _has_profanable_castle() -> bool:
    for castle_name in player_ref.castles:
        if _castle_profane_eligible(String(castle_name)):
            return true
    return false


func _castle_profane_eligible(castle_name: String) -> bool:
    if not bool(rules_ref.profane_requires_full_integrity):
        return true
    var maximum: int = CastleIntegrityRulesData.max_integrity(castle_name)
    return int(player_ref.castle_integrity.get(castle_name, maximum)) == maximum


func _castle_type_is_buildable(castle_name: String) -> bool:
    if not bool(rules_ref.castle_construction):
        return false
    return (
        not player_ref.castles.has(castle_name)
        and not player_ref.ruined_castles.has(castle_name)
        and not player_ref.profaned_castles.has(castle_name)
        and not player_ref.lost_castles.has(castle_name)
    )


func _card_id(card) -> String:
    if card == null:
        return ""
    if card.has_method("card_id"):
        return String(card.card_id())
    return "%s:%d" % [String(card.suit), int(card.value)]


func _phase_copy(stage_name: String) -> String:
    match stage_name:
        "NO_GAME":
            return "Round complete. Advance when ready."
        "DEVELOPMENT_SNARE":
            return "Orias may spend 1 Threat to Snare enemy Development."
        "MARKET":
            return "Trade one Hand card for one Market offer, or pass."
        "REPAIR":
            return "Choose REPAIR for a damaged active Castle or CONSTRUCT for an unbuilt Castle. Wright efficiency applies only to Repair."
        "DOMINION_RITES":
            return "Perform optional Dominion rites, then continue."
        "DEPLOY":
            return "Click-to-stage or drag Hand cards directly into their final Guard zones. STAGED Guards are reversible until FINISH DEPLOY."
        "MARCH":
            return "Drag a Lord/Castle Guard directly into a lane, or use the selectors below. Passing launches nothing."
        "SUMMON":
            return "Pay to return your Banished Lord, or remain Banished."
        "REFLEX_BID":
            return "Bid Hand cards for Reflex priority, or bid zero."
        "COMMITMENT":
            return "Choose your sealed order."
        "SEALED":
            return "Both orders are sealed; reveal when ready."
        "KANIFOUS_INVOKE":
            return "Invoke one revealed card and pay the Hand toll."
        "KANIFOUS_WRIGHT":
            return "Move up to two Lord Guards to the Castle zone."
        "VULTURE_RECON":
            return "Scout one enemy Guard zone before the clash."
        "REVEALED":
            return "Both orders are public. Resolve the round."
        "RESOLUTION_HUMBABA_TOLL":
            return "Ruin one of your Castles for Humbaba's Toll, or pass."
        "RESOLUTION_ACTION":
            return "Resolve your sealed action and any optional modifier."
        "RESOLUTION_VESSEL":
            return (
                "Once per match, a living Lord may be offered as the Vessel: "
                + "+1 Tear to you, +1 Soul to the opponent, discard your Lord "
                + "Guards, and remove the Lord from play. It is not placed in "
                + "the Breach; if summoned later it returns at Threat 2."
            )
        "RESOLUTION_REFLEX":
            return "Take the extra Momentum action, or pass."
        "RESOLUTION_ODRADEK_BREACH":
            return "Predict and steal the opponent's extra action, or pass."
        "RESOLUTION_GREMORY":
            return "Pay for Inevitable Ruin, or pass."
        "TERMINAL":
            return "The match is complete."
        "INVALID":
            return "The controller rejected the current game state."
        _:
            return "Resolve the current phase decision."


func _friendly_phase_name(raw_stage: String) -> String:
    return raw_stage.replace("_", " ").capitalize()
