import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_speech/features/generation/audio_post_processor.dart';

void main() {
  test('removes a short noise burst after sustained trailing quiet', () {
    const sampleRate = 1000;
    final samples = Float32List.fromList([
      ...List<double>.filled(1000, 0.2),
      ...List<double>.filled(100, 0.001),
      ...List<double>.filled(40, 0.08),
    ]);

    final cleaned = cleanGeneratedAudioTail(samples, sampleRate: sampleRate);

    expect(cleaned.length, 1030);
    expect(cleaned.last, 0);
  });

  test('trims excess quiet and fades the retained tail', () {
    const sampleRate = 1000;
    final samples = Float32List.fromList([
      ...List<double>.filled(1000, 0.2),
      ...List<double>.filled(200, 0.001),
    ]);

    final cleaned = cleanGeneratedAudioTail(samples, sampleRate: sampleRate);

    expect(cleaned.length, 1030);
    expect(cleaned.last, 0);
  });

  test('keeps speech length when no trailing quiet region exists', () {
    final samples = Float32List.fromList(List<double>.filled(1000, 0.2));

    final cleaned = cleanGeneratedAudioTail(samples, sampleRate: 1000);

    expect(cleaned.length, samples.length);
    expect(cleaned.last, 0);
  });

  test('appends digital silence when trailing silence is requested', () {
    const sampleRate = 1000;
    final samples = Float32List.fromList(List<double>.filled(1000, 0.2));

    final cleaned = cleanGeneratedAudioTail(
      samples,
      sampleRate: sampleRate,
      trailingSilenceMs: 80,
    );

    expect(cleaned.length, samples.length + 80);
    expect(cleaned.last, 0);
    // The padded region must be pure digital silence.
    for (var i = samples.length; i < cleaned.length; i++) {
      expect(cleaned[i], 0);
    }
  });
}
