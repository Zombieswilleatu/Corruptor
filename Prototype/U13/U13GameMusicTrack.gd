extends RefCounted
## Runtime loading and gated RMS matching. Originals are never rewritten.
## This is active-window RMS, not an EBU R128/LUFS meter.
const Project = preload("res://Prototype/U13/U13GameMusicProject.gd")
const ANALYSIS_VERSION: int = 2
const TARGET_DB: float = -23.0
const PEAK_CEILING_DB: float = -1.5
const MAX_BOOST_DB: float = 24.0

static func fingerprint(path: String) -> String:
	if path.get_extension().to_lower() == "json": return str(ANALYSIS_VERSION) + ":" + Project.fingerprint(path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	return "%d:%d:%d" % [ANALYSIS_VERSION, FileAccess.get_modified_time(path), file.get_length()]

static func load_track(path: String) -> AudioStream:
	var stream: AudioStream
	match path.get_extension().to_lower():
		"wav":
			stream = AudioStreamWAV.load_from_file(path, {"force/max_rate": false, "edit/normalize": false, "edit/trim": false, "edit/loop_mode": 0})
			if stream != null: (stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
		"mp3":
			stream = AudioStreamMP3.load_from_file(path)
			if stream != null: (stream as AudioStreamMP3).loop = false
		"ogg":
			stream = AudioStreamOggVorbis.load_from_file(path)
			if stream != null: (stream as AudioStreamOggVorbis).loop = false
	return stream

static func prepare(path: String, cached: Dictionary, mix_rate: float, cancelled: Callable) -> Dictionary:
	var stamp := fingerprint(path)
	var stream: AudioStream
	if path.get_extension().to_lower() == "json":
		var project_result: Dictionary = Project.prepare(path, cancelled)
		if project_result.get("cancelled", false): return {"cancelled": true}
		if project_result.has("error"): return {"path": path, "error": project_result.error, "stamp": stamp}
		stream = project_result.stream
	else:
		stream = load_track(path)
	if stream == null: return {"path": path, "error": "could not decode", "stamp": stamp}
	var length: float = stream.get_length()
	if not is_finite(length) or length < 0.05:
		return {"path": path, "error": "empty or invalid duration", "stamp": stamp}
	if cached.get("stamp", "") == stamp and cached.has("gain_db") and cached.has("rms_db"):
		return {"path": path, "stream": stream, "length": length, "analysis": cached, "cached": true}
	var playback := stream.instantiate_playback()
	if playback == null: return {"path": path, "error": "could not decode samples", "stamp": stamp}
	playback.start()
	var remaining: int = ceili(length * mix_rate)
	var block_frames: int = maxi(1, roundi(mix_rate * 0.1))
	var energies: Array[float] = []
	var weights: Array[int] = []
	var peak: float = 0.0
	var energy_sum: float = 0.0
	var frame_sum: int = 0
	while remaining > 0:
		if cancelled.call():
			playback.stop()
			return {"cancelled": true}
		var count: int = mini(remaining, block_frames)
		var samples: PackedVector2Array = playback.mix_audio(1.0, count)
		if samples.is_empty(): break
		var energy: float = 0.0
		for sample in samples:
			energy += (sample.x * sample.x + sample.y * sample.y) * 0.5
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		var mean_energy: float = energy / float(samples.size())
		# Ignore silence below -60 dBFS before calculating the relative gate.
		if mean_energy > 0.000001:
			energies.append(mean_energy)
			weights.append(samples.size())
			energy_sum += energy
			frame_sum += samples.size()
		remaining -= count
	playback.stop()
	if frame_sum == 0 or peak < 0.00001:
		return {"path": path, "error": "silent recording", "stamp": stamp}
	var gate: float = energy_sum / float(frame_sum) * 0.1
	energy_sum = 0.0
	frame_sum = 0
	for index in range(energies.size()):
		if energies[index] >= gate:
			energy_sum += energies[index] * weights[index]
			frame_sum += weights[index]
	var rms_db: float = linear_to_db(sqrt(energy_sum / float(maxi(1, frame_sum))))
	var peak_db: float = linear_to_db(peak)
	# Match active musical passages; preserve peak headroom without clipping.
	var gain_db: float = minf(minf(TARGET_DB - rms_db, MAX_BOOST_DB), PEAK_CEILING_DB - peak_db)
	var analysis := {"stamp": stamp, "gain_db": gain_db, "rms_db": rms_db, "peak_db": peak_db}
	return {"path": path, "stream": stream, "length": length, "analysis": analysis, "cached": false}
