extends RefCounted
const Midi = preload("res://Prototype/U13/GameMusicRender/U13MusicMidi.gd")
const Voices = preload("res://Prototype/U13/GameMusicRender/U13MusicVoices.gd")
const Arrange = preload("res://Prototype/U13/GameMusicRender/U13MusicArrange.gd")
const Guitar = preload("res://Prototype/U13/GameMusicRender/U13MusicGuitar.gd")
const RATE: int = 22050
var external_cancel: Callable
var _cancelled: bool = false
var _mutex := Mutex.new()

static func defaults() -> Dictionary:
	var result: Dictionary = {"speed":100.0,"transpose":0.0,"root":9,"scale":"keep","instrument":"harpsichord","brightness":6500.0,"ring":1.2,"detune":0.0,"grit":0.0,"room":15.0,"echo":0.0,"volume":50.0,"human":0.0,"reverse":false,"sid":false,"sid_level":35.0,"pulse":25.0,"sid_crunch":20.0,"sid_ring":0.0,"sid_sweep":0.0,"sid_cutoff":3000.0,"bass":[0,-1,0,-1,7,-1,3,-1,0,-1,12,-1,10,-1,7,-1],"kick":[1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0],"snare":[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0],"hat":[1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0]}
	result.merge(Voices.defaults())
	return result

static func scaled_pitch(pitch: int, key: int, mode: String) -> int:
	var scales: Dictionary = {"minor":[0,2,3,5,7,8,10],"harmonic":[0,2,3,5,7,8,11],"phrygian":[0,1,3,5,7,8,10]}
	if not scales.has(mode): return pitch
	for distance in range(7):
		if posmod(pitch-distance-key,12) in scales[mode]: return pitch-distance
		if posmod(pitch+distance-key,12) in scales[mode]: return pitch+distance
	return pitch

static func compose(song: Dictionary, settings: Dictionary, start: float, finish: float, original: bool = false) -> Array:
	var notes: Array = []
	var musical_notes: Array = []
	var end: float = Midi.end_beat(song)
	var map: Array = Midi.tempo_map(song.tempos,settings.speed)
	var tracks: Dictionary = {}
	for t in song.tracks: tracks[int(t.id)] = t
	for source in song.notes:
		var track: Dictionary = tracks.get(int(source.track), {})
		if track.get("mute",false) or track.get("level",100.0) <= 0: continue
		var n: Dictionary = source.duplicate(true)
		n.voice = "midi_chip" if str(settings.instrument).begins_with("sid_") and not original else "keys"
		if not original:
			n.pitch = clampi(scaled_pitch(int(n.pitch),int(settings.root),settings.scale)+int(settings.transpose)+int(track.get("octave",0))*12,0,127)
			if settings.reverse: n.beat = maxf(0.0,end-float(n.beat)-float(n.duration))
			# Stable jitter; playback, export and rerender agree, no global RNG.
			var jitter: float = (float(posmod(int(n.id)*7919,1001))/500.0-1.0)*settings.human/1000.0
			var seconds_per_beat: float = Midi.seconds_at(map,float(n.beat)+1.0)-Midi.seconds_at(map,n.beat)
			n.beat = maxf(0.0,float(n.beat)+jitter/maxf(.001,seconds_per_beat))
		n.velocity = clampi(roundi(n.velocity*float(track.get("level",100))/100.0),1,127)
		musical_notes.append(n)
		if (not settings.get("sid_solo",false) or original) and n.beat < finish and n.beat+n.duration > start: notes.append(n)
	if settings.sid and not original and settings.get("sid_follow",false):
		notes.append_array(Arrange.follow(musical_notes,settings,start,finish))
	elif settings.sid and not original:
		var step_length: float = .25/float(settings.get("sid_rate",1.0))
		var first: int = maxi(0,floori(start/step_length)-2)
		var last: int = ceili(finish/step_length)
		for step in range(first,last):
			var beat: float = step*step_length
			if step%2==1: beat+=step_length*float(settings.get("sid_swing",0.0))/100.0
			var index: int = step%16
			for voice in ["bass","kick","snare","hat"]:
				var value: int = int(settings[voice][index])
				if (voice=="bass" and value<0) or (voice!="bass" and value==0): continue
				var note_length: float = step_length*float(settings.get("sid_gate",84.0))/100.0 if voice=="bass" else minf(.13,step_length*.9)
				if beat>=finish or beat+note_length<=start: continue
				var pitch: int = 36+int(settings.root)+int(settings.transpose)+int(settings.get("sid_octave",0))*12+value if voice=="bass" else {"kick":36,"snare":38,"hat":42}[voice]
				notes.append({"id":100000+step*4+["bass","kick","snare","hat"].find(voice),"track":-1,"beat":beat,"duration":note_length,"pitch":clampi(pitch,0,127),"velocity":100 if step%4==0 else 84,"voice":voice})
	notes.sort_custom(func(a,b): return a.beat<b.beat)
	return notes

