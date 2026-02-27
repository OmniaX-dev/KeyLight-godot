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


# Builtin methods
func _ready() -> void:
	vpk.initialize(vpd)
	vpr.initialize(vpd)
	
	midi_start_signal.connect(on_midi_start)
	note_on_signal.connect(on_note_on)
	note_off_signal.connect(on_note_off)
	
	if project_file.is_loaded():
		vpr.midi_notes = project_file.load_midi(vpd)
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
