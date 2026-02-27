class_name VPianoResources
extends RefCounted

var vpd : VirtualPianoData
var midi_notes : Array
var audioManager : AudioManager = AudioManager.new()
var note_scene

func initialize(VPD : VirtualPianoData) -> void:
	vpd = VPD
	note_scene = load("res://scenes/falling_note.tscn")

func open_music_file(music_file_path : String) -> bool:
	if not await audioManager.load_audio_file(music_file_path):
		push_error("Failed to load audio file.")
		return false
	return true
