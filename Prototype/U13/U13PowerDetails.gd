extends Node

# Original labels remain live text sources; targeting callbacks are untouched.
var rows: Array = []

func install(board) -> void:
	fold_state(board.war_state, "Extra Siege Engine shot")
	fold_state(board.rout_state, "Retreat and expose enemies")
	fold_state(board.predator_state, "Summon %d Vultures" % board.Gremory.PREDATOR_COUNT)
	fold_state(board.ruin_state, "Castle to 8 next round")
	for power in board.humbaba_states:
		fold_state(board.humbaba_states[power], "Summon 3 Penitents" if power == "MusterTheFaithful" else "Heal and hasten allies")
	for power in board.kalligan_states:
		fold_state(board.kalligan_states[power], "Prepare or move fire" if power == "Inferno" else "Extra Scorch pulse")
	for pair in [
		[board.consume_button, "Eat a Guard next round"],
		[board.ravenous_button, "Devour field Marchers"],
		[board.projection_button, "Spend Essence to kill a Guard"],
		[board.gravity_button, "Pull units into a lethal core"],
		[board.redirect_button, "Move units to the other lane"],
		[board.false_orders_button, "Move a Guard next round"],
		[board.shift_button, "Convert enemy Marchers"],
		[board.inversion_button, "Destroy a Guard; gain up to 3 copies this round"]
	]:
		var button: Button = pair[0]
		var next: int = button.get_index() + 1
		if next < button.get_parent().get_child_count():
			var note = button.get_parent().get_child(next)
			if note is Label: fold([note], str(pair[1]))
	for note in [board.orias_note, board.odradek_note, board.kroni_note, board.essence_note]:
		fold([note], "", note)
	fold([board.wish_note], "", null, false, board.wish_choice)
	for child in board.odradek_box.get_children():
		if child is Label and child.text.begins_with("Psychic Interlock"):
			fold([child], "Psychic Interlock / Breach")
	# Headings whose dropdowns are hidden in board-targeting mode.
	for section in [board.deimos_box, board.gremory_box.get_node("PredatorOfRuinSection"), board.gremory_box.get_node("InevitableRuinSection")]:
		for child in section.get_children():
			if child is Label and child.text in ["Your Siege Engine", "Enemy lane", "Spawn lane", "Enemy Castle target"]: child.hide()
	sync()

func fold_state(state: Label, brief: String) -> void:
	var sources: Array = []
	var index: int = state.get_index()
	if index > 0:
		var previous = state.get_parent().get_child(index - 1)
		if previous is Label and previous.get_theme_font_size("font_size") <= 14 and not previous.text.is_empty(): sources.append(previous)
	sources.append(state)
	fold(sources, brief, state, true)

func fold(sources: Array, brief: String, state: Label = null, compact_state: bool = false, choice: OptionButton = null) -> void:
	var source: Label = sources[0]
	var parent: Node = source.get_parent()
	var index: int = source.get_index()
	var group := VBoxContainer.new()
	group.name = "PowerExplanation"
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_theme_constant_override("separation", 4)
	parent.add_child(group)
	parent.move_child(group, index)
	var summary := Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 13)
	group.add_child(summary)
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.flat = true
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.custom_minimum_size.y = 26
	toggle.add_theme_font_size_override("font_size", 12)
	group.add_child(toggle)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 13)
	group.add_child(body)
	for label in sources:
		label.reparent(group)
		label.hide()
	var row_index: int = rows.size()
	rows.append({"sources": sources, "summary": summary, "body": body, "toggle": toggle, "brief": brief, "state": state, "compact_state": compact_state, "choice": choice, "expanded": false, "last_text": null})
	toggle.pressed.connect(_toggle.bind(row_index))
	_sync_row(rows[row_index])

func _toggle(index: int) -> void:
	var row: Dictionary = rows[index]
	row.expanded = not row.expanded
	_sync_row(row, true)

func _process(_delta: float) -> void:
	sync()

func sync() -> void:
	for row in rows: _sync_row(row)

static func status_summary(copy: String) -> String:
	if copy.strip_edges().is_empty(): return ""
	var lines: PackedStringArray = copy.split("\n")
	var status: String = str(lines[0]).replace("Ready · cooldown 0", "Ready").replace("Queued · not spent yet", "Queued")
	var cost: String = ""
	var notes: PackedStringArray = []
	for line in lines:
		if line.begins_with("Free ·"): cost = "Free"
		elif line.begins_with("Discard "): cost = line.get_slice(" ·", 0)
		elif line.begins_with("No operational Siege Engine"): status = "Unavailable · no Siege Engine"
		elif line.begins_with("No eligible enemy Castle"): status = "Unavailable · no Castle target"
		elif line.begins_with("Not enough uncommitted cards"): status = "Unavailable · need 2 cards"
		elif line.begins_with("Armed ·") or line.begins_with("Round "): notes.append(line)
	if not cost.is_empty(): status += " · " + cost
	if not notes.is_empty(): status += "\n" + "\n".join(notes)
	return status

func _sync_row(row: Dictionary, force: bool = false) -> void:
	var parts: PackedStringArray = []
	for source in row.sources:
		if not source.text.strip_edges().is_empty(): parts.append(source.text.strip_edges())
	var copy: String = "\n".join(parts)
	var brief: String = row.brief
	if row.choice != null:
		brief = ["Summon 1–3 Marchers", "Repair a Castle to 8", "Revive this round's losses", "Destroy units in a circle", "Draw 1–3 cards"][row.choice.selected]
	if not force and row.last_text == [copy, brief]: return
	row.last_text = [copy, brief]
	if row.state != null:
		var state_text: String = row.state.text.strip_edges()
		var status: String = status_summary(state_text) if row.compact_state else state_text.get_slice("\n", 0)
		if not row.compact_state:
			for line in state_text.split("\n"):
				if line.begins_with("THIS TURN:"): status += "\n" + line
		if not status.is_empty(): brief += ("\n" if not brief.is_empty() else "") + status
	row.summary.text = brief
	row.summary.visible = not brief.is_empty()
	row.toggle.visible = not copy.is_empty() and copy != brief
	row.toggle.text = "▾ DETAILS" if row.expanded else "▸ DETAILS"
	row.toggle.set_pressed_no_signal(row.expanded)
	row.body.text = copy
	row.body.visible = row.expanded and row.toggle.visible
