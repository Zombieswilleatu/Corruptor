extends Control
signal closed
const Midi=preload("res://Prototype/U13/U13MusicMidi.gd")
const Synth=preload("res://Prototype/U13/U13MusicSynth.gd")
const Arrange=preload("res://Prototype/U13/U13MusicArrange.gd")
const Voices=preload("res://Prototype/U13/U13MusicVoices.gd")
const Roll=preload("res://Prototype/U13/U13MusicRoll.gd")
var source: Dictionary=Midi.demo()
var song: Dictionary=source.duplicate(true)
var settings: Dictionary=Synth.defaults()
var selected: int=-1
var history: Array=[]
var controls: Dictionary={}
var patterns: Dictionary={}
var player: AudioStreamPlayer
var job: Thread
var renderer
var _job_kind: String=""
var _job_path: String=""
var _job_revision: int=0
var _discard_job: bool=false
var _revision: int=0
var _dirty: bool=true
var _rendered_original: bool=false
var _original: bool=false
var _loaded_path: String=""
var _status: Label
var _title: Label
var _parts: VBoxContainer
var _files: ItemList
var _roll
var _note_pick: OptionButton
var _track_pick: OptionButton
var _start: SpinBox
var _finish: SpinBox
var _loop: CheckBox
var _play: Button
var _compare: Button
var _return: Button
var _note_fields: Dictionary={}
var _updating: bool=false
var _folder_dialog: FileDialog
var _open_dialog: FileDialog
var _save_dialog: FileDialog
var _open_kind: String="midi"
var _save_kind: String="wav"
var _position: Label
var _last_region: float=0.0
var _follow_label: Label
var _random_history: Array=[]
var _random_base_notes: Array=[]
var _random_amount: OptionButton
var _random_notes: CheckBox
var _random_back: Button
var _pending_audition: bool=false

