class_name PianoKey
extends RefCounted

var note_info : NoteInfo = NoteInfo.new()
var pressed : bool = false
var pressed_force : Vector2 = Vector2(0, 0)
var color : Color = Color.TRANSPARENT
var hit_effect
