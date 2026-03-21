class_name VPianoKeyboard
extends RefCounted

var vpd : VirtualPianoData
var vpr : VPianoResources
var piano_keys : Array[PianoKey] = []

func initialize(VPD : VirtualPianoData, VPR : VPianoResources) -> void:
	vpd = VPD
	vpr = VPR
	var white_index = 0
	for midi_note in range(21, 109):
		var note_in_octave = midi_note % 12
		var pk = PianoKey.new()
		pk.note_info = MidiParser.get_note_info(midi_note)
		pk.pressed = false
		pk.hit_effect = VPR.note_hit_scene.instantiate()
		pk.hit_effect.note_index = pk.note_info.key_index
		pk.hit_effect.initialize(vpd, white_index, MidiParser.is_white_key(note_in_octave))
		if MidiParser.is_white_key(note_in_octave):
			white_index += 1
		pk.hit_effect.queue_redraw()
		piano_keys.push_back(pk)

func render(vpiano : Control):
	var window_size = vpiano.get_viewport_rect().size
	var white_index = 0
	for midi_note in range(21, 109):
		var note_in_octave = midi_note % 12
		if MidiParser.is_white_key(note_in_octave):
			var info =  MidiParser.get_note_info(midi_note)
			var x = vpd.vpx() + white_index * vpd.white_key_w()
			var y = vpd.vpy()
			var color = vpd.white_key_color
			if piano_keys[info.key_index].pressed:
				color = vpd.get_note_color(info)
				if vpd.use_note_color_on_pressed:
					color = piano_keys[info.key_index].color
					piano_keys[info.key_index].hit_effect.set_light_color(color.lightened(0.4))
			vpiano.draw_rect(Rect2(x, y, vpd.white_key_w(), vpd.white_key_h()), color, true)
			vpiano.draw_rect(Rect2(x, y, vpd.white_key_w(), vpd.white_key_h()), vpd.white_key_split_color, false)
			white_index += 1

	vpiano.draw_rect(Rect2(vpd.vpx(), vpd.vpy() - 2, window_size.x, 4), vpd.piano_line_color1, true)
	vpiano.draw_rect(Rect2(vpd.vpx(), vpd.vpy(), window_size.x, 8), vpd.piano_line_color2, true)

	white_index = 0
	for midi_note in range(21, 109):
		var note_in_octave = midi_note % 12
		if MidiParser.is_white_key(note_in_octave):
			white_index += 1
		else:
			var info =  MidiParser.get_note_info(midi_note)
			var x = vpd.vpx() + ((white_index - 1) * vpd.white_key_w() + (vpd.white_key_w() - vpd.black_key_w() / 2.0)) - vpd.black_key_off()
			var y = vpd.vpy()
			var color = vpd.black_key_color
			if piano_keys[info.key_index].pressed:
				color = vpd.get_note_color(info)
				if vpd.use_note_color_on_pressed:
					color = piano_keys[info.key_index].color
					piano_keys[info.key_index].hit_effect.set_light_color(color.lightened(0.4))
			Primitives.fill_rounded_rect(vpiano, Rect2(x, y, vpd.black_key_w(), vpd.black_key_h()), color, 0, 0, 8, 8)
