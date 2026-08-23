import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../core/audio/hash_file.dart';
import '../../core/audio/wave_file.dart';
import '../../core/model/pocket_tts_model.dart'
    show HttpModelArchiveDownloader, ModelArchiveDownloader;

/// A native Pocket TTS voice, identified by the same voice ID used by the
/// official `pocket-tts` CLI (`--voice alba` etc.). sherpa-onnx has no
/// embedding (.safetensors) support, so we ship the exact source recordings
/// that Kyutai derived those embeddings from.
class BuiltinVoice {
  const BuiltinVoice({
    required this.id,
    required this.label,
    required this.remotePath,
    required this.bytes,
    required this.sha256,
    required this.license,
  });

  final String id;
  final String label;
  final String remotePath;
  final int bytes;
  final String sha256;
  final String license;

  Uri get uri => Uri.parse(
    'https://huggingface.co/kyutai/tts-voices/resolve/main/$remotePath',
  );
}

const builtinVoiceCatalog = <BuiltinVoice>[
  BuiltinVoice(
    id: 'alba',
    label: 'Alba',
    remotePath: 'alba-mackenna/casual.wav',
    bytes: 958542,
    sha256: '46264e83cb99115c3d210260e029117566d9c64f20266d10daa78107759ede3e',
    license: 'CC BY 4.0',
  ),
  BuiltinVoice(
    id: 'javert',
    label: 'Javert',
    remotePath: 'voice-donations/Butter.wav',
    bytes: 480044,
    sha256: 'b889e080eec3efa824bddaf875b4f531d75464f88128d08941ae648d9d3ade70',
    license: 'CC0',
  ),
  BuiltinVoice(
    id: 'bill_boerst',
    label: 'Bill Boerst',
    remotePath: 'voice-zero/bill_boerst.wav',
    bytes: 955496,
    sha256: 'be4815e4fb760ba1b78117545a260cce4a4c124c7657bc5c6127a0fef8ba661f',
    license: 'CC0 (LibriVox)',
  ),
  BuiltinVoice(
    id: 'caro_davy',
    label: 'Caro Davy',
    remotePath: 'voice-zero/caro_davy.wav',
    bytes: 743528,
    sha256: '40c692c005a0268a7a5b6ebae348077d3dca6a86eb6b12bd36e343bbcd71b5f6',
    license: 'CC0 (LibriVox)',
  ),
  BuiltinVoice(
    id: 'fantine',
    label: 'Fantine',
    remotePath: 'vctk/p244_023_enhanced.wav',
    bytes: 674852,
    sha256: '5f07d4e2a3f20a15572aae885156b43ef3fc12ef3812996fd135680d9956448b',
    license: 'CC BY 4.0 (VCTK)',
  ),
];

class InstalledBuiltinVoice {
  const InstalledBuiltinVoice({
    required this.voice,
    required this.path,
    required this.durationMs,
    required this.sampleRate,
  });

  final BuiltinVoice voice;
  final String path;
  final int durationMs;
  final int sampleRate;

  String get selectId => 'builtin:${voice.id}';
}

class BuiltinVoiceException implements Exception {
  const BuiltinVoiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BuiltinVoiceRepository {
  BuiltinVoiceRepository({
    required Directory supportDirectory,
    ModelArchiveDownloader? downloader,
    this.catalog = builtinVoiceCatalog,
  }) : _directory = Directory(
         path.join(supportDirectory.path, 'builtin_voices'),
       ),
       _downloader = downloader ?? const HttpModelArchiveDownloader();

  final Directory _directory;
  final ModelArchiveDownloader _downloader;
  final List<BuiltinVoice> catalog;

  File _fileFor(BuiltinVoice voice) =>
      File(path.join(_directory.path, '${voice.id}.wav'));

  /// Voices that are present with the exact pinned byte count and digest.
  Future<List<InstalledBuiltinVoice>> installed() async {
    if (!await _directory.exists()) return const [];
    final installed = <InstalledBuiltinVoice>[];
    for (final voice in catalog) {
      final file = _fileFor(voice);
      if (!await _isValid(file, voice)) continue;
      final metadata = await readWaveFileMetadata(file);
      if (metadata == null) continue;
      installed.add(
        InstalledBuiltinVoice(
          voice: voice,
          path: file.path,
          durationMs: metadata.durationMs,
          sampleRate: metadata.sampleRate,
        ),
      );
    }
    return installed;
  }

  Future<bool> _isValid(File file, BuiltinVoice voice) async {
    if (!await file.exists() || await file.length() != voice.bytes) {
      return false;
    }
    return await sha256FilePath(file.path) == voice.sha256;
  }

  /// Downloads any missing voices, verifying each against its pinned size and
  /// SHA-256 before atomic activation. Safe to call repeatedly.
  Future<List<InstalledBuiltinVoice>> ensureInstalled({
    void Function(int completedFiles, int totalFiles)? onFileProgress,
    void Function(double overall)? onOverallProgress,
  }) async {
    await _directory.create(recursive: true);
    var index = 0;
    for (final voice in catalog) {
      index += 1;
      onFileProgress?.call(index, catalog.length);
      final target = _fileFor(voice);
      if (await _isValid(target, voice)) {
        continue;
      }
      final partial = File('${target.path}.part');
      try {
        await _downloader.download(
          source: voice.uri,
          destination: partial,
          expectedBytes: voice.bytes,
          onProgress: (downloaded, total) {},
        );
        final digest = await sha256FilePath(partial.path);
        if (digest != voice.sha256) {
          await partial.delete();
          throw BuiltinVoiceException(
            '${voice.label} failed its integrity check and will retry.',
          );
        }
        if (await target.exists()) await target.delete();
        await partial.rename(target.path);
      } on BuiltinVoiceException {
        rethrow;
      } on Object {
        if (await partial.exists()) await partial.delete();
        throw BuiltinVoiceException(
          'Built-in voices could not be downloaded. Check your connection '
          'and try again.',
        );
      }
      onOverallProgress?.call(index / catalog.length);
    }
    return installed();
  }

  Future<void> remove() async {
    if (await _directory.exists()) {
      await _directory.delete(recursive: true);
    }
  }
}

final builtinVoiceRepositoryProvider = Provider<BuiltinVoiceRepository>((ref) {
  throw StateError('BuiltinVoiceRepository must be supplied at bootstrap.');
});

final builtinVoicesProvider = FutureProvider<List<InstalledBuiltinVoice>>((
  ref,
) async {
  // Silent best-effort: downloads run in the background whenever the picker
  // is visible; failures surface only as an empty list until retried.
  final repository = ref.watch(builtinVoiceRepositoryProvider);
  try {
    return await repository.ensureInstalled();
  } on BuiltinVoiceException {
    return repository.installed();
  }
});
