extends "res://Prototype/U13/U13DirectBoard.gd"

const Orias = preload("res://Scripts/Sim/U13Orias.gd")
const WebPlacement = preload("res://Prototype/U13/U13WebPlacement.gd")
const WebVisuals = preload("res://Prototype/U13/U13WebVisuals.gd")
var orias_box: VBoxContainer
var orias_note: Label
var web_button: Button
var snare_button: Button
var placement
var development_box: VBoxContainer
var development_note: Label
var guard_button: Button
var summon_button: Button
var guard_plan: Array = []
var summon_plan: Dictionary = {}
var snare_visuals = WebVisuals.new()
var snare_overlay: Node2D


func _build() -> void:
	super._build()
	if not _direct():
		return
	orias_box = VBoxContainer.new()
	powers_box.add_child(orias_box)
	powers_box.move_child(orias_box, 0)
	_label(orias_box, "ORIAS · THE HUNTER", 18)
	orias_note = _label(orias_box, "", 13)
	orias_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	web_button = _button(orias_box, "PLACE WEB", _begin_web)
	snare_button = _button(orias_box, "PREPARE SNARE · GAIN 1 THREAT", _queue_snare)
	development_box = VBoxContainer.new()
	castle_box.get_parent().add_child(development_box)
	castle_box.get_parent().move_child(development_box, castle_box.get_index() + 1)
	_label(development_box, "GUARDS & LORD RETURN", 17)
	development_note = _label(development_box, "", 13)
	development_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guard_button = _button(development_box, "PLACE GUARD", _select_direct_action.bind("Guard"))
	summon_button = _button(
		development_box, "RESUMMON LORD", _select_direct_action.bind("Resummon")
	)
	_button(development_box, "Clear Guard placements", _clear_guards)
	_button(development_box, "Cancel resummon · return cards", _clear_summon)
	placement = WebPlacement.new()
	add_child(placement)
	placement.confirmed.connect(_confirm_web)
	placement.cancelled.connect(_cancel_web)
	snare_overlay = Node2D.new()
	snare_overlay.z_index = 2
	add_child(snare_overlay)
	snare_overlay.draw.connect(_draw_snare_markers)


func _development_enabled() -> bool:
	return _direct() and _visible_world.has("resummon_profile")


func _order() -> Dictionary:
	return _with_development(super._order())


func _with_development(order: Dictionary) -> Dictionary:
	var result: Dictionary = order.duplicate(true)
	if not guard_plan.is_empty():
		result["guard_moves"] = guard_plan.duplicate(true)
	if not summon_plan.is_empty():
		result["summon"] = summon_plan.duplicate(true)
	return result


func _hand_reserved(id: String) -> bool:
	if id in summon_plan.get("card_ids", []):
		return true
	for move in guard_plan:
		if move.card_id == id:
			return true
	return super._hand_reserved(id)


