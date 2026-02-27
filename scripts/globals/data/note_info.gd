class_name NoteInfo
extends RefCounted

var name: String = ""
var octave: int = 0
var note_in_octave: int = 0
var key_index: int = 0

func is_white_key() -> bool:
	return note_in_octave in [0, 2, 4, 5, 7, 9, 11]
