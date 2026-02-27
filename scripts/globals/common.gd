class_name Common
extends RefCounted


static func get_current_time_us() -> float:
	return Time.get_ticks_usec()

static func calc_pressed_velocity(vpd : VirtualPianoData, midi_velocity : int) -> Vector2:
	return Vector2(0.0, (midi_velocity / 128.0)) * vpd.pressed_velocity_multiplier

static func build_curve_from_points(points: Array) -> CurveTexture:
	var curve := Curve.new()

	# Expecting: [x0, y0, x1, y1, x2, y2, ...]
	for i in range(0, points.size(), 2):
		if i + 1 < points.size():
			var x := float(points[i])
			var y := float(points[i + 1])
			curve.add_point(Vector2(x, y))

	var tex := CurveTexture.new()
	tex.curve = curve
	return tex

static func apply_color_intensity(base: Color, intensity_ev: float) -> Color:
	# Step 1: EV → multiplier
	var m = pow(2.0, intensity_ev)

	# Step 2: multiply in linear space
	var r_lin = base.r * m
	var g_lin = base.g * m
	var b_lin = base.b * m

	# Step 3: convert linear → sRGB
	return Color(
		linear_to_srgb(r_lin),
		linear_to_srgb(g_lin),
		linear_to_srgb(b_lin),
		1.0
	)

static func linear_to_srgb(x: float) -> float:
	if x <= 0.0031308:
		return 12.92 * x
	return 1.055 * pow(x, 1.0 / 2.4) - 0.055

static func build_note_gfx_data(vpd : VirtualPianoData, noteEvent : NoteEvent) -> FallingNoteGfxData:
	var info : NoteInfo =  MidiParser.get_note_info(noteEvent.pitch);
	var h : float = noteEvent.duration * vpd.pps()
	var y : float = -h + noteEvent.progress * (vpd.vpy() + h)
	var x : float = vpd.key_offsets()[info.key_index] + (vpd.white_key_shrink() / 2.0)
	if not info.is_white_key():
		var note_color = vpd.get_note_color(info, noteEvent.id)
		var gfx_data : FallingNoteGfxData = FallingNoteGfxData.new()
		gfx_data.rect = Rect2(x, y, vpd.black_key_w() - vpd.black_key_shrink(), h)
		gfx_data.fill_color = note_color
		gfx_data.filled = vpd.use_filled_notes
		gfx_data.outline_thickness = vpd.falling_black_note_outline_width
		gfx_data.corner_radius = vpd.falling_black_note_border_radius
		gfx_data.id = noteEvent.id
		return gfx_data
	else:
		var note_color = vpd.get_note_color(info, noteEvent.id)
		var gfx_data : FallingNoteGfxData = FallingNoteGfxData.new()
		gfx_data.rect = Rect2(x, y, vpd.white_key_w() - vpd.white_key_shrink(), h)
		gfx_data.fill_color = note_color
		gfx_data.filled = vpd.use_filled_notes
		gfx_data.outline_thickness = vpd.falling_white_note_outline_width
		gfx_data.corner_radius = vpd.falling_white_note_border_radius
		gfx_data.id = noteEvent.id
		return gfx_data
