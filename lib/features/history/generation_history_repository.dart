import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../core/audio/wave_file.dart';

class GenerationRecord {
  const GenerationRecord({
    required this.id,
    required this.audioPath,
    required this.durationMs,
    required this.sampleRate,
    required this.createdAt,
  });

  factory GenerationRecord.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final audioPath = json['audio_path'];
    final durationMs = json['duration_ms'];
    final sampleRate = json['sample_rate'];
    final createdAt = json['created_at'];
    if (id is! String ||
        audioPath is! String ||
        durationMs is! int ||
        sampleRate is! int ||
        createdAt is! String) {
      throw const FormatException('Invalid generation metadata.');
    }
    final timestamp = DateTime.tryParse(createdAt);
    if (timestamp == null) {
      throw const FormatException('Invalid generation timestamp.');
    }
    return GenerationRecord(
      id: id,
      audioPath: audioPath,
      durationMs: durationMs,
      sampleRate: sampleRate,
      createdAt: timestamp,
    );
  }

  final String id;
  final String audioPath;
  final int durationMs;
  final int sampleRate;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
    'id': id,
    'audio_path': audioPath,
    'duration_ms': durationMs,
    'sample_rate': sampleRate,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

class GenerationHistoryException implements Exception {
  const GenerationHistoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GenerationHistoryRepository {
  GenerationHistoryRepository({required Directory supportDirectory})
    : _metadataFile = File(
        path.join(supportDirectory.path, 'generations', 'history.json'),
      );

  final File _metadataFile;

  Future<List<GenerationRecord>> load() async {
    try {
      final records = <GenerationRecord>[];
      if (await _metadataFile.exists()) {
        final decoded = jsonDecode(await _metadataFile.readAsString());
        if (decoded is! List<Object?>) throw const FormatException();
        records.addAll(
          decoded.map(
            (item) => GenerationRecord.fromJson(item! as Map<String, Object?>),
          ),
        );
      }

      final availableByPath = <String, GenerationRecord>{};
      for (final record in records) {
        if (await File(record.audioPath).exists()) {
          availableByPath.putIfAbsent(record.audioPath, () => record);
        }
      }
      if (await _metadataFile.parent.exists()) {
        await for (final entity in _metadataFile.parent.list()) {
          if (entity is! File ||
              path.extension(entity.path).toLowerCase() != '.wav' ||
              availableByPath.containsKey(entity.path)) {
            continue;
          }
          final recovered = await _recover(entity);
          if (recovered != null) availableByPath[entity.path] = recovered;
        }
      }
      final available = availableByPath.values.toList();
      available.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (available.length != records.length) await _write(available);
      return available;
    } on GenerationHistoryException {
      rethrow;
    } on Object {
      throw const GenerationHistoryException(
        'Saved audio history could not be opened.',
      );
    }
  }

  Future<void> add(GenerationRecord record) async {
    final records = await load();
    await _write([
      record,
      ...records.where(
        (item) => item.id != record.id && item.audioPath != record.audioPath,
      ),
    ]);
  }

  Future<void> delete(GenerationRecord record) async {
    final audio = File(record.audioPath);
    if (await audio.exists()) await audio.delete();
    final records = await load();
    await _write(records.where((item) => item.id != record.id).toList());
  }

  Future<void> _write(List<GenerationRecord> records) async {
    try {
      await _metadataFile.parent.create(recursive: true);
      final temporary = File('${_metadataFile.path}.tmp');
      await temporary.writeAsString(
        jsonEncode(records.map((record) => record.toJson()).toList()),
        flush: true,
      );
      if (await _metadataFile.exists()) await _metadataFile.delete();
      await temporary.rename(_metadataFile.path);
    } on FileSystemException {
      throw const GenerationHistoryException(
        'Generated audio history could not be saved.',
      );
    }
  }

  Future<GenerationRecord?> _recover(File file) async {
    final wave = await readWaveFileMetadata(file);
    if (wave == null) return null;
    final stat = await file.stat();
    return GenerationRecord(
      id: path.basenameWithoutExtension(file.path),
      audioPath: file.path,
      durationMs: wave.durationMs,
      sampleRate: wave.sampleRate,
      createdAt: stat.modified,
    );
  }
}

final generationHistoryRepositoryProvider =
    Provider<GenerationHistoryRepository>((ref) {
      throw StateError(
        'GenerationHistoryRepository must be supplied at bootstrap.',
      );
    });

final generationHistoryProvider = FutureProvider<List<GenerationRecord>>((ref) {
  return ref.watch(generationHistoryRepositoryProvider).load();
});
