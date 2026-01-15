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
