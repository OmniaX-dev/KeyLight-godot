class_name VirtualPianoData
extends RefCounted

const BASE_WIDTH  := 2080
const BASE_HEIGHT := 1400

enum NoteColor { C, Csharp, D, Dsharp, E, F, Fsharp, G, Gsharp, A, Asharp, B }

# --- Internal state ---------------------------------------------------------
var pixels_per_second: float = 0.0
var virtual_piano_x: float = 0.0
var virtual_piano_y: float = 0.0
var white_key_width: float = 0.0
var white_key_height: float = 0.0
var black_key_width: float = 0.0
var black_key_height: float = 0.0
var black_key_offset: float = 0.0
var scale_x: float = 1.0
var scale_y: float = 1.0
var white_key_shrink_factor: float = 0.0
var black_key_shrink_factor: float = 0.0
var _key_offsets := {}   # Dictionary<int, float>

# --- Public fields ----------------------------------------------------------
var falling_time_s: float = 0.0
var pressed_velocity_multiplier: float = 0.0
var falling_white_note_outline_width: int = 0
var falling_white_note_border_radius: float = 0.0
var falling_black_note_outline_width: int = 0
var falling_black_note_border_radius: float = 0.0
var fog_height: float = 0.0
var fog_fade_percent: float = 0.0

# --- Colors -----------------------------------------------------------------
var background_color: Color
var white_key_color: Color
var white_key_pressed_color: Color
var white_key_split_color: Color
var black_key_color: Color
var black_key_pressed_color: Color
var black_key_split_color: Color
var falling_white_note_color: Color
var falling_black_note_color: Color
var piano_line_color1: Color
var piano_line_color2: Color
var use_per_note_colors: bool = false
var use_filled_notes: bool = true
var fog_color: Color
var per_note_colors = []   # size 12
var per_note_colors_use = []   # size 12
var per_id_colors : Dictionary[int, Color] = { }


# --- Methods ----------------------------------------------------------------
func _init():
	falling_time_s = 4.5

	white_key_width = 40
	white_key_height = white_key_width * 8
	black_key_width = 22
	black_key_height = black_key_width * 9
	black_key_offset = 4

	white_key_color = Color8(245, 245, 245)
	white_key_pressed_color = Color8(120, 120, 210)
	white_key_split_color = Color8(0, 0, 0)

	black_key_color = Color8(0, 0, 0)
	black_key_pressed_color = Color8(20, 20, 90)
	black_key_split_color = Color8(0, 0, 0)

	virtual_piano_x = 0.0
	pixels_per_second = 250
	virtual_piano_y = BASE_HEIGHT - white_key_height

	scale_x = 1.0
	scale_y = 1.0

	falling_white_note_color = Color8(20, 110, 170)

	falling_black_note_color = Color8(0, 50, 75)

	piano_line_color1 = Color8(60, 10, 10)
	piano_line_color2 = Color8(160, 10, 10)

	background_color = Color8(20, 20, 20)
	fog_color = Color8(255, 255, 255)

	pressed_velocity_multiplier = 8.0

	white_key_shrink_factor = 8
	black_key_shrink_factor = 0

	falling_white_note_outline_width = 2
	falling_white_note_border_radius = 5

	falling_black_note_outline_width = 2
	falling_black_note_border_radius = 5
	fog_height = 200
	fog_fade_percent = 0.5

	# Initialize per-note colors
	per_note_colors.resize(36)
	per_note_colors_use.resize(36)
	for i in range(36):
		per_note_colors[i] = Color8(0, 0, 0)
		per_note_colors_use[i] = false

	per_id_colors.clear()
	recalc__key_offsets()

func update_scale(width: int, height: int):
	scale_x = float(width) / float(BASE_WIDTH)
	scale_y = float(height) / float(BASE_HEIGHT)
	recalc__key_offsets()

func pps() -> float:
	return pixels_per_second * scale_y

func vpx() -> float:
	return virtual_piano_x * scale_x

func vpy() -> float:
	return virtual_piano_y * scale_y

func white_key_w() -> float:
	return white_key_width * scale_x

func white_key_h() -> float:
	return white_key_height * scale_y

func black_key_w() -> float:
	return black_key_width * scale_x

func black_key_h() -> float:
	return black_key_height * scale_y

func black_key_off() -> float:
	return black_key_offset * scale_x

func white_key_shrink() -> float:
	return white_key_shrink_factor * scale_x

func black_key_shrink() -> float:
	return black_key_shrink_factor * scale_x

func key_offsets():
	recalc__key_offsets()
	return _key_offsets

func is_per_note_color_used(noteName : NoteColor) -> bool:
	return use_per_note_colors && per_note_colors_use[noteName]

func add_voice_note_colors(note_id : int, color : Color):
	per_id_colors[note_id] = color
	
func get_note_color(noteInfo : NoteInfo, note_id = -1) -> Color:
	if note_id >= 0:
		if note_id in per_id_colors:
			return per_id_colors[note_id]
	if use_per_note_colors:
		return per_note_colors[noteInfo.note_in_octave]
	if noteInfo.is_white_key():
		return falling_white_note_color
	return falling_black_note_color

func recalc__key_offsets():
	_key_offsets.clear()
	var white_count := 0

	for midi_note in range(21, 109):
		var note_in_octave := midi_note % 12
		var key_index := midi_note - 21

		if MidiParser.is_white_key(note_in_octave):
			var x := vpx() + white_count * white_key_w()
			_key_offsets[key_index] = x
			white_count += 1
		else:
			var x := vpx() + ((white_count - 1) * white_key_w() + (white_key_w() - black_key_w() / 2.0)) - black_key_off()
			_key_offsets[key_index] = x

