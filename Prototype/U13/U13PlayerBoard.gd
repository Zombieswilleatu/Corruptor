extends HBoxContainer

# Layout methods extracted from UI2 PlayerBoard at b8259e4.
const ScorchVisuals = preload("res://Prototype/U13/U13ScorchVisuals.gd")
var scorch_visuals = ScorchVisuals.new()
var scorch_front: Node2D
const Textures = preload("res://Prototype/U13/U13BoardTextures.gd")
const Card = preload("res://Prototype/U13/U13LayoutCard.gd")
const Castles = preload("res://Prototype/UI2/CastleArtCatalog.gd")
const UI2_SHARED_DOMAIN_ALPHA: float = 1.0
const UI2_SHARED_DOMAIN_ENEMY_TOP: float = 0.0
const UI2_SHARED_DOMAIN_ENEMY_BOTTOM: float = 0.5
const UI2_SHARED_DOMAIN_PLAYER_TOP: float = 0.5
const UI2_SHARED_DOMAIN_PLAYER_BOTTOM: float = 1.0
var UI2_SHARED_DOMAIN_TEXTURE: Texture2D
var castle_guards_above_castles: bool = false
const Resummon = preload("res://Scripts/Sim/U13Resummoning.gd")
# Printed ratings from the existing Lord content; independent of return Threat.
const FRACTURE: Dictionary = {
	"Orias": 0, "Deimos": 0, "Gremory": 2, "Humbaba": 2, "Kalligan": 1, "Odradek": 2
}
var lord_group
var lord_guard_group
var castle_group
var lord_card
var _castle_art_states: Dictionary = {}
var lord_absent_label
var lord_sigil
var castle_sigil
var castle_row
var castle_guard_box
var lord_guard_box
var castle_guard_drop_area
var scorch_titles: Dictionary = {}
var direct_targets: bool = false
var target_controls: Dictionary = {}
var commission_buttons: Dictionary = {}
signal commission_requested(castle_id: String)
var ward_lord_overlay
var attack_lord_overlay
var ward_castle_overlay
signal target_selected(action: String, lane: String, target_id: String)


func _ready() -> void:
	# UI2_DOMAIN1_CLEAR_SECTION_BACKGROUNDS_V1
	call_deferred("_apply_domain1_clear_section_backgrounds_v1")
	custom_minimum_size = Vector2(930, 300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_FILL
	add_theme_constant_override("separation", 8)

	UI2_SHARED_DOMAIN_TEXTURE = Textures.texture("res://ConceptImages/Menus/Domain1.png")

	_build_lord_group()
	_build_lord_guards()

	# UI2_PROMPT_CASTLE_GUTTER_V1
	# Reserve a small visual lane for the floating decision prompt. Because the
	# Castle group expands into the remaining width, this 64 px gutter moves the
	# centered Castle spine only about half that distance instead of wasting a
	# huge permanent column.
	var prompt_castle_gutter := Control.new()
	prompt_castle_gutter.name = "PromptCastleGutter"
	# UI2_CASTLE_PREVIEW_INTERACTION_GUTTER_V2
	# The 64 px gutter still let the floating prompt nick the first Castle.
	# Give the prompt a real visual lane while retaining the same overall board.
	prompt_castle_gutter.custom_minimum_size = Vector2(128, 0)
	prompt_castle_gutter.size_flags_horizontal = Control.SIZE_FILL
	prompt_castle_gutter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prompt_castle_gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt_castle_gutter)

	_build_castle_group()
	# Node2D avoids participating in the HBox layout or intercepting card input.
	# Ground stays below cards; translucent flames can lick over their faces.
	scorch_front = Node2D.new()
	scorch_front.name = "GuardFireForeground"
	scorch_front.z_index = 1
	add_child(scorch_front)
	scorch_front.draw.connect(_draw_guard_flames)
	_apply_castle_vertical_order()
	_apply_domain1_clear_section_backgrounds_v1()


