extends "res://Prototype/U13/U13Board.gd"

const OrderPreview = preload("res://Prototype/U13/U13OrderPreview.gd")
var direct_enabled: bool = true
var _draft_combat: Dictionary = {}
var _intent: String = ""
var _interaction_error: String = ""
var _target: Dictionary = {}
var _power_cost: Array = []
var _direct_refresh_pending: bool = false
var _direct_binding: bool = false
var _pulse_pending: bool = false
var _selected_pulse: Dictionary = {}
var _visible_world: Dictionary = {}
var _order_preview
var _direct_castle_buttons: Array = []


func _direct() -> bool:
	return direct_enabled and setup_enabled and not dense_mode


func _new_loadout_session():
	var candidate = super._new_loadout_session()
	candidate.hunt_enabled = _direct()
	return candidate


func _build() -> void:
	super._build()
	if not _direct():
		return
	action_choice.add_item("Hunt")
	action_zone._add_action("Hunt", "Attack the enemy Lord.")
	action_zone.action_box.move_child(action_zone.action_buttons.Hunt, 0)
	controls.append(action_zone.action_buttons.Hunt)
	for pair in [["Construct", "CONSTRUCT"], ["Repair", "REPAIR"]]:
		var button: Button = _button(castle_box, pair[1], _select_direct_action.bind(pair[0]))
		castle_box.move_child(button, 1 + _direct_castle_buttons.size())
		_direct_castle_buttons.append(button)
		controls.append(button)
	for row in sides:
		row.direct_targets = true
		row.commission_requested.connect(_commission)
	lanes.lane_selected.connect(_lane_selected)
	hand_view.direct_gestures = true
	hand_view.set_attack_drag_enabled(true)
	hand_view.all_in_requested.connect(_all_in)
	castle_token.toggled.connect(_repair_token_changed)
	_order_preview = OrderPreview.new()
	add_child(_order_preview)


func _hand_reserved(id: String) -> bool:
	return (
		super._hand_reserved(id)
		or (_direct() and (id in _draft_combat.get("card_ids", []) or id in _power_cost))
	)


func _order() -> Dictionary:
	if not _direct():
		return super._order()
	var result: Dictionary = _draft_combat.duplicate(true)
	if not castle_plan.is_empty():
		result["castle_action"] = castle_plan.duplicate(true)
	return result


func _refresh(presented: Dictionary = {}) -> void:
	if not _direct():
		super._refresh(presented)
		return
	_direct_binding = true
	_visible_world = session.board_view().world if presented.is_empty() else presented.world
	super._refresh(presented)
	_direct_binding = false
	for row in sides:
		row.show_commission_buttons(
			_planning() and not powers_step,
			castle_plan.get("target_id", "") if castle_plan.get("action") == "Activate" else ""
		)
		for id in row.target_controls:
			_wire_target(row.target_controls[id], _entity_target(id))
			if (
				powers_step
				and _intent == Deimos.WAR_MACHINE
				and _target_allowed(_entity_target(id), _intent)
			):
				row.target_controls[id].tooltip_text += "\n" + _artillery_target_note(_entity(id))
		var shared: Dictionary = {
			"id": "", "kind": "zone", "owner": 0 if row == sides[1] else 1, "lane": "Castle"
		}
		_wire_target(row.castle_guard_box, shared)
		for slot in row.castle_guard_box.get_children():
			_wire_target(slot.input_surface, shared)
	_update_direct_ui()
	if _pulse_pending:
		_pulse_pending = false
		_pulse_targets()
	if not _selected_pulse.is_empty():
		_flash_selected(_selected_pulse)
		_selected_pulse = {}
	call_deferred("_show_stacks")


func _preview() -> void:
	super._preview()
	if _direct() and match_started:
		_update_direct_ui()


func _update_decision_copy() -> void:
	super._update_decision_copy()
	if _direct() and match_started:
		_update_direct_ui()


