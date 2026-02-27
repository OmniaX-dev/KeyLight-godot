class_name MidiParser
extends RefCounted


# -------------------------------------------------------------------------
# Low-level helpers
# -------------------------------------------------------------------------

static func _read_vlq(data: PackedByteArray, pos: int) -> Dictionary:
	var value := 0
	var i := pos

	while true:
		if i >= data.size():
			push_error("VLQ read out of bounds")
			return { "value": value, "next": i }
		var b := data[i]
		value = (value << 7) | (b & 0x7F)
		i += 1
		if (b & 0x80) == 0:
			break

	return { "value": value, "next": i }


static func _read_u16_be(data: PackedByteArray, offset: int) -> int:
	return (data[offset] << 8) | data[offset + 1]


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3]


# -------------------------------------------------------------------------
# Tempo map helpers
# -------------------------------------------------------------------------

class TempoSegment:
	var start_tick: int
	var us_per_quarter: int
	var base_seconds: float

	func _init(_start_tick: int, _us_per_quarter: int, _base_seconds: float) -> void:
		start_tick = _start_tick
		us_per_quarter = _us_per_quarter
		base_seconds = _base_seconds


static func _build_tempo_segments(tpq: int, tempo_events: Array) -> Array:
	# tempo_events: Array of { tick: int, us_per_quarter: int }, sorted by tick
	var segments: Array = []
	if tempo_events.is_empty():
		# Default 120 bpm = 500000 us/quarter
		segments.append(TempoSegment.new(0, 500000, 0.0))
		return segments

	# First segment from tick 0 to first tempo event (using default 120 bpm)
	var first_event: Dictionary = tempo_events[0]
	if first_event["tick"] > 0:
		segments.append(TempoSegment.new(0, 500000, 0.0))

	# Now add segments at each tempo event
	var current_us := 500000
	var current_base_seconds := 0.0
	var current_tick := 0

	for ev in tempo_events:
		var t_tick: int = ev["tick"]
		if t_tick > current_tick:
			# Close previous tempo region
			var delta_ticks := t_tick - current_tick
			var seconds := (float(delta_ticks) * float(current_us)) / (1_000_000.0 * float(tpq))
			current_base_seconds += seconds
			current_tick = t_tick
		current_us = ev["us_per_quarter"]
		segments.append(TempoSegment.new(current_tick, current_us, current_base_seconds))

	return segments


static func _ticks_to_seconds(tick: int, tpq: int, segments: Array) -> float:
	# segments are ordered by start_tick
	var seg: TempoSegment = segments[0]
	for s in segments:
		if s.start_tick <= tick:
			seg = s
		else:
			break

	var delta_ticks := tick - seg.start_tick
	var dt := (float(delta_ticks) * float(seg.us_per_quarter)) / (1_000_000.0 * float(tpq))
	return seg.base_seconds + dt


# -------------------------------------------------------------------------
# Main MIDI parser (midifile-compatible)
# -------------------------------------------------------------------------