func _apply_castle_vertical_order() -> void:
	if (
		castle_group == null
		or castle_row == null
		or castle_guard_drop_area == null
		or castle_group.get_child_count() <= 0
	):
		return

	var column = castle_group.get_child(0)
	if column == null:
		return

	var castle_index: int = castle_row.get_index()
	var guard_index: int = castle_guard_drop_area.get_index()

	if castle_index <= 0 or guard_index <= 0:
		return

	# Each row's header is its immediate previous sibling. Capture the actual
	# nodes before moving anything so repeated calls remain safe in either order.
	var castle_header = column.get_child(castle_index - 1)
	var guard_header = column.get_child(guard_index - 1)

	if castle_header == null or guard_header == null or castle_header == guard_header:
		return

	if castle_guards_above_castles:
		column.move_child(guard_header, 0)
		column.move_child(castle_guard_drop_area, 1)
		column.move_child(castle_header, 2)
		column.move_child(castle_row, 3)
	else:
		column.move_child(castle_header, 0)
		column.move_child(castle_row, 1)
		column.move_child(guard_header, 2)
		column.move_child(castle_guard_drop_area, 3)


func _build_lord_group() -> void:
	lord_group = PanelContainer.new()
	lord_group.name = "LordGroup"
	lord_group.custom_minimum_size = Vector2(180, 0)
	lord_group.size_flags_horizontal = Control.SIZE_FILL
	lord_group.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(lord_group)

	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	lord_group.add_child(column)

	column.add_child(_header_label("LORD"))

	lord_card = Card.new()
	lord_card.custom_minimum_size = Vector2(188, 282)
	lord_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lord_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_child(lord_card)

	lord_absent_label = Label.new()
	lord_absent_label.text = "IN THE BREACH"
	lord_absent_label.visible = false
	lord_absent_label.custom_minimum_size = Vector2(188, 282)
	lord_absent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lord_absent_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lord_absent_label.add_theme_font_size_override("font_size", 14)
	lord_absent_label.add_theme_color_override("font_color", Color(0.54, 0.48, 0.66, 1.0))
	column.add_child(lord_absent_label)

	lord_sigil = _sigil_badge()
	lord_sigil.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(lord_sigil)

	ward_lord_overlay = HBoxContainer.new()
	ward_lord_overlay.name = "WardLordOverlay"
	ward_lord_overlay.alignment = BoxContainer.ALIGNMENT_CENTER
	ward_lord_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ward_lord_overlay.add_theme_constant_override("separation", -12)
	lord_group.add_child(ward_lord_overlay)
	_configure_ward_drop_target(ward_lord_overlay, "Lord")

	attack_lord_overlay = HBoxContainer.new()
	attack_lord_overlay.name = "AttackLordOverlay"
	attack_lord_overlay.alignment = BoxContainer.ALIGNMENT_CENTER
	attack_lord_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attack_lord_overlay.z_index = 6
	attack_lord_overlay.add_theme_constant_override("separation", -16)
	lord_group.add_child(attack_lord_overlay)


func _build_lord_guards() -> void:
	lord_guard_group = PanelContainer.new()
	lord_guard_group.name = "LordGuards"
	lord_guard_group.custom_minimum_size = Vector2(90, 0)
	lord_guard_group.size_flags_horizontal = Control.SIZE_FILL
	lord_guard_group.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(lord_guard_group)

	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	lord_guard_group.add_child(column)

	scorch_titles.Lord = _header_label("LORD\nGUARDS")
	column.add_child(scorch_titles.Lord)

	lord_guard_box = VBoxContainer.new()
	lord_guard_box.alignment = BoxContainer.ALIGNMENT_CENTER
	lord_guard_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lord_guard_box.add_theme_constant_override("separation", 4)
	column.add_child(lord_guard_box)

	_configure_deploy_drop_target(lord_guard_group, "Lord")
	_configure_deploy_drop_target(column, "Lord")
	_configure_deploy_drop_target(lord_guard_box, "Lord")


