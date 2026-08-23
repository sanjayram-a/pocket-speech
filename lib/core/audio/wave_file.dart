import 'dart:io';
import 'dart:typed_data';

class WaveFileMetadata {
  const WaveFileMetadata({
    required this.durationMs,
    required this.sampleRate,
    required this.channels,
  });

  final int durationMs;
  final int sampleRate;
  final int channels;
}

class WaveSamples {
  const WaveSamples(this.samples, this.sampleRate);

  final Float32List samples;
  final int sampleRate;
}

/// Reads mono PCM16 WAV data as normalized float samples in [-1, 1].
Future<WaveSamples?> readMonoWaveSamples(File file) async {
  RandomAccessFile? input;
  try {
    input = await file.open();
    final length = await input.length();
    if (length < 44) return null;
    final riff = await input.read(12);
    if (_fourCc(riff, 0) != 'RIFF' || _fourCc(riff, 8) != 'WAVE') return null;

    var sampleRate = 0;
    var channels = 0;
    var bitsPerSample = 0;
    var dataBytes = 0;
    var dataOffset = -1;
    var position = 12;
    while (position + 8 <= length) {
      await input.setPosition(position);
      final header = await input.read(8);
      if (header.length != 8) return null;
      final chunkId = _fourCc(header, 0);
      final chunkSize = ByteData.sublistView(
        Uint8List.fromList(header),
      ).getUint32(4, Endian.little);
      final contentStart = position + 8;
      if (contentStart + chunkSize > length) return null;

      if (chunkId == 'fmt ' && chunkSize >= 16) {
        final format = await input.read(16);
        final bytes = ByteData.sublistView(Uint8List.fromList(format));
        channels = bytes.getUint16(2, Endian.little);
        sampleRate = bytes.getUint32(4, Endian.little);
        bitsPerSample = bytes.getUint16(14, Endian.little);
      } else if (chunkId == 'data') {
        dataBytes = chunkSize;
        dataOffset = contentStart;
      }
      if (dataOffset >= 0 && sampleRate > 0 && bitsPerSample > 0) break;
      position = contentStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }
    if (sampleRate <= 0 ||
        channels != 1 ||
        bitsPerSample != 16 ||
        dataBytes <= 0 ||
        dataOffset < 0) {
      return null;
    }

    await input.setPosition(dataOffset);
    final pcm = await input.read(dataBytes);
    final bytes = ByteData.sublistView(Uint8List.fromList(pcm));
    final frameCount = dataBytes ~/ 2;
    final samples = Float32List(frameCount);
    for (var i = 0; i < frameCount; i++) {
      samples[i] = bytes.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return WaveSamples(samples, sampleRate);
  } on FileSystemException {
    return null;
  } finally {
    await input?.close();
  }
}

/// Writes normalized mono float samples as a canonical PCM16 WAV file.
Future<void> writeMonoWaveFile(
  File file,
  Float32List samples,
  int sampleRate,
) async {
  final dataBytes = samples.length * 2;
  final bytes = Uint8List(44 + dataBytes);
  final header = ByteData.sublistView(bytes);
  void fourCc(int offset, String value) =>
      bytes.setRange(offset, offset + 4, value.codeUnits);

  fourCc(0, 'RIFF');
  header.setUint32(4, 36 + dataBytes, Endian.little);
  fourCc(8, 'WAVE');
  fourCc(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  fourCc(36, 'data');
  header.setUint32(40, dataBytes, Endian.little);

  final data = ByteData.sublistView(bytes, 44);
  for (var i = 0; i < samples.length; i++) {
    final clamped = samples[i].clamp(-1.0, 1.0).toDouble();
    data.setInt16(i * 2, (clamped * 32767).round(), Endian.little);
  }
  final temporary = File('${file.path}.tmp');
  await temporary.writeAsBytes(bytes, flush: true);
  if (await file.exists()) await file.delete();
  await temporary.rename(file.path);
}

Future<WaveFileMetadata?> readWaveFileMetadata(File file) async {
  RandomAccessFile? input;
  try {
    input = await file.open();
    final length = await input.length();
    if (length < 44) return null;
    final riff = await input.read(12);
    if (_fourCc(riff, 0) != 'RIFF' || _fourCc(riff, 8) != 'WAVE') return null;

    var sampleRate = 0;
    var channels = 0;
    var byteRate = 0;
    var dataBytes = 0;
    var position = 12;
    while (position + 8 <= length) {
      await input.setPosition(position);
      final header = await input.read(8);
      if (header.length != 8) return null;
      final chunkId = _fourCc(header, 0);
      final chunkSize = ByteData.sublistView(
        Uint8List.fromList(header),
      ).getUint32(4, Endian.little);
      final contentStart = position + 8;
      if (contentStart + chunkSize > length) return null;

      if (chunkId == 'fmt ' && chunkSize >= 16) {
        final format = await input.read(16);
        final bytes = ByteData.sublistView(Uint8List.fromList(format));
        channels = bytes.getUint16(2, Endian.little);
        sampleRate = bytes.getUint32(4, Endian.little);
        byteRate = bytes.getUint32(8, Endian.little);
      } else if (chunkId == 'data') {
        dataBytes = chunkSize;
      }
      if (byteRate > 0 && dataBytes > 0) break;
      position = contentStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }
    if (sampleRate <= 0 || channels <= 0 || byteRate <= 0 || dataBytes <= 0) {
      return null;
    }
    return WaveFileMetadata(
      durationMs: (dataBytes * Duration.millisecondsPerSecond) ~/ byteRate,
      sampleRate: sampleRate,
      channels: channels,
    );
  } on FileSystemException {
    return null;
  } finally {
    await input?.close();
  }
}

String _fourCc(List<int> bytes, int offset) =>
    String.fromCharCodes(bytes.skip(offset).take(4));