func _update_direct_ui() -> void:
	super._update_direct_ui()
	if orias_box == null:
		return
	orias_box.visible = _human_lord() == "Orias"
	development_box.visible = _development_enabled() and not powers_step and _planning()
	if not _planning():
		return
	guard_button.disabled = not _development_enabled()
	summon_button.disabled = not _development_enabled() or _human_alive()
	if _development_enabled():
		var cap: int = _visible_world.guard_placement_limits[0]
		development_note.text = (
			"%d/%d Guards staged across both zones. Choose an empty slot, then a hand card."
			% [guard_plan.size(), cap]
		)
		if _visible_world.snare_rounds[0] == session.round_number():
			development_note.text += "\nSNARED · one Guard placement this round."
		elif cap == 2:
			development_note.text += "\nENTANGLEMENT · two Guard placements this round."
		if not _human_alive():
			development_note.text += "\nResummon your Lord with cards; missing payment becomes Threat (maximum 4)."
			if not summon_plan.is_empty():
				var quote: Dictionary = session.summon_preview(summon_plan.card_ids)
				development_note.text += (
					"\nCost %d · paid %d · return Threat %d%s"
					% [
						quote.get("cost", 0),
						quote.get("paid_value", 0),
						quote.get("return_threat", 0),
						" · THE MARK" if quote.get("marked", false) else ""
					]
				)
			status.text = _guide()
	if _human_lord() == "Orias":
		var state: Dictionary = session.power_status(Orias.WEB)
		var ready: bool = (
			_human_alive()
			and powers_step
			and not _queued_power(Orias.WEB)
			and state.remaining == 0
			and not state.awaiting_expiration
		)
		web_button.disabled = not ready
		snare_button.disabled = not _human_alive() or not powers_step or _queued_power(Orias.SNARE)
		orias_note.text = (
			"Web: "
			+ (
				"queued"
				if _queued_power(Orias.WEB)
				else (
					"active"
					if state.awaiting_expiration
					else ("ready" if state.remaining == 0 else "cooldown %d" % state.remaining)
				)
			)
		)
		orias_note.text += "\nSnare limits the enemy to one Guard next round. Gain 1 Threat when orders lock."
		var bonus: int = int(
			_visible_world.get("relentless_pursuit", [{"strength_bonus": 0}])[0].strength_bonus
		)
		orias_note.text += (
			"\nRelentless Pursuit: +%d Hunt Strength. Accelerate: first Lord Guard defeat adds 1 enemy Threat."
			% bonus
		)
		orias_note.text += "\nThe Mark: Banish at Threat 3+ for +2 bonus Souls and 1 Neutral Tear; that Lord returns with +1 Threat."
		if _intent == "Hunt":
			status.text += " · RELENTLESS PURSUIT +%d" % bonus
	if _intent in ["Guard", "Resummon"] and _target.is_empty():
		confirm.disabled = true
	if placement != null and placement.visible:
		confirm.disabled = true
		pass_button.disabled = true


func _select_direct_action(action: String) -> void:
	if action not in ["Guard", "Resummon"]:
		super._select_direct_action(action)
		return
	if not _planning() or powers_step or not _development_enabled():
		return
	_intent = action
	_target = {}
	_interaction_error = ""
	if action == "Resummon":
		if _human_alive():
			return
		for entity in _visible_world.entities:
			if entity.kind == "lord" and entity.owner == 0:
				_target = _entity_target(entity.id)
		if summon_plan.is_empty():
			summon_plan = {"card_ids": []}
	_schedule_refresh()
	_reveal_targets()


func _guide() -> String:
	if _intent == "Guard":
		return "PLACE GUARD · click an empty Guard slot, then one hand card. Snare and Entanglement limits apply across both zones."
	if _intent == "Resummon":
		return "RESUMMON · select payment cards. The same Lord returns during Development; its powers become available at the following submission."
	return super._guide()


func _target_allowed(target: Dictionary, intent: String) -> bool:
	if intent != "Guard":
		return super._target_allowed(target, intent)
	if (
		not _planning()
		or not _development_enabled()
		or target.get("owner") != 0
		or target.get("kind") != "zone"
		or not target.has("slot")
	):
		return false
	for entity in _visible_world.entities:
		if (
			entity.kind == "card"
			and entity.owner == 0
			and entity.attributes.get("role") == "guard"
			and entity.attributes.lane == target.lane
			and entity.attributes.slot == target.slot
		):
			return false
	for move in guard_plan:
		if move.lane == target.lane and move.slot == target.slot:
			return false
	return guard_plan.size() < _visible_world.guard_placement_limits[0]


func _guard_selected(target: Dictionary) -> void:
	if _intent == "Guard":
		_choose_target(target)
	else:
		super._guard_selected(target)


func _drop_intent(target: Dictionary) -> String:
	if _intent == "Guard" and target.get("owner") == 0 and target.has("slot"):
		return "Guard"
	return super._drop_intent(target)


func _apply_cards(ids: Array, append: bool) -> bool:
	if _intent == "Guard":
		if ids.is_empty() or not _target_allowed(_target, "Guard"):
			return false
		var proposed: Array = guard_plan.duplicate(true)
		proposed.append({"card_id": ids[0], "lane": _target.lane, "slot": int(_target.slot)})
		var order: Dictionary = _order()
		order["guard_moves"] = proposed
		if _error(session.choose(queued, order)):
			return false
		guard_plan = proposed
		_target = {}
		_intent = ""
		_schedule_refresh()
		return true
	if _intent == "Resummon":
		var selected: Array = summon_plan.get("card_ids", []).duplicate() if append else []
		for id in ids:
			if id not in selected:
				selected.append(id)
		var quoted: Dictionary = session.summon_preview(selected)
		if quoted.action == "invalid" and quoted.get("reason") != "summon_payment_shortfall":
			_error(quoted)
			return false
		summon_plan = {"card_ids": selected}
		_schedule_refresh()
		return true
	return super._apply_cards(ids, append)


