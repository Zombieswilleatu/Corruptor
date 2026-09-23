extends Control

const Tape = preload("res://Prototype/U13/U13ResolutionTape.gd")
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const Castles = preload("res://Prototype/UI2/CastleArtCatalog.gd")
var _steps: Array = []
var _index: int = 0
var _elapsed: float = 0.0
var _begun: bool = false
var _sides: Array = []
var _world: Dictionary = {}
var _copies: Array = []
var _hidden: Array = []
var _attackers: Array = []
var _label: Label
var _damage_before: int = 0
var _damage_shown: int = -1
var _hit: Dictionary = {}
var _attack_pid: int = 0
var _lane: String = "Castle"
var _target_id: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 90
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 23)
	_label.add_theme_color_override("font_color", Color("f4dfab"))
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_outline_size", 8)
	add_child(_label)
	hide()

func play(presentation: Dictionary, sides: Array) -> void:
	clear()
	_steps = Tape.build(presentation)
	_sides = sides
	if active():
		_world = presentation.before.world.duplicate(true)

func active() -> bool:
	return _index < _steps.size()

func clear() -> void:
	_clear_copies()
	_clear_attackers()
	_steps = []
	_sides = []
	_world = {}
	_index = 0
	_elapsed = 0.0
	_begun = false
	hide()

func advance(delta: float) -> bool:
	if not active(): return false
	var step: Dictionary = _steps[_index]
	if not _begun:
		_begin(step)
		_begun = true
	_elapsed = minf(float(step.seconds), _elapsed + maxf(0.0, delta))
	_pose(step, _elapsed / float(step.seconds))
	if _elapsed >= float(step.seconds):
		_complete(step)
		_clear_copies()
		_index += 1
		_elapsed = 0.0
		_begun = false
		if not active():
			_clear_attackers()
			hide()
	return true

func _side(pid: int):
	for side in _sides:
		if int(side.lord_card.input_surface.get_meta("owner_id", -1)) == pid: return side
	return null

func _point(control: Control) -> Vector2:
	return get_global_transform().affine_inverse() * control.get_global_rect().get_center()

func _target(id: String, pid: int) -> Vector2:
	var side = _side(pid)
	if side == null: return size * 0.5
	var surface = side.target_controls.get(id)
	if is_instance_valid(surface): return _point(surface)
	return _point(side.lord_card if _lane == "Lord" else side.castle_row)

func _origin(pid: int, lane: String) -> Vector2:
	var side = _side(pid)
	if side == null: return size * 0.5
	var center: Vector2 = _point(side.lord_guard_box if lane == "Lord" else side.castle_row)
	return center + Vector2(0, -90 if pid == 0 else 90)

func _entity(id: String) -> Dictionary:
	for row in _world.get("entities", []):
		if row.id == id: return row
	return {}

func _copy(row: Dictionary, dimensions: Vector2 = Vector2(76, 110)) -> Control:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = dimensions
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171515")
	style.border_color = Color("b8a071")
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var face := TextureRect.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(face)
	var a: Dictionary = row.attributes
	if row.kind == "card": face.texture = Art.texture_for(a.suit, a.value, _world.get("void_active", false))
	elif row.kind == "castle": face.texture = Art.texture(Castles.ART_PATHS.get(a.castle_type, ""))
	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	title.offset_top = -24
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_outline_size", 5)
	title.text = String(a.get("castle_type", a.get("suit", "")))
	if row.kind == "card" and not _world.get("void_active", false): title.text += " %d" % int(a.value)
	panel.add_child(title)
	return panel

func _begin(step: Dictionary) -> void:
	show()
	_damage_shown = -1
	_hit = {}
	match step.kind:
		"advance":
			_clear_attackers()
			_attack_pid = step.pid
			_lane = step.lane
			_target_id = step.target_id
			for row in step.cards: _attackers.append(_copy(row))
			_label.text = ("YOUR " if step.pid == 0 else "ENEMY ") + ("SIEGE" if _lane == "Castle" else "HUNT")
			if not _world.get("void_active", false): _label.text += " · %d STRENGTH" % int(step.result.strength)
		"ward":
			_label.text = "WARD INTERCEPTS" if _world.get("void_active", false) else "WARD SCREEN · %d" % int(step.amount)
			for row in step.cards: _copies.append({"node": _copy(row), "start": _ward_origin(step), "dead": false})
		"guards":
			_label.text = "GUARDS DEFEND"
			if int(step.pair_screen) > 0: _label.text += " · BONDED SCREEN"
			var side = _side(step.pid)
			for row in step.cards:
				var dead: bool = false
				for lost in step.deaths:
					if lost.id == row.id: dead = true
				var start: Vector2 = _origin(step.pid, step.lane)
				if side != null:
					var box = side.lord_guard_box if step.lane == "Lord" else side.castle_guard_box
					var slot: int = int(row.attributes.slot)
					if slot < box.get_child_count():
						var source = box.get_child(slot)
						start = _point(source)
						_hide_source(source)
				_copies.append({"node": _copy(row), "start": start, "dead": dead})
		"sigil": _label.text = "SIGIL BROKEN"
		"intercept", "impact":
			_hit = _entity(step.hit_id)
			if not _hit.is_empty() and _hit.kind == "castle":
				_damage_before = int(step.result.get("integrity_before", _hit.attributes.integrity))
				if step.kind == "intercept":
					_label.text = String(_hit.attributes.castle_type).to_upper() + " INTERPOSES"
					_copies.append({"node": _copy(_hit, Vector2(100, 144)), "start": _target(step.hit_id, step.pid), "dead": false})
					var side = _side(step.pid)
					if side != null:
						var surface = side.target_controls.get(step.hit_id)
						if is_instance_valid(surface): _hide_source(surface.get_parent().get_parent())
				else: _label.text = "IMPACT" if int(step.result.get("damage", 0)) > 0 else "ATTACK HELD"
			elif step.result.get("pillage", false): _label.text = "PILLAGE · +1 SOUL" if step.result.get("pillage_success", false) else "PILLAGE STOPPED"
			else: _label.text = "LORD BANISHED" if step.result.get("banished", false) else "LORD WITHSTANDS THE HUNT"

