extends Node2D

var note_gfx: FallingNoteGfxData = FallingNoteGfxData.new():
	set(value):
		note_gfx = value
		$DebugLabel.text = str(note_gfx.id)
		queue_redraw()
	
func _draw():
	var fill_color = note_gfx.fill_color
	if not note_gfx.filled:
		fill_color = Color.TRANSPARENT
	var outline_color = note_gfx.fill_color
	var local_rect = Rect2(Vector2.ZERO, note_gfx.rect.size)
	Primitives.outline_rounded_rect(
		self,
		local_rect,
		fill_color,
		outline_color,
		note_gfx.outline_thickness,
		note_gfx.corner_radius,
		note_gfx.corner_radius,
		note_gfx.corner_radius,
		note_gfx.corner_radius
	)