func _build_castle_group() -> void:
	castle_group = PanelContainer.new()
	castle_group.name = "CastleGroup"
	castle_group.custom_minimum_size = Vector2(660, 0)
	castle_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	castle_group.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(castle_group)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 5)
	castle_group.add_child(column)

	column.add_child(_header_label("CASTLES"))

	castle_row = HBoxContainer.new()
	castle_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	castle_row.alignment = BoxContainer.ALIGNMENT_CENTER
	castle_row.add_theme_constant_override("separation", 8)
	column.add_child(castle_row)

	scorch_titles.Castle = _header_label("CASTLE GUARDS")
	column.add_child(scorch_titles.Castle)

	castle_guard_drop_area = HBoxContainer.new()
	castle_guard_drop_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	castle_guard_drop_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	castle_guard_drop_area.add_theme_constant_override("separation", 8)
	column.add_child(castle_guard_drop_area)

	# Equal reserve opposite the real Sigil keeps Guards truly centered.
	var sigil_balance := Control.new()
	sigil_balance.custom_minimum_size = Vector2(70, 0)
	castle_guard_drop_area.add_child(sigil_balance)

	castle_guard_box = HBoxContainer.new()
	castle_guard_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	castle_guard_box.alignment = BoxContainer.ALIGNMENT_CENTER
	castle_guard_box.add_theme_constant_override("separation", 8)
	castle_guard_drop_area.add_child(castle_guard_box)

	castle_sigil = _sigil_badge()
	castle_sigil.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	castle_guard_drop_area.add_child(castle_sigil)

	_configure_deploy_drop_target(castle_guard_drop_area, "Castle")
	_configure_deploy_drop_target(castle_guard_box, "Castle")

	ward_castle_overlay = HBoxContainer.new()
	ward_castle_overlay.name = "WardCastleOverlay"
	ward_castle_overlay.alignment = BoxContainer.ALIGNMENT_CENTER
	ward_castle_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ward_castle_overlay.add_theme_constant_override("separation", -12)
	castle_group.add_child(ward_castle_overlay)
	_configure_ward_drop_target(ward_castle_overlay, "Castle")


func _header_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	return label


func _sigil_badge() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(70, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = "◈—"
	return label


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _domain_uv_bounds_v1() -> Vector2:
	var n := name.to_lower()

	if n.find("enemy") != -1 or n.find("bot") != -1 or n.find("top") != -1:
		return Vector2(UI2_SHARED_DOMAIN_ENEMY_TOP, UI2_SHARED_DOMAIN_ENEMY_BOTTOM)

	if n.find("human") != -1 or n.find("player") != -1 or n.find("bottom") != -1:
		return Vector2(UI2_SHARED_DOMAIN_PLAYER_TOP, UI2_SHARED_DOMAIN_PLAYER_BOTTOM)

	# Fallback if the board is renamed in the future.
	# Better to show the whole place than fail invisible.
	return Vector2(0.0, 1.0)


func _draw() -> void:
	if UI2_SHARED_DOMAIN_TEXTURE == null:
		return

	if size.x <= 0.0 or size.y <= 0.0:
		return

	var texture_size: Vector2 = UI2_SHARED_DOMAIN_TEXTURE.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var uv: Vector2 = _domain_uv_bounds_v1()
	var top_v: float = clampf(uv.x, 0.0, 1.0)
	var bottom_v: float = clampf(uv.y, top_v + 0.001, 1.0)

	var source := Rect2(
		0.0, texture_size.y * top_v, texture_size.x, texture_size.y * (bottom_v - top_v)
	)

	draw_texture_rect_region(
		UI2_SHARED_DOMAIN_TEXTURE,
		Rect2(Vector2.ZERO, size),
		source,
		Color(1.0, 1.0, 1.0, UI2_SHARED_DOMAIN_ALPHA),
		false,
		true
	)

	for lane in ["Lord", "Castle"]:
		var box = lord_guard_box if lane == "Lord" else castle_guard_box
		scorch_visuals.draw_area(
			self, Rect2(box.global_position - global_position, box.size), lane, true, false
		)
	if scorch_front != null:
		scorch_front.queue_redraw()


func _draw_guard_flames() -> void:
	for lane in ["Lord", "Castle"]:
		var box = lord_guard_box if lane == "Lord" else castle_guard_box
		scorch_visuals.draw_area(
			scorch_front,
			Rect2(box.global_position - global_position, box.size),
			lane,
			false,
			true,
			0.8
		)


func _apply_domain1_clear_section_backgrounds_v1() -> void:
	_make_domain1_major_panel_transparent_v1(lord_group)
	_make_domain1_major_panel_transparent_v1(lord_guard_group)
	_make_domain1_major_panel_transparent_v1(castle_group)


func _make_domain1_major_panel_transparent_v1(panel: PanelContainer) -> void:
	if panel == null:
		return

	# No hidden theme margins: preserve the measured 16:9 board footprint.
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())


