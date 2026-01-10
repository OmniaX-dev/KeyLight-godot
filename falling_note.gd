extends Node2D

var note_material := ShaderMaterial.new()
var note_gfx : FallingNoteGfxData

func _ready() -> void:
	note_material.shader = load("res://shaders/note.gdshader")


func _process(_delta: float) -> void:
	pass

func _draw():
	Primitives.outline_rounded_rect(self, note_gfx.rect, note_gfx.fill_color, note_gfx.outline_color, note_gfx.outline_thickness, note_gfx.corner_radius, note_gfx.corner_radius, note_gfx.corner_radius, note_gfx.corner_radius)
	#var mat := note_material.duplicate()
	#mat.set_shader_parameter("fill_color", note_gfx.fill_color)
	#mat.set_shader_parameter("outline_color", note_gfx.outline_color)
	#mat.set_shader_parameter("radius", note_gfx.corner_radius)
	#mat.set_shader_parameter("outline_width", note_gfx.outline_thickness)
	#mat.set_shader_parameter("rect_size", note_gfx.rect.size)
#
	#material = mat 
	#draw_rect(note_gfx.rect, Color.WHITE, true)
