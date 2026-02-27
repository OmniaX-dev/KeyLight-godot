class_name VPianoResources
extends RefCounted

var vpd : VirtualPianoData
var midi_notes : Array
var audioManager : AudioManager = AudioManager.new()
var note_scene

func initialize(VPD : VirtualPianoData) -> void:
	vpd = VPD
	note_scene = load("res://scenes/falling_note.tscn")

func open_midi_file(midi_file_path : String) -> void:
	midi_notes = MidiParser.parse_file(midi_file_path)
	for note : NoteEvent in midi_notes:
		note.start_time += vpd.falling_time_s
		note.end_time += vpd.falling_time_s

func open_music_file(music_file_path : String) -> bool:
	if not await audioManager.load_audio_file(music_file_path):
		push_error("Failed to load audio file.")
		return false
	return true
