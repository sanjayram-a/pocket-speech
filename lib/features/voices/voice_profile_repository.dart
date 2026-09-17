import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../app/preferences.dart';
import '../../core/audio/wave_file.dart';
import '../generation/audio_post_processor.dart';

const minimumReferenceDuration = Duration(seconds: 5);
const maximumReferenceDuration = Duration(seconds: 12);

class VoiceProfile {
  const VoiceProfile({
    required this.id,
    required this.name,
    required this.referencePath,
    required this.durationMs,
    required this.sampleRate,
    required this.createdAt,
  });

  factory VoiceProfile.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final referencePath = json['reference_path'];
    final durationMs = json['duration_ms'];
    final sampleRate = json['sample_rate'];
    final createdAt = json['created_at'];
    if (id is! String ||
        name is! String ||
        referencePath is! String ||
        durationMs is! int ||
        sampleRate is! int ||
        createdAt is! String) {
      throw const FormatException('Invalid Voice Profile metadata.');
    }
    final timestamp = DateTime.tryParse(createdAt);
    if (timestamp == null) {
      throw const FormatException('Invalid Voice Profile timestamp.');
    }
    return VoiceProfile(
      id: id,
      name: name,
      referencePath: referencePath,
      durationMs: durationMs,
      sampleRate: sampleRate,
      createdAt: timestamp,
    );
  }

  final String id;
  final String name;
  final String referencePath;
  final int durationMs;
  final int sampleRate;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'reference_path': referencePath,
    'duration_ms': durationMs,
    'sample_rate': sampleRate,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

class VoiceProfileException implements Exception {
  const VoiceProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Denoises a reference recording and returns the cleaned file path.
///
/// Currently a pass-through; wire an RNNoise-based implementation here later.
/// Note: cargokit-based native plugins (e.g. flutter_nnnoiseless) currently
/// fail on Gradle 9 because bundled cargokit uses removed project.exec API.
typedef ReferenceDenoiser = Future<String> Function(String inputPath);

class VoiceProfileRepository {
  VoiceProfileRepository({
    required Directory supportDirectory,
    ReferenceDenoiser? denoiser,
  }) : _voicesDirectory = Directory(path.join(supportDirectory.path, 'voices')),
       _denoiser = denoiser ?? _passThroughDenoise;

  final Directory _voicesDirectory;
  final ReferenceDenoiser _denoiser;

  File get _metadataFile =>
      File(path.join(_voicesDirectory.path, 'profiles.json'));

  Future<List<VoiceProfile>> load() async {
    if (!await _metadataFile.exists()) return const [];
    try {
      final decoded = jsonDecode(await _metadataFile.readAsString());
      if (decoded is! List<Object?>) throw const FormatException();
      final profiles =
          decoded
              .map(
                (item) => VoiceProfile.fromJson(item! as Map<String, Object?>),
              )
              .where((profile) => File(profile.referencePath).existsSync())
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (profiles.length != decoded.length) await _write(profiles);
      return profiles;
    } on VoiceProfileException {
      rethrow;
    } on Object {
      throw const VoiceProfileException('Voice Profiles could not be opened.');
    }
  }

  Future<String> createRecordingPath() async {
    final temp = Directory(path.join(_voicesDirectory.path, '.recording'));
    await temp.create(recursive: true);
    return path.join(
      temp.path,
      'reference-${DateTime.now().microsecondsSinceEpoch}.wav',
    );
  }