func _update_direct_ui() -> void:
	for control in [
		target_choice,
		lane_choice,
		action_zone.primary_label,
		action_zone.secondary_label,
		castle_action_choice,
		castle_target,
		castle_stage,
		power_lane,
		ruin_target,
		engine_choice,
		rout_lane
	]:
		control.hide()
	for option in humbaba_lanes.values():
		option.hide()
	# Target headings remain as prose; choices happen on the board.
	predator_button.text = "CHOOSE PREDATOR OF RUIN"
	ruin_button.text = "CHOOSE INEVITABLE RUIN"
	war_button.text = "CHOOSE WAR MACHINE"
	rout_button.text = "CHOOSE ROUT"
	war_state.text = (
		String(war_state.text.split("\nArtillery:")[0]) + "\nArtillery: " + _war_machine_note()
	)
	castle_token.visible = not powers_step and _intent == "Repair"
	castle_token.disabled = not _planning()
	castle_note.text = "Construct / Repair: choose the action, click your Castle, then click payment cards. Commission is on each eligible Castle."
	if not castle_plan.is_empty():
		castle_note.text = (
			"Staged: %s · %d cards. Click a staged card to return it."
			% [
				"Commission" if castle_plan.action == "Activate" else castle_plan.action,
				castle_plan.card_ids.size()
			]
		)
	castle_note.text += "\nRepair tokens: %d" % int(_visible_world.get("repair_tokens", 0))
	if _intent == "Construct":
		castle_note.text += "\nSelecting an eligible Castle stages free +3 progress. Cards add progress."
	if _intent == "Repair":
		castle_note.text += "\nWrights: full value; other cards: value minus 1 (minimum 1). Token: +3."
	hand_view.all_in_enabled = (
		_planning()
		and not setup_open
		and _intent in ["Siege", "Hunt", "Ward", "Construct", "Repair"]
		and not _target.is_empty()
		and _intent_cards().size() > 0
	)
	lanes.target_lane_enabled = (_planning() and powers_step and _is_lane_power(_intent))
	lanes.mouse_filter = (
		Control.MOUSE_FILTER_STOP if lanes.target_lane_enabled else Control.MOUSE_FILTER_IGNORE
	)
	if _planning():
		var guide: String = _guide() if _interaction_error.is_empty() else _interaction_error
		_busy_label.text = guide
		status.text = guide
		if (
			not _intent.is_empty()
			and (
				_target.is_empty()
				or (
					_intent
					in [
						Gremory.PREDATOR,
						Gremory.RUIN,
						Deimos.WAR_MACHINE,
						Deimos.ROUT,
						Humbaba.MUSTER,
						Humbaba.BREATH
					]
				)
			)
		):
			confirm.disabled = true
		if (
			_intent == "Repair"
			and (
				castle_plan.get("action") != "Repair"
				or castle_plan.get("target_id") != _target.get("id")
				or castle_plan.get("card_ids", []).is_empty()
			)
		):
			confirm.disabled = true
		if not _human_alive():
			for button in (
				[predator_button, ruin_button, war_button, rout_button] + humbaba_buttons.values()
			):
				button.disabled = true
			status.text = "Your Lord is banished. Powers and combat are unavailable; Castle development or a new exercise remain available."
		if powers_step:
			phase_prompt.copy_label.text = "Click a power, its payment cards if needed, then its target on the board. Resolve submits all staged orders."
		else:
			phase_prompt.copy_label.text = "Choose action → click target → click hand cards. Or drag a card directly to a target. Double-click the hand after staging one card for ALL IN."
		pass_button.disabled = false


func _guide() -> String:
	if _intent == Gremory.RUIN:
		return (
			"INEVITABLE RUIN · select payment %d/2, then click a damaged enemy Castle."
			% _power_cost.size()
		)
	if _is_lane_power(_intent):
		return _power_name(_intent).to_upper() + " · click LORD or CASTLE lane on the right."
	if _intent == Deimos.WAR_MACHINE:
		return "WAR MACHINE · click your Engine. Its extra shot uses its retained or automatically acquired target."
	if _intent in ["Siege", "Hunt", "Ward", "Construct", "Repair"]:
		if _target.is_empty():
			return _intent.to_upper() + " · click a highlighted target."
		return (
			"%s · %d cards staged. Click hand cards, drag more here, or double-click the hand for ALL IN."
			% [_intent.to_upper(), _intent_cards().size()]
		)
	return (
		"Choose an action or drag a card to a destination."
		if not powers_step
		else "Choose optional Lord powers, or resolve your staged orders."
	)


