extends Control

# Signals ==============================================================================
signal note_on_signal(note : NoteEvent)
signal note_off_signal(note : NoteEvent)
signal midi_start_signal(note : NoteEvent)
signal vkeyboard_size_updated
# ======================================================================================


# Data =================================================================================
var vpd : VirtualPianoData
var vpr : VPianoResources = VPianoResources.new()
var vpk : VPianoKeyboard = VPianoKeyboard.new()
var project_file : KLProject

# Falling notes
var active_falling_notes : Array[NoteEvent] = []
var next_falling_note_index : int = 0
var white_notes_gfx_data = {} # id -> FallingNoteNode
var black_notes_gfx_data = {} # id -> FallingNoteNode

# Playback data
var start_time_offset_us : float = 0.0
var paused_time_us : float = 0.0
var paused_offset_us : float = 0.0
var is_paused : bool = false
var is_playing : bool = false
var first_note_played : bool = false
var first_note_start_time : float = 0.0
# ======================================================================================

var LH_voice = [
	10, 3, 9, 15, 12, 16, 21, 29, 30, 35, 32, 36, 49, 41, 48, 53,
	56, 58, 69, 63, 68, 74, 79, 80, 93, 86, 94, 101, 96, 102, 112,
	107, 113, 123, 118, 124, 130, 127, 132, 135, 139, 143, 152, 145,
	153, 157, 162, 161, 173, 172, 166, 182, 179, 183, 189, 196, 197,
	202, 199, 203, 213, 208
]
var Error_voice = [
	174, 216, 229, 230, 231, 215, 226, 222, 219, 224, 214, 220, 217,
	227, 218, 221, 223, 225, 228, 62, 211
]
var RH_lower_voice = [
	0, 2, 4, 5, 8, 11, 13, 14, 17, 19, 20, 22, 24, 25, 27, 31, 33,
	34, 37, 40, 38, 42, 44, 46, 50, 52, 54, 55, 59, 60, 64, 66, 70,
	71, 73, 75, 76, 77, 78, 81, 82, 83, 84, 87, 88, 90, 92, 95, 97,
	99, 100, 103, 105, 109, 110, 114, 116, 119, 121, 125, 128, 129,
	133, 134, 136, 138, 142, 144, 146, 148, 149, 155, 156, 158, 159,
	160, 164, 165, 163, 168, 170, 175, 176, 178, 180, 181, 184, 187,
	186, 188, 192, 191, 194, 198, 200, 201, 204, 207, 205, 209
]
var RH_upper_voice = [
	1, 6, 7, 18, 23, 26, 28, 39, 43, 45, 47, 51, 57, 61, 65, 67, 72,
	85, 89, 91, 98, 104, 106, 108, 111, 115, 117, 120, 122, 126, 131,
	137, 140, 141, 147, 150, 151, 154, 167, 169, 171, 177, 185, 190,
	193, 195, 206, 210, 212
]

func get_note_color(note_id) -> Color:
	for voice in LH_voice:
		if voice == note_id:
			return Color.DARK_RED
	for voice in RH_lower_voice:
		if voice == note_id:
			return Color.CORNFLOWER_BLUE
	for voice in RH_upper_voice:
		if voice == note_id:
			return Color.GREEN_YELLOW
	for voice in Error_voice:
		if voice == note_id:
			return Color.SLATE_GRAY
	return Color.DARK_GRAY
	#for note in vpr.midi_notes:
		#var found = false
		#for voice in LH_voice:
			#if voice == note.id:
				#found = true
				#var info : NoteInfo = MidiParser.get_note_info(note.pitch)


# Builtin methods
func _ready() -> void:
	vpk.initialize(vpd)
	vpr.initialize(vpd)
	
	midi_start_signal.connect(on_midi_start)
	note_on_signal.connect(on_note_on)
	note_off_signal.connect(on_note_off)
	
	if project_file.is_loaded():
		vpr.open_midi_file(project_file.midi_file_path)
		vpr.open_music_file(project_file.audio_file_path)
		$StreamPlayer.stream = vpr.audioManager.audio_stream
		$StreamPlayer.volume_db = -4

	queue_redraw()