func _ready() -> void:
	get_window().content_scale_size=Vector2i(1440,960)
	get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background:=ColorRect.new()
	background.color=Color("111711")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var outer:=ScrollContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(outer)
	var margin:=MarginContainer.new()
	margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,18)
	outer.add_child(margin)
	var root:=VBoxContainer.new()
	root.add_theme_constant_override("separation",10)
	margin.add_child(root)
	_label(root,"CORRUPTOR / MUSIC LAB",28)
	var toolbar:=HBoxContainer.new()
	root.add_child(toolbar)
	_button(toolbar,"OPEN MIDI",func(): _open_file("midi"))
	_button(toolbar,"OPEN MIDI FOLDER",func(): _folder_dialog.popup_centered(Vector2i(1050,720)))
	_button(toolbar,"DEMO",func(): _load_song(Midi.demo(),""))
	_button(toolbar,"SAVE PROJECT",func(): _save_as("project"))
	_button(toolbar,"OPEN PROJECT",func(): _open_file("project"))
	_button(toolbar,"RELOAD SOURCE",_restore)
	_return=_button(toolbar,"RETURN TO SETUP",dismiss)
	_return.hide()
	_title=_label(root,"",18)
	_status=_label(root,"Ready. Play the demo, or open your MIDI folder.",14)
	_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var transport:=HBoxContainer.new()
	root.add_child(transport)
	_play=_button(transport,"PLAY REGION",_play_region)
	_button(transport,"STOP / CANCEL",_stop)
	_compare=_button(transport,"A/B: EDITED",_toggle_original)
	_loop=CheckBox.new()
	_loop.text="Loop"
	transport.add_child(_loop)
	_label(transport,"Beats:")
	_start=_spin(transport,0,100000,.25,0)
	_finish=_spin(transport,.25,100000,.25,16)
	_start.value_changed.connect(func(_v): _changed())
	_finish.value_changed.connect(func(_v): _changed())
	_button(transport,"WHOLE PIECE",func(): _start.value=0; _finish.value=Midi.end_beat(song))
	_position=_label(transport,"",14)
	var columns:=HBoxContainer.new()
	columns.add_theme_constant_override("separation",16)
	root.add_child(columns)
	var left:=VBoxContainer.new()
	left.custom_minimum_size.x=225
	columns.add_child(left)
	_label(left,"MIDI FILES",17)
	_files=ItemList.new()
	_files.custom_minimum_size=Vector2(225,170)
	_files.item_activated.connect(func(index): _load_midi(_files.get_item_metadata(index)))
	left.add_child(_files)
	_label(left,"Double-click a file to load.",12)
	_label(left,"PARTS",17)
	var part_scroll:=ScrollContainer.new()
	part_scroll.custom_minimum_size=Vector2(225,410)
	left.add_child(part_scroll)
	_parts=VBoxContainer.new()
	_parts.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	part_scroll.add_child(_parts)
	var centre:=VBoxContainer.new()
	centre.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	centre.custom_minimum_size.x=700
	columns.add_child(centre)
	var preset_row:=HBoxContainer.new()
	centre.add_child(preset_row)
	_preset_picker(preset_row,Voices.KEY_PRESETS,_preset)
	var random_row:=HBoxContainer.new()
	centre.add_child(random_row)
	_button(random_row,"RANDOMIZE MIDI",_randomize_midi)
	_random_back=_button(random_row,"UNDO RANDOMIZE",_undo_randomize)
	_random_amount=OptionButton.new()
	for title in ["Restrained","Haunted","Unhinged"]: _random_amount.add_item(title)
	_random_amount.select(1)
	random_row.add_child(_random_amount)
	_random_notes=CheckBox.new()
	_random_notes.text="Vary notes too"
	_random_notes.tooltip_text="Optional octave, duration and accent variations. Original source is preserved."
	_random_notes.toggled.connect(func(_enabled): _random_base_notes=[])
	random_row.add_child(_random_notes)
	var tabs:=TabContainer.new()
	tabs.use_hidden_tabs_for_min_size=false
	centre.add_child(tabs)
	var composition:=VBoxContainer.new()
	composition.name="Composition"
	tabs.add_child(composition)
	_slider(composition,"speed","Tempo",40,180,1,"%","100% follows the MIDI tempo map.")
	_slider(composition,"transpose","Transpose",-24,24,1," semitones","-12 is one octave down.")
	_slider(composition,"human","Uneven timing",0,45,1," ms","Repeatable tiny timing slips.")
	_option(composition,"root","Key centre",["C","C#","D","Eb","E","F","F#","G","Ab","A","Bb","B"],range(12))
	_option(composition,"scale","Scale",["Keep notes","Natural minor","Harmonic minor","Phrygian"],["keep","minor","harmonic","phrygian"])
	_check(composition,"reverse","Reverse note order")
	var sid:=VBoxContainer.new()
	sid.name="SID machine"
	tabs.add_child(sid)
	_check(sid,"sid","Enable SID-style bass and percussion")
	var match_row:=HBoxContainer.new()
	sid.add_child(match_row)
	_button(match_row,"MATCH SID TO MIDI",_match_sid)
	_button(match_row,"USE 16-STEP PATTERN",_manual_sid)
	_follow_label=_label(sid,"",12)
	var sid_presets:=HBoxContainer.new()
	sid.add_child(sid_presets)
	_preset_picker(sid_presets,Voices.SID_PRESETS,_sid_preset)
	_check(sid,"sid_solo","Solo sequencer (mute imported MIDI)")
	_label(sid,"SID voices also work on imported MIDI: choose SID pulse / saw / triangle under INSTRUMENT.",12)
	var sid_tabs:=TabContainer.new()
	sid_tabs.use_hidden_tabs_for_min_size=false
	sid.add_child(sid_tabs)
	var sequence: VBoxContainer=_control_page(sid_tabs,"Pattern")
	_label(sequence,"16 steps; bass: rest / root / b3 / fifth / b7 / octave. Pattern rate changes all four rows.",12)
	var grid:=GridContainer.new()
	grid.columns=17
	sequence.add_child(grid)
	_label(grid,"")
	for i in range(16): _label(grid,str(i+1),12)
	for voice in ["bass","kick","snare","hat"]:
		_label(grid,voice.capitalize(),13)
		patterns[voice]=[]
		for i in range(16):
			var button:=Button.new()
			button.custom_minimum_size=Vector2(34,34)
			button.add_theme_font_size_override("font_size",12)
			grid.add_child(button)
			button.pressed.connect(_pattern_click.bind(voice,i))
			patterns[voice].append(button)
	_slider(sequence,"sid_rate","Pattern rate",.5,2,.5,"x","1x = four beats per pattern; .5x = eight; 2x = two.")
	_slider(sequence,"sid_swing","Swing",0,60,1,"%","Delays alternate steps. Exported MIDI keeps this timing.")
	_slider(sequence,"sid_gate","Bass note length",25,100,1,"%","How much of a sequencer step the bass holds before release.")
	_slider(sequence,"sid_octave","Bass octave",-2,2,1," oct","Moves the generated bass without moving the imported notes.")
	var tone: VBoxContainer=_control_page(sid_tabs,"Tone")
	_option(tone,"sid_wave","Bass voice",["Pulse / hollow", "Saw / growl", "Triangle / soft", "Hard sync / metal", "Noise / airlock"],["pulse","saw","triangle","sync","noise"])
	_slider(tone,"pulse","Pulse width",5,95,1,"%","Pulse only: narrow is nasal; 50% is square.")
	_slider(tone,"sid_sync_ratio","Hard-sync ratio",1,8,.1,"x","Hard-sync voice only: growling harmonic changes.")
	_option(tone,"sid_filter_mode","Filter",["Soft / original", "Resonant low-pass", "Band-pass", "High-pass"],["soft","lowpass","bandpass","highpass"])
	_slider(tone,"sid_cutoff","Filter cutoff",100,9000,25," Hz","Lower darkens the tone; resonance makes the moving edge speak.")
	_slider(tone,"sid_resonance","Filter resonance",0,90,1,"%","The hollow whistle or growl around the cutoff. Also activates the resonant filter in Soft mode.")
	_slider(tone,"sid_crunch","SID crunch",0,100,1,"%","Sample-rate and bit-depth reduction on all SID audio.")
	var motion: VBoxContainer=_control_page(sid_tabs,"Motion")
	_slider(motion,"sid_lfo_rate","Motion speed",.1,12,.05," Hz","Shared speed for pulse breathing, pitch wobble and filter movement.")
	_slider(motion,"sid_pwm","Pulse breathing",0,45,1,"%","Moves pulse width back and forth; works on pulse voices.")
	_slider(motion,"sid_vibrato","Pitch wobble",0,200,1," cents","100 cents = one semitone. Zero holds pitch steady.")
	_slider(motion,"sid_filter_motion","Filter movement",0,100,1,"%","Sweeps the resonant filter up and down. Try Alien / breathing filter.")
	_slider(motion,"sid_ring","Ring modulation",0,100,1,"%","Metallic and inharmonic tones across SID audio.")
	_slider(motion,"sid_ring_hz","Ring frequency",20,900,1," Hz","Changes the metallic pitch of ring modulation.")
	_option(motion,"sid_arp","Fast arpeggio",["Off", "Octave trill", "Minor chord"],["off","octave","minor"])
	_slider(motion,"sid_arp_rate","Arpeggio speed",4,40,1," Hz","Rapid pitch switching within each held note; baked into WAV, not MIDI.")
	var envelope: VBoxContainer=_control_page(sid_tabs,"Envelope")
	_slider(envelope,"sid_attack","Fade in / attack",2,500,1," ms","Soft entrance versus immediate bite. Applies to bass and MIDI SID voices.")
	_slider(envelope,"sid_decay","Decay",10,1500,5," ms","Time from the initial peak down to the sustain level.")
	_slider(envelope,"sid_sustain","Held level",0,100,1,"%","Level held until note release. Zero gives a pluck.")
	_slider(envelope,"sid_release","Fade out / release",5,1500,5," ms","How long a released note trails away.")
	_slider(envelope,"sid_sweep","Pitch dive",0,100,1,"%","High-to-low pitch dive at each bass/SID note attack.")
	_slider(envelope,"sid_sweep_time","Pitch dive time",10,800,5," ms","Short = zap; long = falling growl.")
	_slider(envelope,"sid_filter_env","Filter pluck",0,100,1,"%","Opens the filter on each bass/SID note, then closes it.")
	_slider(envelope,"sid_filter_decay","Filter pluck time",20,2000,10," ms","Duration of that per-note filter sweep.")
	var mix: VBoxContainer=_control_page(sid_tabs,"Mix")
	_slider(mix,"sid_level","Sequencer level",0,100,1,"%","Balances the generated sequence against the imported piece.")
	_slider(mix,"sid_bass_level","Bass / SID voice level",0,100,1,"%","Level for generated bass and imported MIDI played with SID voices.")
	_slider(mix,"sid_drum_level","Percussion level",0,100,1,"%","Balance kick, snare and hat against the bass.")
	_label(mix,"Master volume is on the right and starts at 50%. Presets preserve both master and sequencer level.",12)
	var guitar: VBoxContainer=_control_page(tabs,"Guitar amp")
	_label(guitar,"Select Acoustic guitar or Electric guitar on the right, or apply a guitar preset.",12)
	_slider(guitar,"guitar_drive","Amp drive / electric only",0,100,1,"%","Saturates the guitar before speaker filtering. SID accompaniment stays on its own bus.")
	_slider(guitar,"guitar_sustain","String sustain",.2,8,.1," s","How long a held string rings. MIDI note release still stops it.")
	_slider(guitar,"guitar_mute","Palm mute",0,100,1,"%","Shortens and darkens the pluck for tighter chugs.")
	_slider(guitar,"guitar_tone","Guitar tone",600,6500,50," Hz","Darker speaker/body tone at low values; more bite at high values.")
	_slider(guitar,"guitar_pick","Pick position",10,45,1,"%","Changes string harmonics: near the bridge is sharper, near the centre rounder.")
	_slider(guitar,"guitar_pick_rate","Tremolo picking",0,16,1," Hz","Zero = one pluck per note. Higher values repeatedly pick held notes; Black metal uses 11 Hz.")
	_label(centre,"SCORE / drag to move, Shift-drag to resize, double-click to add, right-click to delete",13)
	var roll_scroll:=ScrollContainer.new()
	roll_scroll.custom_minimum_size=Vector2(700,270)
	centre.add_child(roll_scroll)
	_roll=Roll.new()
	roll_scroll.add_child(_roll)
	_roll.picked.connect(func(id): selected=id; _inspect())
	_roll.edited.connect(_edit_drag)
	_roll.added.connect(_add_note)
	_roll.removed.connect(_delete_note)
	var tools:=HBoxContainer.new()
	centre.add_child(tools)
	_button(tools,"UNDO NOTE EDIT",_undo)
	_track_pick=OptionButton.new()
	_track_pick.custom_minimum_size.x=160
	tools.add_child(_track_pick)
	_button(tools,"ADD NOTE",func(): _add_note(_start.value,60))
	_button(tools,"DELETE NOTE",func(): _delete_note(selected))
	var fields:=HBoxContainer.new()
	centre.add_child(fields)
	_note_pick=OptionButton.new()
	_note_pick.custom_minimum_size.x=170
	fields.add_child(_note_pick)
	_note_pick.item_selected.connect(func(index): selected=int(_note_pick.get_item_metadata(index)); _inspect(); _roll.bind_notes(song.notes,selected))
	for entry in [["pitch","Pitch",0,127,1],["beat","Beat",0,100000,.25],["duration","Length",.0625,10000,.25],["velocity","Strength",1,127,1]]:
		var col:=VBoxContainer.new()
		fields.add_child(col)
		_label(col,entry[1],12)
		_note_fields[entry[0]]=_spin(col,entry[2],entry[3],entry[4],entry[2])
	_button(fields,"APPLY",_apply_note)
	_label(centre,"The score shows editable source notes; scale, transpose and SID are applied for playback/export.",12)
	var right:=VBoxContainer.new()
	right.custom_minimum_size.x=285
	columns.add_child(right)
	_label(right,"INSTRUMENT",17)
	_option(right,"instrument","Voice",Voices.INSTRUMENT_NAMES,Voices.INSTRUMENTS)
	_slider(right,"volume","Volume",0,100,1,"%","Starts halfway, at 50%.")
	_slider(right,"brightness","Brightness",350,10000,50," Hz","Non-SID voices: lower removes the bright edge. SID voices use their own filter.")
	_slider(right,"ring","String ring",.15,3,.05," s","Plucked keyboard voices. Guitars use String sustain in Guitar amp.")
	_slider(right,"detune","Out of tune",0,35,1," cents","Two strings drift apart.")
	_slider(right,"grit","Grit",0,100,1,"%","Drive the full mix into distortion.")
	_slider(right,"room","Room",0,75,1,"%","Short reflective room around the instrument.")
	_slider(right,"echo","Echo",0,70,1,"%","Repeats behind the notes.")
	var exports:=HBoxContainer.new()
	root.add_child(exports)
	_button(exports,"EXPORT WAV / REGION",func(): _save_as("wav"))
	_button(exports,"EXPORT MIDI / WHOLE PIECE",func(): _save_as("midi"))
	_label(root,"WAV includes the sound and SID effects. MIDI includes note edits, tempo and generated SID notes, not the exact timbre. Synthesized SID-style sound, not hardware emulation.",12)
	player=AudioStreamPlayer.new()
	add_child(player)
	player.finished.connect(_play_finished)
	_folder_dialog=_dialog(FileDialog.FILE_MODE_OPEN_DIR)
	_folder_dialog.dir_selected.connect(_browse_folder)
	_open_dialog=_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	_open_dialog.file_selected.connect(_file_chosen)
	_save_dialog=_dialog(FileDialog.FILE_MODE_SAVE_FILE)
	_save_dialog.file_selected.connect(_export)
	var folder: String=_default_folder()
	_folder_dialog.current_dir=folder
	_open_dialog.current_dir=folder
	_save_dialog.current_dir=ProjectSettings.globalize_path("res://Music") if DirAccess.dir_exists_absolute("res://Music") else folder
	_refresh_all()
	if DirAccess.dir_exists_absolute(folder): _browse_folder(folder)