func _clear_guards() -> void:
	if _planning() and not powers_step:
		guard_plan = []
		_intent = ""
		_target = {}
		_schedule_refresh()


func _clear_summon() -> void:
	if _planning() and not powers_step:
		summon_plan = {}
		_intent = ""
		_target = {}
		_schedule_refresh()


func _begin_web() -> void:
	if not _planning() or not powers_step or web_button.disabled:
		return
	_intent = ""
	_target = {}
	placement.open()
	phase_prompt.set_presenting(false)


func _confirm_web(target: Dictionary) -> void:
	if not _planning() or not powers_step or _queued_power(Orias.WEB):
		return
	var proposed: Array = queued.duplicate(true)
	proposed.append(session.declaration(Orias.WEB, proposed.size(), target))
	if _error(session.choose(proposed, _order())):
		return
	queued = proposed
	placement.close()
	_refresh()
	reopen_decision()


func _cancel_web() -> void:
	placement.close()
	_refresh()
	reopen_decision()


func _queue_snare() -> void:
	if not _planning() or not powers_step or snare_button.disabled:
		return
	var proposed: Array = queued.duplicate(true)
	proposed.append(session.declaration(Orias.SNARE, proposed.size(), {"player_id": 1}))
	if _error(session.choose(proposed, _order())):
		return
	queued = proposed
	_refresh()


func _reset_direct() -> void:
	guard_plan = []
	summon_plan = {}
	if placement != null:
		placement.close()
	super._reset_direct()


func _development_stacks(stacks: Array) -> void:
	for move in guard_plan:
		var before: int = stacks.size()
		_add_stack(
			stacks,
			"guard",
			"%s GUARD %d" % [move.lane.to_upper(), move.slot + 1],
			[move.card_id],
			{"id": "", "kind": "zone", "owner": 0, "lane": move.lane}
		)
		if stacks.size() > before:
			var box = sides[1].lord_guard_box if move.lane == "Lord" else sides[1].castle_guard_box
			stacks.back().anchor = box.get_child(move.slot)
			stacks.back().locked = powers_step
	if not summon_plan.is_empty():
		_add_stack(
			stacks,
			"summon",
			"RESUMMON PAYMENT",
			summon_plan.card_ids,
			{"id": "", "kind": "zone", "owner": 0, "lane": "Lord"}
		)
		if not summon_plan.card_ids.is_empty():
			stacks.back().locked = powers_step


func _return_card(role: String, id: String) -> void:
	if role not in ["guard", "summon"]:
		super._return_card(role, id)
		return
	if not _planning() or powers_step:
		return
	if role == "guard":
		guard_plan = guard_plan.filter(func(move: Dictionary) -> bool: return move.card_id != id)
	else:
		summon_plan.card_ids.erase(id)
	_schedule_refresh()


func _process(delta: float) -> void:
	super._process(delta)
	if snare_overlay != null and _development_enabled():
		snare_visuals.warm_next()
		snare_overlay.queue_redraw()


func _draw_snare_markers() -> void:
	if not _development_enabled() or setup_open:
		return
	for pid in [0, 1]:
		if _visible_world.snare_rounds[pid] != session.round_number():
			continue
		var row = sides[1] if pid == 0 else sides[0]
		for box in [row.lord_guard_box, row.castle_guard_box]:
			if box.get_child_count() < 3:
				continue
			var middle: Control = box.get_child(1)
			var center: Vector2 = snare_overlay.to_local(middle.get_global_rect().get_center())
			var diameter: float = maxf(middle.size.x, middle.size.y) * 1.65
			var area := Rect2(center - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter)
			snare_visuals.draw_area(
				snare_overlay, area, Rect2(Vector2.ZERO, size), false, 0.0, false
			)
