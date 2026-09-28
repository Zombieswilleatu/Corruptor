extends RefCounted

const INSTRUMENT_NAMES: Array = ["Plucked harpsichord", "Chamber organ", "Music box", "Hammered dulcimer", "Reed organ", "Iron bell", "SID pulse", "SID saw", "SID triangle", "Acoustic guitar", "Electric guitar"]
const INSTRUMENTS: Array = ["harpsichord", "organ", "music_box", "dulcimer", "reed", "bell", "sid_pulse", "sid_saw", "sid_triangle", "acoustic_guitar", "electric_guitar"]
const KEY_PRESETS: Array = ["Clean keys", "Abandoned chapel", "Broken clock", "Basement ritual", "Dead music box", "Rusted dulcimer", "Reed funeral", "Chip cathedral", "Iron chapel", "Crypt acoustic", "Clean electric", "Doom metal", "Black metal"]
const SID_PRESETS: Array = ["Machine", "Alien", "Doom", "Alien / breathing filter", "Hollow transmission", "Nostromo pulse", "Acid march", "Clock swarm", "Ghost sonar", "Metal ritual", "Airlock hiss", "Clear"]

static func defaults() -> Dictionary:
	return {"guitar_drive":20.0,"guitar_sustain":2.5,"guitar_mute":0.0,"guitar_tone":4500.0,"guitar_pick":22.0,"guitar_pick_rate":0.0, "sid_follow":false, "sid_solo":false, "sid_wave":"pulse", "sid_pwm":0.0, "sid_lfo_rate":1.2, "sid_vibrato":0.0,
		"sid_filter_env":0.0, "sid_filter_decay":300.0, "sid_resonance":0.0, "sid_filter_mode":"soft", "sid_filter_motion":0.0,
		"sid_attack":2.0, "sid_decay":160.0, "sid_sustain":100.0, "sid_release":23.0,
		"sid_gate":84.0, "sid_rate":1.0, "sid_swing":0.0, "sid_octave":0.0,
		"sid_bass_level":100.0, "sid_drum_level":100.0, "sid_sync_ratio":2.0,
		"sid_ring_hz":96.0, "sid_sweep_time":35.0, "sid_arp":"off", "sid_arp_rate":16.0}

static func key_patch(title: String) -> Dictionary:
	match title:
		"Abandoned chapel": return {"speed":78.0,"scale":"harmonic","transpose":-12.0,"brightness":3200.0,"room":52.0,"detune":5.0,"ring":1.7}
		"Broken clock": return {"speed":88.0,"scale":"minor","detune":23.0,"grit":32.0,"human":21.0,"brightness":5400.0,"echo":19.0}
		"Basement ritual": return {"speed":65.0,"scale":"phrygian","transpose":-12.0,"instrument":"organ","brightness":1900.0,"room":60.0,"grit":22.0}
		"Dead music box": return {"instrument":"music_box","speed":76.0,"detune":13.0,"ring":2.1,"room":42.0,"echo":24.0,"human":9.0}
		"Rusted dulcimer": return {"instrument":"dulcimer","detune":17.0,"ring":.7,"grit":28.0,"brightness":4200.0,"human":12.0,"room":30.0}
		"Reed funeral": return {"instrument":"reed","speed":65.0,"transpose":-12.0,"detune":8.0,"brightness":2600.0,"room":50.0}
		"Chip cathedral": return {"instrument":"sid_triangle","speed":85.0,"room":55.0,"echo":28.0}
		"Crypt acoustic": return {"instrument":"acoustic_guitar","speed":88.0,"guitar_sustain":2.8,"guitar_pick":28.0,"guitar_tone":4000.0,"detune":3.0,"room":35.0,"echo":12.0,"grit":0.0}
		"Clean electric": return {"instrument":"electric_guitar","guitar_drive":5.0,"guitar_sustain":3.5,"guitar_tone":4300.0,"guitar_pick":18.0,"room":22.0,"grit":0.0}
		"Doom metal": return {"instrument":"electric_guitar","speed":65.0,"transpose":-12.0,"guitar_drive":82.0,"guitar_sustain":7.0,"guitar_mute":8.0,"guitar_tone":1900.0,"guitar_pick":30.0,"guitar_pick_rate":0.0,"detune":5.0,"brightness":6000.0,"room":36.0,"echo":10.0,"grit":0.0}
		"Black metal": return {"instrument":"electric_guitar","speed":135.0,"guitar_drive":93.0,"guitar_sustain":3.0,"guitar_mute":12.0,"guitar_tone":5000.0,"guitar_pick":13.0,"guitar_pick_rate":11.0,"detune":4.0,"brightness":9000.0,"room":48.0,"echo":12.0,"grit":0.0}
		"Iron chapel": return {"instrument":"bell","transpose":-12.0,"ring":2.7,"room":55.0,"echo":20.0}
	return {}