func _control_page(parent: TabContainer, title: String) -> VBoxContainer:
	var scroll:=ScrollContainer.new()
	scroll.name=title
	scroll.custom_minimum_size.y=330
	parent.add_child(scroll)
	var content:=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",8)
	scroll.add_child(content)
	return content

func _preset_picker(parent: Node, names: Array, action: Callable) -> void:
	var picker:=OptionButton.new()
	picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for title in names: picker.add_item(title)
	parent.add_child(picker)
	_button(parent,"APPLY PRESET",func(): action.call(picker.get_item_text(picker.selected)))

func _label(parent: Node, text: String, font_size: int=14) -> Label:
	var label:=Label.new()
	label.text=text
	label.add_theme_font_size_override("font_size",font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button:=Button.new()
	button.text=text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _spin(parent: Node, low: float, high: float, step_value: float, value: float) -> SpinBox:
	var spin:=SpinBox.new()
	spin.min_value=low
	spin.max_value=high
	spin.step=step_value
	spin.value=value
	spin.custom_minimum_size.x=88
	parent.add_child(spin)
	return spin

func _slider(parent: Node, key: String, title: String, low: float, high: float, step_value: float, unit: String, help: String) -> void:
	var column:=VBoxContainer.new()
	parent.add_child(column)
	var label: Label=_label(column,"",13)
	var slider:=HSlider.new()
	slider.min_value=low
	slider.max_value=high
	slider.step=step_value
	slider.tooltip_text=help
	column.add_child(slider)
	controls[key]={"control":slider,"label":label,"title":title,"unit":unit}
	slider.value_changed.connect(func(value):
		settings[key]=value
		label.text=title+"  "+str(snappedf(value,.01))+unit
		if key=="volume" and player!=null: player.volume_linear=value/100.0
		elif not _updating: _changed())

func _option(parent: Node, key: String, title: String, names: Array, values: Array) -> void:
	var row:=HBoxContainer.new()
	parent.add_child(row)
	_label(row,title,13)
	var pick:=OptionButton.new()
	pick.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for i in range(names.size()):
		pick.add_item(names[i])
		pick.set_item_metadata(i,values[i])
	row.add_child(pick)
	controls[key]={"control":pick}
	pick.item_selected.connect(func(index): settings[key]=pick.get_item_metadata(index); _changed())

func _check(parent: Node, key: String, title: String) -> void:
	var check:=CheckBox.new()
	check.text=title
	parent.add_child(check)
	controls[key]={"control":check}
	check.toggled.connect(func(value): settings[key]=value; _changed())

func _dialog(mode: FileDialog.FileMode) -> FileDialog:
	var dialog:=FileDialog.new()
	dialog.access=FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode=mode
	add_child(dialog)
	return dialog

func _default_folder() -> String:
	var home: String=OS.get_environment("USERPROFILE")
	if home.is_empty(): home=OS.get_environment("HOME")
	var requested: String=home.path_join("OneDrive/Documents/Corruptor/Music/Midis")
	if DirAccess.dir_exists_absolute(requested): return requested
	var local: String=ProjectSettings.globalize_path("res://Music/Midis")
	return local if DirAccess.dir_exists_absolute(local) else home

func _browse_folder(path: String) -> void:
	_files.clear()
	_scan(path,0)
	_status.text="Found %d MIDI files. Double-click one to load." % _files.item_count
	_open_dialog.current_dir=path

func _scan(path: String, depth: int) -> void:
	if depth>8 or _files.item_count>=2000: return
	for name in DirAccess.get_files_at(path):
		if name.get_extension().to_lower() in ["mid","midi"]:
			_files.add_item(name)
			_files.set_item_metadata(_files.item_count-1,path.path_join(name))
	for name in DirAccess.get_directories_at(path):
		if not name.begins_with("."): _scan(path.path_join(name),depth+1)

func _open_file(kind: String) -> void:
	_open_kind=kind
	_open_dialog.filters=PackedStringArray(["*.mid, *.midi ; MIDI files"] if kind=="midi" else ["*.json ; Music Lab project"])
	_open_dialog.popup_centered(Vector2i(1050,720))

func _file_chosen(path: String) -> void:
	if _open_kind=="midi": _load_midi(path)
	else: _load_project(path)

func _load_midi(path: String) -> void:
	var result: Dictionary=Midi.load_file(path)
	if result.has("error"):
		_status.text=result.error
		return
	_load_song(result.song,path)

func _load_song(value: Dictionary, path: String) -> void:
	_stop()
	source=value.duplicate(true)
	song=value.duplicate(true)
	settings=Synth.defaults()
	_loaded_path=path
	selected=-1
	history=[]
	_reset_random()
	_original=false
	_start.value=0
	_finish.value=minf(16,Midi.end_beat(song))
	_refresh_all()
	_changed()
	_status.text="Loaded "+song.name+". "+" ".join(song.get("warnings",[]))

func _refresh_all() -> void:
	_updating=true
	for key in controls:
		var control: Control=controls[key].control
		if control is Range:
			control.value=settings[key]
			controls[key].label.text=controls[key].title+"  "+str(snappedf(control.value,.01))+controls[key].unit
		elif control is CheckBox: control.set_pressed_no_signal(settings[key])
		elif control is OptionButton:
			for i in range(control.item_count):
				if control.get_item_metadata(i)==settings[key]: control.select(i)
	for child in _parts.get_children():
		_parts.remove_child(child)
		child.queue_free()
	_track_pick.clear()
	for track in song.tracks:
		_track_pick.add_item(track.name)
		_track_pick.set_item_metadata(_track_pick.item_count-1,int(track.id))
		var check:=CheckBox.new()
		check.text=track.name
		check.tooltip_text=track.name
		check.clip_text=true
		check.button_pressed=not track.mute
		_parts.add_child(check)
		check.toggled.connect(func(value): track.mute=not value; _changed())
		var mix:=HBoxContainer.new()
		_parts.add_child(mix)
		var level: SpinBox=_spin(mix,0,100,5,track.level)
		level.suffix="%"
		level.value_changed.connect(func(value): track.level=value; _changed())
		var octave: SpinBox=_spin(mix,-2,2,1,track.octave)
		octave.prefix="Oct "
		octave.value_changed.connect(func(value): track.octave=int(value); _changed())
	_title.text=str(song.name)+"  /  %d notes, %d parts"%[song.notes.size(),song.tracks.size()]
	_compare.text="A/B: ORIGINAL" if _original else "A/B: EDITED"
	_refresh_notes()
	_refresh_pattern()
	_random_back.disabled=_random_history.is_empty()
	_updating=false

func _refresh_notes() -> void:
	_note_pick.clear()
	for n in song.notes:
		_note_pick.add_item("Beat %.2f / %s"%[n.beat,_pitch_name(int(n.pitch))])
		_note_pick.set_item_metadata(_note_pick.item_count-1,int(n.id))
	_roll.bind_notes(song.notes,selected)
	_inspect()

func _pitch_name(pitch: int) -> String:
	return ["C","C#","D","Eb","E","F","F#","G","Ab","A","Bb","B"][pitch%12]+str(floori(pitch/12.0)-1)

func _inspect() -> void:
	for n in song.notes:
		if int(n.id)!=selected: continue
		for key in _note_fields: _note_fields[key].value=n[key]
		for i in range(_note_pick.item_count):
			if int(_note_pick.get_item_metadata(i))==selected: _note_pick.select(i)
		return

func _remember() -> void:
	_reset_random()
	history.append(song.notes.duplicate(true))
	if history.size()>12: history.pop_front()

func _undo() -> void:
	if history.is_empty(): return
	_reset_random()
	song.notes=history.pop_back()
	selected=-1
	_refresh_notes()
	_changed()

func _edit_drag(id: int, beat: float, pitch: int, duration: float) -> void:
	for n in song.notes:
		if int(n.id)==id:
			if n.beat==beat and int(n.pitch)==pitch and n.duration==duration: return
			_remember()
			n.beat=beat
			n.pitch=pitch
			n.duration=duration
			break
	_refresh_notes()
	_changed()

func _apply_note() -> void:
	for n in song.notes:
		if int(n.id)==selected:
			_remember()
			for key in _note_fields: n[key]=_note_fields[key].value
			n.pitch=int(n.pitch)
			n.velocity=int(n.velocity)
			break
	_refresh_notes()
	_changed()

func _add_note(beat: float, pitch: int) -> void:
	if song.notes.size()>=30000: return
	_remember()
	var id: int=1
	for n in song.notes: id=maxi(id,int(n.id)+1)
	song.notes.append({"id":id,"track":int(_track_pick.get_selected_metadata()),"pitch":pitch,"beat":beat,"duration":.5,"velocity":90})
	selected=id
	_refresh_notes()
	_changed()

func _delete_note(id: int) -> void:
	if id<0: return
	_remember()
	song.notes=song.notes.filter(func(n): return int(n.id)!=id)
	selected=-1
	_refresh_notes()
	_changed()

func _preset(name: String) -> void:
	var volume: float=settings.volume
	var root_note: int=int(settings.root)
	var sid_values: Dictionary={}
	for key in settings:
		if key=="sid" or str(key).begins_with("sid_") or key in ["pulse","bass","kick","snare","hat"]: sid_values[key]=settings[key]
	settings=Synth.defaults()
	settings.merge(sid_values,true)
	settings.volume=volume
	settings.root=root_note
	settings.merge(Voices.key_patch(name),true)
	settings.sid_solo=false
	_original=false
	_refresh_all()
	_changed()

func _refresh_pattern() -> void:
	var following: bool=bool(settings.get("sid_follow",false))
	_follow_label.text="FOLLOWING MIDI: bass follows its low notes; drums follow note attacks. Updates with edits." if following else "MANUAL: the 16-step pattern repeats across the piece."
	for key in ["sid_rate","sid_swing"]: controls[key].control.editable=not following
	for voice in patterns:
		for i in range(16):
			var value: int=int(settings[voice][i])
			var button: Button=patterns[voice][i]
			button.disabled=following
			button.text={-1:"-",0:"R",3:"b3",7:"5",10:"b7",12:"8"}.get(value,"R") if voice=="bass" else ("X" if value else "-")
			button.modulate=Color("cae5a0") if (value>=0 if voice=="bass" else value>0) else Color("80917a")

func _pattern_click(voice: String, index: int) -> void:
	if settings.get("sid_follow",false): return
	if voice=="bass":
		var options: Array=[-1,0,3,7,10,12]
		settings.bass[index]=options[(options.find(int(settings.bass[index]))+1)%options.size()]
	else: settings[voice][index]=1-int(settings[voice][index])
	_refresh_pattern()
	_changed()

func _sid_preset(name: String) -> void:
	var clean: Dictionary=Synth.defaults()
	var level: float=settings.sid_level
	var solo: bool=settings.sid_solo
	var follow_midi: bool=bool(settings.get("sid_follow",false))
	for key in clean:
		if key=="sid" or str(key).begins_with("sid_") or key in ["pulse","bass","kick","snare","hat"]:
			settings[key]=clean[key].duplicate() if clean[key] is Array else clean[key]
	settings.sid=name!="Clear"
	settings.sid_level=level
	settings.sid_solo=solo
	settings.sid_follow=follow_midi
	settings.merge(Voices.sid_patch(name),true)
	if name=="Clear":
		for key in ["kick","snare","hat"]: settings[key].fill(0)
		settings.bass.fill(-1)
		settings.sid_solo=false
		settings.sid_follow=false
	_original=false
	_refresh_all()
	_changed()

func _match_sid() -> void:
	settings.sid=true
	settings.sid_follow=true
	settings.sid_solo=false
	_refresh_all()
	_audition_changes()

func _manual_sid() -> void:
	settings.sid_follow=false
	_refresh_all()
	_audition_changes()

func _reset_random() -> void:
	_random_history=[]
	_random_base_notes=[]
	if _random_back!=null: _random_back.disabled=true

func _randomize_midi() -> void:
	_random_history.append({"settings":settings.duplicate(true),"notes":song.notes.duplicate(true)})
	if _random_history.size()>12: _random_history.pop_front()
	if _random_base_notes.is_empty(): _random_base_notes=song.notes.duplicate(true)
	var rng:=RandomNumberGenerator.new()
	rng.randomize()
	var result: Dictionary=Arrange.variation(settings,_random_base_notes,_random_amount.selected,_random_notes.button_pressed,int(rng.randi()))
	settings=result.settings
	song.notes=result.notes
	_refresh_all()
	_audition_changes()

func _undo_randomize() -> void:
	if _random_history.is_empty(): return
	var previous: Dictionary=_random_history.pop_back()
	for key in ["instrument","brightness","ring","detune","grit","room","echo","guitar_drive","guitar_sustain","guitar_mute","guitar_tone","guitar_pick","guitar_pick_rate"]:
		settings[key]=previous.settings[key]
	song.notes=previous.notes.duplicate(true)
	_refresh_all()
	_audition_changes()

func _audition_changes() -> void:
	_original=false
	_compare.text="A/B: EDITED"
	_changed()
	if job!=null:
		if _job_kind=="preview": _stop()
		_pending_audition=true
		_status.text="Preparing the latest variation…"
	else: _play_region()

func _changed() -> void:
	if _updating: return
	_dirty=true
	_revision+=1
	if player!=null and player.playing: _status.text="Changed. Press PLAY to audition now; loops pick it up on the next pass."

func _toggle_original() -> void:
	_original=not _original
	_compare.text="A/B: ORIGINAL" if _original else "A/B: EDITED"
	_changed()
	_play_region()

func _restore() -> void:
	if not _loaded_path.is_empty() and FileAccess.file_exists(_loaded_path): _load_midi(_loaded_path)
	else: _load_song(source,"")

func _play_region() -> void:
	if job!=null:
		_status.text="Still rendering. STOP / CANCEL cancels the current job."
		return
	if not _dirty and player.stream!=null and _rendered_original==_original:
		player.volume_linear=settings.volume/100.0
		player.play()
		return
	_render("preview","")

func _render(kind: String, path: String) -> void:
	if job!=null: return
	player.stop()
	if _finish.value<=_start.value:
		_status.text="Region end must be after the start."
		return
	var config: Dictionary=settings.duplicate(true)
	if kind=="preview": config.volume=100.0
	renderer=Synth.new()
	job=Thread.new()
	_job_kind=kind
	_job_path=path
	_job_revision=_revision
	var compare: bool=_original and kind=="preview"
	var error: Error=job.start(renderer.render.bind((source if compare else song).duplicate(true),config,_start.value,_finish.value,compare))
	if error!=OK:
		job=null
		_status.text="Could not start audio render."
		return
	_discard_job=false
	_rendered_original=compare
	_play.disabled=true
	_status.text="Rendering "+("original" if compare else "edited")+" audio… STOP / CANCEL is available."

func _process(_delta: float) -> void:
	if player!=null and player.playing: _position.text="%.1fs / %.1fs"%[player.get_playback_position(),_last_region]
	if player!=null and player.playing and _loop.button_pressed and player.get_playback_position()>=_last_region:
		player.stop()
		_play_finished()
	if job==null or job.is_alive(): return
	var result: Dictionary=job.wait_to_finish()
	job=null
	renderer=null
	_play.disabled=false
	if _pending_audition and _job_kind=="preview":
		_pending_audition=false
		call_deferred("_play_region")
		return
	if _discard_job or result.has("cancelled"):
		_status.text="Render cancelled."
		return
	if result.has("error"):
		_status.text=result.error
		if _pending_audition:
			_pending_audition=false
			call_deferred("_play_region")
		return
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=int(result.rate)
	stream.stereo=false
	stream.data=result.pcm
	if _job_kind=="wav":
		var error: Error=stream.save_to_wav(_job_path)
		_status.text=("Saved WAV: "+_job_path) if error==OK else "Could not save WAV (error %d)."%error
		if _pending_audition:
			_pending_audition=false
			call_deferred("_play_region")
	else:
		player.stream=stream
		player.volume_linear=settings.volume/100.0
		_dirty=_job_revision!=_revision
		_last_region=result.seconds
		player.play()
		_status.text="Playing %s / %d notes. %s"%["original" if _rendered_original else "edited",result.notes,"Peak trimmed to avoid clipping." if result.trimmed else ""]

func _play_finished() -> void:
	if _loop.button_pressed: _play_region()

func _stop() -> void:
	_pending_audition=false
	if player!=null: player.stop()
	if renderer!=null:
		_discard_job=true
		renderer.cancel()

func _save_as(kind: String) -> void:
	_save_kind=kind
	var name: String=str(song.name).validate_filename().substr(0,70)+"-corrupted"
	_save_dialog.filters=PackedStringArray(["*.wav ; Rendered audio"] if kind=="wav" else (["*.mid ; MIDI notes"] if kind=="midi" else ["*.json ; Music Lab project"]))
	_save_dialog.current_file=name+({"wav":".wav","midi":".mid","project":".musiclab.json"}[kind])
	_save_dialog.popup_centered(Vector2i(1050,720))

func _export(path: String) -> void:
	if _save_kind=="wav":
		if job!=null: _status.text="Wait for the current render, then export again."
		else: _render("wav",path)
		return
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		_status.text="Could not write that file."
		return
	if _save_kind=="midi":
		var notes: Array=Synth.compose(song,settings,0,Midi.end_beat(song))
		file.store_buffer(Midi.encode(notes,song.tempos,settings))
	else: file.store_string(JSON.stringify({"format":"CORRUPTOR_MUSIC_LAB_V1","source":source,"song":song,"settings":settings,"region":[_start.value,_finish.value]},"\t"))
	file.close()
	_status.text="Saved: "+path

func _valid_song(value) -> bool:
	if not value is Dictionary or not value.get("notes") is Array or not value.get("tracks") is Array or not value.get("tempos") is Array: return false
	if value.notes.size()>30000 or value.tracks.is_empty() or value.tracks.size()>512 or value.tempos.is_empty(): return false
	var ids: Array=[]
	for t in value.tracks:
		if not t is Dictionary or not t.has_all(["id","name","mute","level","octave"]): return false
		ids.append(int(t.id))
	for n in value.notes:
		if not n is Dictionary or not n.has_all(["id","track","pitch","beat","duration","velocity"]): return false
		if int(n.track) not in ids or not is_finite(float(n.beat)) or not is_finite(float(n.duration)) or n.beat<0 or n.beat>100000 or n.duration<=0 or n.duration>10000 or n.pitch<0 or n.pitch>127 or n.velocity<1 or n.velocity>127: return false
	for t in value.tempos:
		if not t is Dictionary or not t.has_all(["beat","us"]) or t.beat<0 or t.us<1 or t.us>16777215: return false
	return true

func _load_project(path: String) -> void:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>32000000:
		_status.text="Project missing or too large."
		return
	var value=JSON.parse_string(file.get_as_text())
	if not value is Dictionary or value.get("format")!="CORRUPTOR_MUSIC_LAB_V1" or not _valid_song(value.get("source")) or not _valid_song(value.get("song")) or not value.get("settings") is Dictionary:
		_status.text="Not a valid Music Lab project."
		return
	var safe: Dictionary=Synth.defaults()
	for key in safe:
		if not value.settings.has(key): continue
		if key in ["bass","kick","snare","hat"]:
			if not value.settings[key] is Array or value.settings[key].size()!=16: continue
			for i in range(16):
				var v: int=int(value.settings[key][i])
				safe[key][i]=v if v in ([-1,0,3,7,10,12] if key=="bass" else [0,1]) else safe[key][i]
		elif controls.has(key) and controls[key].control is Range:
			var control: Range=controls[key].control
			safe[key]=clampf(float(value.settings[key]),control.min_value,control.max_value)
		elif key in ["sid","reverse","sid_solo","sid_follow"]: safe[key]=bool(value.settings[key])
		elif key=="root": safe[key]=clampi(int(value.settings[key]),0,11)
		elif key=="scale" and value.settings[key] in ["keep","minor","harmonic","phrygian"]: safe[key]=value.settings[key]
		elif controls.has(key) and controls[key].control is OptionButton:
			var options: OptionButton=controls[key].control
			for i in range(options.item_count):
				if value.settings[key]==options.get_item_metadata(i): safe[key]=value.settings[key]
	_load_song(value.source,"")
	song=value.song
	settings=safe
	if value.get("region") is Array and value.region.size()==2:
		_start.value=clampf(float(value.region[0]),0,100000)
		_finish.value=clampf(float(value.region[1]),.25,100000)
	_refresh_all()
	_changed()
	_status.text="Project restored."

func enable_return_to_setup() -> void: _return.show()

func dismiss() -> void:
	_stop()
	closed.emit()

func _exit_tree() -> void:
	_stop()
	if job!=null:
		job.wait_to_finish()
		job=null