func _select_action(action: String) -> void:
	if not _direct():
		super._select_action(action)
		return
	_select_direct_action(action)


func _select_direct_action(action: String) -> void:
	if not _planning() or powers_step:
		return
	_interaction_error = ""
	if action == "Powers Only":
		_draft_combat = {}
		_intent = ""
		_target = {}
		action_choice.select(0)
		_schedule_refresh()
		return
	_intent = action
	_target = {}
	if action in ["Siege", "Hunt", "Ward"]:
		action_choice.select({"Siege": 1, "Ward": 2, "Hunt": 3}[action])
	_preview()
	_reveal_targets()


func _board_target_selected(action: String, lane: String, target_id: String) -> void:
	if not _direct():
		super._board_target_selected(action, lane, target_id)
		return
	var target: Dictionary = _entity_target(target_id)
	if target.is_empty():
		target = {"kind": "zone", "owner": 0, "id": "", "lane": lane}
	_choose_target(target)


func _entity_target(id: String) -> Dictionary:
	for entity in _visible_world.get("entities", []):
		if entity.id == id:
			return {
				"id": id,
				"kind": entity.kind,
				"owner": entity.owner,
				"lane": "Lord" if entity.kind == "lord" else "Castle"
			}
	return {}


func _entity(id: String) -> Dictionary:
	for entity in _visible_world.get("entities", []):
		if entity.id == id:
			return entity
	return {}


func _target_allowed(target: Dictionary, intent: String) -> bool:
	if not _planning() or target.is_empty():
		return false
	if intent in ["Siege", "Hunt", "Ward"] and not _human_alive():
		return false
	var entity: Dictionary = _entity(target.id)
	match intent:
		"Siege":
			return target.owner == 1 and target.kind == "castle" and Structures.targetable(entity)
		"Hunt":
			return (
				target.owner == 1
				and target.kind == "lord"
				and not entity.is_empty()
				and entity.attributes.alive
			)
		"Ward":
			return target.owner == 0 and target.kind in ["lord", "castle", "zone"]
		"Construct", "Repair":
			if target.owner != 0 or target.kind != "castle":
				return false
			var a: Dictionary = entity.attributes
			if intent == "Construct":
				return (
					(
						a.construction_state in ["unbuilt", "building", "ready"]
						and a.integrity < a.max_integrity
						and a.status not in ["ruined", "profaned"]
					)
					or (
						_human_lord() == "Deimos"
						and a.castle_type == "SiegeEngine"
						and a.status == "ruined"
						and _human_alive()
					)
				)
			return (
				a.construction_state == "active"
				and a.status in ["standing", "defunct"]
				and a.integrity < a.max_integrity
				and int(a.get("repair_lock_until_round", 0)) < session.round_number()
			)
		Gremory.RUIN:
			return (
				_power_cost.size() == 2
				and target.owner == 1
				and target.kind == "castle"
				and Structures.targetable(entity)
				and entity.attributes.status == "standing"
				and entity.attributes.integrity > 0
				and entity.attributes.integrity < entity.attributes.max_integrity
			)
		Deimos.WAR_MACHINE:
			return (
				target.owner == 0
				and target.kind == "castle"
				and entity.attributes.get("combat_profile") == "siege_engine"
				and Structures.operational(entity)
			)
	return false


