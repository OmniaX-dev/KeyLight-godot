class_name VirtualPianoData

extends RefCounted

# --- Constants --------------------------------------------------------------

const BASE_WIDTH  := 2080
const BASE_HEIGHT := 1400

# Enum equivalent
enum NoteColor {
	C_Main, Csharp_Main, D_Main, Dsharp_Main,
	E_Main, F_Main, Fsharp_Main, G_Main,
	Gsharp_Main, A_Main, Asharp_Main, B_Main,

	C_Outline, Csharp_Outline, D_Outline, Dsharp_Outline,
	E_Outline, F_Outline, Fsharp_Outline, G_Outline,
	Gsharp_Outline, A_Outline, Asharp_Outline, B_Outline,

	C_Glow, Csharp_Glow, D_Glow, Dsharp_Glow,
	E_Glow, F_Glow, Fsharp_Glow, G_Glow,
	Gsharp_Glow, A_Glow, Asharp_Glow, B_Glow
}

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

# var tex_coords_pos := Vector2.ZERO
# var tex_coords_scale := Vector2.ONE

# Colors
var background_color: Color

var white_key_color: Color
var white_key_pressed_color: Color
var white_key_split_color: Color

var black_key_color: Color
var black_key_pressed_color: Color
var black_key_split_color: Color

var falling_white_note_color: Color
var falling_white_note_outline_color: Color
var falling_white_note_glow_color: Color

var falling_black_note_color: Color
var falling_black_note_outline_color: Color
var falling_black_note_glow_color: Color

var piano_line_color1: Color
var piano_line_color2: Color

var use_per_note_colors: bool = false
var per_note_colors := []   # size 36

# --- Constructor ------------------------------------------------------------

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
	falling_white_note_outline_color = Color8(50, 140, 200)
	falling_white_note_glow_color = Color8(50, 140, 200)

	falling_black_note_color = Color8(0, 50, 75)
	falling_black_note_outline_color = Color8(30, 80, 105)
	falling_black_note_glow_color = Color8(30, 80, 105)

	piano_line_color1 = Color8(60, 10, 10)
	piano_line_color2 = Color8(160, 10, 10)

	background_color = Color8(20, 20, 20)

	pressed_velocity_multiplier = 8.0

	white_key_shrink_factor = 8
	black_key_shrink_factor = 0

	falling_white_note_outline_width = 2
	falling_white_note_border_radius = 5

	falling_black_note_outline_width = 2
	falling_black_note_border_radius = 5

	# Initialize per-note colors
	per_note_colors.resize(36)
	for i in range(36):
		per_note_colors[i] = Color8(0, 0, 0)

	recalc__key_offsets()

# --- Scaling ---------------------------------------------------------------

func update_scale(width: int, height: int):
	scale_x = float(width) / float(BASE_WIDTH)
	scale_y = float(height) / float(BASE_HEIGHT)
	recalc__key_offsets()

# --- Accessors (equivalent to inline getters) ------------------------------

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

# --- Key offset calculation ------------------------------------------------

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

# --- JSON Loading ----------------------------------------------------------

