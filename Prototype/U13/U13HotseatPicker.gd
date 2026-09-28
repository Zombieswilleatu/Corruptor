extends "res://Prototype/U13/U13LoadoutPicker.gd"
var play_mode: OptionButton
var replay_mode: OptionButton
var hotseat_note: Label

func _ready() -> void:
	super._ready()
	var column: Node = message.get_parent()
	var row := HBoxContainer.new()
	column.add_child(row)
	column.move_child(row, 1)
	_label(row, "PLAY MODE", 16)
	play_mode = _option(row, ["Solo · doctrine opponent", "Hotseat · two players"])
	_label(row, "RESOLUTION", 16)
	replay_mode = _option(row, ["Watch on your turn", "Watch together"])
	hotseat_note = _label(column, "", 14)
	column.move_child(hotseat_note, 2)
	play_mode.item_selected.connect(func(_index): _hotseat_mode_changed())
	_hotseat_mode_changed()

func hotseat_enabled() -> bool:
	return play_mode != null and play_mode.selected == 1
func watch_mode() -> String:
	return "together" if replay_mode.selected == 1 else "own_turn"
func _hotseat_mode_changed() -> void:
	replay_mode.disabled = not hotseat_enabled()
	hotseat_note.visible = hotseat_enabled()
	hotseat_note.text = "P1 → P2, then P2 → P1. Each turn includes your draws, Slaver, planning and commitment. Pass only when the privacy screen appears."
	_relabel(_loadout_content)
func _relabel(node: Node) -> void:
	if node is Label:
		if node.text in ["YOU", "PLAYER 1"]: node.text = "PLAYER 1" if hotseat_enabled() else "YOU"
		elif node.text.begins_with("Play to Dominion, Ritual or Final Collapse"):
			node.text = node.text.replace("against the doctrine bot", "against the other player") if hotseat_enabled() else node.text.replace("against the other player", "against the doctrine bot")
		elif node.text in ["DOCTRINE OPPONENT", "PLAYER 2"]: node.text = "PLAYER 2" if hotseat_enabled() else "DOCTRINE OPPONENT"
	for child in node.get_children(): _relabel(child)
