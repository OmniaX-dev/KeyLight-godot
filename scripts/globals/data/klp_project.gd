class_name KLProject
extends RefCounted

class VoiceData:
	var name : String = ""
	var file_path : String = ""
	var color : Color = Color.WHITE

var project_file_path : String = ""
var name : String = "UNNAMED"
var midi_file_path : String = ""
var audio_file_path : String = ""
var voice_count : int = 1
var midi_voices : Array[VoiceData] = []
var style_file_path : String = "res://resources/styles/default_style.json"
var particles_file_path : String = "res://resources/styles/default_style.json"
var background_image_path : String = ""
var use_background_image : bool = false
var use_multiple_voices : bool = false
var loaded : bool = false


func load(klp_file_path : String) -> bool:
	loaded = false
	if not (FileAccess.file_exists(klp_file_path) and klp_file_path.ends_with(".klp")):
		print("Invalid project file 1.")
		return false
	project_file_path = klp_file_path
	var base_path : String = klp_file_path.get_base_dir()
	var klpJson = JsonFile.new()
	if not klpJson.load(klp_file_path):
		print("Invalid project file 2.")
		return false
	name = klpJson.get_string("project.name", "UNNAMED")
	midi_file_path = klpJson.get_string("project.audio.midiFile")
	audio_file_path = klpJson.get_string("project.audio.audioFile")
	voice_count = klpJson.get_int("project.audio.voiceCount")
	for i in range(0, voice_count):
		var path : String = "project.audio.voices." + str(i)
		var voice : VoiceData = VoiceData.new()
		voice.name = klpJson.get_string(path + ".name")
		voice.file_path = klpJson.get_string(path + ".path")
		voice.file_path = voice.file_path.replace("@@", base_path + "/data")
		voice.color = klpJson.get_color(path + ".color")
		midi_voices.push_back(voice)
	style_file_path = klpJson.get_string("project.graphics.styleFile")
	particles_file_path = klpJson.get_string("project.graphics.particlesFile")
	background_image_path = klpJson.get_string("project.graphics.backgroundImageFile")
	use_background_image = klpJson.get_bool("project.useBackgroundImage")
	use_multiple_voices = klpJson.get_bool("project.useMultipleVoices")
	midi_file_path = midi_file_path.replace("@@", base_path + "/data")
	audio_file_path = audio_file_path.replace("@@", base_path + "/data")
	style_file_path = style_file_path.replace("@@", base_path + "/data")
	particles_file_path = particles_file_path.replace("@@", base_path + "/data")
	background_image_path = background_image_path.replace("@@", base_path + "/data")
	if use_background_image and not FileAccess.file_exists(background_image_path):
		print("Invalid background file.")
		return false
	if use_multiple_voices:
		for voice in midi_voices:
			if not FileAccess.file_exists(voice.file_path):
				print("Invalid voice file")
				return false
	elif not FileAccess.file_exists(midi_file_path):
		print("Invalid midi file")
		return false
	if not FileAccess.file_exists(style_file_path):
		print("Invalid style file")
		return false
	if not FileAccess.file_exists(particles_file_path):
		print("Invalid particles file")
		return false
	if not FileAccess.file_exists(audio_file_path):
		print("Invalid audio file")
		return false
	loaded = true
	return true
	
func load_midi(vpd : VirtualPianoData) -> Array[NoteEvent]:
	var midi_notes : Array[NoteEvent] = []
	if not is_loaded():
		return []
	if not use_multiple_voices:
		midi_notes = MidiParser.parse_file(midi_file_path)
		for note in midi_notes:
			note.start_time += vpd.falling_time_s
			note.end_time += vpd.falling_time_s
		return midi_notes
	if midi_voices.size() != voice_count:
		return []
	if voice_count < 1:
		return []
	var base_id : int = 0
	for voice in midi_voices:
		var midi_data : Array[NoteEvent] = MidiParser.parse_file(voice.file_path)
		for note in midi_data:
			note.id += base_id
			note.start_time += vpd.falling_time_s
			note.end_time += vpd.falling_time_s
			note.first = false
			note.last = false
			vpd.add_voice_note_colors(note.id, voice.color)
			midi_notes.push_back(note)
		base_id += midi_data.size()
	if midi_notes.size() > 0:
		var first_note: NoteEvent = midi_notes[0]
		var last_note: NoteEvent = midi_notes[0]
		for n in midi_notes:
			if n.start_time < first_note.start_time:
				first_note = n
			if n.end_time > last_note.end_time:
				last_note = n
		first_note.first = true
		last_note.last = true
	midi_notes.sort_custom(func(a, b):
		if a.start_time == b.start_time:
			return a.pitch < b.pitch
		return a.start_time < b.start_time
	)
	return midi_notes
		
func is_loaded() -> bool:
	return loaded
