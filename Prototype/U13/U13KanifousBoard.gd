extends "res://Prototype/U13/U13ValakBoard.gd"
const Kanifous = preload("res://Scripts/Sim/U13Kanifous.gd")
var void_overlay: ColorRect
var wish_box: VBoxContainer
var wish_choice: OptionButton
var wish_castles: Array = []
var wish_button: Button
var wish_remove: Button
var wish_note: Label
var price_note: Label
var wish_placement
var resurrection_placement
var wish_visual
var price_visual
var death_wish_visual

func _build() -> void:
	super._build()
	if not _direct():
		return
	wish_box = VBoxContainer.new()
	powers_box.add_child(wish_box)
	_label(wish_box, "WISH · ONE PER ROUND", 18)
	wish_choice = _option(wish_box, ["Power", "Longevity", "Resurrection", "Death", "Wealth"])
	wish_choice.item_selected.connect(func(_index): _update_direct_ui())
	wish_note = _label(wish_box, "", 13)
	wish_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wish_button = _button(wish_box, "QUEUE WISH", _queue_wish)
	wish_remove = _button(wish_box, "REMOVE WISH", _remove_wish)
	price_note = _label(wish_box, "", 13)
	price_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wish_placement = preload("res://Prototype/U13/U13WishDeathPlacement.gd").new()
	add_child(wish_placement)
	wish_placement.battlefield = lanes
	wish_placement.confirmed.connect(_confirm_wish_death)
	wish_placement.cancelled.connect(func(): wish_placement.close(); _refresh(); reopen_decision())
	resurrection_placement = preload("res://Prototype/U13/U13ResurrectionPlacement.gd").new()
	add_child(resurrection_placement)
	resurrection_placement.battlefield = lanes
	resurrection_placement.confirmed.connect(_confirm_resurrection)
	resurrection_placement.cancelled.connect(func(): resurrection_placement.close(); _refresh(); reopen_decision())
	wish_visual = preload("res://Prototype/U13/U13WishmasterVisual.gd").new()
	add_child(wish_visual)
	wish_visual.battlefield = lanes
	death_wish_visual = preload("res://Prototype/U13/U13WishDeathVisual.gd").new()
	add_child(death_wish_visual)
	death_wish_visual.battlefield = lanes
	death_wish_visual.impact.connect(_death_wish_impact)
	price_visual = preload("res://Prototype/U13/U13WishPriceVisual.gd").new()
	add_child(price_visual)
	void_overlay = ColorRect.new()
	void_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	void_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	void_overlay.z_index = 95
	var material := ShaderMaterial.new()
	material.shader = preload("res://Prototype/U13/U13Void.gdshader")
	void_overlay.material = material
	add_child(void_overlay)
	void_overlay.hide()
	_wish_targets()

func _wish_targets() -> void:
	wish_castles = _visible_world.get("entities", []).filter(func(row): return Kanifous.longevity_target(row, 0))
	wish_note.text = ["Spawn 1–3 random-suit Marchers: 70% one, 25% two, 5% three.", "Repair an active Castle up to 8 Integrity (or its maximum if lower). Castles already at or above that cannot be targeted. Protected construction and Ruined/Profaned Castles cannot be targeted.", "Choose a battlefield lane. After Marching, revive your Marchers killed there this round at full HP and Armor near where they fell. They advance next round. Guard cards and prior-round losses are excluded.", "Choose a small circle on the field. Destroy every Marcher inside, friend or enemy.", "Draw 1–3 cards: 20% one, 50% two, 30% three."][wish_choice.selected] + "\nSuccess creates a hidden Price due in 1–3 rounds."

func _update_direct_ui() -> void:
	super._update_direct_ui()
	if wish_box == null:
		return
	_wish_targets()
	wish_box.visible = _human_lord() == "Kanifous" or _visible_world.get("breach_wish_access", [false, false])[0]
	wish_button.text = ("QUEUE " if wish_choice.selected == 4 else "CHOOSE TARGET · ") + ("BREACH WISH" if _using_breach_wish() else "WISH")
	if _using_breach_wish():
		if not _human_alive():
			status.text = "Your Lord is banished. An optional Breach Wish remains available."
		wish_note.text += "\nBREACH WISH — HEAVIER PRICE\nStone, Soul, Ruin and Lord banishment have double their normal draw weight. Due in 1–3 rounds; ineligible outcomes are excluded."
	lanes.void_active = _visible_world.get("void_active", false)
	void_overlay.visible = _visible_world.get("void_active", false)
	wish_visual.bind_world(_visible_world)
	var has_wish: bool = queued.any(func(row: Dictionary) -> bool: return Kanifous.is_wish(row.power_id))
	wish_button.disabled = not _planning() or not powers_step or (not _human_alive() and not _using_breach_wish()) or has_wish or (Kanifous.Wishes[wish_choice.selected] == "WishLongevity" and wish_castles.is_empty())
	wish_remove.visible = has_wish
	price_note.text = ""
	for price in _visible_world.get("wish_prices", []):
		price_note.text += "%s%s Price: %s\n" % ["Your" if price.owner == 0 else "Enemy", " Breach" if price.get("breach", false) else "", "Overdue · still owed" if price.due_round < session.round_number() else "Round %d" % price.due_round]
	if wish_placement.visible or resurrection_placement.visible:
		confirm.disabled = true
		pass_button.disabled = true
		phase_prompt.set_presenting(false)

