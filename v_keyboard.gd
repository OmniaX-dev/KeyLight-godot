extends Control

signal note_on_signal(note : NoteEvent)
signal note_off_signal(note : NoteEvent)
signal midi_start_signal(note : NoteEvent)
signal vkeyboard_size_updated

var vpd : VirtualPianoData
var piano_keys : Array[PianoKey] = []
var active_falling_notes : Array[NoteEvent] = []
var next_falling_note_index : int = 0
var midi_notes : Array
var start_time_offset_us : float = 0.0
var paused_time_us : float = 0.0
var paused_offset_us : float = 0.0
var is_paused : bool = false
var is_playing : bool = false
var first_note_played : bool = false
var first_note_start_time : float = 0.0
var white_notes_gfx_data = {} # id -> FallingNoteNode
var black_notes_gfx_data = {} # id -> FallingNoteNode
var audioManager : AudioManager = AudioManager.new()
var note_scene = load("res://falling_note.tscn")


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(vpd.BASE_WIDTH, vpd.BASE_HEIGHT))
	RenderingServer.set_default_clear_color(vpd.background_color)

	var root_size = get_viewport().get_visible_rect().size

	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0

	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	set_deferred("size", root_size)

	for midi_note in range(21, 109):
		var pk = PianoKey.new()
		pk.note_info = MidiParser.get_note_info(midi_note)
		pk.pressed = false
		piano_keys.push_back(pk)

	midi_notes = MidiParser.parse_file("res://music/chopin_noct_55_1.mid")
	for note : NoteEvent in midi_notes:
		note.start_time += vpd.falling_time_s
		note.end_time += vpd.falling_time_s
		
	if not await audioManager.load_audio_file("res://music/chopin_noct_55_1.mp3"):
		push_error("Failed to load audio file.")
		return
	
	$StreamPlayer.stream = audioManager.audio_stream
	$StreamPlayer.volume_db = -4
	
	midi_start_signal.connect(on_midi_start)
	note_on_signal.connect(on_note_on)
	note_off_signal.connect(on_note_off)

	queue_redraw()

func _process(_delta: float) -> void:
	pass

func _physics_process(_delta):
	handle_input()
	if is_paused:
		paused_offset_us += get_current_time_us() - paused_time_us
		paused_time_us = get_current_time_us()
	if is_playing:
		update_visualization(get_play_time_s())
	queue_redraw()

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
	paused_time_us = get_current_time_us()
	is_playing = false
	is_paused = true

func stop():
	$StreamPlayer.stream_paused = false
	$StreamPlayer.stop()
	is_paused = false
	first_note_played = false
	start_time_offset_us = get_current_time_us()
	paused_time_us = 0.0
	paused_offset_us = 0.0
	next_falling_note_index = 0
	active_falling_notes.clear()
	for pk in piano_keys:
		pk.pressed = false
		pk.pressed_force = Vector2(0.0, 0.0)
	for note in midi_notes:
		note_off_signal.emit(note)
	white_notes_gfx_data.clear()
	black_notes_gfx_data.clear()
	update_visualization(get_play_time_s())
	is_playing = false

func get_play_time_s() -> float:
	var play_time = get_current_time_us() - paused_offset_us - start_time_offset_us
	return play_time * 1e-6

func get_current_time_us() -> float:
	return Time.get_ticks_usec()

func update_visualization(current_time: float):
	# --- Remove notes that have ended ---
	while active_falling_notes.size() > 0 and current_time > (active_falling_notes[0].end_time + 0.05):
		var note: NoteEvent = active_falling_notes[0]
		var info: NoteInfo = MidiParser.get_note_info(note.pitch)

		# Reset key state
		piano_keys[info.key_index].pressed = false
		piano_keys[info.key_index].pressed_force = Vector2.ZERO

		# Remove from front (deque pop_front)
		active_falling_notes.pop_front()

	# --- Add new notes that should start falling now ---

	while next_falling_note_index < midi_notes.size() and current_time >= midi_notes[next_falling_note_index].start_time - vpd.falling_time_s - 1.0:
		active_falling_notes.append(midi_notes[next_falling_note_index])
		spawn_note_node(midi_notes[next_falling_note_index])
		next_falling_note_index += 1

	# --- Update positions, pressed states, etc. ---
	calculate_falling_notes(current_time)

func _calc_pressed_velocity(midi_velocity : int) -> Vector2:
	return Vector2(0.0, (midi_velocity / 128.0)) * vpd.pressed_velocity_multiplier

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
			piano_keys[info.key_index].pressed = false
			piano_keys[info.key_index].pressed_force = Vector2(0.0, 0.0)
			note_off_signal.emit(note)
		elif y + h >= vpd.vpy():
			piano_keys[info.key_index].pressed = true
			piano_keys[info.key_index].pressed_force = _calc_pressed_velocity(note.velocity)
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
			piano_keys[info.key_index].pressed = false
			piano_keys[info.key_index].pressed_force = Vector2(0.0, 0.0)
			note_off_signal.emit(note)
		elif y + h >= vpd.vpy():
			piano_keys[info.key_index].pressed = true
			piano_keys[info.key_index].pressed_force = _calc_pressed_velocity(note.velocity)
			note_on_signal.emit(note)
			if not first_note_played:
				midi_start_signal.emit(note)
				first_note_played = true