func load_from_json(styleJson : JsonFile):
	self.white_key_width = styleJson.get_double("style.dimensions.whiteKeyWidth");
	var mul = styleJson.get_double("style.dimensions.whiteKeyHeightMultiplier");
	self.white_key_height = self.white_key_width * mul;
	self.black_key_width = styleJson.get_double("style.dimensions.blackKeyWidth");
	mul = styleJson.get_double("style.dimensions.blackKeyHeightMultiplier");
	self.black_key_height = self.black_key_width * mul;
	self.black_key_offset = styleJson.get_double("style.dimensions.blackKeyOffset");
	self.virtual_piano_x = styleJson.get_double("style.dimensions.virtualPianoX");
	# self.glowMargins = styleJson.get_rect("style.dimensions.glowMargins");
	self.white_key_shrink_factor = styleJson.get_double("style.dimensions.whiteKeyShrinkFactor");
	self.black_key_shrink_factor = styleJson.get_double("style.dimensions.blackKeyShrinkFactor");
	self.falling_white_note_outline_width = styleJson.get_int("style.dimensions.fallingWhiteNoteOutlineWidth");
	self.falling_white_note_border_radius = styleJson.get_double("style.dimensions.fallingWhiteNoteBorderRadius");
	self.falling_black_note_outline_width = styleJson.get_int("style.dimensions.fallingBlackNoteOutlineWidth");
	self.falling_black_note_border_radius = styleJson.get_double("style.dimensions.fallingBlackNoteBorderRadius");
	# self.texCoordsPos = styleJson.get_vec2("style.dimensions.textureCoordsPosition");
	# self.texCoordsScale = styleJson.get_vec2("style.dimensions.textureCoordsScale");
	self.pixels_per_second = styleJson.get_double("style.dimensions.pixelsPerSecond");
	self.white_key_width = styleJson.get_double("style.dimensions.whiteKeyWidth");
	self.falling_time_s = styleJson.get_double("style.dimensions.noteFallingTime_seconds");

	self.use_per_note_colors = styleJson.get_bool("style.usePerNoteColors");

	self.falling_white_note_color = styleJson.get_color("style.colors.fallingWhiteNote");
	self.falling_white_note_outline_color = styleJson.get_color("style.colors.fallingWhiteNoteOutline");
	self.falling_white_note_glow_color = styleJson.get_color("style.colors.fallingWhiteNoteGlow");
	self.falling_black_note_color = styleJson.get_color("style.colors.fallingBlackNote");
	self.falling_black_note_outline_color = styleJson.get_color("style.colors.fallingBlackNoteOutline");
	self.falling_black_note_glow_color = styleJson.get_color("style.colors.fallingBlackNoteGlow");
	self.background_color = styleJson.get_color("style.colors.background");
	self.white_key_pressed_color = styleJson.get_color("style.colors.whiteKeyPressed");
	self.black_key_pressed_color = styleJson.get_color("style.colors.blackKeyPressed");
	self.white_key_color = styleJson.get_color("style.colors.whiteKey");
	self.black_key_color = styleJson.get_color("style.colors.blackKey");
	self.white_key_split_color = styleJson.get_color("style.colors.whiteKeySeparator");
	self.black_key_split_color = styleJson.get_color("style.colors.blackKeySeparator");
	self.piano_line_color1 = styleJson.get_color("style.colors.pianoLine1");
	self.piano_line_color2 = styleJson.get_color("style.colors.pianoLine2");

	self.per_note_colors[NoteColor.C_Main] = styleJson.get_color("style.colors.perNote.C.main");
	self.per_note_colors[NoteColor.C_Outline] = styleJson.get_color("style.colors.perNote.C.outline");
	self.per_note_colors[NoteColor.C_Glow] = styleJson.get_color("style.colors.perNote.C.glow");

	self.per_note_colors[NoteColor.Csharp_Main] = styleJson.get_color("style.colors.perNote.C#.main");
	self.per_note_colors[NoteColor.Csharp_Outline] = styleJson.get_color("style.colors.perNote.C#.outline");
	self.per_note_colors[NoteColor.Csharp_Glow] = styleJson.get_color("style.colors.perNote.C#.glow");

	self.per_note_colors[NoteColor.D_Main] = styleJson.get_color("style.colors.perNote.D.main");
	self.per_note_colors[NoteColor.D_Outline] = styleJson.get_color("style.colors.perNote.D.outline");
	self.per_note_colors[NoteColor.D_Glow] = styleJson.get_color("style.colors.perNote.D.glow");

	self.per_note_colors[NoteColor.Dsharp_Main] = styleJson.get_color("style.colors.perNote.D#.main");
	self.per_note_colors[NoteColor.Dsharp_Outline] = styleJson.get_color("style.colors.perNote.D#.outline");
	self.per_note_colors[NoteColor.Dsharp_Glow] = styleJson.get_color("style.colors.perNote.D#.glow");

	self.per_note_colors[NoteColor.E_Main] = styleJson.get_color("style.colors.perNote.E.main");
	self.per_note_colors[NoteColor.E_Outline] = styleJson.get_color("style.colors.perNote.E.outline");
	self.per_note_colors[NoteColor.E_Glow] = styleJson.get_color("style.colors.perNote.E.glow");

	self.per_note_colors[NoteColor.F_Main] = styleJson.get_color("style.colors.perNote.F.main");
	self.per_note_colors[NoteColor.F_Outline] = styleJson.get_color("style.colors.perNote.F.outline");
	self.per_note_colors[NoteColor.F_Glow] = styleJson.get_color("style.colors.perNote.F.glow");

	self.per_note_colors[NoteColor.Fsharp_Main] = styleJson.get_color("style.colors.perNote.F#.main");
	self.per_note_colors[NoteColor.Fsharp_Outline] = styleJson.get_color("style.colors.perNote.F#.outline");
	self.per_note_colors[NoteColor.Fsharp_Glow] = styleJson.get_color("style.colors.perNote.F#.glow");

	self.per_note_colors[NoteColor.G_Main] = styleJson.get_color("style.colors.perNote.G.main");
	self.per_note_colors[NoteColor.G_Outline] = styleJson.get_color("style.colors.perNote.G.outline");
	self.per_note_colors[NoteColor.G_Glow] = styleJson.get_color("style.colors.perNote.G.glow");

	self.per_note_colors[NoteColor.Gsharp_Main] = styleJson.get_color("style.colors.perNote.G#.main");
	self.per_note_colors[NoteColor.Gsharp_Outline] = styleJson.get_color("style.colors.perNote.G#.outline");
	self.per_note_colors[NoteColor.Gsharp_Glow] = styleJson.get_color("style.colors.perNote.G#.glow");

	self.per_note_colors[NoteColor.A_Main] = styleJson.get_color("style.colors.perNote.A.main");
	self.per_note_colors[NoteColor.A_Outline] = styleJson.get_color("style.colors.perNote.A.outline");
	self.per_note_colors[NoteColor.A_Glow] = styleJson.get_color("style.colors.perNote.A.glow");

	self.per_note_colors[NoteColor.Asharp_Main] = styleJson.get_color("style.colors.perNote.A#.main");
	self.per_note_colors[NoteColor.Asharp_Outline] = styleJson.get_color("style.colors.perNote.A#.outline");
	self.per_note_colors[NoteColor.Asharp_Glow] = styleJson.get_color("style.colors.perNote.A#.glow");

	self.per_note_colors[NoteColor.B_Main] = styleJson.get_color("style.colors.perNote.B.main");
	self.per_note_colors[NoteColor.B_Outline] = styleJson.get_color("style.colors.perNote.B.outline");
	self.per_note_colors[NoteColor.B_Glow] = styleJson.get_color("style.colors.perNote.B.glow");

	self.recalc__key_offsets();