func _ward_origin(step: Dictionary) -> Vector2:
	var side = _side(step.pid)
	if side == null: return _origin(step.pid, step.lane)
	return _point(side.ward_lord_overlay if step.lane == "Lord" else side.ward_castle_overlay)

func _pose(step: Dictionary, t: float) -> void:
	var end: Vector2 = _target(_target_id, 1 - _attack_pid)
	var direction: float = 1.0 if _attack_pid == 0 else -1.0
	var contact: Vector2 = end + Vector2(0, direction * 85)
	var center: Vector2 = contact
	if step.kind == "advance":
		var travel: float = smoothstep(0.2, 1.0, t)
		center = _origin(_attack_pid, _lane).lerp(contact, travel) + Vector2(sin(travel * PI) * 40, 0)
	elif step.kind == "impact": center = contact.lerp(end, sin(t * PI) * 0.40)
	for index in range(_attackers.size()):
		var card: Control = _attackers[index]
		var offset: float = (float(index) - float(_attackers.size() - 1) * 0.5) * minf(54.0, 260.0 / maxf(1.0, float(_attackers.size())))
		card.position = center + Vector2(offset, absf(offset) * 0.10) - card.size * 0.5
		card.rotation = offset * 0.0015
	for index in range(_copies.size()):
		var item: Dictionary = _copies[index]
		var node: Control = item.node
		var offset: float = (float(index) - float(_copies.size() - 1) * 0.5) * 50.0
		var jump: float = smoothstep(0.0, 0.35, t)
		if step.kind in ["ward", "guards"] and not item.dead: jump *= 1.0 - smoothstep(0.65, 1.0, t)
		node.position = Vector2(item.start).lerp(end + Vector2(offset, direction * 35), jump) - node.size * 0.5
		if item.dead: node.modulate.a = 1.0 - smoothstep(0.5, 1.0, t)
	if not _hit.is_empty() and _hit.kind == "castle":
		var progress: float = smoothstep(0.30 if step.kind == "intercept" else 0.0, 0.90, t)
		var damage: int = int(step.result.get("damage", 0))
		var value: int = maxi(0, _damage_before - roundi(float(damage) * progress))
		if value != _damage_shown:
			_damage_shown = value
			var attributes: Dictionary = _hit.attributes.duplicate(true)
			attributes.integrity = value
			for side in _sides: side.update_castle_presentation(step.hit_id, attributes)
		if t >= 0.30:
			var prefix: String = String(_hit.attributes.castle_type).to_upper()
			_label.text = prefix + (" · HIT" if _world.get("void_active", false) else " · %d → %d  (−%d)" % [_damage_before, value, damage])
			if t >= 0.9: _label.text += " · RUINED" if step.result.get("destroyed", false) else (" · OFFLINE" if value < 7 else "")
	# Stay in the board domain; never cover the marching lanes or hand.
	_label.size = Vector2(620, 62)
	var right: float = size.x - 12
	var defender = _side(1 - _attack_pid)
	if defender != null and defender.size.x > 0:
		right = minf(right, (get_global_transform().affine_inverse() * defender.get_global_rect().end).x)
	_label.position = Vector2(clampf(end.x - 310, 12, maxf(12, right - 620)), clampf(end.y - direction * 130 - 31, 155, size.y - 150))

func _complete(step: Dictionary) -> void:
	if step.kind == "guards":
		for dead in step.deaths:
			_world.entities = _world.entities.filter(func(row): return row.id != dead.id)
		_rebind(step.pid)
	elif step.kind == "sigil":
		_world.sigils[step.pid][step.lane] = ""
		_rebind(step.pid)
	elif step.kind in ["impact", "intercept"] and not _hit.is_empty():
		if _hit.kind == "castle":
			_hit.attributes.integrity = maxi(0, _damage_before - int(step.result.get("damage", 0)))
			if step.result.get("destroyed", false): _hit.attributes.status = "ruined"
		elif _hit.kind == "lord" and step.result.get("banished", false): _hit.attributes.alive = false
		_rebind(step.pid)

func _rebind(pid: int) -> void:
	# Rebuild only the changed side, never the hand, modal, header, or simulation.
	_clear_hidden()
	var side = _side(pid)
	if side != null: side.bind_world(_world, pid, false)

func _hide_source(control: Control) -> void:
	_hidden.append({"node": control, "modulate": control.modulate})
	control.modulate.a = 0.0

func _clear_hidden() -> void:
	for item in _hidden:
		if is_instance_valid(item.node): item.node.modulate = item.modulate
	_hidden = []

func _clear_copies() -> void:
	_clear_hidden()
	for item in _copies:
		if is_instance_valid(item.node): item.node.queue_free()
	_copies = []

func _clear_attackers() -> void:
	for node in _attackers:
		if is_instance_valid(node): node.queue_free()
	_attackers = []
