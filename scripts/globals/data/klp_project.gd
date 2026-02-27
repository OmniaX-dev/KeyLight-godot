class_name KLProject
extends RefCounted

var project_file_path : String = ""
var name : String = "UNNAMED"
var midi_file_path : String = ""
var audio_file_path : String = ""
var midi_voices : Array[String] = []
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
	midi_file_path = klpJson.get_string("project.audio.midiFile", "UNNAMED")
	audio_file_path = klpJson.get_string("project.audio.audioFile", "UNNAMED")
	var voices = klpJson.get_string_array("project.audio.voices")
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
	for voice in voices:
		midi_voices.push_back(voice.replace("@@", base_path + "/data"))
	if use_background_image and not FileAccess.file_exists(background_image_path):
		print("Invalid background file.")
		return false
	if use_multiple_voices:
		for voice in midi_voices:
			if not FileAccess.file_exists(voice):
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

func is_loaded() -> bool:
	return loaded