static func parse_file(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open MIDI file: %s" % path)
		return []

	var data := file.get_buffer(file.get_length())
	if data.size() < 14:
		push_error("Invalid MIDI file: too small")
		return []

	# --- Parse header -----------------------------------------------------
	if data.slice(0, 4).get_string_from_ascii() != "MThd":
		push_error("Invalid MIDI file: missing MThd")
		return []

	var header_len := _read_u32_be(data, 4)
	var _format := _read_u16_be(data, 8)
	var n_tracks := _read_u16_be(data, 10)
	var division := _read_u16_be(data, 12)

	if division & 0x8000 != 0:
		push_error("SMPTE division not supported")
		return []

	var tpq := division  # ticks per quarter note

	if n_tracks != 1:
		push_error("Expected exactly 1 track, but found %d" % n_tracks)
		return []

	var pos: int = 8 + header_len

	# --- Parse single track ----------------------------------------------
	if data.slice(pos, pos + 4).get_string_from_ascii() != "MTrk":
		push_error("Invalid MIDI file: missing MTrk")
		return []

	var track_len := _read_u32_be(data, pos + 4)
	var track_end := pos + 8 + track_len
	var i := pos + 8

	var abs_tick := 0
	var running_status := -1

	# Channel note events (raw)
	var note_events: Array = []  # { tick, channel, pitch, velocity, is_on }
	# Tempo events (tick → us_per_quarter)
	var tempo_events: Array = []

	# Default tempo 120 bpm
	tempo_events.append({ "tick": 0, "us_per_quarter": 500000 })

	while i < track_end:
		# Delta time
		var vlq := _read_vlq(data, i)
		abs_tick += vlq["value"]
		i = vlq["next"]

		if i >= track_end:
			break

		var status := data[i]

		if status < 0x80:
			# Running status
			if running_status < 0:
				push_error("Invalid running status at tick %d" % abs_tick)
				return []
			status = running_status
		else:
			i += 1
			running_status = status

		if status == 0xFF:
			# Meta event
			if i >= track_end:
				break
			var meta_type := data[i]
			i += 1
			var len_vlq := _read_vlq(data, i)
			var meta_len: int = len_vlq["value"]
			i = len_vlq["next"]

			# Tempo meta: FF 51 03 tttttt
			if meta_type == 0x51 and meta_len == 3:
				if i + 3 <= track_end:
					var us_per_quarter := (data[i] << 16) | (data[i + 1] << 8) | data[i + 2]
					tempo_events.append({
						"tick": abs_tick,
						"us_per_quarter": us_per_quarter
					})
			# Skip meta data
			i += meta_len
			running_status = -1

		elif status == 0xF0 or status == 0xF7:
			# SysEx event: F0/F7, length VLQ, data
			var syx_len_v := _read_vlq(data, i)
			var syx_len: int = syx_len_v["value"]
			i = syx_len_v["next"] + syx_len
			running_status = -1

		else:
			# Channel message
			var event_type := status & 0xF0
			var channel := status & 0x0F

			if event_type == 0x80 or event_type == 0x90:
				if i + 2 > track_end:
					break
				var pitch := data[i]
				var velocity := data[i + 1]
				i += 2

				if event_type == 0x90 and velocity > 0:
					note_events.append({
						"tick": abs_tick,
						"channel": channel,
						"pitch": pitch,
						"velocity": velocity,
						"is_on": true
					})
				else:
					# Note Off: 0x80 or 0x90 with velocity 0
					note_events.append({
						"tick": abs_tick,
						"channel": channel,
						"pitch": pitch,
						"velocity": velocity,
						"is_on": false
					})

			else:
				# Other channel events (CC, program change, etc.)
				var size := 0
				match event_type:
					0xC0, 0xD0:
						size = 1
					_:
						size = 2
				i += size

	# --- Build tempo map & compute seconds for events ---------------------
	# Sort tempo events by tick (just in case)
	tempo_events.sort_custom(func(a, b):
		return a["tick"] < b["tick"]
	)

	var segments := _build_tempo_segments(tpq, tempo_events)

	# Attach seconds/time to note_events
	for ev in note_events:
		ev["seconds"] = _ticks_to_seconds(ev["tick"], tpq, segments)

	# --- Link note pairs (per channel + pitch, LIFO) ----------------------
	var stacks := {}  # key: int (channel<<8 | pitch) -> Array of ev dicts
	var notes: Array = []

	for ev in note_events:
		var key : int = (ev["channel"] << 8) | ev["pitch"]
		if ev["is_on"]:
			if not stacks.has(key):
				stacks[key] = []
			stacks[key].append(ev)
		else:
			if stacks.has(key) and stacks[key].size() > 0:
				var on_ev: Dictionary = stacks[key].pop_back()
				var note := NoteEvent.new()
				note.pitch = on_ev["pitch"]
				note.start_time = on_ev["seconds"]
				note.end_time = ev["seconds"]
				note.duration = note.end_time - note.start_time
				note.velocity = on_ev["velocity"]
				note.channel = on_ev["channel"]
				note.first = false
				note.last = false
				note.right_hand = false
				note.hit = false
				notes.append(note)

	# --- Mark first / last (absolute seconds) -----------------------------
	if notes.size() > 0:
		var first_note: NoteEvent = notes[0]
		var last_note: NoteEvent = notes[0]

		var next_id : int = 0
		for n in notes:
			n.id= next_id
			next_id += 1
			if n.start_time < first_note.start_time:
				first_note = n
			if n.end_time > last_note.end_time:
				last_note = n

		first_note.first = true
		last_note.last = true

	notes.sort_custom(func(a, b):
		if a.start_time == b.start_time:
			return a.pitch < b.pitch
		return a.start_time < b.start_time
	)

	return notes


# -------------------------------------------------------------------------
# Note info utilities
# -------------------------------------------------------------------------

static func get_note_info(midi_pitch: int) -> NoteInfo:
	var names := ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
	var info := NoteInfo.new()

	info.note_in_octave = midi_pitch % 12
	info.name = names[info.note_in_octave]
	info.octave = int(midi_pitch / 12.0) - 1

	if midi_pitch >= 21 and midi_pitch <= 108:
		info.key_index = midi_pitch - 21
	else:
		info.key_index = -1

	return info


static func is_white_key(note_in_octave: int) -> bool:
	return note_in_octave == 0 || note_in_octave == 2 || note_in_octave == 4 || \
		note_in_octave == 5 || note_in_octave == 7 || note_in_octave == 9 || \
		note_in_octave == 11
