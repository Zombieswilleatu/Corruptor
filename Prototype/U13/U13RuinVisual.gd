extends Control

# Presentation only: animate public outcomes without resolving the power again.
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const IMPACT_AT: float = 1.0
const RETURN_AT: float = 2.35
const DURATION: float = 3.0
signal impact(hit: Dictionary)
signal finished
var _hits: Array = []
var _sides: Array = []
var _index: int = 0
var _elapsed: float = 0.0
var _impacted: bool = false
var _from: Vector2
var _to: Vector2
var _card: TextureRect
var _banner: Panel
var _banner_title: Label
var _banner_detail: Label
var _blocked_controls: Array = []
var _held_controls: Array = []
var _prior_focus: WeakRef
var _suppressing: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# A waiting tutorial may have paused the tree. The strike owns its clock
	# and finishes without changing that pause or dismissing the tutorial.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	z_index = 300
	_card = TextureRect.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card.size = Vector2(146, 218)
	_card.pivot_offset = _card.size * 0.5
	add_child(_card)
	# A wrapping Label can retain a huge minimum height when text is assigned
	# before its width. Use a fixed frame and two independent single-line labels.
	_banner = Panel.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color("261524")
	style.border_color = Color("e9a85f")
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	_banner.add_theme_stylebox_override("panel", style)
	add_child(_banner)
	_banner_title = _banner_line(8.0, 18)
	_banner_detail = _banner_line(33.0, 16)
	resized.connect(_layout_banner)
	_layout_banner()
	hide()

func _banner_line(top: float, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("ffe5b0"))
	_banner.add_child(label)
	label.anchor_right = 1.0
	label.offset_left = 8.0
	label.offset_right = -8.0
	label.offset_top = top
	label.offset_bottom = top + 23.0
	return label

func _layout_banner() -> void:
	if _banner == null: return
	var width: float = minf(420.0, maxf(32.0, size.x - 32.0))
	_banner.size = Vector2(width, 64.0)
	_banner.position = Vector2((size.x - width) * 0.5, 16.0)

func _set_banner(hit: Dictionary, impacted: bool) -> void:
	var lines: PackedStringArray = description(hit, impacted).split("\n", false, 1)
	_banner_title.text = lines[0]
	_banner_detail.text = lines[1]
	_layout_banner()

static func collect(events: Array, world: Dictionary) -> Array:
	var hits: Array = []
	for event in events:
		var data: Dictionary = event.get("data", {})
		if event.get("type") != "CASTLE_DAMAGED" or data.get("source") != "InevitableRuin": continue
		if int(data.get("damage", 0)) <= 0: continue
		for entity in world.get("entities", []):
			if entity.id != data.get("castle_id") or entity.kind != "castle": continue
			var hit: Dictionary = data.duplicate(true)
			hit["attributes"] = entity.attributes.duplicate(true)
			hit["before"] = int(data.integrity) + int(data.damage)
			hits.append(hit)
			break
	return hits

static func description(hit: Dictionary, impacted: bool) -> String:
	var castle: String = str(hit.attributes.get("castle_type", "Castle")).replace("SiegeEngine", "Siege Engine").replace("SummoningCircle", "Summoning Circle")
	var detail: String = "%s is struck" % castle
	if impacted:
		detail = "%s · −%d Integrity (%d → %d)" % [castle, hit.damage, hit.before, hit.integrity]
	return "GREMORY · INEVITABLE RUIN\n" + detail

func play_events(events: Array, sides: Array, world: Dictionary, modals: Array = []) -> void:
	clear()
	_hits = collect(events, world)
	_sides = sides
	if not active(): return
	_blocked_controls = modals.duplicate()
	var focus: Control = get_viewport().gui_get_focus_owner()
	_prior_focus = weakref(focus) if focus != null else null
	if focus != null: focus.release_focus()
	for control in _blocked_controls:
		if is_instance_valid(control) and not control.visibility_changed.is_connected(_suppress_modals):
			control.visibility_changed.connect(_suppress_modals)
	_suppress_modals()
	# The worker installed the final board in this same frame. Hold only the
	# affected cards' displayed Integrity until their impact, never game state.
	for hit in _hits:
		_set_integrity(hit, int(hit.before))
	_begin()
	set_process(true)

