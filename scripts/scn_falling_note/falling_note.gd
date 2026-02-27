extends Node2D

var note_gfx: FallingNoteGfxData = FallingNoteGfxData.new():
	set(value):
		note_gfx = value
		queue_redraw()

func _enter_tree() -> void:
	#note_gfx.rect = Rect2(100, 100, 30, 200)
	note_gfx.fill_color = Color8(200, 0, 0)
	note_gfx.outline_color = Color8(0, 200, 0)
	note_gfx.glow_color = Color8(0, 0, 200)
	note_gfx.outline_thickness = 4
	note_gfx.corner_radius = 10
	note_gfx.id = -1
	
func set_particle_position():
	var local_rect = Rect2(Vector2.ZERO, note_gfx.rect.size)
	var part = $Particles
	part.position = Vector2(local_rect.position.x + ((local_rect.size.x) / 2.0),
								  local_rect.position.y + local_rect.size.y - 8)
	part.self_modulate = note_gfx.outline_color
	part.lifetime = note_gfx.rect.size.y / 140.0
	part.amount = (20.0 * note_gfx.rect.size.y) / 120.0
	
func _ready() -> void:
	pass

func on_midi_note_off(note : NoteEvent):
	if note.id == note_gfx.id:
		queue_free()

func _physics_process(_delta: float) -> void:
	position.x = note_gfx.rect.position.x
	position.y = note_gfx.rect.position.y

func _draw():
	$FallingNote.note_gfx = note_gfx
	$FallingNote.queue_redraw()
	#var local_rect = Rect2(Vector2.ZERO, note_gfx.rect.size)
	#Primitives.outline_rounded_rect(
		#self,
		#local_rect,
		#note_gfx.fill_color,
		#note_gfx.outline_color,
		#note_gfx.outline_thickness,
		#note_gfx.corner_radius,
		#note_gfx.corner_radius,
		#note_gfx.corner_radius,
		#note_gfx.corner_radius
	#)
