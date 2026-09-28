extends RefCounted
const Synth = preload("res://Prototype/U13/GameMusicRender/U13MusicSynth.gd")
const Midi = preload("res://Prototype/U13/GameMusicRender/U13MusicMidi.gd")
const Voices = preload("res://Prototype/U13/GameMusicRender/U13MusicVoices.gd")
const RENDER_VERSION: String = "music-lab-guitars-v1-game-json-1"
const RANGES: Dictionary = {"speed": [40.0, 180.0], "transpose": [-24.0, 24.0], "human": [0.0, 45.0], "sid_rate": [0.5, 2.0], "sid_swing": [0.0, 60.0], "sid_gate": [25.0, 100.0], "sid_octave": [-2.0, 2.0], "pulse": [5.0, 95.0], "sid_sync_ratio": [1.0, 8.0], "sid_cutoff": [100.0, 9000.0], "sid_resonance": [0.0, 90.0], "sid_crunch": [0.0, 100.0], "sid_lfo_rate": [0.1, 12.0], "sid_pwm": [0.0, 45.0], "sid_vibrato": [0.0, 200.0], "sid_filter_motion": [0.0, 100.0], "sid_ring": [0.0, 100.0], "sid_ring_hz": [20.0, 900.0], "sid_arp_rate": [4.0, 40.0], "sid_attack": [2.0, 500.0], "sid_decay": [10.0, 1500.0], "sid_sustain": [0.0, 100.0], "sid_release": [5.0, 1500.0], "sid_sweep": [0.0, 100.0], "sid_sweep_time": [10.0, 800.0], "sid_filter_env": [0.0, 100.0], "sid_filter_decay": [20.0, 2000.0], "sid_level": [0.0, 100.0], "sid_bass_level": [0.0, 100.0], "sid_drum_level": [0.0, 100.0], "guitar_drive": [0.0, 100.0], "guitar_sustain": [0.2, 8.0], "guitar_mute": [0.0, 100.0], "guitar_tone": [600.0, 6500.0], "guitar_pick": [10.0, 45.0], "guitar_pick_rate": [0.0, 16.0], "volume": [0.0, 100.0], "brightness": [350.0, 10000.0], "ring": [0.15, 3.0], "detune": [0.0, 35.0], "grit": [0.0, 100.0], "room": [0.0, 75.0], "echo": [0.0, 70.0], "root": [0, 11]}