func _configure_ward_drop_target(_control: Control, _lane: String) -> void:
	pass


func _configure_deploy_drop_target(_control: Control, _lane: String) -> void:
	pass


func bind_world(world: Dictionary, pid: int, planning: bool) -> void:
	var lord_name: String = world.get("lord_ids", ["Gremory", "Gremory"])[pid]
	lord_card.bind_art(
		Textures.lord_texture(lord_name), lord_name.to_upper(), lord_name + " — hold to inspect"
	)
	if not lord_card.input_surface.pressed.is_connected(_select_lord):
		lord_card.input_surface.pressed.connect(_select_lord)
	lord_card.input_surface.set_meta("planning", planning)
	lord_card.input_surface.set_meta("owner_id", pid)
	var lord_id: String = ""
	var alive: bool = true
	for entity in world.entities:
		if entity.kind == "lord" and entity.owner == pid:
			lord_id = entity.id
			alive = entity.attributes.alive
	lord_card.input_surface.set_meta("lord_id", lord_id)
	lord_card.input_surface.set_meta("alive", alive)
	lord_card.caption.text = lord_name.to_upper() if alive else lord_name.to_upper() + "\nBANISHED"
	if lord_name == "Humbaba" and world.has("lord_stats"):
		var stats: Dictionary = world.lord_stats[pid]
		if alive:
			lord_card.caption.text += "\nDEFENSE %d · NO THREAT" % stats.defense
		lord_card.input_surface.tooltip_text += (
			"\nNo Threat stat. Defense: 2 + standing Castles (%d).\nEndurance: one Neutral Tear if a friendly Penitent ends Marching at exactly 1 HP while Humbaba lives.\nThe Stones Forget: entering the Breach damages every exposed Castle by 4."
			% stats.standing_castles
		)
	if world.has("lord_stats"):
		var stats: Dictionary = world.lord_stats[pid]
		var bonus: int = 0
		if world.has("relentless_pursuit"):
			bonus = int(world.relentless_pursuit[pid].strength_bonus)
		lord_card.bind_lord_stats(
			{
				"lord": lord_name,
				"alive": alive,
				"defense": stats.defense,
				"threat": stats.threat,
				"summon": Resummon.COSTS.get(lord_name, 0),
				"fracture": FRACTURE.get(lord_name, 0),
				"hunt_bonus": bonus
			}
		)
		if alive and lord_name != "Humbaba":
			lord_card.caption.text += "\nTHREAT %d" % stats.threat
		if alive and bonus > 0:
			lord_card.caption.text += "\nHUNT +%d" % bonus
		lord_card.input_surface.tooltip_text += (
			"\nBase Summon cost: %d. Breach and Circle modifiers are shown when resummoning."
			% Resummon.COSTS.get(lord_name, 0)
		)
		lord_card.input_surface.tooltip_text += (
			"\nCurrent Defense: %s. Hunt must exceed Defense after Guards and Sigil."
			% (str(stats.defense) if alive else "— (banished)")
		)
		lord_card.input_surface.tooltip_text += (
			"\nFracture rating: %d. Fracture effects are not yet active in U13; this is not current Threat."
			% FRACTURE.get(lord_name, 0)
		)
		if bonus > 0:
			lord_card.input_surface.tooltip_text += (
				"\nRelentless Pursuit: +%d Hunt Strength against the current enemy Lord." % bonus
			)
	if lord_name == "Odradek" and world.has("reconfiguration"):
		lord_card.caption.text += "\nRECONFIGURATION %d/4" % world.reconfiguration[pid]
		lord_card.input_surface.tooltip_text += "\nReconfiguration: +1 each round while active, capped at 4. Banishment resets it to 0."
	target_controls = {lord_id: lord_card.input_surface}
	commission_buttons = {}
	var live_castle: Dictionary = {}
	var slots: Dictionary = {}
	var guards: Dictionary = {"Lord": {}, "Castle": {}}
	for entity in world.entities:
		if entity.owner != pid:
			continue
		if entity.kind == "castle":
			live_castle = entity
			if entity.attributes.has("castle_slot"):
				slots[int(entity.attributes.castle_slot)] = entity
		elif entity.kind == "card" and entity.attributes.get("role") == "guard":
			guards[entity.attributes.lane][int(entity.attributes.slot)] = entity
	_clear_children(castle_row)
	# Preserve all five physical positions without pretending their U12 powers run.
	var names: Array = ["Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine"]
	for index in range(names.size()):
		if slots.has(index):
			_add_instance_card(slots[index], pid, planning)
			continue
		var card = Card.new()
		card.custom_minimum_size = Vector2(124, 180)
		castle_row.add_child(card)
		var path: String = Castles.ART_PATHS[names[index]]
		var active: bool = index == 0 and not live_castle.is_empty()
		var label: String = "INACTIVE"
		var help: String = names[index] + " slot — its U13 rules are not implemented."
		if index == 0:
			label = (
				"RUINED"
				if live_castle.is_empty()
				else (
					"TEST CASTLE\n%s · %d/%d"
					% [
						String(live_castle.attributes.status).to_upper(),
						live_castle.attributes.integrity,
						live_castle.attributes.max_integrity
					]
				)
			)
			help = "Test Castle — plain Integrity only; printed Keep power is inactive."
		card.bind_art(Textures.texture(path), label, help, active)
		if active:
			card.input_surface.pressed.connect(_select_castle.bind(pid, live_castle.id, planning))
	for lane in ["Lord", "Castle"]:
		var box = lord_guard_box if lane == "Lord" else castle_guard_box
		_clear_children(box)
		var slot_count: int = 3
		for slot in guards[lane]:
			slot_count = maxi(slot_count, int(slot) + 1)
		for slot in range(slot_count):
			var card = Card.new()
			card.custom_minimum_size = Vector2(58, 72 if lane == "Lord" else 80)
			card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			box.add_child(card)
			var guard: Dictionary = guards[lane].get(slot, {})
			if guard.is_empty():
				card.bind_art(null, "", "Empty Guard slot")
			else:
				card.bind_suit(guard.attributes.suit)
				card.bind_art(
					Textures.texture_for(guard.attributes.suit, guard.attributes.value),
					"",
					"%s %d" % [guard.attributes.suit, guard.attributes.value]
				)
	lord_sigil.text = "◈ " + String(world.sigils[pid].Lord)
	castle_sigil.text = "◈ " + String(world.sigils[pid].Castle)


