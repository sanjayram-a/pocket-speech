import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_speech/features/voices/voice_profile_repository.dart';

void main() {
  late Directory supportDirectory;
  late VoiceProfileRepository repository;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'voice-profile-test-',
    );
    repository = VoiceProfileRepository(
      supportDirectory: supportDirectory,
      denoiser: (inputPath) async => inputPath,
    );
  });

  tearDown(() async {
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test('moves a valid mono WAV into a persistent Voice Profile', () async {
    final temporaryPath = await repository.createRecordingPath();
    await File(
      temporaryPath,
    ).writeAsBytes(_wave(sampleRate: 24000, channels: 1, seconds: 5));

    final profile = await repository.saveRecording(
      name: 'My voice',
      temporaryPath: temporaryPath,
    );

    expect(profile.name, 'My voice');
    expect(profile.durationMs, 5000);
    expect(profile.sampleRate, 24000);
    expect(await File(profile.referencePath).exists(), isTrue);
    expect(await File(temporaryPath).exists(), isFalse);
    expect(await repository.load(), hasLength(1));
  });

  test('rejects recordings shorter than five seconds', () async {
    final temporaryPath = await repository.createRecordingPath();
    await File(
      temporaryPath,
    ).writeAsBytes(_wave(sampleRate: 24000, channels: 1, seconds: 4));

    await expectLater(
      repository.saveRecording(name: 'Too short', temporaryPath: temporaryPath),
      throwsA(isA<VoiceProfileException>()),
    );
  });

  test('deletes the reference recording and profile metadata', () async {
    final temporaryPath = await repository.createRecordingPath();
    await File(
      temporaryPath,
    ).writeAsBytes(_wave(sampleRate: 24000, channels: 1, seconds: 5));
    final profile = await repository.saveRecording(
      name: 'Delete me',
      temporaryPath: temporaryPath,
    );

    await repository.delete(profile);

    expect(await File(profile.referencePath).exists(), isFalse);
    expect(await repository.load(), isEmpty);
  });

  test('uses the denoised file when the denoiser produces one', () async {
    final calls = <String>[];
    final denoisingRepository = VoiceProfileRepository(
      supportDirectory: supportDirectory,
      denoiser: (inputPath) async {
        calls.add(inputPath);
        final output = '$inputPath.denoised.wav';
        await File(
          output,
        ).writeAsBytes(_wave(sampleRate: 24000, channels: 1, seconds: 5));
        return output;
      },
    );
    final temporaryPath = await denoisingRepository.createRecordingPath();
    await File(
      temporaryPath,
    ).writeAsBytes(_wave(sampleRate: 24000, channels: 1, seconds: 5));

    final profile = await denoisingRepository.saveRecording(
      name: 'Denoised',
      temporaryPath: temporaryPath,
    );

    expect(calls, [temporaryPath]);
    expect(profile.durationMs, 5000);
    expect(await File(temporaryPath).exists(), isFalse);
  });
}

Uint8List _wave({
  required int sampleRate,
  required int channels,
  required int seconds,
}) {
  final dataBytes = sampleRate * channels * 2 * seconds;
  final bytes = Uint8List(44 + dataBytes);
  final data = ByteData.sublistView(bytes);
  void fourCc(int offset, String value) {
    bytes.setRange(offset, offset + 4, value.codeUnits);
  }

  fourCc(0, 'RIFF');
  data.setUint32(4, 36 + dataBytes, Endian.little);
  fourCc(8, 'WAVE');
  fourCc(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * channels * 2, Endian.little);
  data.setUint16(32, channels * 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  fourCc(36, 'data');
  data.setUint32(40, dataBytes, Endian.little);
  // Fill with a -14 dBFS-ish tone so the fixture contains real "speech".
  const amplitude = 0.2;
  for (var i = 0; i < dataBytes ~/ 2; i++) {
    data.setInt16(
      44 + i * 2,
      (amplitude * 32767 * (i % 48 < 24 ? 1 : -1)).round(),
      Endian.little,
    );
  }
  return bytes;
}