func load_from_json(styleJson : JsonFile):
	self.white_key_width = styleJson.get_double("style.dimensions.whiteKeyWidth");
	var mul = styleJson.get_double("style.dimensions.whiteKeyHeightMultiplier");
	self.white_key_height = self.white_key_width * mul;
	self.black_key_width = styleJson.get_double("style.dimensions.blackKeyWidth");
	mul = styleJson.get_double("style.dimensions.blackKeyHeightMultiplier");
	self.black_key_height = self.black_key_width * mul;
	self.black_key_offset = styleJson.get_double("style.dimensions.blackKeyOffset");
	self.virtual_piano_x = styleJson.get_double("style.dimensions.virtualPianoX");
	self.white_key_shrink_factor = styleJson.get_double("style.dimensions.whiteKeyShrinkFactor");
	self.black_key_shrink_factor = styleJson.get_double("style.dimensions.blackKeyShrinkFactor");
	self.falling_white_note_outline_width = styleJson.get_int("style.dimensions.fallingWhiteNoteOutlineWidth");
	self.falling_white_note_border_radius = styleJson.get_double("style.dimensions.fallingWhiteNoteBorderRadius");
	self.falling_black_note_outline_width = styleJson.get_int("style.dimensions.fallingBlackNoteOutlineWidth");
	self.falling_black_note_border_radius = styleJson.get_double("style.dimensions.fallingBlackNoteBorderRadius");
	self.pixels_per_second = styleJson.get_double("style.dimensions.pixelsPerSecond");
	self.white_key_width = styleJson.get_double("style.dimensions.whiteKeyWidth");
	self.falling_time_s = styleJson.get_double("style.dimensions.noteFallingTime_seconds");
	self.fog_height = styleJson.get_double("style.fog.height");
	self.fog_fade_percent = styleJson.get_double("style.fog.fade_percent");
	self.falling_time_s = styleJson.get_double("style.dimensions.noteFallingTime_seconds");

	self.use_per_note_colors = styleJson.get_bool("style.usePerNoteColors");
	self.use_filled_notes = styleJson.get_bool("style.useFilledNotes");

	self.falling_white_note_color = styleJson.get_color("style.colors.fallingWhiteNote");
	self.falling_black_note_color = styleJson.get_color("style.colors.fallingBlackNote");
	self.background_color = styleJson.get_color("style.colors.background");
	self.white_key_pressed_color = styleJson.get_color("style.colors.whiteKeyPressed");
	self.black_key_pressed_color = styleJson.get_color("style.colors.blackKeyPressed");
	self.white_key_color = styleJson.get_color("style.colors.whiteKey");
	self.black_key_color = styleJson.get_color("style.colors.blackKey");
	self.white_key_split_color = styleJson.get_color("style.colors.whiteKeySeparator");
	self.black_key_split_color = styleJson.get_color("style.colors.blackKeySeparator");
	self.piano_line_color1 = styleJson.get_color("style.colors.pianoLine1");
	self.piano_line_color2 = styleJson.get_color("style.colors.pianoLine2");
	self.fog_color = styleJson.get_color("style.colors.fog");

	self.per_note_colors[NoteColor.C] = styleJson.get_color("style.colors.perNote.C.color");
	self.per_note_colors_use[NoteColor.C] = styleJson.get_bool("style.colors.perNote.C.use");

	self.per_note_colors[NoteColor.Csharp] = styleJson.get_color("style.colors.perNote.C#.color");
	self.per_note_colors_use[NoteColor.Csharp] = styleJson.get_bool("style.colors.perNote.C#.use")

	self.per_note_colors[NoteColor.D] = styleJson.get_color("style.colors.perNote.D.color");
	self.per_note_colors_use[NoteColor.D] = styleJson.get_bool("style.colors.perNote.D.use")

	self.per_note_colors[NoteColor.Dsharp] = styleJson.get_color("style.colors.perNote.D#.color");
	self.per_note_colors_use[NoteColor.Dsharp] = styleJson.get_bool("style.colors.perNote.D#.use")

	self.per_note_colors[NoteColor.E] = styleJson.get_color("style.colors.perNote.E.color");
	self.per_note_colors_use[NoteColor.E] = styleJson.get_bool("style.colors.perNote.E.use")

	self.per_note_colors[NoteColor.F] = styleJson.get_color("style.colors.perNote.F.color");
	self.per_note_colors_use[NoteColor.F] = styleJson.get_bool("style.colors.perNote.F.use")

	self.per_note_colors[NoteColor.Fsharp] = styleJson.get_color("style.colors.perNote.F#.color");
	self.per_note_colors_use[NoteColor.Fsharp] = styleJson.get_bool("style.colors.perNote.F#.use")

	self.per_note_colors[NoteColor.G] = styleJson.get_color("style.colors.perNote.G.color");
	self.per_note_colors_use[NoteColor.G] = styleJson.get_bool("style.colors.perNote.G.use")

	self.per_note_colors[NoteColor.Gsharp] = styleJson.get_color("style.colors.perNote.G#.color");
	self.per_note_colors_use[NoteColor.Gsharp] = styleJson.get_bool("style.colors.perNote.G#.use")

	self.per_note_colors[NoteColor.A] = styleJson.get_color("style.colors.perNote.A.color");
	self.per_note_colors_use[NoteColor.A] = styleJson.get_bool("style.colors.perNote.A.use")

	self.per_note_colors[NoteColor.Asharp] = styleJson.get_color("style.colors.perNote.A#.color");
	self.per_note_colors_use[NoteColor.Asharp] = styleJson.get_bool("style.colors.perNote.A#.use")

	self.per_note_colors[NoteColor.B] = styleJson.get_color("style.colors.perNote.B.color");
	self.per_note_colors_use[NoteColor.B] = styleJson.get_bool("style.colors.perNote.B.use")

	self.recalc__key_offsets();
