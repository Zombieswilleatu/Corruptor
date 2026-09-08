extends Control

# UI2 PlayerBoard's overlapping, clickable card stacks, bound to U13 IDs.
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
var _positions: Dictionary = {}
var _stacks: Array = []
var _return_card: Callable
var _drop_card: Callable
var _can_drop: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 12


func show_orders(
	stacks: Array, return_card: Callable, can_drop: Callable, drop_card: Callable
) -> void:
	_stacks = stacks
	_return_card = return_card
	_can_drop = can_drop
	_drop_card = drop_card
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var current: Dictionary = {}
	for stack in stacks:
		if stack.cards.is_empty() or not is_instance_valid(stack.anchor):
			continue
		var rect: Rect2 = stack.anchor.get_global_rect()
		var spacing: float = minf(30.0, 150.0 / float(maxi(1, stack.cards.size())))
		var width: float = 48.0 + float(stack.cards.size() - 1) * spacing
		var origin := (
			Vector2(rect.get_center().x - width * 0.5, rect.get_center().y - 34) - global_position
		)
		if String(stack.role).begins_with("ruin"):
			origin.y = rect.end.y - 74 - global_position.y
		var label := Label.new()
		label.text = stack.label
		label.position = origin + Vector2(0, -22)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_outline_size", 3)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		for index in range(stack.cards.size()):
			var entity: Dictionary = stack.cards[index]
			var button := Button.new()
			button.size = Vector2(48, 68)
			var destination: Vector2 = origin + Vector2(float(index) * spacing, 0)
			button.position = destination
			button.tooltip_text = (
				"%s %d · %s · click to return"
				% [entity.attributes.suit, entity.attributes.value, stack.label]
			)
			var texture: Texture2D = Art.texture_for(
				entity.attributes.suit, int(entity.attributes.value)
			)
			var skin := StyleBoxTexture.new()
			skin.texture = texture
			button.add_theme_stylebox_override("normal", skin)
			button.add_theme_stylebox_override("hover", skin)
			button.add_theme_stylebox_override("pressed", skin)
			add_child(button)
			button.pressed.connect(_return_card.bind(stack.role, entity.id))
			button.set_drag_forwarding(
				Callable(), _can_drop.bind(stack.target), _drop_card.bind(stack.target)
			)
			var key: String = stack.role + ":" + entity.id
			current[key] = stack.target
			if not _positions.has(key) or _positions[key] != stack.target:
				button.position = stack.from_position - global_position
				button.create_tween().tween_property(button, "position", destination, 0.18)
	_positions = current
