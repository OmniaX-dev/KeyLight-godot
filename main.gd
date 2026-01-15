extends Node2D

var vpd : VirtualPianoData = VirtualPianoData.new();

func _enter_tree() -> void:
	var styleJsonFile = JsonFile.new()
	styleJsonFile.load("res://styles/DefaultStyle.json")
	vpd.load_from_json(styleJsonFile)
	$VKeyboard.vpd = vpd

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$VKeyboard.vkeyboard_size_updated.connect(_on_window_resized)
	#get_window().size_changed.connect(_on_window_resized)
	get_window().size_changed.connect($VKeyboard._on_window_resized)
	var window_size = get_viewport().get_visible_rect().size
	$LightBar.position = Vector2(window_size.x / 2, vpd.vpy())
	$LightBar/LightBarParticles.process_material.emission_box_extents.x = window_size.x
	
	
	var root_size = get_viewport().get_visible_rect().size

	$Vignette.anchor_left = 0.0
	$Vignette.anchor_top = 0.0
	$Vignette.anchor_right = 0.0
	$Vignette.anchor_bottom = 0.0

	$Vignette.offset_left = 0.0
	$Vignette.offset_top = 0.0
	$Vignette.offset_right = 0.0
	$Vignette.offset_bottom = 0.0

	$Vignette.set_deferred("size", root_size)
	

func _on_window_resized():
	var window_size = get_viewport().get_visible_rect().size
	$LightBar.position = Vector2(window_size.x / 2, vpd.vpy())
	$LightBar/LightBarParticles.process_material.emission_box_extents.x = window_size.x
	$Vignette.set_deferred("size", window_size)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_fullscreen"):
		toggle_fullscreen()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		AudioConverter.CleanupConvertedFiles()
		get_tree().quit()

func toggle_fullscreen():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
