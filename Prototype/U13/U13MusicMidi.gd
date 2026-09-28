extends RefCounted

# Standard MIDI type 0/1, beat timing. Sustain is baked into note lengths.
# No external packages, soundfonts, account or MIDI device required.
class Reader:
	extends RefCounted
	var data: PackedByteArray
	var pos: int = 0
	var end: int = 0
	var error: String = ""
	func byte() -> int:
		if pos >= end:
			error = "Truncated MIDI data."
			return 0
		var value: int = data[pos]
		pos += 1
		return value
	func word() -> int: return (byte() << 8) | byte()
	func long_word() -> int: return (word() << 16) | word()
	func variable() -> int:
		var value: int = 0
		for i in range(4):
			var b: int = byte()
			value = (value << 7) | (b & 127)
			if b < 128: return value
		error = "Invalid MIDI event length."
		return 0
	func take(count: int) -> PackedByteArray:
		if count < 0 or pos + count > end:
			error = "Truncated MIDI event."
			return PackedByteArray()
		var result: PackedByteArray = data.slice(pos, pos + count)
		pos += count
		return result

static func load_file(path: String) -> Dictionary:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() > 16000000: return {"error": "Please use a MIDI smaller than 16 MB."}
	var result: Dictionary = parse(bytes)
	if result.has("song"): result.song.name = path.get_file().get_basename()
	return result

static func parse(bytes: PackedByteArray) -> Dictionary:
	var r := Reader.new()
	r.data = bytes
	r.end = bytes.size()
	if r.take(4).get_string_from_ascii() != "MThd": return {"error": "Choose a standard .mid or .midi file."}
	var header: int = r.long_word()
	if header < 6: return {"error": "Invalid MIDI header."}
	var format: int = r.word()
	var count: int = r.word()
	var ppq: int = r.word()
	r.take(header - 6)
	if format > 1: return {"error": "Type 2 MIDI is not supported. Export as type 0 or 1."}
	if ppq == 0 or ppq & 32768: return {"error": "Timecode MIDI is not supported. Use beat-based timing."}
	if count > 512: return {"error": "Too many MIDI tracks."}
	var notes: Array = []
	var tracks: Array = []
	var tempos: Array = []
	var warnings: Array = []
	var serial: int = 1
	for ti in range(count):
		if r.take(4).get_string_from_ascii() != "MTrk": return {"error": "Invalid MIDI track."}
		var length: int = r.long_word()
		var finish: int = r.pos + length
		if finish > bytes.size(): return {"error": "Truncated MIDI track."}
		r.end = finish
		var tick: int = 0
		var running: int = 0
		var title: String = "Track %d" % (ti + 1)
		var active: Dictionary = {}
		var held: Dictionary = {}
		var pedals: Dictionary = {}
		var voices: Dictionary = {}
		while r.pos < finish and r.error.is_empty():
			tick += r.variable()
			var status: int = r.byte()
			if status < 128:
				if running == 0: return {"error": "Invalid MIDI running status."}
				r.pos -= 1
				status = running
			elif status < 240: running = status
			if status == 255:
				var kind: int = r.byte()
				var data: PackedByteArray = r.take(r.variable())
				if kind == 3:
					title = data.get_string_from_utf8().substr(0, 120)
					for voice in voices.values(): voice.name = title
				elif kind == 81 and data.size() == 3:
					var us: int = (int(data[0]) << 16) | (int(data[1]) << 8) | int(data[2])
					if us > 0: tempos.append({"beat": float(tick) / ppq, "us": us})
				elif kind == 47: break
				continue
			if status in [240, 247]:
				r.take(r.variable())
				running = 0
				continue
			if status >= 240: return {"error": "Unsupported MIDI system event."}
			var kind: int = status >> 4
			var channel: int = status & 15
			var x: int = r.byte()
			var y: int = 0 if kind in [12, 13] else r.byte()
			if x > 127 or y > 127: return {"error": "Invalid MIDI note data."}
			var key: String = "%d:%d" % [channel, x]
			if kind == 9 and y > 0:
				if not voices.has(channel):
					voices[channel] = {"id": ti * 16 + channel, "name": title, "channel": channel, "mute": channel == 9, "level": 100.0, "octave": 0}
					tracks.append(voices[channel])
				if not active.has(key): active[key] = []
				active[key].append({"id": serial, "track": ti * 16 + channel, "beat": float(tick) / ppq, "pitch": x, "velocity": y})
				serial += 1
			elif kind == 8 or (kind == 9 and y == 0):
				if not active.get(key, []).is_empty():
					var note: Dictionary = active[key].pop_front()
					if pedals.get(channel, false):
						if not held.has(channel): held[channel] = []
						held[channel].append(note)
					else: _finish_note(notes, note, float(tick) / ppq)
			elif kind == 11 and x == 64:
				if pedals.get(channel, false) and y < 64:
					for note in held.get(channel, []): _finish_note(notes, note, float(tick) / ppq)
					held.erase(channel)
				pedals[channel] = y >= 64
			elif kind in [10, 11, 13, 14]:
				if warnings.is_empty(): warnings.append("Bends/expression automation omitted; sustain becomes note lengths.")
			if serial > 30000: return {"error": "Please use an excerpt with fewer than 30,000 notes."}
		if not r.error.is_empty(): return {"error": r.error}
		for list in active.values():
			for note in list: _finish_note(notes, note, maxf(float(tick) / ppq, note.beat + 0.25))
		for list in held.values():
			for note in list: _finish_note(notes, note, float(tick) / ppq)
		r.pos = finish
		r.end = bytes.size()
	if notes.is_empty(): return {"error": "No note events found."}
	if tempos.is_empty(): tempos.append({"beat": 0.0, "us": 500000})
	notes.sort_custom(func(a, b): return a.beat < b.beat)
	return {"song": {"name": "Imported MIDI", "notes": notes, "tracks": tracks, "tempos": tempos, "warnings": warnings}}

