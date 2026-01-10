extends Control

signal note_on_signal(note : NoteEvent)
signal note_off_signal(note : NoteEvent)
signal midi_start_signal(note : NoteEvent)

var vpd : VirtualPianoData = VirtualPianoData.new();
var piano_keys : Array[PianoKey] = []
var active_falling_notes : Array[NoteEvent] = []
var next_falling_note_index : int = 0
var falling_notes_gfx_white : Array[FallingNoteGfxData]
var falling_notes_gfx_black : Array[FallingNoteGfxData]
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
	get_window().size_changed.connect(_on_window_resized)
	var styleJsonFile = JsonFile.new()
	styleJsonFile.load("res://styles/DefaultStyle.json")
	vpd.load_from_json(styleJsonFile)
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

	midi_notes = MidiParser.parse_file("res://music/chopin_waltz_64_2.mid")
	for note : NoteEvent in midi_notes:
		note.start_time += vpd.falling_time_s
		note.end_time += vpd.falling_time_s
		
	if not await audioManager.load_audio_file("res://music/chopin_waltz_64_2.mp3"):
		push_error("Failed to load audio file.")
		return
	
	$StreamPlayer.stream = audioManager.audio_stream
	
	midi_start_signal.connect(on_midi_start)
	
	var note = note_scene.instantiate()
	var gfx := FallingNoteGfxData.new()
	gfx.rect = Rect2(100, 100, 40, 200)
	gfx.fill_color = Color(0.2, 0.6, 1.0)
	gfx.outline_color = Color.RED
	gfx.outline_thickness = 2
	gfx.corner_radius = 10.0

	note.note_gfx = gfx
	note.queue_redraw()
	add_child(note)


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

	while next_falling_note_index < midi_notes.size() and current_time >= midi_notes[next_falling_note_index].start_time - vpd.falling_time_s:
		active_falling_notes.append(midi_notes[next_falling_note_index])
		next_falling_note_index += 1

	# --- Update positions, pressed states, etc. ---
	calculate_falling_notes(current_time)

func _calc_pressed_velocity(midi_velocity : int) -> Vector2:
	return Vector2(0.0, (midi_velocity / 128.0)) * vpd.pressed_velocity_multiplier

func calculate_falling_notes(current_time : float):
	falling_notes_gfx_white.clear()
	falling_notes_gfx_black.clear()
	for note in active_falling_notes:
		var info : NoteInfo =  MidiParser.get_note_info(note.pitch);
		if not info.is_white_key():
			continue
		var h : float = note.duration * vpd.pps()
		var total_travel_time : float = vpd.falling_time_s + note.duration
		var elapsed_since_spawn : float = (current_time - (note.start_time - vpd.falling_time_s))
		var progress : float = elapsed_since_spawn / total_travel_time
		progress = clamp(progress, 0.0, 1.0)
		var y : float = -h + progress * (vpd.vpy() + h)
		var x : float = vpd.key_offsets()[info.key_index] + (vpd.white_key_shrink() / 2.0)

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

		var note_color = vpd.falling_white_note_color
		var outline_color = vpd.falling_white_note_outline_color
		var glow_color = vpd.falling_white_note_glow_color

		if vpd.use_per_note_colors:
			note_color = vpd.per_note_colors[info.note_in_octave]
			outline_color = vpd.per_note_colors[info.note_in_octave + 12]
			glow_color = vpd.per_note_colors[info.note_in_octave + 24]
		var gfx_data : FallingNoteGfxData = FallingNoteGfxData.new()
		gfx_data.rect = Rect2(x, y, vpd.white_key_w() - vpd.white_key_shrink(), h)
		gfx_data.fill_color = note_color
		gfx_data.outline_color = outline_color
		gfx_data.glow_color = glow_color
		gfx_data.outline_thickness = vpd.falling_white_note_outline_width
		gfx_data.corner_radius = vpd.falling_white_note_border_radius
		falling_notes_gfx_white.push_back(gfx_data)

	for note in active_falling_notes:
		var info : NoteInfo =  MidiParser.get_note_info(note.pitch);
		if info.is_white_key():
			continue
		var h : float = note.duration * vpd.pps()
		var total_travel_time : float = vpd.falling_time_s + note.duration
		var elapsed_since_spawn : float = (current_time - (note.start_time - vpd.falling_time_s))
		var progress : float = elapsed_since_spawn / total_travel_time
		progress = clamp(progress, 0.0, 1.0)
		var y : float = -h + progress * (vpd.vpy() + h)
		var x : float = vpd.key_offsets()[info.key_index] + (vpd.black_key_shrink() / 2.0)

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

		var note_color = vpd.falling_black_note_color
		var outline_color = vpd.falling_black_note_outline_color
		var glow_color = vpd.falling_black_note_glow_color

		if vpd.use_per_note_colors:
			note_color = vpd.per_note_colors[info.note_in_octave]
			outline_color = vpd.per_note_colors[info.note_in_octave + 12]
			glow_color = vpd.per_note_colors[info.note_in_octave + 24]
		var gfx_data : FallingNoteGfxData = FallingNoteGfxData.new()
		gfx_data.rect = Rect2(x, y, vpd.black_key_w() - vpd.black_key_shrink(), h)
		gfx_data.fill_color = note_color
		gfx_data.outline_color = outline_color
		gfx_data.glow_color = glow_color
		gfx_data.outline_thickness = vpd.falling_black_note_outline_width
		gfx_data.corner_radius = vpd.falling_black_note_border_radius
		falling_notes_gfx_black.push_back(gfx_data)

