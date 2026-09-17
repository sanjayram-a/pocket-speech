import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../app/app_controllers.dart';
import '../../core/model/pocket_tts_model.dart';
import 'audio_post_processor.dart';

class LocalGenerationResult {
  const LocalGenerationResult({
    required this.path,
    required this.duration,
    required this.elapsed,
    required this.sampleRate,
  });

  final String path;
  final Duration duration;
  final Duration elapsed;
  final int sampleRate;

  double get realTimeFactor => duration.inMicroseconds == 0
      ? 0
      : elapsed.inMicroseconds / duration.inMicroseconds;
}

class LocalTtsException implements Exception {
  const LocalTtsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalTtsService {
  Isolate? _isolate;
  SendPort? _commands;
  String? _modelDirectory;
  String? _decoderPath;
  bool _generating = false;

  Future<LocalGenerationResult> generate({
    required PocketTtsModelPaths model,
    required String text,
    required String referenceAudioPath,
    required String outputPath,
    double speed = 1.0,
    int numSteps = 5,
    double temperature = defaultGenerationTemperature,
    int sentenceChunkChars = defaultSentenceChunkChars,
    void Function(double progress)? onProgress,
  }) async {
    if (_generating) {
      throw const LocalTtsException('A generation is already running.');
    }
    if (text.trim().isEmpty) {
      throw const LocalTtsException('Enter text to generate.');
    }
    if (!await File(referenceAudioPath).exists()) {
      throw const LocalTtsException('The reference voice is unavailable.');
    }

    _generating = true;
    try {
      await _start(model);
      final replies = ReceivePort();
      _commands!.send({
        'type': 'generate',
        'reply': replies.sendPort,
        'text': text,
        'reference': referenceAudioPath,
        'output': outputPath,
        'speed': speed.clamp(0.25, 4.0).toDouble(),
        'numSteps': numSteps.clamp(1, 16),
        'temperature': temperature.clamp(0.1, 1.5).toDouble(),
        'sentenceChunkChars': sentenceChunkChars.clamp(20, 500),
      });

      await for (final Object? message in replies) {
        if (message is! Map<Object?, Object?>) continue;
        switch (message['type']) {
          case 'progress':
            final progress = message['progress'];
            if (progress is num) onProgress?.call(progress.toDouble());
          case 'complete':
            replies.close();
            return LocalGenerationResult(
              path: message['path']! as String,
              duration: Duration(microseconds: message['durationUs']! as int),
              elapsed: Duration(microseconds: message['elapsedUs']! as int),
              sampleRate: message['sampleRate']! as int,
            );
          case 'error':
            replies.close();
            throw LocalTtsException(message['message']! as String);
        }
      }
      throw const LocalTtsException('The local voice engine stopped.');
    } finally {
      _generating = false;
    }
  }

  Future<void> _start(PocketTtsModelPaths model) async {
    // Prefer the FP32 decoder whenever it has been downloaded; the isolate
    // bakes the decoder path into its engine config, so a decoder change
    // must recreate it.
    final decoderPath = await File(model.fp32Decoder).exists()
        ? model.fp32Decoder
        : model.decoder;
    if (_commands != null &&
        _modelDirectory == model.directory &&
        _decoderPath == decoderPath) {
      return;
    }
    await dispose();

    final ready = ReceivePort();
    _isolate = await Isolate.spawn(_localTtsWorker, {
      'reply': ready.sendPort,
      'modelDirectory': model.directory,
      'decoderPath': decoderPath,
    }, debugName: 'pocket-tts-worker');
    final response = await ready.first;
    ready.close();
    if (response is SendPort) {
      _commands = response;
      _modelDirectory = model.directory;
      _decoderPath = decoderPath;
      return;
    }
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    throw const LocalTtsException('The local voice engine could not start.');
  }

  Future<void> dispose() async {
    final commands = _commands;
    if (commands != null) {
      final reply = ReceivePort();
      commands.send({'type': 'dispose', 'reply': reply.sendPort});
      await reply.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      reply.close();
    }
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _commands = null;
    _modelDirectory = null;
    _decoderPath = null;
  }
}

final localTtsServiceProvider = Provider<LocalTtsService>((ref) {
  final service = LocalTtsService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

Future<void> _localTtsWorker(Map<Object?, Object?> startup) async {
  final reply = startup['reply']! as SendPort;
  sherpa.OfflineTts? tts;
  try {
    await sherpa.initBindingsAsync();
    final directory = startup['modelDirectory']! as String;
    final model = PocketTtsModelPaths(directory);
    tts = sherpa.OfflineTts(
      sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          pocket: sherpa.OfflineTtsPocketModelConfig(
            lmFlow: model.lmFlow,
            lmMain: model.lmMain,
            encoder: model.encoder,
            decoder: startup['decoderPath']! as String,
            textConditioner: model.textConditioner,
            vocabJson: model.vocabJson,
            tokenScoresJson: model.tokenScoresJson,
            voiceEmbeddingCacheCapacity: 10,
          ),
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        ),
      ),
    );
  } on Object {
    tts?.free();
    reply.send({'type': 'error'});
    return;
  }

  final commands = ReceivePort();
  reply.send(commands.sendPort);
  await for (final Object? rawMessage in commands) {
    if (rawMessage is! Map<Object?, Object?>) continue;
    final response = rawMessage['reply']! as SendPort;
    if (rawMessage['type'] == 'dispose') {
      tts.free();
      response.send({'type': 'disposed'});
      commands.close();
      return;
    }
    if (rawMessage['type'] != 'generate') continue;

    try {
      final reference = sherpa.readWave(rawMessage['reference']! as String);
      if (reference.samples.isEmpty || reference.sampleRate <= 0) {
        throw const LocalTtsException('The reference WAV could not be read.');
      }
      final stopwatch = Stopwatch()..start();
      final rawSpeed = rawMessage['speed'];
      final rawSteps = rawMessage['numSteps'];
      final rawTemperature = rawMessage['temperature'];
      final rawSentenceChunkChars = rawMessage['sentenceChunkChars'];
      final extra = <String, Object>{'max_reference_audio_len': 12};
      if (rawTemperature is num) {
        extra['temperature'] = rawTemperature.toDouble();
      }
      if (rawSentenceChunkChars is int) {
        extra['max_char_in_sentence'] = rawSentenceChunkChars;
      }
      final audio = tts.generateWithConfig(
        text: rawMessage['text']! as String,
        config: sherpa.OfflineTtsGenerationConfig(
          referenceAudio: reference.samples,
          referenceSampleRate: reference.sampleRate,
          numSteps: rawSteps is int ? rawSteps.clamp(1, 16) : 5,
          speed: rawSpeed is num ? rawSpeed.toDouble().clamp(0.25, 4.0) : 1.0,
          extra: extra,
        ),
        onProgress: (samples, progress) {
          response.send({'type': 'progress', 'progress': progress});
          return 1;
        },
      );
      stopwatch.stop();
      final cleanedSamples = cleanGeneratedAudioTail(
        audio.samples,
        sampleRate: audio.sampleRate,
        trailingSilenceMs: 80,
      );
      final output = rawMessage['output']! as String;
      final written = sherpa.writeWave(
        filename: output,
        samples: cleanedSamples,
        sampleRate: audio.sampleRate,
      );
      if (!written || cleanedSamples.isEmpty || audio.sampleRate <= 0) {
        throw const LocalTtsException('Generated audio could not be saved.');
      }
      response.send({
        'type': 'complete',
        'path': output,
        'durationUs':
            (cleanedSamples.length * Duration.microsecondsPerSecond) ~/
            audio.sampleRate,
        'elapsedUs': stopwatch.elapsedMicroseconds,
        'sampleRate': audio.sampleRate,
      });
    } on Object {
      response.send({
        'type': 'error',
        'message': 'Speech generation failed on this device.',
      });
    }
  }
}
