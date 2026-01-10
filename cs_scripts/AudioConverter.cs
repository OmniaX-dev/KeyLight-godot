using Godot;
using System;
using System.IO;
using System.Text;
using NLayer;
using NVorbis;
using System.Threading.Tasks;

public partial class AudioConverter : Node
{
	private string _outputDir;

	public override void _Ready()
	{
		// Convert user:// to an absolute filesystem path
		string userRoot = ProjectSettings.GlobalizePath("user://");
		_outputDir = Path.Combine(userRoot, "converted");

		if (!Directory.Exists(_outputDir))
			Directory.CreateDirectory(_outputDir);
	}

	public async Task<string> ConvertToWavAsync(string inputPath)
	{
		return await Task.Run(() =>
		{
			return ConvertToWav(inputPath);
		});
	}


	/// <summary>
	/// Converts MP3/OGG to WAV. WAV files are returned unchanged.
	/// Supports res://, user://, and absolute paths.
	/// </summary>
	public string ConvertToWav(string inputPath)
	{
		if (string.IsNullOrEmpty(inputPath))
		{
			GD.PushError("ConvertToWav: inputPath is null or empty");
			return "";
		}

		// Normalize Godot paths → absolute filesystem paths
		string absoluteInput = ProjectSettings.GlobalizePath(inputPath);
		string extension = Path.GetExtension(absoluteInput).ToLowerInvariant();

		// WAV passthrough
		if (extension == ".wav")
			return absoluteInput;

		string fileName = Path.GetFileNameWithoutExtension(absoluteInput);
		string outputPath = Path.Combine(_outputDir, $"{fileName}_{Guid.NewGuid()}.wav");

		try
		{
			switch (extension)
			{
				case ".mp3":
					ConvertMp3(absoluteInput, outputPath);
					break;

				case ".ogg":
					ConvertOgg(absoluteInput, outputPath);
					break;

				default:
					GD.PushError($"ConvertToWav: Unsupported format: {extension}");
					return "";
			}
		}
		catch (Exception ex)
		{
			GD.PushError($"ConvertToWav failed: {ex.Message}");
			return "";
		}

		// return AbsoluteToUserPath(outputPath);
		return outputPath;
	}

	// ------------------------------------------------------------
	// MP3 → WAV (NLayer)
	// ------------------------------------------------------------
	private void ConvertMp3(string inputPath, string outputPath)
	{
		using var fs = File.OpenRead(inputPath);
		using var decoder = new MpegFile(fs);

		int sampleRate = decoder.SampleRate;
		int channels = decoder.Channels;

		WritePcm16Wav(outputPath, sampleRate, channels, writer =>
		{
			float[] buffer = new float[4096];
			int samplesRead;

			while ((samplesRead = decoder.ReadSamples(buffer, 0, buffer.Length)) > 0)
			{
				for (int i = 0; i < samplesRead; i++)
				{
					short pcm = FloatToPcm16(buffer[i]);
					writer.Write(pcm);
				}
			}
		});
	}





	// ------------------------------------------------------------
	// OGG → WAV (NVorbis)
	// ------------------------------------------------------------
	private void ConvertOgg(string inputPath, string outputPath)
	{
		using var vorbis = new VorbisReader(inputPath);

		int sampleRate = vorbis.SampleRate;
		int channels = vorbis.Channels;

		WritePcm16Wav(outputPath, sampleRate, channels, writer =>
		{
			float[] buffer = new float[4096];
			int samplesRead;

			while ((samplesRead = vorbis.ReadSamples(buffer, 0, buffer.Length)) > 0)
			{
				for (int i = 0; i < samplesRead; i++)
				{
					short pcm = (short)(buffer[i] * short.MaxValue);
					writer.Write(pcm);
				}
			}
		});
	}


	// ------------------------------------------------------------
	// WAV header helpers
	// ------------------------------------------------------------
	private void WritePcm16Wav(string outputPath, int sampleRate, int channels, Action<BinaryWriter> writeSamples)
	{
		using var stream = File.Open(outputPath, FileMode.Create);
		using var writer = new BinaryWriter(stream);

		// Write placeholder header
		writer.Write(Encoding.ASCII.GetBytes("RIFF"));
		writer.Write(0); // placeholder for RIFF chunk size
		writer.Write(Encoding.ASCII.GetBytes("WAVE"));

		writer.Write(Encoding.ASCII.GetBytes("fmt "));
		writer.Write(16); // PCM header size
		writer.Write((short)1); // PCM format
		writer.Write((short)channels);
		writer.Write(sampleRate);
		writer.Write(sampleRate * channels * 2); // byte rate
		writer.Write((short)(channels * 2)); // block align
		writer.Write((short)16); // bits per sample

		writer.Write(Encoding.ASCII.GetBytes("data"));
		writer.Write(0); // placeholder for data size

		long dataStart = writer.BaseStream.Position;

		// Write PCM samples
		writeSamples(writer);

		long dataEnd = writer.BaseStream.Position;
		int dataSize = (int)(dataEnd - dataStart);

		// Patch data size
		writer.Seek((int)(dataStart - 4), SeekOrigin.Begin);
		writer.Write(dataSize);

		// Patch RIFF size
		writer.Seek(4, SeekOrigin.Begin);
		writer.Write(dataSize + 36);
	}


	private void FixWavHeader(string path, int totalSamples, int channels, int sampleRate)
	{
		int dataSize = totalSamples * 2;

		using var writer = new BinaryWriter(File.Open(path, FileMode.Open, System.IO.FileAccess.Write));

		writer.Seek(4, SeekOrigin.Begin);
		writer.Write(dataSize + 36);

		writer.Seek(40, SeekOrigin.Begin);
		writer.Write(dataSize);
	}

	private static short FloatToPcm16(float f)
	{
		if (float.IsNaN(f)) return 0;
		if (f > 1.0f) f = 1.0f;
		if (f < -1.0f) f = -1.0f;
		return (short)MathF.Round(f * 32767f);
	}


	private string AbsoluteToUserPath(string absolutePath)
	{
		string userRoot = ProjectSettings.GlobalizePath("user://");

		if (!absolutePath.StartsWith(userRoot))
			return absolutePath; // fallback

		string relative = absolutePath.Substring(userRoot.Length).TrimStart('/');
		return "user://" + relative;
	}




	// ------------------------------------------------------------
	// Cleanup
	// ------------------------------------------------------------
	public void CleanupConvertedFiles()
	{
		if (!Directory.Exists(_outputDir))
			return;

		foreach (string file in Directory.GetFiles(_outputDir, "*.wav"))
		{
			try { File.Delete(file); }
			catch (Exception ex)
			{
				GD.PushError($"Failed to delete {file}: {ex.Message}");
			}
		}
	}
}