func _select_lord() -> void:
	if not direct_targets and int(lord_card.input_surface.get_meta("owner_id", 0)) == 1:
		return
	if lord_card.input_surface.get_meta("planning", false):
		target_selected.emit(
			"Ward" if int(lord_card.input_surface.get_meta("owner_id", 0)) == 0 else "Hunt",
			"Lord",
			String(lord_card.input_surface.get_meta("lord_id", ""))
		)


func _select_castle(pid: int, id: String, planning: bool) -> void:
	if planning:
		target_selected.emit("Siege" if pid == 1 else "Ward", "Castle", id)


func _add_instance_card(entity: Dictionary, pid: int, planning: bool) -> void:
	var card = Card.new()
	card.custom_minimum_size = Vector2(124, 180)
	castle_row.add_child(card)
	_bind_instance_art(card, entity)
	var a: Dictionary = entity.attributes
	card.set_meta("castle_id", entity.id)
	target_controls[entity.id] = card.input_surface
	if (
		pid == 0
		and a.construction_state in ["building", "ready"]
		and a.status == "standing"
		and a.integrity >= 7
	):
		card.input_surface.set_meta("commission_eligible", true)
	# Own cards still select the shared Ward lane. Only exposed enemy copies
	# offer a Siege target; construction never becomes a clickable attack target.
	if pid == 0 or (a.construction_state == "active" and a.status in ["standing", "defunct"]):
		card.input_surface.pressed.connect(_select_castle.bind(pid, entity.id, planning))


