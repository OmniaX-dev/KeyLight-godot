extends GPUParticles2D

func _ready() -> void:
	var white_index = 29
	var emitter_width = 2.0
	var vpd : VirtualPianoData = get_parent().get_node("VKeyboard").vpd
	var tmpx = vpd.vpx() + (white_index * vpd.white_key_w()) + ((vpd.white_key_w() - emitter_width) / 2.0)
	var tmpy = vpd.vpy()
	process_material.emission_box_extents.x = emitter_width
	position = Vector2(tmpx, tmpy)
	
	var _scale : float = vpd.white_key_w() / 256.0
	
	var spr : Sprite2D = get_parent().get_node("Sprite2D2")
	spr.position.x = tmpx
	spr.position.y = tmpy - 12
	spr.scale.x = _scale
	spr.scale.y = _scale
