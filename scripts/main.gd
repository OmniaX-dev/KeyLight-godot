extends Node2D

var vpd : VirtualPianoData = VirtualPianoData.new();
var project_file : KLProject = KLProject.new()
@onready var vpiano = $VKeyboard

func _enter_tree() -> void:
	var proj_file : String = ""
	var args: PackedStringArray = OS.get_cmdline_args()
	if args.size() > 0:
		for i in range(0, args.size()):
			var file_path: String = args[i]
			if FileAccess.file_exists(file_path) and file_path.ends_with(".klp"):
				proj_file = file_path
	if proj_file != "":
		project_file.load(proj_file)
		$VKeyboard.project_file = project_file
		if project_file.is_loaded():
			$ProjNameLabel.text = project_file.name
			
	var styleJsonFile = JsonFile.new()
	if project_file.is_loaded():
		styleJsonFile.load(project_file.style_file_path)
	else:
		styleJsonFile.load("res://resources/styles/default_style.json")
	vpd.load_from_json(styleJsonFile)
	$VKeyboard.vpd = vpd

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(vpd.BASE_WIDTH, vpd.BASE_HEIGHT))
	RenderingServer.set_default_clear_color(vpd.background_color)
	
	var root_size = get_viewport().get_visible_rect().size
	vpiano.anchor_left = 0.0
	vpiano.anchor_top = 0.0
	vpiano.anchor_right = 0.0
	vpiano.anchor_bottom = 0.0
	vpiano.offset_left = 0.0
	vpiano.offset_top = 0.0
	vpiano.offset_right = 0.0
	vpiano.offset_bottom = 0.0
	vpiano.set_deferred("size", root_size)
	
	var partJsonFile = JsonFile.new()
	partJsonFile.load("res://resources/particles/default_light_bar.json")

	vpiano.vkeyboard_size_updated.connect(on_window_resized)
	get_window().size_changed.connect(vpiano.on_window_resized)

func handle_input():
	if Input.is_action_just_pressed("play_pause"):
		if not vpiano.is_playing:
			vpiano.play()
		else:
			vpiano.pause()
	elif Input.is_action_just_pressed("stop_playback"):
		vpiano.stop()
	elif Input.is_action_just_pressed("toggle_fullscreen"):
		toggle_fullscreen()

func on_window_resized():
	var window_size = get_viewport().get_visible_rect().size
	$Vignette.set_deferred("size", window_size)

func _process(_delta: float) -> void:
	handle_input()
	
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		AudioConverter.CleanupConvertedFiles()
		get_tree().quit()

func toggle_fullscreen():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