  Future<VoiceProfile> saveRecording({
    required String name,
    required String temporaryPath,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanName.length > 40) {
      throw const VoiceProfileException(
        'Enter a Voice Profile name up to 40 characters.',
      );
    }
    final source = File(temporaryPath);
    final metadata = await readWaveFileMetadata(source);
    if (metadata == null || metadata.channels != 1) {
      throw const VoiceProfileException(
        'The reference must be a valid mono WAV recording.',
      );
    }

    // Kyutai Pocket TTS reproduces reference noise faithfully: denoise with
    // RNNoise, then trim edge breaths/room noise so generated clips do not
    // start or end with artifacts from the recording.
    String effectivePath = temporaryPath;
    try {
      effectivePath = await _denoiser(temporaryPath);
    } on Object {
      effectivePath = temporaryPath;
    }
    final denoised = File(effectivePath);
    try {
      final wave = await readMonoWaveSamples(denoised);
      if (wave == null) {
        throw const VoiceProfileException(
          'The reference must be a valid mono WAV recording.',
        );
      }
      final cleaned = trimReferenceEdges(
        wave.samples,
        sampleRate: wave.sampleRate,
      );
      final cleanedDurationMs =
          cleaned.length * Duration.millisecondsPerSecond ~/ wave.sampleRate;
      if (cleanedDurationMs < minimumReferenceDuration.inMilliseconds ||
          cleanedDurationMs > maximumReferenceDuration.inMilliseconds + 250) {
        throw const VoiceProfileException(
          'Record between 5 and 12 seconds of speech.',
        );
      }

      final createdAt = DateTime.now();
      final id = createdAt.microsecondsSinceEpoch.toString();
      final profileDirectory = Directory(path.join(_voicesDirectory.path, id));
      await profileDirectory.create(recursive: true);
      final destination = File(
        path.join(profileDirectory.path, 'reference.wav'),
      );
      try {
        await writeMonoWaveFile(destination, cleaned, wave.sampleRate);
        final profile = VoiceProfile(
          id: id,
          name: cleanName,
          referencePath: destination.path,
          durationMs: cleanedDurationMs,
          sampleRate: wave.sampleRate,
          createdAt: createdAt,
        );
        final profiles = await load();
        await _write([profile, ...profiles]);
        return profile;
      } on VoiceProfileException {
        await _deleteDirectory(profileDirectory);
        rethrow;
      } on Object {
        await _deleteDirectory(profileDirectory);
        throw const VoiceProfileException(
          'The Voice Profile could not be saved. Check available storage.',
        );
      }
    } finally {
      if (effectivePath != temporaryPath) {
        await discardRecording(effectivePath);
      }
      await discardRecording(temporaryPath);
    }
  }

  Future<void> delete(VoiceProfile profile) async {
    final profiles = await load();
    await _deleteDirectory(File(profile.referencePath).parent);
    await _write(profiles.where((item) => item.id != profile.id).toList());
  }

  Future<VoiceProfile> rename(VoiceProfile profile, String newName) async {
    final cleanName = newName.trim();
    if (cleanName.isEmpty || cleanName.length > 40) {
      throw const VoiceProfileException(
        'Enter a Voice Profile name up to 40 characters.',
      );
    }
    final profiles = await load();
    final index = profiles.indexWhere((item) => item.id == profile.id);
    if (index == -1) {
      throw const VoiceProfileException('Voice Profile not found.');
    }
    final updated = VoiceProfile(
      id: profile.id,
      name: cleanName,
      referencePath: profile.referencePath,
      durationMs: profile.durationMs,
      sampleRate: profile.sampleRate,
      createdAt: profile.createdAt,
    );
    final next = [...profiles];
    next[index] = updated;
    await _write(next);
    return updated;
  }

  Future<void> discardRecording(String? recordingPath) async {
    if (recordingPath == null) return;
    final file = File(recordingPath);
    if (await file.exists()) await file.delete();
  }

  Future<void> _write(List<VoiceProfile> profiles) async {
    try {
      await _voicesDirectory.create(recursive: true);
      final temporary = File('${_metadataFile.path}.tmp');
      await temporary.writeAsString(
        jsonEncode(profiles.map((profile) => profile.toJson()).toList()),
        flush: true,
      );
      if (await _metadataFile.exists()) await _metadataFile.delete();
      await temporary.rename(_metadataFile.path);
    } on FileSystemException {
      throw const VoiceProfileException('Voice Profiles could not be saved.');
    }
  }

  Future<void> _deleteDirectory(Directory directory) async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

Future<String> _passThroughDenoise(String inputPath) async => inputPath;

final voiceProfileRepositoryProvider = Provider<VoiceProfileRepository>((ref) {
  throw StateError('VoiceProfileRepository must be supplied at bootstrap.');
});

final voiceProfilesProvider = FutureProvider<List<VoiceProfile>>((ref) {
  return ref.watch(voiceProfileRepositoryProvider).load();
});

const _selectedVoiceIdKey = 'selected_voice_profile_id';

class SelectedVoiceController extends Notifier<String?> {
  @override
  String? build() {
    final value = ref
        .watch(appPreferencesProvider)
        .getString(_selectedVoiceIdKey);
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> select(String? id) async {
    state = id;
    await ref
        .read(appPreferencesProvider)
        .setString(_selectedVoiceIdKey, id ?? '');
  }
}

final selectedVoiceIdProvider =
    NotifierProvider<SelectedVoiceController, String?>(
      SelectedVoiceController.new,
    );
