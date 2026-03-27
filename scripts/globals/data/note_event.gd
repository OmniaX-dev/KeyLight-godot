class_name NoteEvent
extends RefCounted

var pitch: int = 0
var start_time: float = 0.0
var end_time: float = 0.0
var duration: float = 0.0
var velocity: int = 0
var channel: int = 0

var hit: bool = false
var right_hand: bool = false
var last: bool = false
var first: bool = false
var id: int = 0
var progress : float = 0

func info_to_string() -> String:
	var s := ""
	s += "NoteEvent {\n"
	s += "  id: %s\n" % id
	s += "  pitch: %s\n" % pitch
	s += "  start_time: %s\n" % start_time
	s += "  end_time: %s\n" % end_time
	s += "  duration: %s\n" % duration
	s += "  velocity: %s\n" % velocity
	s += "  channel: %s\n" % channel
	s += "  hit: %s\n" % hit
	s += "  right_hand: %s\n" % right_hand
	s += "  first: %s\n" % first
	s += "  last: %s\n" % last
	s += "  progress: %s\n" % progress
	s += "}\n"
	return s

static func write_notes_to_file(path: String, notes: Array[NoteEvent]) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Failed to open file for writing: %s" % path)
		return

	for n in notes:
		f.store_string(n.info_to_string())

	f.close()
