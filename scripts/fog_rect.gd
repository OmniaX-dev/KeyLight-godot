extends TextureRect

var vpiano : Control
var fog_height : float = 200.0

func _ready() -> void:
	vpiano = get_parent().get_node("VKeyboard")
	vpiano.vkeyboard_size_updated.connect(on_window_resized)
	
	fog_height = vpiano.vpd.fog_height
	if material is ShaderMaterial:
		material.set_shader_parameter("fade_height", vpiano.vpd.fog_fade_percent)
		material.set_shader_parameter("base_color", vpiano.vpd.fog_color)
	
	position.x = 0
	position.y = vpiano.vpd.vpy() - fog_height
	var window_size = get_viewport().get_visible_rect().size
	var fog_size : Vector2
	fog_size.x = window_size.x
	fog_size.y = fog_height + 50
	#set_deferred("size", fog_size)

func on_window_resized():
	var window_size = get_viewport().get_visible_rect().size
	var fog_size : Vector2
	position.y = vpiano.vpd.vpy() - fog_height
	fog_size.x = window_size.x
	fog_size.y = size.y
	set_deferred("size", fog_size)
