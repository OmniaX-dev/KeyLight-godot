class_name AudioManager
extends RefCounted

var has_audio_file : bool = false
var audio_stream : AudioStreamWAV
var auto_sound_start : float = 0.0
var audio_file_path : String = ""
var wav_file_path : String = ""
	
static func convert_to_wav_ffmpeg(input_path: String) -> String:
	var abs_in := ProjectSettings.globalize_path(input_path)

	# Ensure output directory exists
	var out_dir := ProjectSettings.globalize_path("user://converted")
	DirAccess.make_dir_recursive_absolute(out_dir)

	# Unique output filename
	var base := abs_in.get_file().get_basename()
	var out_path := out_dir + "/" + base + "_" + str(Time.get_ticks_msec()) + ".wav"

	# FFmpeg arguments (must be PackedStringArray)
	var args: PackedStringArray = [
		"-y",                   # overwrite output
		"-i", abs_in,           # input file
		"-acodec", "pcm_s16le", # 16-bit PCM
		"-ac", "2",             # stereo
		"-ar", "44100",         # sample rate
		out_path
	]

	# Run FFmpeg
	var exit_code := OS.execute("ffmpeg", args, [], true)

	if exit_code != 0:
		push_error("FFmpeg conversion failed with code %d" % exit_code)
		return ""

	return out_path

func load_audio_file(path: String) -> bool:
	has_audio_file = false
	
	wav_file_path = await AudioConverter.ConvertToWav(path)
	if wav_file_path == "":
		push_error("Conversion failed")
		return false

	var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(wav_file_path)
	if stream == null:
		push_error("Failed to open audio file: %s" % wav_file_path)
		return false

	var wav_stream: AudioStreamWAV = stream as AudioStreamWAV
	audio_stream = wav_stream
	has_audio_file = true

	auto_sound_start = scan_music_start_point(wav_stream, 0.005, 0.05)
	audio_file_path = wav_file_path

	return true

func scan_music_start_point(stream: AudioStreamWAV, threshold_percent: float, min_duration: float = 0.05) -> float:
	var data: PackedByteArray = stream.data
	var channels: int = 2 if stream.stereo else 1
	var sample_rate: int = stream.mix_rate
	var format: int = stream.format

	# Only 16-bit PCM supported (matches your C++ logic)
	if format != AudioStreamWAV.FORMAT_16_BITS:
		push_error("Unsupported WAV format (need 16-bit PCM)")
		return 0.0

	# Number of int16 samples
	var sample_count = data.size() / 2.0

	# Threshold in PCM units
	var full_scale: float = 32767.0
	var threshold: float = threshold_percent * full_scale
	var hop: int = 256

	# Window size (per channel)
	var window_samples: int = int(min_duration * float(sample_rate))

	var i: int = 0
	while i + window_samples * channels < sample_count:

		var sum_squares: float = 0.0

		# RMS over window
		for j: int in range(window_samples):
			for c: int in range(channels):
				var byte_index: int = ((i + j * channels) + c) * 2
				var s: float = float(data.decode_s16(byte_index))
				sum_squares += s * s

		var mean_square: float = sum_squares / float(window_samples * channels)
		var rms: float = sqrt(mean_square)

		if rms > threshold:
			var time_seconds = float(i) / float(channels) / float(sample_rate)
			return time_seconds

		i += hop * channels

	return 0.0