func _choose_target(target: Dictionary) -> void:
	if not _planning():
		return
	if _intent.is_empty():
		_busy_label.text = "Select an action first, or drag a hand card directly to the target."
		return
	if not _target_allowed(target, _intent):
		_busy_label.text = "That target is unavailable for " + _power_name(_intent) + "."
		return
	if powers_step:
		_submit_power(target)
		return
	_interaction_error = ""
	_target = target.duplicate(true)
	_selected_pulse = target.duplicate(true)
	_schedule_refresh()
	if _intent == "Construct":
		_apply_cards([], false)
	elif _intent in ["Siege", "Hunt", "Ward"]:
		_apply_cards(_draft_combat.get("card_ids", []), false)
	else:
		_schedule_refresh()


func _wire_target(control: Control, target: Dictionary) -> void:
	control.set_drag_forwarding(Callable(), _can_drop.bind(target), _drop.bind(target))


func _can_drop(_position: Vector2, data, target: Dictionary) -> bool:
	if (
		not _planning()
		or powers_step
		or typeof(data) != TYPE_DICTIONARY
		or data.get("ui2_type") != "commitment_hand_card"
		or data.get("source") != "Hand"
		or data.get("card") not in _available_ids()
	):
		return false
	return _target_allowed(target, _drop_intent(target))


func _drop_intent(target: Dictionary) -> String:
	if target.owner == 0:
		return _intent if _intent in ["Construct", "Repair"] and target.kind == "castle" else "Ward"
	return "Hunt" if target.kind == "lord" else "Siege"


func _drop(at_position: Vector2, data, target: Dictionary) -> void:
	if not _can_drop(at_position, data, target):
		return
	_intent = _drop_intent(target)
	_target = target.duplicate(true)
	if _intent in ["Siege", "Hunt", "Ward"]:
		action_choice.select({"Siege": 1, "Hunt": 3, "Ward": 2}[_intent])
	if _apply_cards([String(data.card)], true):
		_selected_pulse = target.duplicate(true)


func _hand_selection_changed(ids: Array) -> void:
	if not _direct():
		super._hand_selection_changed(ids)
		return
	if _direct_binding or not _planning() or ids.is_empty():
		return
	var available: Array = _available_ids()
	var chosen: Array = []
	for id in ids:
		if id in available:
			chosen.append(id)
	if powers_step:
		if _intent == Gremory.RUIN:
			for id in chosen:
				if _power_cost.size() < 2:
					_power_cost.append(id)
			if _power_cost.size() == 2:
				_reveal_targets()
	elif not _target.is_empty():
		_apply_cards(chosen, true)
	_schedule_refresh()


func _intent_cards() -> Array:
	if _intent in ["Construct", "Repair"]:
		return castle_plan.get("card_ids", []) if castle_plan.get("action") == _intent else []
	return _draft_combat.get("card_ids", [])


func _apply_cards(ids: Array, append: bool) -> bool:
	if _target.is_empty():
		return false
	var selected: Array = _intent_cards().duplicate() if append else []
	for id in ids:
		if id not in selected:
			selected.append(id)
	var combat: Dictionary = _draft_combat.duplicate(true)
	var castle: Dictionary = castle_plan.duplicate(true)
	if _intent in ["Construct", "Repair"]:
		castle = {
			"action": _intent,
			"target_id": _target.id,
			"card_ids": selected,
			"use_repair_token": _intent == "Repair" and castle_token.button_pressed
		}
	else:
		combat = {"action": _intent, "lane": _target.lane, "card_ids": selected}
		if _intent in ["Siege", "Hunt"]:
			combat["target_id"] = _target.id
	var order: Dictionary = combat.duplicate(true)
	if not castle.is_empty():
		order["castle_action"] = castle
	var checked: Dictionary = session.choose(queued, order)
	if checked.action == "invalid":
		_interaction_error = _friendly_error(checked)
		_busy_label.text = _interaction_error
		status.text = _interaction_error
		return false
	_interaction_error = ""
	_draft_combat = combat
	castle_plan = castle
	if powers_step:
		staged_order = _order()
	_schedule_refresh()
	return true


func _available_ids() -> Array:
	var available: Array = []
	for id in _visible_world.get("hand", []):
		if not _hand_reserved(id):
			available.append(id)
	return available


