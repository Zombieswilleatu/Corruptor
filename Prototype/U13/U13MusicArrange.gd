extends RefCounted
const Voices=preload("res://Prototype/U13/U13MusicVoices.gd")

# Follow the lowest sounding note, including held notes underneath a melody.
# Durations and note attacks are in beats, so the source tempo map still applies.
static func follow(notes: Array, settings: Dictionary, start: float, finish: float) -> Array:
	var events: Array=[]
	for i in range(notes.size()):
		var n: Dictionary=notes[i]
		events.append({"beat":float(n.beat),"on":true,"index":i})
		events.append({"beat":float(n.beat+n.duration),"on":false,"index":i})
	events.sort_custom(func(a,b): return a.beat<b.beat if a.beat!=b.beat else int(a.on)<int(b.on))
	var active: Dictionary={}
	var bass: Array=[]
	var attacks: Array=[]
	var segment: Dictionary={}
	var cursor: int=0
	while cursor<events.size():
		var beat: float=events[cursor].beat
		var starts: Array=[]
		while cursor<events.size() and absf(events[cursor].beat-beat)<.00001:
			var event: Dictionary=events[cursor]
			if event.on:
				active[event.index]=notes[event.index]
				starts.append(notes[event.index])
			else: active.erase(event.index)
			cursor+=1
		var lowest: Dictionary={}
		for n in active.values():
			if lowest.is_empty() or n.pitch<lowest.pitch: lowest=n
		var reattack: bool=false
		var strength: int=0
		for n in starts:
			strength=maxi(strength,int(n.velocity))
			if not lowest.is_empty() and n.pitch==lowest.pitch: reattack=true
		if not starts.is_empty(): attacks.append({"beat":beat,"strength":strength,"count":starts.size()})
		if not segment.is_empty() and (lowest.is_empty() or segment.pitch!=lowest.pitch or reattack):
			segment.duration=maxf(.001,beat-segment.beat)
			bass.append(segment)
			segment={}
		if segment.is_empty() and not lowest.is_empty():
			segment={"beat":beat,"pitch":int(lowest.pitch),"velocity":int(lowest.velocity)}
	var output: Array=[]
	var serial: int=200000
	var last_kick: float=-100.0
	var kick_beats: Dictionary={}
	for n in bass:
		var pitch: int=int(n.pitch)
		while pitch<36: pitch+=12
		while pitch>59: pitch-=12
		pitch=clampi(pitch+int(settings.get("sid_octave",0))*12,0,127)
		var duration: float=maxf(.02,n.duration*float(settings.get("sid_gate",84.0))/100.0)
		if n.beat<finish and n.beat+duration>start:
			output.append(_note(serial,n.beat,duration,pitch,clampi(int(n.velocity),35,115),"bass"))
			serial+=1
		# Keep fast ornaments from turning the kick into a machine gun.
		if n.beat-last_kick>=.49:
			last_kick=n.beat
			kick_beats[roundi(n.beat*960)]=true
			if n.beat>=start and n.beat<finish:
				output.append(_note(serial,n.beat,.12,36,clampi(int(n.velocity),45,110),"kick"))
				serial+=1
	var last_hat: float=-100.0
	var last_snare: float=-100.0
	for attack in attacks:
		if attack.beat-last_hat>=.124:
			last_hat=attack.beat
			if attack.beat>=start and attack.beat<finish:
				output.append(_note(serial,attack.beat,.07,42,clampi(roundi(attack.strength*.6),25,80),"hat"))
				serial+=1
		if attack.count>=2 and attack.strength>=85 and attack.beat-last_snare>=.49 and not kick_beats.has(roundi(attack.beat*960)):
			last_snare=attack.beat
			if attack.beat>=start and attack.beat<finish:
				output.append(_note(serial,attack.beat,.12,38,clampi(roundi(attack.strength*.7),35,95),"snare"))
				serial+=1
	return output

static func _note(id: int, beat: float, duration: float, pitch: int, velocity: int, voice: String) -> Dictionary:
	return {"id":id,"track":-1,"beat":beat,"duration":duration,"pitch":pitch,"velocity":velocity,"voice":voice}

# Bounded, reproducible variations. Master gain, tempo, key and all SID design
# settings are intentionally kept. Note variants always start from a baseline.
static func variation(settings: Dictionary, base_notes: Array, intensity: int, vary_notes: bool, seed_value: int) -> Dictionary:
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value
	var amount: int=clampi(intensity,0,2)
	var s: Dictionary=settings.duplicate(true)
	var previous: String=str(s.instrument)
	var choices: Array=Voices.INSTRUMENTS.duplicate()
	choices.erase(previous)
	s.instrument=choices[rng.randi_range(0,choices.size()-1)]
	s.brightness=rng.randf_range([3000.0,1500.0,500.0][amount],9000.0)
	s.ring=rng.randf_range(.35,[1.8,2.5,3.0][amount])
	s.detune=rng.randf_range(0.0,[6.0,18.0,35.0][amount])
	s.grit=rng.randf_range(0.0,[12.0,45.0,80.0][amount])
	s.room=rng.randf_range(8.0,[35.0,55.0,75.0][amount])
	s.echo=rng.randf_range(0.0,[15.0,35.0,65.0][amount])
	if s.instrument in ["acoustic_guitar","electric_guitar"]:
		s.guitar_drive=rng.randf_range(0.0,[20.0,60.0,95.0][amount])
		s.guitar_sustain=rng.randf_range(.7,[3.0,5.0,7.5][amount])
		s.guitar_mute=rng.randf_range(0.0,[15.0,45.0,75.0][amount])
		s.guitar_tone=rng.randf_range(1400.0,6000.0)
		s.guitar_pick=rng.randf_range(10.0,40.0)
		s.guitar_pick_rate=float(rng.randi_range(6,14)) if amount==2 and rng.randf()<.5 else 0.0
	s.sid_solo=false
	var changed: Array=base_notes.duplicate(true)
	if vary_notes:
		for n in changed:
			if rng.randf()<[.12,.25,.45][amount]:
				var shifted: int=int(n.pitch)+(12 if rng.randf()<.5 else -12)
				if shifted>=0 and shifted<=127: n.pitch=shifted
			n.duration=maxf(.0625,float(n.duration)*rng.randf_range([.95,.85,.65][amount],[1.05,1.15,1.3][amount]))
			n.velocity=clampi(roundi(float(n.velocity)*rng.randf_range(.85,1.15)),1,127)
	return {"settings":s,"notes":changed}
