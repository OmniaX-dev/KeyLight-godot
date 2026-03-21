extends Sprite2D

@export var fade_time := 0.10
var fade_tween: Tween

var note_index : int = -1
var white_index : int = -1
var is_white_key : bool = false
var vpd : VirtualPianoData
var emitter_width : float = 2.0
@export var max_light_energy := 2.0
@export var max_alpha := 1.0
var on_fade_finished: Callable = func(): pass
var key_press_velocity : int = 1

func _ready() -> void:
	pass

func initialize(_vpd : VirtualPianoData, _white_index : int, _is_white_key : bool):
	modulate.a = 0.0
	visible = false
	white_index  = _white_index
	vpd = _vpd
	is_white_key = _is_white_key
	set_key_position()

func set_light_color(color : Color):
	$Light.color = color

func set_key_position():
	var x : float = 0
	var y : float = vpd.vpy()
	var _scale : float = 1
	if is_white_key:
		x = vpd.vpx() + (white_index * vpd.white_key_w()) + ((vpd.white_key_w() - emitter_width) / 2.0) + 1
		_scale = vpd.white_key_w() / 256.0
		y -= 12
	else:
		x = vpd.vpx() + (white_index * vpd.white_key_w()) + ((vpd.white_key_w() - emitter_width) / 2.0) - vpd.black_key_w() - 1
		_scale = vpd.black_key_w() / 256.0
		y -= 6
	position.x = x
	position.y = y
	scale.x = _scale
	scale.y = _scale

func on_window_resized():
	set_key_position()

func on_note_on(note : NoteEvent):
	var info : NoteInfo = MidiParser.get_note_info(note.pitch)
	if note_index == info.key_index:
		key_press_velocity = note.velocity
		fade_in()

func on_note_off(note : NoteEvent):
	var info : NoteInfo = MidiParser.get_note_info(note.pitch)
	if note_index == info.key_index:
		fade_out()

func fade_in():
	visible = true
	_start_fade(1.0, func():
		pass
	)

func fade_out():
	_start_fade(0.0, func():
		visible = false
	)

func _start_fade(target_alpha: float, callback: Callable):
	# Store callback for when tween finishes
	on_fade_finished = callback

	# Kill previous tween but DO NOT reset alpha
	if fade_tween:
		fade_tween.kill()
		
	var velocity_strength : float = velocity_to_strength(key_press_velocity, 1, 127)
	if velocity_strength < 0.6:
		velocity_strength = 0.6

	# Start from current alpha (smooth interruption)
	var current_alpha := modulate.a
	var current_energy : float = $Light.energy
	var target_energy := target_alpha * max_light_energy
	
	# Scale targets by velocity
	var scaled_alpha := target_alpha * max_alpha * velocity_strength
	var scaled_energy := target_energy * max_light_energy * velocity_strength
	
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", scaled_alpha, fade_time).from(current_alpha)
	fade_tween.parallel().tween_property($Light, "energy", scaled_energy, fade_time).from(current_energy)
	
	# Connect the finished signal once
	fade_tween.finished.connect(_on_fade_finished)
	
func _on_fade_finished():
	on_fade_finished.call()

func velocity_to_strength(vel: int, min_vel: int, max_vel: int) -> float:
	if max_vel == min_vel:
		return 1.0  # avoid division by zero; treat as full strength
	return clamp(float(vel - min_vel) / float(max_vel - min_vel), 0.0, 1.0)