func _all_in() -> void:
	if (
		not _planning()
		or _target.is_empty()
		or _intent_cards().is_empty()
		or _intent not in ["Siege", "Hunt", "Ward", "Construct", "Repair"]
	):
		return
	_apply_cards(_available_ids(), true)


func _commission(id: String) -> void:
	if not _planning() or powers_step:
		return
	var choice: Dictionary = (
		{}
		if castle_plan.get("action") == "Activate" and castle_plan.get("target_id") == id
		else {"action": "Activate", "target_id": id, "card_ids": [], "use_repair_token": false}
	)
	var order: Dictionary = _draft_combat.duplicate(true)
	if not choice.is_empty():
		order["castle_action"] = choice
	if _error(session.choose(queued, order)):
		return
	castle_plan = choice
	if _intent in ["Construct", "Repair"]:
		_intent = ""
		_target = {}
	_schedule_refresh()


func queue_predator() -> void:
	if not _direct():
		super.queue_predator()
		return
	_arm_power(Gremory.PREDATOR)


func queue_ruin() -> void:
	if not _direct():
		super.queue_ruin()
		return
	_arm_power(Gremory.RUIN)


func queue_war_machine() -> void:
	if not _direct():
		super.queue_war_machine()
		return
	_arm_power(Deimos.WAR_MACHINE)


func queue_rout() -> void:
	if not _direct():
		super.queue_rout()
		return
	_arm_power(Deimos.ROUT)


func _arm_power(power: String) -> void:
	if not _planning() or not powers_step or _queued_power(power) or not _human_alive():
		return
	var clock_state: Dictionary = session.power_status(power)
	if clock_state.remaining > 0 or clock_state.awaiting_expiration:
		return
	_interaction_error = ""
	_intent = "" if _intent == power else power
	_target = {}
	_power_cost = []
	_schedule_refresh()
	_reveal_targets()


func _lane_selected(lane: String) -> void:
	if _planning() and powers_step and _is_lane_power(_intent):
		_submit_power({"lane": lane})


func _submit_power(target: Dictionary) -> void:
	var payload: Dictionary = (
		{"lane": target.lane} if _is_lane_power(_intent) else {"entity_id": target.id}
	)
	var cost: Dictionary = (
		{"discard_ids": _power_cost.duplicate()} if _intent == Gremory.RUIN else {}
	)
	var candidate: Array = queued.duplicate(true)
	candidate.append(session.declaration(_intent, queued.size(), payload, cost))
	if _error(session.choose(candidate, _order())):
		return
	queued = candidate
	_selected_pulse = target.duplicate(true)
	payment.append_array(_power_cost)
	_power_cost = []
	_intent = ""
	_target = {}
	_schedule_refresh()
	reopen_decision()


func clear_powers() -> void:
	if _direct():
		_interaction_error = ""
		_power_cost = []
		_intent = ""
		_target = {}
	super.clear_powers()


func clear_castle_action() -> void:
	if not _direct():
		super.clear_castle_action()
		return
	if not _planning() or powers_step:
		return
	castle_plan = {}
	_intent = ""
	_target = {}
	_schedule_refresh()


func enter_powers() -> void:
	if _direct():
		_interaction_error = ""
		_intent = ""
		_target = {}
	super.enter_powers()


func back_to_combat() -> void:
	if not _direct():
		super.back_to_combat()
		return
	if not _planning() or not powers_step:
		return
	powers_step = false
	staged_order = {}
	queued = []
	payment = []
	_power_cost = []
	_intent = ""
	_target = {}
	_refresh()


func pass_round() -> void:
	if not _direct():
		super.pass_round()
		return
	if not _planning():
		return
	queued = []
	payment = []
	_power_cost = []
	_intent = ""
	_target = {}
	if powers_step:
		resolve_round()
	else:
		_draft_combat = {}
		action_choice.select(0)
		enter_powers()


func _reset_direct() -> void:
	_selected_pulse = {}
	_pulse_pending = false
	_interaction_error = ""
	_draft_combat = {}
	_intent = ""
	_target = {}
	_power_cost = []


