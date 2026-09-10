extends "res://Prototype/U13/U13KroniBoard.gd"

const Valak = preload("res://Scripts/Sim/U13Valak.gd")
var valak_box: VBoxContainer
var essence_note: Label
var projection_zone: OptionButton
var projection_spend: SpinBox
var projection_button: Button
var gravity_button: Button
var valak_queue: VBoxContainer
var gravity_placement
var valak_effects


func _power_name(power: String) -> String:
	return "Gravity Orb" if power == Valak.ORB else super._power_name(power)


func _build() -> void:
	super._build()
	if not _direct():
		return
	valak_box = VBoxContainer.new()
	valak_box.add_theme_constant_override("separation", 10)
	powers_box.add_child(valak_box)
	powers_box.move_child(valak_box, 0)
	essence_note = _label(valak_box, "", 15)
	essence_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(valak_box, "PROJECTION · GUARD ZONE", 18)
	projection_zone = _option(valak_box, ["Enemy Lord guards", "Enemy Castle guards"])
	projection_spend = SpinBox.new()
	projection_spend.min_value = 1
	projection_spend.max_value = 5
	projection_spend.step = 1
	projection_spend.value = 1
	projection_spend.prefix = "Essence to spend: "
	valak_box.add_child(projection_spend)
	projection_button = _button(valak_box, "QUEUE PROJECTION", _queue_projection)
	var note: Label = _label(valak_box, "After combat: defeat the highest-value Guard at or below your chosen spend. An empty zone or miss still spends the Essence. No refund from Projection kills.", 13)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gravity_button = _button(valak_box, "GRAVITY ORB", _begin_gravity)
	note = _label(valak_box, "Pulls both armies; touching Marchers are destroyed. Four kills create one Neutral Tear per Orb. Active for two rounds, then two-round cooldown.", 13)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	valak_queue = VBoxContainer.new()
	valak_box.add_child(valak_queue)
	gravity_placement = preload("res://Prototype/U13/U13GravityPlacement.gd").new()
	add_child(gravity_placement)
	gravity_placement.battlefield = lanes
	gravity_placement.confirmed.connect(_confirm_gravity)
	gravity_placement.cancelled.connect(_cancel_gravity)
	valak_effects = preload("res://Prototype/U13/U13ValakEffects.gd").new()
	add_child(valak_effects)
	valak_effects.sides = sides
	valak_effects.battlefield = lanes


func _update_direct_ui() -> void:
	super._update_direct_ui()
	if valak_box == null:
		return
	valak_box.visible = _human_lord() == "Valak"
	if gravity_placement.visible:
		confirm.disabled = true
		pass_button.disabled = true
		phase_prompt.set_presenting(false)
	if valak_effects != null:
		valak_effects.bind_world(_visible_world)
	if not valak_box.visible:
		return
	var amount: int = int(_visible_world.get("life_essence", [0, 0])[0])
	essence_note.text = "LIFE ESSENCE %d / 5\nHunt / Siege guard kills: +2 each. Unreserved Essence absorbs incoming Hunt strength after Ward." % amount
	projection_spend.max_value = maxi(1, amount)
	for power in Valak.VALAK_POWERS:
		var button: Button = projection_button if power == Valak.PROJECTION else gravity_button
		var state: Dictionary = session.power_status(power)
		button.disabled = not _planning() or not powers_step or not _human_alive() or _queued_power(power) or int(state.remaining) > 0 or int(state.fire_round) > 0 or (power == Valak.PROJECTION and amount == 0) or state.awaiting_expiration
		button.text = ("QUEUE PROJECTION" if power == Valak.PROJECTION else "GRAVITY ORB") + (" · QUEUED" if _queued_power(power) else (" · ACTIVE" if state.awaiting_expiration else (" · READY ROUND %d" % state.ready_round if int(state.remaining) > 0 else "")))
	for child in valak_queue.get_children():
		valak_queue.remove_child(child)
		child.queue_free()
	for index in range(queued.size()):
		var source: Dictionary = queued[index]
		if source.power_id in Valak.VALAK_POWERS:
			var row := HBoxContainer.new()
			valak_queue.add_child(row)
			_label(row, ("Projection: %d → %s guards" % [source.parameters.spend, source.target.zone]) if source.power_id == Valak.PROJECTION else "Gravity Orb queued", 13)
			_button(row, "REMOVE", _remove_valak.bind(index))


func _queue_projection() -> void:
	if projection_button.disabled:
		return
	var source: Dictionary = session.declaration(Valak.PROJECTION, queued.size(), {"kind": "guard_zone", "player_id": 1, "zone": "Lord" if projection_zone.selected == 0 else "Castle"})
	source.parameters = {"spend": int(projection_spend.value)}
	_queue_valak(source)


func _queue_valak(source: Dictionary) -> bool:
	var draft: Array = queued.duplicate(true)
	draft.append(source)
	if _error(session.choose(draft, _order())):
		return false
	queued = draft
	_refresh()
	reopen_decision()
	return true


func _remove_valak(index: int) -> void:
	var draft: Array = queued.duplicate(true)
	draft.remove_at(index)
	for i in range(draft.size()):
		draft[i].queue_index = i
		draft[i].declaration_id = Valak.MatchOwner.declaration_id(0, session.round_number(), i)
	if not _error(session.choose(draft, _order())):
		queued = draft
		_refresh()
		reopen_decision()


func _begin_gravity() -> void:
	if gravity_button.disabled:
		return
	gravity_placement.open()
	_refresh()
	phase_prompt.set_presenting(false)


func _confirm_gravity(target: Dictionary) -> void:
	if _queue_valak(session.declaration(Valak.ORB, queued.size(), target)):
		gravity_placement.close()
		_refresh()
		reopen_decision()


func _cancel_gravity() -> void:
	gravity_placement.close()
	_refresh()
	reopen_decision()


func _complete_job() -> void:
	var previous = session
	var operation: String = _job_operation
	super._complete_job()
	if session != previous and operation == "marching" and valak_effects != null:
		valak_effects.bind_world(_visible_world)
		valak_effects.play(session.valak_events)


func _process(delta: float) -> void:
	if _job == null and valak_effects != null and valak_effects.active() and not artillery_view.active() and not gem_dagger_view.active() and not odradek_effects.active():
		valak_effects.advance(delta)
		phase_prompt.set_presenting(false)
		_busy_label.text = "Valak…"
		return
	super._process(delta)
	if valak_effects != null and not valak_effects.active():
		valak_effects.advance(delta)


func finish_playback(skip: bool = true) -> void:
	if valak_effects != null:
		valak_effects.clear()
	super.finish_playback(skip)


func _reset_direct() -> void:
	if valak_effects != null:
		valak_effects.clear()
	if gravity_placement != null:
		gravity_placement.close()
	super._reset_direct()


func _planning() -> bool:
	return (valak_effects == null or not valak_effects.active()) and super._planning()
