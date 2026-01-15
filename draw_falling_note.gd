extends Node2D

var note_gfx: FallingNoteGfxData = FallingNoteGfxData.new():
	set(value):
		note_gfx = value
		queue_redraw()
	
func _draw():
	var local_rect = Rect2(Vector2.ZERO, note_gfx.rect.size)
	Primitives.outline_rounded_rect(
		self,
		local_rect,
		note_gfx.fill_color,
		note_gfx.outline_color,
		note_gfx.outline_thickness,
		note_gfx.corner_radius,
		note_gfx.corner_radius,
		note_gfx.corner_radius,
		note_gfx.corner_radius
	)
