extends ColorRect

func _ready() -> void:
	var root_size = get_viewport().get_visible_rect().size

	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0

	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	set_deferred("size", root_size)
