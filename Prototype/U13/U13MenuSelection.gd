extends Control
signal closed
const Data = preload("res://Prototype/U13/U13MenuSelectionData.gd")
const Layout = preload("res://Prototype/U13/U13MenuSlotLayout.gd")
const StatOverlay = preload("res://Prototype/U13/U13LordCardStats.gd")
var flow: Node
var font: Font
var content: Control
var heading: Label
var note: Label
var inspect_root: Control
var inspect_art: TextureRect
var inspect_copy: RichTextLabel
var inspect_title: Label
var inspect_select: Button
var inspect_remove: Button
var inspect_back: Button
var detail_kind: String = ""
var detail_id: String = ""
var detail_slot: int = -1
var stage: String = "lord"
var busy: bool = false
var player: int = 0
var hotseat: bool = false
var replay: int = 0
var lords: Array = ["", ""]
var castles: Array = [["","","","",""],["","","","",""]]
var selected_slot: int = 0
var slot_controls: Array = []
var card_controls: Dictionary = {}
var geometry: Dictionary = {}
var geometry_size: Vector2 = Vector2.ZERO
var finish_button: Button
var source_focus: Control
var pending_animation: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flow = get_node("/root/CorruptorMenuFlow")
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "DejaVu Serif", "Times New Roman"])
	_build_inspector()
	hide()

func open() -> void:
	player = 0
	hotseat = false
	replay = 0
	lords = ["", ""]
	castles = [["","","","",""],["","","","",""]]
	show()
	_show_lords()

func _new_content(title: String, explanation: String) -> void:
	if is_instance_valid(content):
		remove_child(content)
		content.queue_free()
	content = Control.new()
	content.modulate.a = 0.0
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	move_child(inspect_root, get_child_count()-1)
	var shade := ColorRect.new()
	shade.color = Color(0.015,0.015,0.02,0.34)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(shade)
	heading = _label(content,title,38,Rect2(60,60,size.x-120,62))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font",font)
	note = _label(content,explanation,20,Rect2(80,130,size.x-160,55))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_controls.clear()
	slot_controls.clear()

func _fade_in() -> void:
	content.modulate.a = 0.0
	pending_animation = create_tween()
	pending_animation.tween_property(content,"modulate:a",1.0,0.45)

