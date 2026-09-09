extends "res://Prototype/U13/U13VisualPreview.gd"

const View = preload("res://Prototype/U13/U13GemDaggerView.gd")
const Card = preload("res://Prototype/U13/U13LayoutCard.gd")
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const Scenario = preload("res://Scripts/Sim/U13KalliganScenario.gd")
const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
var animation
var guard_box: HBoxContainer
var status: Label
var looping: bool = true
var speed: float = 1.0
var gap: float = 0.0
var events: Array = []
var guard: Dictionary = {}


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("111211")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var column := VBoxContainer.new()
	column.position = Vector2(30, 25)
	column.add_theme_constant_override("separation", 18)
	add_child(column)
	var title := Label.new()
	title.text = "GREMORY · GEM DAGGER"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var note := Label.new()
	note.text = "Gremory is in the Breach. A Guard falls, then both players draw at impact."
	column.add_child(note)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 16)
	column.add_child(controls)
	var replay := Button.new()
	replay.text = "REPLAY DAGGER"
	replay.pressed.connect(play)
	controls.add_child(replay)
	var loop := CheckButton.new()
	loop.text = "Loop"
	loop.button_pressed = true
	loop.toggled.connect(func(value: bool) -> void: looping = value)
	controls.add_child(loop)
	var slow := CheckButton.new()
	slow.text = "Slow motion"
	slow.toggled.connect(func(value: bool) -> void: speed = 0.25 if value else 1.0)
	controls.add_child(slow)
	var close := Button.new()
	close.text = "Back / Exit"
	close.pressed.connect(_close_preview.bind(0))
	controls.add_child(close)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 20)
	column.add_child(status)
	guard_box = HBoxContainer.new()
	guard_box.add_theme_constant_override("separation", 26)
	add_child(guard_box)
	var world: Dictionary = Scenario.world()
	world.data.breach_lord = "Gremory"
	for row in world.entities.entities:
		if (
			row.kind == "card"
			and row.attributes.get("role") == "guard"
			and row.attributes.slot == 1
		):
			guard = row
			break
	for slot in range(3):
		var card = Card.new()
		card.custom_minimum_size = Vector2(160, 240)
		guard_box.add_child(card)
		card.bind_art(
			Art.texture_for(guard.attributes.suit, guard.attributes.value),
			"TRIGGERING GUARD" if slot == 1 else "GUARD",
			"Preview only"
		)
		card.input_surface.set_meta("owner_id", guard.owner)
	var hit: Dictionary = Battle.apply(
		world,
		{"command_id": "gem-preview", "kind": "defeat_guard", "target_id": guard.id},
		1,
		Timeline.COMBAT_RESOLUTION
	)
	var reaction: Dictionary = Gremory.react(hit.world, hit.event, "gem-preview", [0, 1])
	events = [hit.event]
	for row in reaction.events:
		if row.views[0] != null:
			events.append(row.views[0])
	animation = View.new()
	add_child(animation)
	animation.impact.connect(_impact)
	resized.connect(_layout)
	_layout()
	play()


func _layout() -> void:
	guard_box.position = Vector2((size.x - 532) * 0.5, maxf(270, size.y * 0.45))


func play() -> void:
	guard_box.get_child(1).modulate = Color.WHITE
	status.text = "Dagger falling · draws pending"
	gap = 0.0
	animation.play_events(
		events,
		[
			{
				"lord_card": guard_box.get_child(0),
				"lord_guard_box": guard_box,
				"castle_guard_box": guard_box
			}
		]
	)


func _impact(_shot: Dictionary) -> void:
	guard_box.get_child(1).modulate = Color(1, 1, 1, 0.18)
	status.text = "IMPACT · Guard defeated · You +1 card · Opponent +1 card"


func _process(delta: float) -> void:
	if animation == null:
		return
	if animation.active():
		animation.advance(delta * speed)
	elif looping:
		gap += delta
		if gap >= 1.4:
			play()
