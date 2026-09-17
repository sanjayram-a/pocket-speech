import 'dart:math' as math;
import 'dart:typed_data';

Float32List cleanGeneratedAudioTail(
  Float32List samples, {
  required int sampleRate,
  int trailingSilenceMs = 0,
}) {
  if (samples.isEmpty || sampleRate <= 0) return samples;

  final frameSize = math.max(1, sampleRate ~/ 100);
  final searchStart = math.max(0, samples.length - sampleRate ~/ 2);
  final minimumQuietSamples = sampleRate * 80 ~/ 1000;
  final maximumTrailingBurst = sampleRate * 80 ~/ 1000;
  final retainedQuietSamples = sampleRate * 30 ~/ 1000;
  const quietMeanSquare = 0.0001; // Approximately -40 dBFS RMS.

  int? quietStart;
  int? trimAt;
  for (var start = searchStart; start < samples.length; start += frameSize) {
    final end = math.min(start + frameSize, samples.length);
    var squareSum = 0.0;
    for (var i = start; i < end; i++) {
      squareSum += samples[i] * samples[i];
    }
    final quiet = squareSum / (end - start) <= quietMeanSquare;
    if (quiet) {
      quietStart ??= start;
      continue;
    }
    if (quietStart != null &&
        start - quietStart >= minimumQuietSamples &&
        samples.length - start <= maximumTrailingBurst) {
      trimAt = quietStart + retainedQuietSamples;
    }
    quietStart = null;
  }
  if (quietStart != null &&
      samples.length - quietStart >= minimumQuietSamples) {
    trimAt = quietStart + retainedQuietSamples;
  }

  final outputLength = math.min(trimAt ?? samples.length, samples.length);
  final output = Float32List.sublistView(samples, 0, outputLength);
  final fadeSamples = math.min(sampleRate * 30 ~/ 1000, output.length);
  for (var i = 0; i < fadeSamples; i++) {
    final index = output.length - fadeSamples + i;
    output[index] *= (fadeSamples - i - 1) / fadeSamples;
  }

  // Digital-silence padding gives the device audio sink room to wind down
  // without an end-of-stream pop during in-app playback.
  final silenceSamples = sampleRate * trailingSilenceMs ~/ 1000;
  if (silenceSamples <= 0) return Float32List.fromList(output);
  final padded = Float32List(output.length + silenceSamples);
  padded.setRange(0, output.length, output);
  return padded;
}

/// Trims low-energy edges from a reference recording. The head is cut but\n/// never faded, and the tail fades out.
///
/// Kyutai documents that Pocket TTS reproduces reference noise faithfully, so
/// breaths and room noise at the recording's edges become artifacts in every
/// generated clip. This keeps only the padded speech region.
Float32List trimReferenceEdges(Float32List samples, {required int sampleRate}) {
  if (samples.isEmpty || sampleRate <= 0) return samples;

  const loudMeanSquare = 0.00025; // Approximately -36 dBFS RMS.
  final frameSize = math.max(1, sampleRate ~/ 100);
  final pad = sampleRate * 150 ~/ 1000;
  final maximumEdgeTrim = sampleRate * 3;
  final frameCount = samples.length ~/ frameSize;
  if (frameCount == 0) return samples;

  var firstLoudFrame = -1;
  var lastLoudFrame = -1;
  for (var frame = 0; frame < frameCount; frame++) {
    var squareSum = 0.0;
    final start = frame * frameSize;
    final end = math.min(start + frameSize, samples.length);
    for (var i = start; i < end; i++) {
      squareSum += samples[i] * samples[i];
    }
    if (squareSum / (end - start) > loudMeanSquare) {
      if (firstLoudFrame < 0) firstLoudFrame = frame;
      lastLoudFrame = frame;
    }
  }
  if (firstLoudFrame < 0) return Float32List(0);

  final trimStart = math.min(
    math.max(firstLoudFrame * frameSize - pad, 0),
    maximumEdgeTrim,
  );
  final desiredEnd = math.min(
    (lastLoudFrame + 1) * frameSize + pad,
    samples.length,
  );
  // Never remove more than maximumEdgeTrim of trailing material.
  final trimEnd = math.max(desiredEnd, samples.length - maximumEdgeTrim);

  final output = Float32List.fromList(
    samples.sublist(trimStart, math.min(trimEnd, samples.length)),
  );
  // Fade-out only; the start must remain untouched so the first phoneme is
  // never softened or clipped.
  final fadeSamples = math.min(sampleRate * 20 ~/ 1000, output.length);
  for (var i = 0; i < fadeSamples; i++) {
    final tailIndex = output.length - fadeSamples + i;
    output[tailIndex] *= (fadeSamples - i - 1) / fadeSamples;
  }
  return output;
}