# Impact presentation updates the existing card; no row rebuild or input rewiring.
func update_castle_presentation(id: String, attributes: Dictionary) -> void:
	var surface = target_controls.get(id)
	if not is_instance_valid(surface) or not attributes.has("castle_type"):
		return
	var card = surface.get_parent().get_parent()
	_bind_instance_art(card, {"id": id, "attributes": attributes})


func _bind_instance_art(card, entity: Dictionary) -> void:
	var a: Dictionary = entity.attributes
	var type: String = String(a.castle_type).replace("SiegeEngine", "Siege Engine").replace(
		"SummoningCircle", "Summoning Circle"
	)
	var lifecycle: String = (
		"PROTECTED"
		if a.construction_state != "active"
		else ("OPERATIONAL" if a.integrity >= 7 and a.status == "standing" else "OFFLINE")
	)
	if a.status in ["ruined", "profaned"]:
		lifecycle = String(a.status).to_upper()
	elif a.construction_state == "unbuilt":
		lifecycle = "UNBUILT"
	var caption: String = (
		"%d · %s\n%s · %d/%d"
		% [int(a.castle_slot) + 1, type, lifecycle, a.integrity, a.max_integrity]
	)
	var help: String = (
		"Slot %d · %s\n%s · %s\nIntegrity %d/%d. All Castles share one Castle Guard zone."
		% [
			int(a.castle_slot) + 1,
			type,
			a.construction_state,
			a.status,
			a.integrity,
			a.max_integrity
		]
	)
	if a.castle_type != "SiegeEngine":
		help += "\nPrinted Castle power is not connected in this U13 slice."
	if a.construction_state != "active":
		help += "\nProtected. Commission at 7+ makes this copy vulnerable."
	card.bind_art(
		Textures.texture(Castles.ART_PATHS[a.castle_type]),
		caption,
		help,
		a.construction_state != "unbuilt" and a.status not in ["ruined", "profaned"]
	)
	card.caption.add_theme_font_size_override("font_size", 10)
	card.bind_castle_art(a, _castle_art_states.get(entity.id, {}))
	_castle_art_states[entity.id] = {
		"ratio": float(a.integrity) / maxf(1.0, float(a.max_integrity)),
		"construction": a.construction_state != "active"
	}
	card.set_meta("display_integrity", a.integrity)


func show_commission_buttons(enabled: bool, staged_id: String) -> void:
	for id in target_controls:
		var control = target_controls[id]
		if not control.has_meta("commission_eligible"):
			continue
		var button := Button.new()
		button.text = "UNDO COMMISSION" if id == staged_id else "COMMISSION"
		button.add_theme_font_size_override("font_size", 10)
		button.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		button.offset_top = 4
		button.offset_bottom = 28
		button.tooltip_text = "Stage Commission for this round. This Castle becomes vulnerable at its current Integrity when orders resolve."
		control.add_child(button)
		button.disabled = not enabled
		button.pressed.connect(_commission_clicked.bind(id))
		commission_buttons[id] = button


func _commission_clicked(id: String) -> void:
	commission_requested.emit(id)


func bind_scorch(records: Array, player_id: int) -> void:
	scorch_visuals.sync(records, "guard", player_id)
	set_process(not scorch_visuals.groups.is_empty())
	queue_redraw()
	for lane in ["Lord", "Castle"]:
		var title: Label = scorch_titles[lane]
		title.text = "LORD\nGUARDS" if lane == "Lord" else "CASTLE GUARDS"
		title.remove_theme_color_override("font_color")
		for row in records:
			if (
				row.target.kind == "guard"
				and row.target.player_id == player_id
				and row.target.lane == lane
			):
				title.text += (
					"\n"
					+ (
						"FIRE R%d" % row.fire_round
						if row.fire_round > 0
						else "SCORCH %d · %dr" % [row.intensity, row.remaining]
					)
				)
				title.add_theme_color_override("font_color", Color("ffb26e"))


func _process(delta: float) -> void:
	if scorch_visuals.groups.is_empty():
		set_process(false)
		return
	scorch_visuals.warm_next()
	scorch_visuals.advance(delta)
	queue_redraw()


func flash_scorch(effect_id: String) -> void:
	scorch_visuals.flash(effect_id)
	if not scorch_visuals.groups.is_empty():
		set_process(true)
		queue_redraw()
