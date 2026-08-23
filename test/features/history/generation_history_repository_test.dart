import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pocket_speech/features/history/generation_history_repository.dart';

void main() {
  late Directory supportDirectory;
  late GenerationHistoryRepository repository;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'generation-history-test-',
    );
    repository = GenerationHistoryRepository(
      supportDirectory: supportDirectory,
    );
  });

  tearDown(() async {
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test('persists generated audio metadata without input text', () async {
    final audio = File(path.join(supportDirectory.path, 'result.wav'));
    await audio.writeAsBytes(const [1, 2, 3]);
    final record = GenerationRecord(
      id: 'generation-1',
      audioPath: audio.path,
      durationMs: 1200,
      sampleRate: 24000,
      createdAt: DateTime.utc(2026, 8, 22, 10, 30),
    );

    await repository.add(record);

    final loaded = await repository.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.id, record.id);
    final metadata = await File(
      path.join(supportDirectory.path, 'generations', 'history.json'),
    ).readAsString();
    expect(metadata, isNot(contains('generated text')));
  });

  test('reconciles metadata when an audio file is missing', () async {
    final audio = File(path.join(supportDirectory.path, 'missing.wav'));
    await audio.writeAsBytes(const [1]);
    await repository.add(
      GenerationRecord(
        id: 'generation-1',
        audioPath: audio.path,
        durationMs: 1000,
        sampleRate: 24000,
        createdAt: DateTime.utc(2026, 8, 22),
      ),
    );
    await audio.delete();

    expect(await repository.load(), isEmpty);
  });

  test('deletes the audio file and its metadata', () async {
    final audio = File(path.join(supportDirectory.path, 'delete.wav'));
    await audio.writeAsBytes(const [1]);
    final record = GenerationRecord(
      id: 'generation-1',
      audioPath: audio.path,
      durationMs: 1000,
      sampleRate: 24000,
      createdAt: DateTime.utc(2026, 8, 22),
    );
    await repository.add(record);

    await repository.delete(record);

    expect(await audio.exists(), isFalse);
    expect(await repository.load(), isEmpty);
  });

  test('recovers an untracked generated WAV into history', () async {
    final directory = Directory(
      path.join(supportDirectory.path, 'generations'),
    );
    await directory.create(recursive: true);
    final audio = File(path.join(directory.path, 'generation-existing.wav'));
    await audio.writeAsBytes(_wave(sampleRate: 24000, samples: 24000));

    final records = await repository.load();

    expect(records, hasLength(1));
    expect(records.single.id, 'generation-existing');
    expect(records.single.durationMs, 1000);
    expect(records.single.sampleRate, 24000);
  });

  test(
    'replaces a recovered row when generation metadata is committed',
    () async {
      final directory = Directory(
        path.join(supportDirectory.path, 'generations'),
      );
      await directory.create(recursive: true);
      final audio = File(path.join(directory.path, 'generation-existing.wav'));
      await audio.writeAsBytes(_wave(sampleRate: 24000, samples: 24000));
      expect(await repository.load(), hasLength(1));

      await repository.add(
        GenerationRecord(
          id: 'committed-id',
          audioPath: audio.path,
          durationMs: 1000,
          sampleRate: 24000,
          createdAt: DateTime.utc(2026, 8, 22),
        ),
      );

      final records = await repository.load();
      expect(records, hasLength(1));
      expect(records.single.id, 'committed-id');
    },
  );
}

Uint8List _wave({required int sampleRate, required int samples}) {
  final dataBytes = samples * 2;
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
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  fourCc(36, 'data');
  data.setUint32(40, dataBytes, Endian.little);
  return bytes;
}