func _queue_wish() -> void:
	if wish_button.disabled:
		return
	var power: String = Kanifous.Wishes[wish_choice.selected]
	var target: Dictionary = {}
	if power == "WishDeath":
		wish_placement.open()
		_refresh()
		return
	if power == "WishResurrection":
		resurrection_placement.open()
		_refresh()
		return
	if power in ["WishPower", "WishLongevity"]:
		_intent = power
		_target = {}
		_interaction_error = ""
		_refresh()
		_reveal_targets()
		return
	_queue_valak(session.declaration(_wish_power(power), queued.size(), target))

func _is_lane_power(power: String) -> bool:
	return power == "WishPower" or super._is_lane_power(power)

func _board_power_targeting() -> bool:
	return _intent == "WishLongevity" or super._board_power_targeting()

func _target_allowed(target: Dictionary, intent: String) -> bool:
	if intent == "WishLongevity":
		return _planning() and powers_step and (_human_alive() or _using_breach_wish()) and target.get("kind") == "castle" and Kanifous.longevity_target(_entity(str(target.get("id", ""))), 0)
	return super._target_allowed(target, intent)

func _guide() -> String:
	if _intent == "WishPower":
		return "WISH OF POWER · click the Lord or Castle marching lane on the battlefield to choose where your Marchers appear."
	if _intent == "WishLongevity":
		return "WISH OF LONGEVITY · click one of your highlighted Castles on the board. Repair it up to %d Integrity." % Kanifous.LONGEVITY_INTEGRITY
	return super._guide()

func _submit_power(target: Dictionary) -> void:
	if _intent not in ["WishPower", "WishLongevity"]:
		super._submit_power(target)
		return
	if not _planning() or not powers_step or (not _human_alive() and not _using_breach_wish()): return
	var payload: Dictionary
	if _intent == "WishPower":
		if target.get("lane") not in ["Lord", "Castle"]: return
		payload = {"lane": target.lane}
	else:
		if not _target_allowed(target, _intent): return
		payload = {"entity_id": target.id}
	_queue_valak(session.declaration(_wish_power(_intent), queued.size(), payload))

func _confirm_wish_death(target: Dictionary) -> void:
	if _queue_valak(session.declaration(_wish_power("WishDeath"), queued.size(), target)):
		wish_placement.close()
		_refresh()
		reopen_decision()

func _confirm_resurrection(target: Dictionary) -> void:
	if _queue_valak(session.declaration(_wish_power("WishResurrection"), queued.size(), target)):
		resurrection_placement.close()
		_refresh()
		reopen_decision()

func _remove_wish() -> void:
	for index in range(queued.size()):
		if Kanifous.is_wish(queued[index].power_id):
			_remove_valak(index)
			return

func _planning() -> bool:
	return (wish_placement == null or not wish_placement.visible) and (resurrection_placement == null or not resurrection_placement.visible) and super._planning()


func _complete_job() -> void:
	var previous = session
	var operation: String = _job_operation
	super._complete_job()
	if session != previous and price_visual != null:
		price_visual.present(session.kanifous_events, sides)
	if session != previous and operation == "marching" and wish_visual != null:
		wish_visual.play_events(session.kanifous_events)
		var victims: Array = death_wish_visual.play_events(session.kanifous_events)
		for victim in victims:
			# Super installed the post-resolution picture in this same call. Restore
			# these presentation-only chits until the skull reaches its impact frame.
			lanes.deaths.visible = lanes.deaths.visible.filter(func(row): return row.unit.id != victim.id)
			lanes.deaths.seen.erase(victim.id)
			lanes._units = lanes._units.filter(func(row): return row.id != victim.id)
			lanes._units.append(victim)
		lanes.queue_redraw()

func _process(delta: float) -> void:
	if death_wish_visual != null and death_wish_visual.active() and not _resolution_pending() and not artillery_view.active():
		death_wish_visual.advance(delta)
		return
	super._process(delta)
	if wish_visual != null and playing:
		wish_visual.show_time(clock)

func finish_playback(skip: bool = true) -> void:
	if death_wish_visual != null:
		death_wish_visual.clear()
	super.finish_playback(skip)
	if wish_visual != null:
		wish_visual.playback_time = -1.0
		wish_visual.bind_world(session.board_view().world)

func _reset_direct() -> void:
	if death_wish_visual != null:
		death_wish_visual.clear()
	if wish_placement != null:
		wish_placement.close()
	if resurrection_placement != null:
		resurrection_placement.close()
	super._reset_direct()


func _death_wish_impact(details: Dictionary) -> void:
	var rows: Array = []
	for victim in details.get("victims", []):
		lanes._units = lanes._units.filter(func(unit): return unit.id != victim.id)
		rows.append({"unit": victim})
	lanes.show_deaths(rows)
	lanes.queue_redraw()

func _using_breach_wish() -> bool:
	return _visible_world.get("breach_wish_access", [false, false])[0] and not (_human_lord() == "Kanifous" and _human_alive())

func _wish_power(power: String) -> String:
	return "Breach" + power if _using_breach_wish() else power
