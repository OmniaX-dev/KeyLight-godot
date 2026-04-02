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

static func make_linear_gradient(start_color: Color, end_color: Color, steps: int, color_repeat: int = 1) -> Array:
	if steps <= 1:
		return [start_color]

	# How many unique colors we actually generate
	var base_count := steps / float(color_repeat)

	# If color_repeat is larger than steps, clamp to 1 base color
	if base_count < 1:
		base_count = 1

	# Compute remainder (steps not evenly divisible by color_repeat)
	var remainder := steps - base_count * color_repeat

	# Split remainder: half at start, half at end
	var extra_start := remainder / 2
	var extra_end := remainder - extra_start  # ensures odd remainder puts extra at end

	# Generate the base gradient colors
	var base_colors: Array = []
	for i in range(base_count):
		var t = float(i) / float(base_count - 1) if base_count > 1 else 0.0
		var r = lerp(start_color.r, end_color.r, t)
		var g = lerp(start_color.g, end_color.g, t)
		var b = lerp(start_color.b, end_color.b, t)
		var a = lerp(start_color.a, end_color.a, t)
		base_colors.append(Color(r, g, b, a))

	# Build the final array
	var result: Array = []

	# Add extra repeats of the first color
	for i in range(extra_start):
		result.append(base_colors[0])

	# Add each base color repeated color_repeat times
	for c in base_colors:
		for i in range(color_repeat):
			result.append(c)

	# Add extra repeats of the last color
	for i in range(extra_end):
		result.append(base_colors[-1])

	# Ensure final size is exactly "steps"
	return result.slice(0, steps)

static func make_linear_multi_gradient(colors: Array, steps: int) -> Array:
	var result: Array = []

	if steps <= 1:
		return [colors[0]]

	var segments := colors.size() - 1
	var steps_per_segment := steps / float(segments)
	var remainder := steps % segments

	# We'll distribute the remainder by adding +1 step to the first N segments
	# This keeps the distribution even and avoids gaps.
	var extra_steps := remainder

	for i in range(segments):
		var c1: Color = colors[i]
		var c2: Color = colors[i + 1]

		# Base number of steps for this segment
		var count := steps_per_segment

		# Distribute remainder: first segments get +1
		if i < extra_steps:
			count += 1

		# If this is the last segment, ensure we end exactly on the final color
		# and avoid duplicating the boundary color.
		for s in range(count):
			var t = float(s) / float(count)
			var r = lerp(c1.r, c2.r, t)
			var g = lerp(c1.g, c2.g, t)
			var b = lerp(c1.b, c2.b, t)
			var a = lerp(c1.a, c2.a, t)
			result.append(Color(r, g, b, a))

	# Ensure exact size (in case of floating rounding)
	return result.slice(0, steps)


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
		
static func load_external_texture(path: String) -> Texture2D:
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_error("Failed to load external image: " + path)
		return null
	return ImageTexture.create_from_image(img)
