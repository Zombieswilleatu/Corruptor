extends Control

# Shared by standalone scenes and the in-board gallery. Closing an embedded
# preview releases that scene; only a standalone preview exits the application.
signal close_requested
var embedded: bool = false


func _close_preview(exit_code: int = 0) -> void:
	if embedded:
		close_requested.emit()
	else:
		get_tree().quit(exit_code)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close_preview()