static func sid_patch(title: String) -> Dictionary:
	match title:
		"Alien": return {"bass":[0,-1,12,7,-1,3,10,-1,0,12,-1,7,3,-1,10,12],"kick":[1,0,0,1,0,0,1,0,1,0,1,0,0,1,0,0],"sid_ring":65.0,"sid_sweep":75.0,"sid_crunch":60.0,"pulse":16.0}
		"Doom": return {"bass":[0,-1,-1,-1,-1,-1,3,-1,0,-1,-1,-1,10,-1,7,-1],"hat":[0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0],"sid_cutoff":1100.0,"sid_crunch":45.0}
		"Alien / breathing filter": return {"sid_wave":"saw","sid_filter_mode":"lowpass","sid_cutoff":220.0,"sid_resonance":82.0,"sid_filter_motion":68.0,"sid_lfo_rate":.28,"sid_filter_env":40.0,"sid_filter_decay":700.0,"sid_attack":35.0,"sid_decay":700.0,"sid_sustain":75.0,"sid_release":420.0,"sid_gate":98.0,"sid_rate":.5,"sid_crunch":0.0,"sid_drum_level":15.0,"bass":[0,-1,7,-1,0,-1,3,-1,0,-1,7,-1,10,-1,3,-1]}
		"Hollow transmission": return {"sid_wave":"pulse","pulse":35.0,"sid_pwm":24.0,"sid_lfo_rate":.65,"sid_gate":98.0,"sid_rate":.5,"sid_attack":18.0,"sid_release":300.0,"sid_vibrato":12.0,"sid_crunch":0.0,"bass":[0,-1,0,-1,7,-1,3,-1,0,-1,0,-1,10,-1,7,-1],"sid_drum_level":24.0,"sid_cutoff":2600.0}
		"Nostromo pulse": return {"sid_wave":"pulse","pulse":18.0,"sid_pwm":14.0,"sid_lfo_rate":.9,"sid_filter_mode":"lowpass","sid_cutoff":850.0,"sid_filter_motion":55.0,"sid_resonance":48.0,"sid_gate":92.0,"sid_decay":220.0,"sid_sustain":50.0,"sid_release":160.0,"sid_crunch":8.0,"sid_swing":12.0,"sid_drum_level":50.0}
		"Acid march": return {"sid_wave":"saw","sid_filter_mode":"lowpass","sid_resonance":72.0,"sid_cutoff":700.0,"sid_filter_motion":72.0,"sid_lfo_rate":1.8,"sid_decay":90.0,"sid_sustain":15.0,"sid_gate":72.0,"sid_swing":22.0,"sid_crunch":10.0}
		"Clock swarm": return {"sid_wave":"pulse","pulse":12.0,"sid_arp":"minor","sid_arp_rate":24.0,"sid_gate":96.0,"sid_pwm":8.0,"sid_crunch":32.0,"sid_octave":1.0,"sid_bass_level":65.0,"sid_drum_level":40.0}
		"Ghost sonar": return {"sid_wave":"triangle","sid_attack":8.0,"sid_decay":350.0,"sid_sustain":0.0,"sid_release":400.0,"sid_rate":.5,"sid_octave":1.0,"sid_vibrato":24.0,"sid_lfo_rate":4.0,"sid_crunch":0.0,"sid_drum_level":0.0,"bass":[0,-1,-1,-1,7,-1,-1,-1,3,-1,-1,-1,10,-1,-1,-1]}
		"Metal ritual": return {"sid_wave":"sync","sid_sync_ratio":3.7,"sid_ring":58.0,"sid_ring_hz":173.0,"sid_sweep":45.0,"sid_sweep_time":240.0,"sid_filter_mode":"bandpass","sid_cutoff":1700.0,"sid_resonance":40.0,"sid_release":130.0,"sid_crunch":22.0,"sid_drum_level":65.0}
		"Airlock hiss": return {"sid_wave":"noise","sid_filter_mode":"bandpass","sid_cutoff":900.0,"sid_filter_motion":65.0,"sid_lfo_rate":.35,"sid_resonance":55.0,"sid_attack":60.0,"sid_decay":400.0,"sid_sustain":30.0,"sid_release":200.0,"sid_rate":.5,"sid_drum_level":0.0,"sid_crunch":15.0}
	return {}

static func waveform(phase: float, slave: float, width: float, kind: String, noise: float) -> float:
	match kind:
		"saw": return 2.0*phase-1.0
		"triangle": return 1.0-4.0*absf(phase-.5)
		"sync": return 2.0*slave-1.0
		"noise": return noise
	return (1.0 if phase<width else -1.0)-(2.0*width-1.0)

static func envelope(time: float, gate: float, attack: float, decay: float, sustain: float, release_time: float) -> float:
	var held: float=minf(time,gate)
	var level: float
	if held<attack: level=held/maxf(.0001,attack)
	else: level=lerpf(1.0,sustain,clampf((held-attack)/maxf(.0001,decay),0.0,1.0))
	if time>gate: level*=maxf(0.0,1.0-(time-gate)/maxf(.0001,release_time))
	return level