func restart() -> void:
	if _direct() and not setup_open and _job == null:
		_reset_direct()
	super.restart()


func open_setup() -> void:
	super.open_setup()
	if _direct() and setup_open:
		if not match_started:
			setup_picker.present(
				["Deimos", "Gremory"],
				[setup_picker.Slots.TYPES.duplicate(), setup_picker.Slots.TYPES.duplicate()],
				true,
				false
			)
		hand_view.all_in_enabled = false
		_show_stacks()


func start_loadout(lords: Array, castles: Array, quick: bool) -> void:
	if not setup_open or _job != null:
		return
	var saved: Dictionary = {
		"combat": _draft_combat, "intent": _intent, "target": _target, "cost": _power_cost
	}
	_reset_direct()
	super.start_loadout(lords, castles, quick)
	if setup_open:
		_draft_combat = saved.combat
		_intent = saved.intent
		_target = saved.target
		_power_cost = saved.cost


func _complete_job() -> void:
	if _direct() and _job_operation == "next_round":
		_reset_direct()
	super._complete_job()


func _schedule_refresh() -> void:
	if _direct_refresh_pending:
		return
	_direct_refresh_pending = true
	call_deferred("_flush_direct_refresh")


func _flush_direct_refresh() -> void:
	_direct_refresh_pending = false
	if match_started and _job == null and not playing and not setup_open:
		_refresh()


func _human_alive() -> bool:
	for entity in _visible_world.get("entities", []):
		if entity.kind == "lord" and entity.owner == 0:
			return entity.attributes.alive
	return false


func _reveal_targets() -> void:
	if not _planning():
		return
	_pulse_pending = true
	_schedule_refresh()
	_update_direct_ui()


func _pulse_targets() -> void:
	if _is_lane_power(_intent):
		lanes.pulse_lanes()
	else:
		for row in sides:
			for id in row.target_controls:
				if _target_allowed(_entity_target(id), _intent):
					var control: Control = row.target_controls[id].get_parent().get_parent()
					_flash_control(control, Color(1.5, 1.25, 0.6))
	_update_direct_ui()


func _return_card(role: String, id: String) -> void:
	if not _planning() or (powers_step and role in ["combat", "castle"]):
		return
	_interaction_error = ""
	if role == "combat":
		_draft_combat.card_ids.erase(id)
		if _draft_combat.card_ids.is_empty():
			_draft_combat = {}
	elif role == "castle":
		castle_plan.card_ids.erase(id)
		if castle_plan.card_ids.is_empty() and castle_plan.action == "Repair":
			castle_plan = {}
	elif role == "ruin_pending":
		_power_cost.erase(id)
	elif role == "ruin":
		var kept: Array = []
		for source in queued:
			if source.power_id != Gremory.RUIN:
				kept.append(
					session.declaration(source.power_id, kept.size(), source.target, source.cost)
				)
		queued = kept
		payment = []
	if powers_step:
		staged_order = _order()
	_schedule_refresh()


func _show_stacks() -> void:
	if not _direct() or _order_preview == null:
		return
	var stacks: Array = []
	if _planning() and not setup_open:
		if not _draft_combat.is_empty():
			var dest: Dictionary = (
				_entity_target(_draft_combat.target_id)
				if _draft_combat.action in ["Siege", "Hunt"]
				else {"id": "", "kind": "zone", "owner": 0, "lane": _draft_combat.lane}
			)
			_add_stack(
				stacks, "combat", _draft_combat.action.to_upper(), _draft_combat.card_ids, dest
			)
		if not castle_plan.is_empty():
			_add_stack(
				stacks,
				"castle",
				castle_plan.action.to_upper(),
				castle_plan.card_ids,
				_entity_target(castle_plan.target_id)
			)
		var payment_target: Dictionary = {"id": "", "kind": "zone", "owner": 0, "lane": "Lord"}
		_add_stack(
			stacks,
			"ruin_pending",
			"RUIN PAYMENT %d/2" % _power_cost.size(),
			_power_cost,
			payment_target
		)
		_add_stack(stacks, "ruin", "RUIN PAYMENT", payment, payment_target)
	_order_preview.show_orders(stacks, _return_card, _can_drop, _drop)