func _physics_process(_delta):
	if is_paused:
		paused_offset_us += Common.get_current_time_us() - paused_time_us
		paused_time_us = Common.get_current_time_us()
	if is_playing:
		update_visualization(get_play_time_s())
	queue_redraw()

func _draw():
	vpk.render(self)
	#var r : Rect2
	#r.size.x = $TestParticles.process_material.emission_box_extents.x
	#r.size.y = $TestParticles.process_material.emission_box_extents.y
	#r.position.x = $TestParticles.position.x
	#r.position.y = $TestParticles.position.y
	#draw_rect(r, Color.RED, false)


# Update logic
func update_visualization(current_time: float):
	# --- Remove notes that have ended ---
	while active_falling_notes.size() > 0 and current_time > (active_falling_notes[0].end_time + 0.05):
		var note: NoteEvent = active_falling_notes[0]
		var info: NoteInfo = MidiParser.get_note_info(note.pitch)

		# Reset key state
		vpk.piano_keys[info.key_index].pressed = false
		vpk.piano_keys[info.key_index].pressed_force = Vector2.ZERO

		# Remove from front (deque pop_front)
		active_falling_notes.pop_front()

	# --- Add new notes that should start falling now ---
	while next_falling_note_index < vpr.midi_notes.size() and current_time >= vpr.midi_notes[next_falling_note_index].start_time - vpd.falling_time_s - 1.0:
		active_falling_notes.append(vpr.midi_notes[next_falling_note_index])
		spawn_note_node(vpr.midi_notes[next_falling_note_index])
		next_falling_note_index += 1

	# --- Update positions, pressed states, etc. ---
	calculate_falling_notes(current_time)

func calculate_falling_notes(current_time : float):
	for note in active_falling_notes:
		var info : NoteInfo =  MidiParser.get_note_info(note.pitch);
		if not info.is_white_key():
			continue
		var h : float = note.duration * vpd.pps()
		var total_travel_time : float = vpd.falling_time_s + note.duration
		var elapsed_since_spawn : float = (current_time - (note.start_time - vpd.falling_time_s))
		note.progress = elapsed_since_spawn / total_travel_time
		note.progress = clamp(note.progress, 0.0, 1.0)
		var y : float = -h + note.progress * (vpd.vpy() + h)
		var x : float = vpd.key_offsets()[info.key_index] + (vpd.white_key_shrink() / 2.0)
		
		if white_notes_gfx_data.has(note.id):
			white_notes_gfx_data[note.id].rect.position.x = x
			white_notes_gfx_data[note.id].rect.position.y = y

		if y >= vpd.vpy():
			vpk.piano_keys[info.key_index].pressed = false
			vpk.piano_keys[info.key_index].pressed_force = Vector2(0.0, 0.0)
			note_off_signal.emit(note)
		elif y + h >= vpd.vpy():
			vpk.piano_keys[info.key_index].pressed = true
			vpk.piano_keys[info.key_index].pressed_force = Common.calc_pressed_velocity(vpd, note.velocity)
			note_on_signal.emit(note)
			if not first_note_played:
				midi_start_signal.emit(note)
				first_note_played = true

	for note in active_falling_notes:
		var info : NoteInfo =  MidiParser.get_note_info(note.pitch);
		if info.is_white_key():
			continue
		var h : float = note.duration * vpd.pps()
		var total_travel_time : float = vpd.falling_time_s + note.duration
		var elapsed_since_spawn : float = (current_time - (note.start_time - vpd.falling_time_s))
		note.progress = elapsed_since_spawn / total_travel_time
		note.progress = clamp(note.progress, 0.0, 1.0)
		var y : float = -h + note.progress * (vpd.vpy() + h)
		var x : float = vpd.key_offsets()[info.key_index] + (vpd.black_key_shrink() / 2.0)
		
		if black_notes_gfx_data.has(note.id):
			black_notes_gfx_data[note.id].rect.position.x = x
			black_notes_gfx_data[note.id].rect.position.y = y

		if y >= vpd.vpy():
			vpk.piano_keys[info.key_index].pressed = false
			vpk.piano_keys[info.key_index].pressed_force = Vector2(0.0, 0.0)
			note_off_signal.emit(note)
		elif y + h >= vpd.vpy():
			vpk.piano_keys[info.key_index].pressed = true
			vpk.piano_keys[info.key_index].pressed_force = Common.calc_pressed_velocity(vpd, note.velocity)
			note_on_signal.emit(note)
			if not first_note_played:
				midi_start_signal.emit(note)
				first_note_played = true