static func _finish_note(notes: Array, note: Dictionary, beat: float) -> void:
	note.duration = maxf(1.0 / 960.0, beat - float(note.beat))
	notes.append(note)

static func end_beat(song: Dictionary) -> float:
	var last: float = 1.0
	for note in song.notes: last = maxf(last, float(note.beat) + float(note.duration))
	return last

static func tempo_map(tempos: Array, speed: float = 100.0) -> Array:
	var sorted: Array = tempos.duplicate(true)
	sorted.sort_custom(func(a, b): return a.beat < b.beat)
	if sorted.is_empty() or sorted[0].beat > 0.0: sorted.push_front({"beat": 0.0, "us": 500000})
	var result: Array = []
	for row in sorted:
		var t: Dictionary = {"beat": float(row.beat), "us": float(row.us) * 100.0 / speed, "seconds": 0.0}
		if not result.is_empty() and result.back().beat == t.beat: result.pop_back()
		if not result.is_empty():
			var previous: Dictionary = result.back()
			t.seconds = previous.seconds + (t.beat - previous.beat) * previous.us / 1000000.0
		result.append(t)
	return result

static func seconds_at(map: Array, beat: float) -> float:
	var row: Dictionary = map[0]
	for next in map:
		if next.beat > beat: break
		row = next
	return row.seconds + (beat - row.beat) * row.us / 1000000.0

static func _vlq(value: int) -> PackedByteArray:
	var result := PackedByteArray([value & 127])
	value >>= 7
	while value > 0:
		result.insert(0, (value & 127) | 128)
		value >>= 7
	return result

static func _u32(value: int) -> PackedByteArray:
	return PackedByteArray([(value >> 24) & 255, (value >> 16) & 255, (value >> 8) & 255, value & 255])

static func _track(events: Array) -> PackedByteArray:
	events.sort_custom(func(a, b): return a.tick < b.tick if a.tick != b.tick else a.order < b.order)
	var bytes := PackedByteArray()
	var tick: int = 0
	for event in events:
		bytes.append_array(_vlq(int(event.tick) - tick))
		bytes.append_array(event.bytes)
		tick = event.tick
	bytes.append_array(PackedByteArray([0, 255, 47, 0]))
	return "MTrk".to_ascii_buffer() + _u32(bytes.size()) + bytes

static func encode(notes: Array, tempos: Array, settings: Dictionary) -> PackedByteArray:
	var groups: Dictionary = {}
	for note in notes:
		var key: String = str(note.track) + ":" + str(note.get("voice", "keys"))
		if not groups.has(key): groups[key] = []
		groups[key].append(note)
	var result := PackedByteArray([77,84,104,100,0,0,0,6,0,1,(groups.size()+1)>>8,(groups.size()+1)&255,3,192])
	var timing: Array = []
	for row in tempo_map(tempos, settings.speed):
		var us: int = clampi(roundi(row.us), 1, 16777215)
		timing.append({"tick": roundi(row.beat*960), "order": 0, "bytes": PackedByteArray([255,81,3,(us>>16)&255,(us>>8)&255,us&255])})
	result.append_array(_track(timing))
	var channel: int = 0
	for key in groups:
		var list: Array = groups[key]
		var voice: String = str(list[0].get("voice", "keys"))
		var drum: bool = voice in ["kick", "snare", "hat"]
		var ch: int = 9 if drum else (channel % 15 if channel % 15 < 9 else channel % 15 + 1)
		channel += 1
		var programs: Dictionary = {"harpsichord":6,"organ":19,"music_box":10,"dulcimer":15,"reed":20,"bell":14,"sid_pulse":80,"sid_saw":81,"sid_triangle":80,"acoustic_guitar":25,"electric_guitar":(30 if settings.get("guitar_drive",20.0)>=25.0 else 27)}
		var program: int = (81 if settings.get("sid_wave","pulse")=="saw" else 80) if voice == "bass" else int(programs.get(settings.instrument,6))
		var events: Array = [{"tick": 0, "order": 0, "bytes": PackedByteArray([192|ch,program])}]
		for note in list:
			var start: int = roundi(note.beat * 960)
			var finish: int = maxi(start+1, roundi((note.beat+note.duration)*960))
			var pitch: int = int(note.pitch)
			events.append({"tick": start,"order": 2,"bytes": PackedByteArray([144|ch,pitch,int(note.velocity)])})
			events.append({"tick": finish,"order": 1,"bytes": PackedByteArray([128|ch,pitch,0])})
		result.append_array(_track(events))
	return result

static func demo() -> Dictionary:
	var melody: Array = [69,72,76,72,71,74,77,74,72,76,81,76,71,74,79,74,69,72,76,72,68,71,76,71,69,72,71,68,69,76,72,69]
	var bass: Array = [45,47,48,43,45,40,41,45]
	var notes: Array = []
	for bar in range(2):
		for i in range(melody.size()): notes.append({"id": notes.size()+1,"track": 0,"beat": bar*16.0+i*0.5,"duration": 0.43,"pitch": melody[i],"velocity": 90})
		for i in range(bass.size()): notes.append({"id": notes.size()+1,"track": 1,"beat": bar*16.0+i*2.0,"duration": 1.7,"pitch": bass[i],"velocity": 78})
	return {"name": "The little clock - original demo", "notes": notes, "tracks": [{"id":0,"name":"Upper keys","channel":0,"mute":false,"level":100.0,"octave":0},{"id":1,"name":"Lower keys","channel":1,"mute":false,"level":100.0,"octave":0}], "tempos":[{"beat":0.0,"us":500000}], "warnings":[]}
