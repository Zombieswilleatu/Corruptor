extends Control
signal picked(id: int)
signal edited(id: int, beat: float, pitch: int, duration: float)
signal added(beat: float, pitch: int)
signal removed(id: int)
var notes: Array = []
var selected: int = -1
var zoom: float = 38.0
var low: int = 36
var high: int = 84
var _drag: Dictionary = {}
var _origin: Vector2
var _preview: Dictionary = {}
var _resize_note: bool = false
const HEIGHT: float = 14.0
const LEFT: float = 42.0

func bind_notes(rows: Array, id: int) -> void:
	notes=rows
	selected=id
	low=60
	high=72
	var finish: float=1.0
	for n in notes:
		low=mini(low,int(n.pitch)-3)
		high=maxi(high,int(n.pitch)+3)
		finish=maxf(finish,n.beat+n.duration)
	low=maxi(0,low)
	high=mini(127,high)
	custom_minimum_size=Vector2(maxf(600,LEFT+finish*zoom+40),(high-low+1)*HEIGHT+20)
	queue_redraw()

func _hit(pos: Vector2) -> Dictionary:
	for i in range(notes.size()-1,-1,-1):
		var n: Dictionary=notes[i]
		if Rect2(LEFT+n.beat*zoom,20+(high-n.pitch)*HEIGHT,maxf(4,n.duration*zoom),HEIGHT).has_point(pos): return n
	return {}

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var n: Dictionary=_hit(event.position)
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and not n.is_empty():
			removed.emit(int(n.id))
			accept_event()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				if n.is_empty():
					if event.double_click: added.emit(maxf(0,snappedf((event.position.x-LEFT)/zoom,.25)),clampi(high-floori((event.position.y-20)/HEIGHT),0,127))
				else:
					selected=int(n.id)
					picked.emit(selected)
					_drag=n.duplicate(true)
					_preview=n.duplicate(true)
					_origin=event.position
					_resize_note=event.shift_pressed
			elif not _drag.is_empty():
				edited.emit(int(_preview.id),_preview.beat,int(_preview.pitch),_preview.duration)
				_drag={}
				_preview={}
			queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion and not _drag.is_empty():
		var delta: Vector2=event.position-_origin
		if _resize_note: _preview.duration=maxf(.0625,_drag.duration+snappedf(delta.x/zoom,.25))
		else:
			_preview.beat=maxf(0,_drag.beat+snappedf(delta.x/zoom,.25))
			_preview.pitch=clampi(int(_drag.pitch)-roundi(delta.y/HEIGHT),0,127)
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("111811"))
	var font: Font=ThemeDB.fallback_font
	for pitch in range(low,high+1):
		var y: float=20+(high-pitch)*HEIGHT
		if pitch%12 in [1,3,6,8,10]: draw_rect(Rect2(LEFT,y,size.x,HEIGHT),Color("0b100c"))
		if pitch%12==0:
			draw_line(Vector2(0,y+HEIGHT),Vector2(size.x,y+HEIGHT),Color("364332"))
			draw_string(font,Vector2(2,y+11),"C%d"%(floori(pitch/12.0)-1),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("bac7b1"))
	for beat in range(0,ceili(size.x/zoom)):
		var x: float=LEFT+beat*zoom
		draw_line(Vector2(x,20),Vector2(x,size.y),Color("3e4b36") if beat%4==0 else Color("222c20"))
		if beat%4==0: draw_string(font,Vector2(x+2,14),str(beat),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("bac7b1"))
	for row in notes:
		var n: Dictionary=_preview if not _preview.is_empty() and _preview.id==row.id else row
		var rect:=Rect2(LEFT+n.beat*zoom,22+(high-n.pitch)*HEIGHT,maxf(3,n.duration*zoom-1),HEIGHT-3)
		var color: Color=Color("bedb8b") if int(n.track)%2==0 else Color("7ebcb3")
		draw_rect(rect,color)
		if int(n.id)==selected: draw_rect(rect.grow(1),Color.WHITE,false,1.5)