#func spawn_note_node(note: NoteEvent):
	#var info = MidiParser.get_note_info(note.pitch)
#
	#var note_scene = note_scene.instantiate()
	#var gfx := FallingNoteGfxData.new()
	#gfx.rect = Rect2(100, 100, 40, 200)
	#gfx.fill_color = Color(0.2, 0.6, 1.0)
	#gfx.outline_color = Color.RED
	#gfx.outline_thickness = 2
	#gfx.corner_radius = 10.0
#
	#note_scene.note_gfx = gfx
	#note.queue_redraw()
	#add_child(note)
#
	#var node = FallingNoteNode.new()
	#node.note = note
	#node.is_white = info.is_white_key()
	#add_child(node)
#
	#if node.is_white:
		#white_notes_gfx_data[note.id] = node
	#else:
		#black_notes_gfx_data[note.id] = node


func _draw():
	renderFallingNotes()
	renderKeyboard()

func renderFallingNotes():
	for note in falling_notes_gfx_white:
		var cr = int(note.corner_radius)
		Primitives.outline_rounded_rect(self, note.rect, note.fill_color, note.outline_color, note.outline_thickness, cr, cr, cr, cr)
	for note in falling_notes_gfx_black:
		var cr = int(note.corner_radius)
		Primitives.outline_rounded_rect(self, note.rect, note.fill_color, note.outline_color, note.outline_thickness, cr, cr, cr, cr)

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
				color = vpd.white_key_pressed_color
			draw_rect(Rect2(x, y, vpd.white_key_w(), vpd.white_key_h()), color, true)
			draw_rect(Rect2(x, y, vpd.white_key_w(), vpd.white_key_h()), vpd.white_key_split_color, false)
			white_index += 1

	draw_rect(Rect2(vpd.vpx(), vpd.vpy() - 2, window_size.x, 2), vpd.piano_line_color1, true);
	draw_rect(Rect2(vpd.vpx(), vpd.vpy(), window_size.x, 5), vpd.piano_line_color2, true);

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
				color = vpd.black_key_pressed_color
			Primitives.fill_rounded_rect(self, Rect2(x, y, vpd.black_key_w(), vpd.black_key_h()), color, 0, 0, 8, 8)

func _on_window_resized():
	var window_size = get_viewport().get_visible_rect().size
	set_deferred("size", window_size)
	vpd.update_scale(window_size.x, window_size.y)
	queue_redraw()

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