func spawn_note_node(note: NoteEvent):
	var info = MidiParser.get_note_info(note.pitch)

	var note_scn = vpr.note_scene.instantiate()
	var note_gfx = Common.build_note_gfx_data(vpd, note)
	note_scn.position = note_gfx.rect.position
	note_gfx.outline_color = get_note_color(note.id)
	note_gfx.fill_color = get_note_color(note.id)
	note_gfx.glow_color = get_note_color(note.id)
	note_scn.self_modulate = Color(1.19, 1.19, 1.19)
	note_scn.queue_redraw()
	var falling_notes = get_parent().get_node("FallingNotes")
	falling_notes.add_child(note_scn)
	#get_parent().move_child(note_scn, get_index())
	note_off_signal.connect(note_scn.on_midi_note_off)
	note_scn.note_gfx = note_gfx
	note_scn.set_particle_position()

	if info.is_white_key():
		white_notes_gfx_data[note.id] = note_scn.note_gfx
	else:
		black_notes_gfx_data[note.id] = note_scn.note_gfx


# Playback functionality
func play():
	if is_paused:
		is_playing = true
		is_paused = false
		if first_note_played:
			$StreamPlayer.stream_paused = false
		return
	stop()
	is_playing = true

func pause():
	$StreamPlayer.stream_paused = true
	paused_time_us = Common.get_current_time_us()
	is_playing = false
	is_paused = true

func stop():
	$StreamPlayer.stream_paused = false
	$StreamPlayer.stop()
	is_paused = false
	first_note_played = false
	start_time_offset_us = Common.get_current_time_us()
	paused_time_us = 0.0
	paused_offset_us = 0.0
	next_falling_note_index = 0
	active_falling_notes.clear()
	for pk in vpk.piano_keys:
		pk.pressed = false
		pk.pressed_force = Vector2(0.0, 0.0)
	for note in vpr.midi_notes:
		note_off_signal.emit(note)
	white_notes_gfx_data.clear()
	black_notes_gfx_data.clear()
	update_visualization(get_play_time_s())
	is_playing = false

func get_play_time_s() -> float:
	var play_time = Common.get_current_time_us() - paused_offset_us - start_time_offset_us
	return play_time * 1e-6


# Signal handlers
func on_window_resized():
	var window_size = get_viewport().get_visible_rect().size
	set_deferred("size", window_size)
	vpd.update_scale(window_size.x, window_size.y)
	queue_redraw()
	vkeyboard_size_updated.emit()

func on_midi_start(_note : NoteEvent):
	$StreamPlayer.play(vpr.audioManager.auto_sound_start)

func on_note_on(_note : NoteEvent):
	pass

func on_note_off(note : NoteEvent):
	var info = MidiParser.get_note_info(note.pitch)
	vpk.piano_keys[info.key_index].pressed = false
	vpk.piano_keys[info.key_index].pressed_force = Vector2(0.0, 0.0)
	if info.is_white_key():
		white_notes_gfx_data.erase(note.id)
	else:
		black_notes_gfx_data.erase(note.id)
