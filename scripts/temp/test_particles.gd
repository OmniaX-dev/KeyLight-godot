extends GPUParticles2D

func _ready() -> void:
	var white_index = 29
	var emitter_width = 2.0
	var vpd : VirtualPianoData = get_parent().get_node("VKeyboard").vpd
	var tmpx = vpd.vpx() + (white_index * vpd.white_key_w()) + ((vpd.white_key_w() - emitter_width) / 2.0)
	var tmpy = vpd.vpy()
	process_material.emission_box_extents.x = emitter_width
	position = Vector2(tmpx, tmpy)