static func fingerprint(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 32000000: return "unreadable"
	return RENDER_VERSION + ":" + file.get_as_text().sha256_text()

static func numeric(value) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func valid_song(song) -> bool:
	if not song is Dictionary or not song.get("notes") is Array or not song.get("tracks") is Array or not song.get("tempos") is Array: return false
	if song.notes.size() > 30000 or song.tracks.is_empty() or song.tracks.size() > 512 or song.tempos.is_empty(): return false
	var ids: Array[int] = []
	for track in song.tracks:
		if not track is Dictionary or not numeric(track.get("id")): return false
		ids.append(int(track.id))
		for key in ["level", "octave"]:
			if track.has(key) and not numeric(track[key]): return false
	for note in song.notes:
		if not note is Dictionary: return false
		for key in ["id", "track", "beat", "duration", "pitch", "velocity"]:
			if not numeric(note.get(key)): return false
		if int(note.track) not in ids or note.beat < 0 or note.beat > 100000 or note.duration <= 0 or note.duration > 10000 or note.pitch < 0 or note.pitch > 127 or note.velocity < 1 or note.velocity > 127: return false
	for tempo in song.tempos:
		if not tempo is Dictionary or not numeric(tempo.get("beat")) or not numeric(tempo.get("us")): return false
		if tempo.beat < 0 or tempo.beat > 100000 or tempo.us < 1 or tempo.us > 16777215: return false
	return true

static func settings_for(saved: Dictionary) -> Dictionary:
	var safe: Dictionary = Synth.defaults()
	var options := {"instrument": Voices.INSTRUMENTS, "scale": ["keep", "minor", "harmonic", "phrygian"], "sid_wave": ["pulse", "saw", "triangle", "sync", "noise"], "sid_filter_mode": ["soft", "lowpass", "bandpass", "highpass"], "sid_arp": ["off", "octave", "minor"]}
	for key in safe:
		if not saved.has(key): continue
		if key in ["bass", "kick", "snare", "hat"]:
			if not saved[key] is Array or saved[key].size() != 16: continue
			for i in range(16):
				if not numeric(saved[key][i]): continue
				var value: int = int(saved[key][i])
				if value in ([-1,0,3,7,10,12] if key == "bass" else [0,1]): safe[key][i] = value
		elif RANGES.has(key) and numeric(saved[key]):
			safe[key] = clampf(float(saved[key]), float(RANGES[key][0]), float(RANGES[key][1]))
		elif options.has(key):
			if saved[key] in options[key]: safe[key] = saved[key]
		elif safe[key] is bool and saved[key] is bool: safe[key] = saved[key]
	# The playlist replaces the lab's monitor volume with measured gain + music volume.
	safe.volume = 100.0
	return safe

static func prepare(path: String, cancelled: Callable) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 32000000: return {"error": "Music Lab project missing or over 32 MB"}
	var text: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary or parsed.get("format") != "CORRUPTOR_MUSIC_LAB_V1" or not valid_song(parsed.get("song")) or not parsed.get("settings") is Dictionary:
		return {"error": "not a valid saved Music Lab arrangement"}
	if cancelled.call(): return {"cancelled": true}
	var stamp: String = RENDER_VERSION + ":" + text.sha256_text()
	var cache_dir: String = "user://game_music_render_cache"
	DirAccess.make_dir_recursive_absolute(cache_dir)
	var cache_path: String = cache_dir.path_join(path.sha256_text() + ".wav")
	var cache_info := ConfigFile.new()
	if cache_info.load(cache_path + ".cfg") == OK and cache_info.get_value("render", "stamp", "") == stamp and FileAccess.file_exists(cache_path):
		var cached := AudioStreamWAV.load_from_file(cache_path)
		if cached != null:
			cached.loop_mode = AudioStreamWAV.LOOP_DISABLED
			return {"stream": cached, "render_cached": true}
	var settings: Dictionary = settings_for(parsed.settings)
	var song: Dictionary = parsed.song.duplicate(true)
	song.tempos.sort_custom(func(a, b): return float(a.beat) < float(b.beat))
	for track in song.tracks:
		track.level = clampf(float(track.get("level", 100.0)), 0.0, 100.0)
		track.octave = clampi(int(track.get("octave", 0)), -4, 4)
	var start: float = 0.0
	var finish: float = Midi.end_beat(song)
	if parsed.get("region") is Array and parsed.region.size() == 2:
		if not numeric(parsed.region[0]) or not numeric(parsed.region[1]): return {"error": "invalid saved playback region"}
		start = float(parsed.region[0])
		finish = float(parsed.region[1])
	if start < 0 or finish <= start or finish > 100000: return {"error": "invalid saved playback region"}
	var map: Array = Midi.tempo_map(song.tempos, settings.speed)
	var seconds: float = Midi.seconds_at(map, finish) - Midi.seconds_at(map, start)
	if seconds <= 0 or seconds > 300.0:
		return {"error": "saved region exceeds the Music Lab's five-minute render limit; shorten its region and resave"}
	print("GAME MUSIC · rendering saved arrangement: " + path.get_file())
	var renderer := Synth.new()
	renderer.external_cancel = cancelled
	var result: Dictionary = renderer.render(song, settings, start, finish)
	if result.has("error") or result.has("cancelled"): return result
	if cancelled.call(): return {"cancelled": true}
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(result.rate)
	stream.stereo = false
	stream.data = result.pcm
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	var temp_path: String = cache_path + ".pending.wav"
	if stream.save_to_wav(temp_path) == OK:
		if FileAccess.file_exists(cache_path): DirAccess.remove_absolute(cache_path)
		if DirAccess.rename_absolute(temp_path, cache_path) == OK:
			cache_info.set_value("render", "stamp", stamp)
			cache_info.save(cache_path + ".cfg")
	return {"stream": stream, "render_cached": false}