func _suppress_modals() -> void:
	if not active() or _suppressing: return
	_suppressing = true
	for control in _blocked_controls:
		if not is_instance_valid(control) or not control.visible: continue
		if not _held_controls.any(func(ref): return ref.get_ref() == control):
			_held_controls.append(weakref(control))
		control.hide()
	_suppressing = false

func _process(delta: float) -> void:
	advance(delta)

func active() -> bool:
	return _index < _hits.size()

func _side(pid: int):
	for side in _sides:
		if int(side.lord_card.input_surface.get_meta("owner_id", -1)) == pid: return side
	return null

func _point(control: Control) -> Vector2:
	return get_global_transform().affine_inverse() * control.get_global_rect().get_center()

func _begin() -> void:
	var hit: Dictionary = _hits[_index]
	var attacker = _side(int(hit.player_id))
	var defender = _side(1 - int(hit.player_id))
	_from = _point(attacker.lord_card) if attacker != null else size * 0.5
	var target = defender.target_controls.get(hit.castle_id) if defender != null else null
	_to = _point(target) if is_instance_valid(target) else size * 0.5
	_card.texture = Art.lord_texture("Gremory")
	_card.position = _from - _card.size * 0.5
	_card.rotation = 0.0
	_card.scale = Vector2.ONE
	_set_banner(hit, false)
	show()
	queue_redraw()

func _set_integrity(hit: Dictionary, integrity: int) -> void:
	var attributes: Dictionary = hit.attributes.duplicate(true)
	attributes.integrity = integrity
	for side in _sides:
		side.update_castle_presentation(hit.castle_id, attributes)

func advance(delta: float) -> bool:
	if not active(): return false
	_elapsed += maxf(0.0, delta)
	var hit: Dictionary = _hits[_index]
	if _elapsed >= IMPACT_AT and not _impacted:
		_impacted = true
		_set_integrity(hit, int(hit.integrity))
		_set_banner(hit, true)
		impact.emit(hit.duplicate(true))
	var travel: float = smoothstep(0.3, IMPACT_AT, _elapsed)
	if _elapsed > RETURN_AT: travel = 1.0 - smoothstep(RETURN_AT, DURATION, _elapsed)
	var center: Vector2 = _from.lerp(_to, travel)
	center.y -= sin(travel * PI) * 85.0
	_card.position = center - _card.size * 0.5
	_card.rotation = sin(travel * PI) * 0.12
	_card.scale = Vector2.ONE * (1.0 + 0.12 * sin(travel * PI))
	queue_redraw()
	if _elapsed >= DURATION:
		_index += 1
		_elapsed = 0.0
		_impacted = false
		if active(): _begin()
		else:
			clear()
			finished.emit()
	return true

func _draw() -> void:
	if not active(): return
	var pulse: float = 0.5 + 0.5 * sin(_elapsed * 9.0)
	draw_arc(_to, 84.0 + pulse * 7.0, 0, TAU, 64, Color(1.0, 0.62, 0.25, 0.95), 5.0, true)
	if _impacted:
		var fade: float = clampf(1.0 - (_elapsed - IMPACT_AT) / 0.65, 0.0, 1.0)
		draw_circle(_to, 110.0 - fade * 35.0, Color(1.0, 0.70, 0.30, fade * 0.75))

func clear() -> void:
	set_process(false)
	# Finish any temporary presentation mask when skipped, reset or replaced.
	for hit in _hits:
		for side in _sides:
			if is_instance_valid(side): side.update_castle_presentation(hit.castle_id, hit.attributes)
	_hits = []
	_sides = []
	_index = 0
	_elapsed = 0.0
	_impacted = false
	hide()
	for control in _blocked_controls:
		if is_instance_valid(control) and control.visibility_changed.is_connected(_suppress_modals):
			control.visibility_changed.disconnect(_suppress_modals)
	_blocked_controls = []
	for ref in _held_controls:
		var control = ref.get_ref()
		if is_instance_valid(control): control.show()
	_held_controls = []
	var focus = _prior_focus.get_ref() if _prior_focus != null else null
	if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()
	_prior_focus = null

func _exit_tree() -> void:
	clear()