func cancel() -> void:
	_mutex.lock()
	_cancelled = true
	_mutex.unlock()

func cancelled() -> bool:
	if external_cancel.is_valid() and external_cancel.call(): return true
	_mutex.lock()
	var result: bool = _cancelled
	_mutex.unlock()
	return result

func render(song: Dictionary, settings: Dictionary, start: float, finish: float, original: bool = false) -> Dictionary:
	var s: Dictionary = defaults()
	if not original: s.merge(settings,true)
	s.volume = settings.volume
	var map: Array = Midi.tempo_map(song.tempos,s.speed)
	var begin_seconds: float = Midi.seconds_at(map,start)
	var end_seconds: float = Midi.seconds_at(map,finish)
	var seconds: float = end_seconds-begin_seconds
	if seconds<=0 or seconds>300: return {"error":"Choose a region of five minutes or less."}
	var count: int = ceili((seconds+2.0)*RATE)
	var keys := PackedFloat32Array()
	var is_guitar: bool = s.instrument in ["acoustic_guitar","electric_guitar"]
	var electric: bool = s.instrument=="electric_guitar"
	var guitars := PackedFloat32Array()
	if is_guitar: guitars.resize(count)
	var chips := PackedFloat32Array()
	keys.resize(count)
	chips.resize(count)
	var filter_envelope := PackedFloat32Array()
	filter_envelope.resize(count)
	var table := PackedFloat32Array()
	table.resize(2048)
	for i in range(2048):
		var value: float = 0.0
		for h in range(1,25):
			var level: float = (1.0/pow(h,1.35))*(.58+.42*pow(sin(h*1.7),2))
			if s.instrument=="organ": level = {1:1.0,2:.4,3:.2,4:.1}.get(h,0.0)
			elif s.instrument=="music_box": level = {1:1.0,2:.08,3:.35,5:.13,7:.08}.get(h,0.0)
			elif s.instrument=="dulcimer": level = 1.0/pow(h,1.05)
			elif s.instrument=="reed": level = 1.0/pow(h,1.1) if h%2==1 else .06/h
			value += sin(TAU*i*h/2048.0)*level
		table[i]=value*.55
	var noise := PackedFloat32Array()
	noise.resize(16384)
	var rng := RandomNumberGenerator.new()
	rng.seed=8371
	for i in range(noise.size()): noise[i]=rng.randf_range(-1,1)
	var notes: Array = compose(song,s,start,finish,original)
	var available: int = 0
	for n in notes:
		if cancelled(): return {"cancelled":true}
		var onset: float = Midi.seconds_at(map,n.beat)
		var offset: float = Midi.seconds_at(map,n.beat+n.duration)
		var first: int = maxi(0,roundi((onset-begin_seconds)*RATE))
		var skipped: int = maxi(0,roundi((begin_seconds-onset)*RATE))
		var duration: int = maxi(1,roundi((minf(offset,end_seconds)-maxf(onset,begin_seconds))*RATE))
		var voice: String = n.voice
		var is_chip: bool = voice in ["bass","midi_chip"]
		var release: int = maxi(1,roundi(s.sid_release*.001*RATE)) if is_chip else (1200 if voice=="keys" else 500)
		var limit: int = mini(count-first,duration+release)
		if limit<=0: continue
		var frequency: float = 440.0*pow(2.0,(float(n.pitch)-69.0)/12.0)
		var increment: float = frequency/RATE
		var second_increment: float = increment*pow(2.0,s.detune/1200.0)
		var phase: float = fmod(skipped*increment,1.0)
		var phase2: float = fmod(skipped*second_increment,1.0)
		var amplitude: float = float(n.velocity)/127.0*.14
		var decay: float = exp(-1.0/(maxf(.08,float(s.ring))*.48*RATE))
		var env: float = pow(decay,skipped)
		var sweep: float = pow(2.0,s.sid_sweep/50.0)
		var sweep_decay: float = exp(-1.0/(maxf(.005,s.sid_sweep_time*.001)*RATE))
		var waveform: String = str(s.instrument).trim_prefix("sid_") if voice=="midi_chip" else str(s.sid_wave)
		var slave_phase: float = 0.0
		var attack_time: float = s.sid_attack*.001
		var decay_time: float = s.sid_decay*.001
		var sustain: float = s.sid_sustain/100.0
		var release_time: float = s.sid_release*.001
		var gate_time: float = float(duration+skipped)/RATE
		var lfo_increment: float = TAU*s.sid_lfo_rate/RATE
		var lfo_phase: float = onset*lfo_increment*RATE+skipped*lfo_increment
		var arp_intervals: Array = [0,12] if s.sid_arp=="octave" else ([0,3,7] if s.sid_arp=="minor" else [0])
		var arp_interval: int = maxi(1,roundi(RATE/s.sid_arp_rate))
		var mod_increment: float = increment
		var width: float = s.pulse/100.0
		var env_release: float = exp(-1.0/(maxf(.01,s.sid_filter_decay*.001)*RATE))
		var filter_env: float = pow(env_release,skipped)
		var string_one
		var string_two
		if is_guitar and voice=="keys":
			string_one=Guitar.new()
			string_one.setup(frequency,RATE,s,int(n.id)*7919+17)
			if s.detune>0:
				string_two=Guitar.new()
				string_two.setup(second_increment*RATE,RATE,s,int(n.id)*7919+43)
			for warmup in range(skipped):
				if warmup%8192==0 and cancelled(): return {"cancelled":true}
				string_one.next_sample()
				if string_two!=null: string_two.next_sample()
		var kick_frequency: float = 150.0
		for i in range(limit):
			if i%8192==0 and cancelled(): return {"cancelled":true}
			var value: float = 0.0
			if voice=="keys" and is_guitar:
				value=string_one.next_sample()
				if string_two!=null: value=(value+string_two.next_sample()*.4)/1.15
				value*=amplitude*2.2
			elif voice=="keys":
				value = (table[int(phase*2048)%2048]+table[int(phase2*2048)%2048]*.35)*amplitude
				if s.instrument=="bell":
					var t: float = float(i+skipped)/RATE
					value = amplitude*(sin(TAU*frequency*t)+.3*sin(TAU*second_increment*RATE*t)+.55*sin(TAU*frequency*2.76*t)*exp(-t*3.0)+.24*sin(TAU*frequency*5.4*t)*exp(-t*7.0))
				if s.instrument not in ["organ","reed"]: value *= env
				phase = fmod(phase+increment,1.0)
				phase2 = fmod(phase2+second_increment,1.0)
				env *= decay
				value *= minf(1.0,float(i+skipped)/66.0)
			elif is_chip:
				if i%16==0:
					var motion: float = sin(lfo_phase)
					width = clampf((s.pulse+s.sid_pwm*motion)/100.0,.03,.97)
					var arp_index: int = floori(float(i+skipped)/arp_interval)%arp_intervals.size()
					mod_increment = increment*pow(2.0,(float(arp_intervals[arp_index])+s.sid_vibrato*motion/100.0)/12.0)
				value = Voices.waveform(phase,slave_phase,width,waveform,noise[(i+int(n.id)*17)%noise.size()])*amplitude*.9
				phase += mod_increment*sweep
				slave_phase = fmod(slave_phase+mod_increment*sweep*s.sid_sync_ratio,1.0)
				if phase>=1.0:
					phase = fmod(phase,1.0)
					if waveform=="sync": slave_phase=0.0
				sweep = 1.0+(sweep-1.0)*sweep_decay
				lfo_phase += lfo_increment
				value *= Voices.envelope(float(i+skipped)/RATE,gate_time,attack_time,decay_time,sustain,release_time)
				value *= s.sid_bass_level/100.0
				filter_envelope[first+i] = maxf(filter_envelope[first+i],filter_env)
				filter_env *= env_release
			elif voice=="kick":
				phase = fmod(phase+kick_frequency/RATE,1.0)
				kick_frequency = 42.0+(kick_frequency-42.0)*.998
				value = (1.0-4.0*absf(phase-.5))*amplitude*2.5*exp(-float(i)/(RATE*.06))
			elif voice=="snare":
				value = noise[(i+int(n.id)*17)%noise.size()]*amplitude*1.7*exp(-float(i)/(RATE*.045))
			else:
				value = (noise[i%noise.size()]-noise[(i+1)%noise.size()])*amplitude*.65*exp(-float(i)/(RATE*.018))
			if not is_chip and i>=duration: value *= maxf(0.0,1.0-float(i-duration)/release)
			if voice=="keys" and is_guitar: guitars[first+i]+=value
			elif voice=="keys": keys[first+i]+=value
			else:
				if not is_chip: value *= s.sid_drum_level/100.0
				chips[first+i] += value*(1.0 if voice=="midi_chip" else s.sid_level/100.0)
		available+=1
	if available==0: return {"error":"No enabled notes in this region. Enable a part or the SID layer."}
	var guitar_low: float = 0.0
	var guitar_cab: float = 0.0
	var guitar_dc_x: float = 0.0
	var guitar_dc_y: float = 0.0
	var guitar_filter: float = 1.0-exp(-TAU*s.guitar_tone/RATE)
	var amp_gain: float = 1.0+s.guitar_drive*.35
	var keys_low: float = 0.0
	var chip_low: float = 0.0
	var a: float = 1.0-exp(-TAU*minf(s.brightness,RATE*.45)/RATE)
	var b: float = 1.0-exp(-TAU*minf(s.sid_cutoff,RATE*.45)/RATE)
	var moving_filter: bool = s.sid_filter_mode!="soft" or s.sid_resonance>0 or s.sid_filter_motion>0 or s.sid_filter_env>0
	var b0: float = 1.0
	var b1: float = 0.0
	var b2: float = 0.0
	var a1: float = 0.0
	var a2: float = 0.0
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	var dc_x: float = 0.0
	var dc_y: float = 0.0
	var hold: int = 1+int(s.sid_crunch/12.0)
	var held: float = 0.0
	var levels: float = pow(2.0,16.0-s.sid_crunch*.105)
	var room: float = s.room/100.0
	var echo: float = s.echo/100.0
	var peak: float = 0.0
	var output := PackedFloat32Array()
	output.resize(count)
	var delay: int = roundi(RATE*.285)
	var room_lags: Array[int] = [683,1031,1601,2621,4093,6421]
	for i in range(count):
		if i%8192==0 and cancelled(): return {"cancelled":true}
		var key_input: float=keys[i]
		if is_guitar:
			var pickup: float=guitars[i]-guitar_dc_x+.985*guitar_dc_y
			guitar_dc_x=guitars[i]; guitar_dc_y=pickup
			# Saturation is confined to the guitar bus. Speaker filtering tames fizz.
			var amp: float=.3*tanh(pickup*amp_gain/.3) if electric else pickup
			guitar_low+=guitar_filter*(amp-guitar_low)
			guitar_cab+=guitar_filter*(guitar_low-guitar_cab)
			key_input+=guitar_cab if electric else guitar_low
		keys_low += a*(key_input-keys_low)
		if i%hold==0: held = roundf(chips[i]*levels)/levels
		if moving_filter:
			if i%64==0:
				var motion: float = sin(TAU*s.sid_lfo_rate*(begin_seconds+float(i)/RATE))
				var cutoff: float = clampf(s.sid_cutoff*pow(2.0,motion*s.sid_filter_motion/35.0+filter_envelope[i]*s.sid_filter_env/25.0),70.0,RATE*.4)
				var omega: float = TAU*cutoff/RATE
				var cosine: float = cos(omega)
				var alpha: float = sin(omega)/(2.0*(.707+s.sid_resonance*.045))
				var a0: float = 1.0+alpha
				if s.sid_filter_mode=="bandpass":
					b0=alpha/a0; b1=0.0; b2=-alpha/a0
				elif s.sid_filter_mode=="highpass":
					b0=(1.0+cosine)*.5/a0; b1=-(1.0+cosine)/a0; b2=b0
				else:
					b0=(1.0-cosine)*.5/a0; b1=(1.0-cosine)/a0; b2=b0
				a1=-2.0*cosine/a0; a2=(1.0-alpha)/a0
			chip_low=b0*held+b1*x1+b2*x2-a1*y1-a2*y2
			x2=x1; x1=held; y2=y1; y1=chip_low
		else: chip_low += b*(held-chip_low)
		var ring_mod: float = 1.0-s.sid_ring/100.0+(s.sid_ring/100.0)*sin(TAU*s.sid_ring_hz*i/RATE)
		var chip_value: float = chip_low*ring_mod
		var dc_value: float = chip_value-dc_x+.995*dc_y
		dc_x=chip_value; dc_y=dc_value
		var value: float = keys_low+dc_value
		if s.grit>0: value = tanh(value*(1.0+s.grit*.1)) / (1.0+s.grit*.025)
		keys[i] = value
		for lag in room_lags:
			if i>=lag: value += keys[i-lag]*room*.16
		if i>=delay: value += output[i-delay]*echo*.55
		output[i] = value
		peak=maxf(peak,absf(value))
	var trim: float = minf(1.0,.97/maxf(.001,peak))*s.volume/100.0
	var pcm := PackedByteArray()
	pcm.resize(count*2)
	for i in range(count):
		if i%8192==0 and cancelled(): return {"cancelled":true}
		pcm.encode_s16(i*2,roundi(clampf(output[i]*trim,-1.0,1.0)*32767))
	return {"pcm":pcm,"rate":RATE,"seconds":seconds,"peak":peak*trim,"trimmed":peak>.97,"notes":available}