func build_note_gfx_data(noteEvent : NoteEvent) -> FallingNoteGfxData:
	var info : NoteInfo =  MidiParser.get_note_info(noteEvent.pitch);
	var h : float = noteEvent.duration * vpd.pps()
	var y : float = -h + noteEvent.progress * (vpd.vpy() + h)
	var x : float = vpd.key_offsets()[info.key_index] + (vpd.white_key_shrink() / 2.0)
	if not info.is_white_key():
		var note_color = vpd.falling_black_note_color
		var outline_color = vpd.falling_black_note_outline_color
		var glow_color = vpd.falling_black_note_glow_color
		if vpd.is_per_note_color_used(info.note_in_octave):
			note_color = vpd.per_note_colors[info.note_in_octave]
		if vpd.is_per_note_color_used(info.note_in_octave + 12):
			outline_color = vpd.per_note_colors[info.note_in_octave + 12]
		if vpd.is_per_note_color_used(info.note_in_octave + 24):
			glow_color = vpd.per_note_colors[info.note_in_octave + 24]
		var gfx_data : FallingNoteGfxData = FallingNoteGfxData.new()
		gfx_data.rect = Rect2(x, y, vpd.black_key_w() - vpd.black_key_shrink(), h)
		gfx_data.fill_color = note_color
		gfx_data.outline_color = outline_color
		gfx_data.glow_color = glow_color
		gfx_data.outline_thickness = vpd.falling_black_note_outline_width
		gfx_data.corner_radius = vpd.falling_black_note_border_radius
		gfx_data.id = noteEvent.id
		return gfx_data
	else:
		var note_color = vpd.falling_white_note_color
		var outline_color = vpd.falling_white_note_outline_color
		var glow_color = vpd.falling_white_note_glow_color
		if vpd.is_per_note_color_used(info.note_in_octave):
			note_color = vpd.per_note_colors[info.note_in_octave]
		if vpd.is_per_note_color_used(info.note_in_octave + 12):
			outline_color = vpd.per_note_colors[info.note_in_octave + 12]
		if vpd.is_per_note_color_used(info.note_in_octave + 24):
			glow_color = vpd.per_note_colors[info.note_in_octave + 24]
		var gfx_data : FallingNoteGfxData = FallingNoteGfxData.new()
		gfx_data.rect = Rect2(x, y, vpd.white_key_w() - vpd.white_key_shrink(), h)
		gfx_data.fill_color = note_color
		gfx_data.outline_color = outline_color
		gfx_data.glow_color = glow_color
		gfx_data.outline_thickness = vpd.falling_white_note_outline_width
		gfx_data.corner_radius = vpd.falling_white_note_border_radius
		gfx_data.id = noteEvent.id
		return gfx_data

func spawn_note_node(note: NoteEvent):
	var info = MidiParser.get_note_info(note.pitch)

	var note_scn = note_scene.instantiate()
	var note_gfx = build_note_gfx_data(note)
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

func _draw():
	renderKeyboard()

func renderKeyboard():
	var window_size = get_viewport_rect().size
	var white_index = 0
	for midi_note in range(21, 109):
		var note_in_octave = midi_note % 12
		if MidiParser.is_white_key(note_in_octave):
			var info =  MidiParser.get_note_info(midi_note)
			var x = vpd.vpx() + white_index * vpd.white_key_w()
			var y = vpd.vpy()
			var color = vpd.white_key_color
			if piano_keys[info.key_index].pressed:
				color = vpd.get_note_base_color(info)
			draw_rect(Rect2(x, y, vpd.white_key_w(), vpd.white_key_h()), color, true)
			draw_rect(Rect2(x, y, vpd.white_key_w(), vpd.white_key_h()), vpd.white_key_split_color, false)
			white_index += 1

	draw_rect(Rect2(vpd.vpx(), vpd.vpy() - 2, window_size.x, 4), vpd.piano_line_color1, true);
	draw_rect(Rect2(vpd.vpx(), vpd.vpy(), window_size.x, 8), vpd.piano_line_color2, true);

	white_index = 0
	for midi_note in range(21, 109):
		var note_in_octave = midi_note % 12
		if MidiParser.is_white_key(note_in_octave):
			white_index += 1
		else:
			var info =  MidiParser.get_note_info(midi_note);
			var x = vpd.vpx() + ((white_index - 1) * vpd.white_key_w() + (vpd.white_key_w() - vpd.black_key_w() / 2.0)) - vpd.black_key_off()
			var y = vpd.vpy()
			var color = vpd.black_key_color
			if piano_keys[info.key_index].pressed:
				color = vpd.get_note_base_color(info)
			Primitives.fill_rounded_rect(self, Rect2(x, y, vpd.black_key_w(), vpd.black_key_h()), color, 0, 0, 8, 8)

func _on_window_resized():
	var window_size = get_viewport().get_visible_rect().size
	set_deferred("size", window_size)
	vpd.update_scale(window_size.x, window_size.y)
	queue_redraw()
	vkeyboard_size_updated.emit()

func handle_input():
	if Input.is_action_just_pressed("play_pause"):
		if not is_playing:
			play()
		else:
			pause()
	elif Input.is_action_just_pressed("stop_playback"):
		stop()

func on_midi_start(_note : NoteEvent):
	$StreamPlayer.play(audioManager.auto_sound_start)

func on_note_on(_note : NoteEvent):
	pass

func on_note_off(note : NoteEvent):
	var info = MidiParser.get_note_info(note.pitch)
	if info.is_white_key():
		white_notes_gfx_data.erase(note.id)
	else:
		black_notes_gfx_data.erase(note.id)
