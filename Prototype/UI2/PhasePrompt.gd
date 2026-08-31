# UI2_DIALOGUE_BREACH_OVERHAUL_V1
class_name UI2PhasePrompt
extends PanelContainer


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
    offset_left = -175.0
    offset_right = 175.0
    offset_top = -170.0
    offset_bottom = 170.0

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
        offset_bottom = 34.0
        return

    title_label.visible = true
    copy_label.visible = true
    divider.visible = true

    var show_details: bool = detail_open and action_zone != null
    content_host.visible = show_details
    if action_zone != null:
        action_zone.visible = show_details
    intro_buttons.visible = not show_details and _has_buttons(stage_key)

    offset_left = -175.0
    offset_right = 175.0
    if show_details:
        offset_top = -300.0
        offset_bottom = 300.0
    else:
        offset_top = -170.0
        offset_bottom = 170.0


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
            yes_button.text = "VISIT THE MARKET"
            no_button.text = "KEEP YOUR HAND"
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
            return "THE MARKET"
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
        "RESOLUTION_GREMORY":
            return "INEVITABLE RUIN"
        "TERMINAL":
            return "THE CONTRACT IS FULFILLED"
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
            return "Exchange one card from your Hand for one offer from the Market, or keep what you have."
        "REPAIR":
            return _castle_maintenance_copy()
        "DOMINION_RITES":
            return "Optional rites convert opportunity into Dominion pressure. Perform one only if the cost is worth the tempo."
        "DEPLOY":
            return _deploy_copy()
        "MARCH":
            return "Send a deployed Guard into a Marching lane now, or hold your defenses in place."
        "SUMMON":
            var cost: int = 0
            if controller_ref != null and controller_ref.has_method("human_summon_cost"):
                cost = int(controller_ref.human_summon_cost())
            return "Your Lord is Banished. Pay %d from your Hand to return from the Breach, or remain there." % cost
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
        "RESOLUTION_GREMORY":
            return "Gremory may pay for Inevitable Ruin after a Siege leaves its target standing."
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