func _add_stack(stacks: Array, role: String, label: String, ids: Array, target: Dictionary) -> void:
	if ids.is_empty() or target.is_empty():
		return
	var row = sides[1] if target.owner == 0 else sides[0]
	var anchor: Control = (
		row.target_controls.get(target.id)
		if not String(target.id).is_empty()
		else (row.castle_guard_box if target.lane == "Castle" else row.lord_card)
	)
	if anchor == null:
		return
	var cards: Array = []
	for id in ids:
		var card: Dictionary = _entity(id)
		if not card.is_empty():
			cards.append(card)
	stacks.append(
		{
			"role": role,
			"locked": powers_step and role in ["combat", "castle"],
			"label": label,
			"cards": cards,
			"anchor": anchor,
			"target": target,
			"from_position": hand_view.get_global_rect().get_center()
		}
	)


func _repair_token_changed(_enabled: bool) -> void:
	if (
		_planning()
		and _intent == "Repair"
		and not _target.is_empty()
		and not castle_plan.is_empty()
	):
		_apply_cards(castle_plan.card_ids, false)


func _war_machine_note() -> String:
	for source in queued:
		if source.power_id == Deimos.WAR_MACHINE:
			return _artillery_target_note(_entity(source.target.entity_id))
	return "Choose one Engine for one extra shot. It keeps its current enemy Castle target, or acquires one automatically when firing."


func _artillery_target_note(engine: Dictionary) -> String:
	if engine.is_empty():
		return "The selected Engine is unavailable."
	var retained: Dictionary = _entity(engine.attributes.get("artillery_target", ""))
	if not retained.is_empty() and Structures.targetable(retained):
		return (
			"Retained enemy target: %s. Reacquires automatically if it becomes invalid."
			% _castle_name(retained)
		)
	var targets: Array = []
	for entity in _visible_world.get("entities", []):
		if entity.kind == "castle" and entity.owner == 1 and Structures.targetable(entity):
			targets.append(entity)
	if targets.size() == 1:
		return (
			"No target retained yet. Only eligible enemy Castle now: %s. Target is acquired when firing."
			% _castle_name(targets[0])
		)
	if targets.is_empty():
		return "No eligible enemy Castle now. The Engine checks for a target when firing."
	return "No target retained yet. The Engine automatically acquires one of the eligible enemy Castles when firing."


func _flash_selected(target: Dictionary) -> void:
	if not target.has("id"):
		lanes.pulse_lanes(target.lane)
		return
	var row = sides[1] if target.owner == 0 else sides[0]
	var control: Control = row.target_controls.get(target.id)
	if control != null:
		_flash_control(control.get_parent().get_parent(), Color(1.8, 1.5, 0.7))
	elif target.kind == "zone":
		_flash_control(
			row.castle_guard_box if target.lane == "Castle" else row.lord_card, Color(1.8, 1.5, 0.7)
		)


func _flash_control(control: Control, tint: Color) -> void:
	if control.has_meta("u13_target_flash"):
		var previous = control.get_meta("u13_target_flash")
		if is_instance_valid(previous):
			previous.kill()
	control.modulate = tint
	var tween = control.create_tween()
	control.set_meta("u13_target_flash", tween)
	tween.tween_property(control, "modulate", Color.WHITE, 0.7)


func _is_lane_power(power: String) -> bool:
	return power in [Gremory.PREDATOR, Deimos.ROUT, Humbaba.MUSTER, Humbaba.BREATH]


func queue_muster() -> void:
	if not _direct():
		super.queue_muster()
		return
	_arm_power(Humbaba.MUSTER)


func queue_breath() -> void:
	if not _direct():
		super.queue_breath()
		return
	_arm_power(Humbaba.BREATH)