func _show_lords() -> void:
	stage = "lord"
	_new_content(("PLAYER %d · " % (player+1) if hotseat else "") + "CHOOSE YOUR LORD", "Inspect a lord to see their card, active powers, passives and Breach.")
	var width: float = minf(184.0,(size.x-160.0)/9.0-14.0)
	var start_x: float = (size.x - (width*9.0 + 14.0*8.0))*0.5
	for i in range(Data.Lords.LORDS.size()):
		var id: String = Data.Lords.LORDS[i]
		var rect := Rect2(start_x + float(i)*(width+14.0),260,width,width*1.5)
		var card := _card(content,"lord",id,rect,func(): _inspect("lord",id))
		card_controls[id] = card
		_label(content,id.to_upper(),18,Rect2(rect.position.x,rect.end.y+12,width,30)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var inspect := _button(content,"INSPECT",Rect2(rect.position.x,rect.end.y+48,width,38),func(): _inspect("lord",id))
		inspect.add_theme_font_size_override("font_size",16)
	if player == 0 and _has_hotseat():
		var solo := _button(content,"SOLO · RANDOM OPPONENT",Rect2(size.x*0.5-300,194,296,44),func(): _set_mode(false))
		var two := _button(content,"HOTSEAT · TWO PLAYERS",Rect2(size.x*0.5+4,194,296,44),func(): _set_mode(true))
		solo.modulate = Color.WHITE if not hotseat else Color(0.65,0.65,0.65)
		two.modulate = Color.WHITE if hotseat else Color(0.65,0.65,0.65)
	if hotseat:
		_button(content,("● " if replay == 0 else "")+"Watch on your turn",Rect2(size.x*0.5-300,720,296,44),func(): replay=0; _show_lords())
		_button(content,("● " if replay == 1 else "")+"Watch together",Rect2(size.x*0.5+4,720,296,44),func(): replay=1; _show_lords())
	_button(content,"Back",Rect2(70,size.y-96,170,52),_back)
	_button(content,"Random Lord",Rect2(size.x-310,size.y-96,240,52),func():
		var draft: Dictionary = Data.Lords.quickstart_selection(str(Time.get_ticks_usec()))
		_inspect("lord",draft.lords[player]))
	_fade_in()
	card_controls[Data.Lords.LORDS[0]].grab_focus()

func _has_hotseat() -> bool:
	return "U13HotseatBoard.gd" in FileAccess.get_file_as_string("res://Prototype/U13/U13PlayableBoard.tscn")

func _set_mode(value: bool) -> void:
	hotseat = value
	_show_lords()

func _show_castles() -> void:
	stage = "castle"
	_new_content(("PLAYER %d · " % (player+1) if hotseat else "") + "CHOOSE YOUR CASTLES", "Keep first is recommended. One of each castle is a good starting build.")
	if geometry.is_empty() or geometry_size != size:
		busy = true
		note.text = "Preparing your Domain…"
		geometry = await Layout.measure(self)
		geometry_size = size
		busy = false
		if geometry.is_empty():
			note.text = "Could not read the board's castle positions. Return to the menu and check the runner log."
			_button(content,"Back",Rect2(70,size.y-96,170,52),_back)
			_fade_in()
			return
	var lord_rect: Rect2 = geometry.lord
	_card(content,"lord",lords[player],lord_rect,func(): _inspect("lord",lords[player],-2))
	var width: float = 188.0
	var x: float = (size.x - 5.0*width - 4.0*30.0)*0.5
	for i in range(Data.Slots.TYPES.size()):
		var id: String = Data.Slots.TYPES[i]
		var rect := Rect2(x+float(i)*(width+30),225,width,282)
		var card := _card(content,"castle",id,rect,func(): _place_castle(id))
		card.tooltip_text = "Place " + Data.display_name(id) + " in the selected slot."
		card_controls[id] = card
		_label(content,Data.display_name(id),18,Rect2(rect.position.x-8,rect.position.y-28,width+16,26)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_button(content,"Inspect",Rect2(rect.position.x,rect.end.y+8,width,42),func(): _inspect("castle",id))
	for i in range(5):
		var rect: Rect2 = geometry.castles[i]
		var slot := _button(content,"",rect,func(): _slot_clicked(i))
		slot_controls.append(slot)
		var label := _label(content,"%d · %s" % [i+1,"ACTIVE" if i<3 else "BLUEPRINT"],15,Rect2(rect.position.x-5,rect.end.y+6,rect.size.x+10,26))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_slot = _next_empty()
	finish_button = _button(content,"Choose Player 2" if hotseat and player==0 else "Begin Game",Rect2(size.x-340,size.y-96,270,52),_finish)
	_button(content,"Back to Lords",Rect2(70,size.y-96,210,52),_back)
	_button(content,"One of Each",Rect2(320,size.y-96,210,52),_recommended)
	_update_slots()
	_fade_in()
	card_controls["Keep"].grab_focus()

func _next_empty() -> int:
	var empty: int = castles[player].find("")
	return empty if empty >= 0 else 0

func _update_slots() -> void:
	for i in range(slot_controls.size()):
		var button: Button = slot_controls[i]
		for child in button.get_children(): child.free()
		var id: String = castles[player][i]
		button.text = "SLOT %d" % (i+1) if id.is_empty() else ""
		if not id.is_empty():
			var art := _art(button,Data.texture("castle",id),Rect2(Vector2(3,3),button.size-Vector2(6,6)))
			art.modulate.a = 1.0 if i<3 else 0.55
		var skin := _skin()
		skin.border_color = Color("e1ba70") if i == selected_slot else Color("736549")
		skin.set_border_width_all(3 if i == selected_slot else 1)
		button.add_theme_stylebox_override("normal",skin)
		button.tooltip_text = "Slot %d · %s" % [i+1,Data.display_name(id) if not id.is_empty() else "Choose a castle"]
	finish_button.disabled = not Data.Slots.selection_valid(castles[player])
	note.text = "Keep first is recommended. One of each castle is a good starting build.\n" + ("All five selected. Inspect a slot to replace or remove its castle." if not finish_button.disabled else "Choose a castle for slot %d. Maximum one Keep and two of each other type." % (selected_slot+1))

func _slot_clicked(index: int) -> void:
	if busy: return
	selected_slot = index
	_update_slots()
	if not String(castles[player][index]).is_empty(): _inspect("castle",castles[player][index],index)

func _legal_placement(id: String, slot: int) -> bool:
	var candidate: Array = castles[player].duplicate()
	candidate[slot] = id
	return candidate.count(id) <= (1 if id == "Keep" else Data.Slots.TYPE_LIMIT)

func _place_castle(id: String) -> void:
	if busy: return
	if not _legal_placement(id,selected_slot):
		note.text = "You can choose only one Keep and at most two of each other castle. Select a filled slot to replace it."
		return
	busy = true
	var from: Rect2 = inspect_art.get_global_rect() if inspect_root.visible else card_controls[id].get_global_rect()
	var slot: int = selected_slot
	castles[player][slot] = id
	_close_inspect(false)
	await _fly(Data.texture("castle",id),from,geometry.castles[slot])
	selected_slot = _next_empty()
	_update_slots()
	busy = false
	if slot == 0 and id != "Keep": note.text = "Keep first is recommended for early protection, but this choice is allowed.\n" + note.text.get_slice("\n",1)
	if not finish_button.disabled: finish_button.grab_focus()

func _recommended() -> void:
	if busy: return
	busy = true
	for i in range(5):
		var id: String = Data.Slots.TYPES[i]
		castles[player][i] = id
		await _fly(Data.texture("castle",id),card_controls[id].get_global_rect(),geometry.castles[i],0.18)
	selected_slot = 0
	_update_slots()
	busy = false
	finish_button.grab_focus()

func _fly(texture: Texture2D, from: Rect2, to: Rect2, seconds: float = 0.4) -> void:
	var image := _art(self,texture,from)
	image.z_index = 20
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(image,"position",to.position,seconds)
	tween.tween_property(image,"size",to.size,seconds)
	await tween.finished
	image.queue_free()

func _choose_lord() -> void:
	if busy: return
	var name_value: String = detail_id
	lords[player] = name_value
	_close_inspect(false)
	busy = true
	var tween := create_tween()
	tween.tween_property(content,"modulate:a",0.0,0.25)
	await tween.finished
	await _show_castles()
	busy = false

func _finish() -> void:
	if busy or not Data.Slots.selection_valid(castles[player]): return
	if hotseat and player == 0:
		player = 1
		_show_lords()
		return
	var draft: Dictionary = Data.Lords.quickstart_selection(str(Time.get_ticks_usec()) + ":menu:" + str(Time.get_unix_time_from_system()))
	for pid in range(2 if hotseat else 1):
		draft.lords[pid] = lords[pid]
		draft.castles[pid] = castles[pid].duplicate()
	draft.merge({"action":"new","hotseat":hotseat,"replay":replay},true)
	flow.launch(draft)

func _back() -> void:
	if busy: return
	if inspect_root.visible:
		_close_inspect()
	elif stage == "castle":
		_show_lords()
	elif player == 1:
		player = 0
		_show_castles()
	else:
		hide()
		closed.emit()

func _build_inspector() -> void:
	inspect_root = Control.new()
	inspect_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(inspect_root)
	var shade := ColorRect.new()
	shade.color = Color(0.02,0.02,0.025,0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inspect_root.add_child(shade)
	inspect_title = _label(inspect_root,"",38,Rect2(80,48,1500,64))
	inspect_title.add_theme_font_override("font",font)
	inspect_art = _art(inspect_root,null,Rect2(90,148,425,640))
	var panel := PanelContainer.new()
	panel.position = Vector2(580,145)
	panel.size = Vector2(1235,720)
	var skin := _skin()
	skin.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel",skin)
	preload("res://Prototype/U13/U13MenuSkin.gd").apply(panel)
	inspect_root.add_child(panel)
	inspect_copy = RichTextLabel.new()
	inspect_copy.bbcode_enabled = true
	inspect_copy.scroll_active = true
	inspect_copy.add_theme_font_size_override("normal_font_size",21)
	inspect_copy.add_theme_font_size_override("bold_font_size",22)
	inspect_copy.add_theme_color_override("default_color",Color("d7ccb8"))
	panel.add_child(inspect_copy)
	inspect_select = _button(inspect_root,"",Rect2(1415,920,400,56),_inspect_select)
	inspect_remove = _button(inspect_root,"Remove from Slot",Rect2(995,920,340,56),_remove_slot)
	inspect_back = _button(inspect_root,"Back",Rect2(90,920,230,56),_close_inspect)
	inspect_root.hide()

func _inspect(kind: String,id: String,slot: int = -1) -> void:
	if busy: return
	source_focus = get_viewport().gui_get_focus_owner()
	detail_kind = kind
	detail_id = id
	detail_slot = slot
	inspect_title.text = Data.display_name(id).to_upper()
	inspect_art.texture = Data.texture(kind,id)
	for child in inspect_art.get_children(): child.free()
	if kind == "lord": _stats_on(inspect_art,id,true)
	inspect_copy.text = Data.lord_text(id) if kind == "lord" else Data.castle_text(id)
	inspect_copy.scroll_to_line(0)
	inspect_select.text = "Choose " + id if kind == "lord" else "Place in Slot %d" % (selected_slot+1)
	inspect_select.visible = slot != -2
	inspect_select.disabled = kind == "castle" and not _legal_placement(id,selected_slot)
	inspect_remove.visible = slot >= 0
	inspect_root.show()
	inspect_root.modulate.a = 0.0
	create_tween().tween_property(inspect_root,"modulate:a",1.0,0.2)
	inspect_back.grab_focus()
	# Gallery controls remain visible, but cannot take keyboard focus behind inspection.
	_set_focus(content,false)

func _inspect_select() -> void:
	if detail_kind == "lord": _choose_lord()
	else: _place_castle(detail_id)

func _remove_slot() -> void:
	if busy or detail_slot < 0: return
	castles[player][detail_slot] = ""
	selected_slot = detail_slot
	_close_inspect()
	_update_slots()

func _close_inspect(restore_focus: bool = true) -> void:
	inspect_root.hide()
	if is_instance_valid(content): _set_focus(content,true)
	if restore_focus and is_instance_valid(source_focus): source_focus.grab_focus()

func _set_focus(node: Node, enabled: bool) -> void:
	if node is BaseButton: node.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	for child in node.get_children(): _set_focus(child,enabled)

func _card(parent: Node,kind: String,id: String,rect: Rect2,action: Callable) -> Button:
	var button := _button(parent,"",rect,action)
	var art := _art(button,Data.texture(kind,id),Rect2(Vector2(3,3),rect.size-Vector2(6,6)))
	if kind == "lord": _stats_on(art,id)
	button.tooltip_text = "Inspect " + Data.display_name(id)
	button.mouse_entered.connect(func(): button.modulate = Color(1.12,1.1,1.03))
	button.mouse_exited.connect(func(): button.modulate = Color.WHITE)
	return button

func _stats_on(art: TextureRect, lord: String, enlarged: bool = false) -> void:
	var stats := StatOverlay.new()
	art.add_child(stats)
	stats.bind_stats(Data.stats(lord),enlarged)

func _art(parent: Node,texture: Texture2D,rect: Rect2) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = rect.position
	art.size = rect.size
	parent.add_child(art)
	return art

func _label(parent: Node,text: String,font_size: int,rect: Rect2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("d9c49e"))
	parent.add_child(label)
	return label

func _skin() -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.06,0.055,0.06,0.87)
	skin.border_color = Color("746347")
	skin.set_border_width_all(1)
	return skin

func _button(parent: Node,text: String,rect: Rect2,action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size",20)
	button.add_theme_color_override("font_color",Color("e1caa3"))
	for state in ["normal","hover","focus","pressed"]:
		var skin := _skin()
		if state != "normal": skin.border_color = Color("e3ba73"); skin.set_border_width_all(2)
		button.add_theme_stylebox_override(state,skin)
	parent.add_child(button)
	button.pressed.connect(func():
		if busy: return
		flow.click(text.begins_with("Back"))
		action.call())
	return button

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
