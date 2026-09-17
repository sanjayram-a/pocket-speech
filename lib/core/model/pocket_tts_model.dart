import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import '../../core/audio/hash_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

const pocketTtsModel = PocketTtsModelManifest(
  id: 'pocket-tts',
  version: '2026-01-26',
  archiveUri:
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/'
      'tts-models/sherpa-onnx-pocket-tts-int8-2026-01-26.tar.bz2',
  archiveBytes: 98336520,
  archiveSha256:
      '2f3b88823cbbb9bf0b2477ec8ae7b3fec417b3a87b6bb5f256dba66f2ad967cb',
  requiredFiles: {
    'lm_flow.int8.onnx',
    'lm_main.int8.onnx',
    'encoder.onnx',
    'decoder.int8.onnx',
    'text_conditioner.onnx',
    'vocab.json',
    'token_scores.json',
  },
);

/// Optional high-fidelity replacement for `decoder.int8.onnx`: the FP32 Mimi
/// decoder published alongside the same engine version. Quantizing the neural
/// audio decoder dulls high frequencies, so this file upgrades clarity at the
/// cost of a one-time ~41 MB download.
const pocketTtsFp32Decoder = PinnedModelFile(
  name: 'decoder.onnx',
  uri:
      'https://huggingface.co/csukuangfj2/sherpa-onnx-pocket-tts-2026-01-26/'
      'resolve/main/decoder.onnx',
  bytes: 41478706,
  sha256: 'f267880fde6c58b17b0a8f3647eaf8dcfad321f833f32d583ebc2fb2d1a15f10',
);

class PinnedModelFile {
  const PinnedModelFile({
    required this.name,
    required this.uri,
    required this.bytes,
    required this.sha256,
  });

  final String name;
  final String uri;
  final int bytes;
  final String sha256;
}

class PocketTtsModelManifest {
  const PocketTtsModelManifest({
    required this.id,
    required this.version,
    required this.archiveUri,
    required this.archiveBytes,
    required this.archiveSha256,
    required this.requiredFiles,
  });

  final String id;
  final String version;
  final String archiveUri;
  final int archiveBytes;
  final String archiveSha256;
  final Set<String> requiredFiles;
}

class PocketTtsModelPaths {
  const PocketTtsModelPaths(this.directory);

  final String directory;

  String file(String name) => path.join(directory, name);

  String get lmFlow => file('lm_flow.int8.onnx');
  String get lmMain => file('lm_main.int8.onnx');
  String get encoder => file('encoder.onnx');
  String get decoder => file('decoder.int8.onnx');
  String get fp32Decoder => file(pocketTtsFp32Decoder.name);
  String get textConditioner => file('text_conditioner.onnx');
  String get vocabJson => file('vocab.json');
  String get tokenScoresJson => file('token_scores.json');
  String get demoReference => file('demo_reference.wav');
}

enum ModelInstallPhase {
  checking,
  absent,
  downloading,
  verifying,
  installing,
  ready,
  failed,
}

class ModelInstallState {
  const ModelInstallState({
    required this.phase,
    this.downloadedBytes = 0,
    this.totalBytes = 98336520,
    this.paths,
    this.message,
  });

  const ModelInstallState.checking() : this(phase: ModelInstallPhase.checking);

  final ModelInstallPhase phase;
  final int downloadedBytes;
  final int totalBytes;
  final PocketTtsModelPaths? paths;
  final String? message;

  double? get progress => totalBytes <= 0
      ? null
      : (downloadedBytes / totalBytes).clamp(0, 1).toDouble();
}

class ModelInstallException implements Exception {
  const ModelInstallException(
    this.message, {
    this.detail,
    this.retryable = true,
  });

  final String message;

  /// Technical cause (exception type + OS message) for diagnostics. Contains
  /// no user content — only model installation paths and system errors.
  final String? detail;
  final bool retryable;

  @override
  String toString() => detail == null ? message : '$message\n$detail';
}

typedef DownloadProgress = void Function(int downloadedBytes, int totalBytes);

abstract interface class ModelArchiveDownloader {
  Future<void> download({
    required Uri source,
    required File destination,
    required int expectedBytes,
    required DownloadProgress onProgress,
  });
}

class HttpModelArchiveDownloader implements ModelArchiveDownloader {
  const HttpModelArchiveDownloader();

  @override
  Future<void> download({
    required Uri source,
    required File destination,
    required int expectedBytes,
    required DownloadProgress onProgress,
  }) async {
    await destination.parent.create(recursive: true);
    var existingBytes = await destination.exists()
        ? await destination.length()
        : 0;
    if (existingBytes > expectedBytes) {
      await destination.delete();
      existingBytes = 0;
    }
    if (existingBytes == expectedBytes) {
      onProgress(existingBytes, expectedBytes);
      return;
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    IOSink? sink;
    try {
      final request = await client
          .getUrl(source)
          .timeout(const Duration(seconds: 30));
      if (existingBytes > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
      }
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );

      final resumes =
          existingBytes > 0 &&
          response.statusCode == HttpStatus.partialContent &&
          _rangeStartsAt(response.headers, existingBytes);
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        await response.drain<void>();
        throw ModelInstallException(
          'The voice engine download failed with HTTP '
          '${response.statusCode}.',
        );
      }
      if (response.statusCode == HttpStatus.partialContent && !resumes) {
        await response.drain<void>();
        throw const ModelInstallException(
          'The download server returned an invalid resume response.',
        );
      }
      if (!resumes) existingBytes = 0;

      sink = destination.openWrite(
        mode: resumes ? FileMode.append : FileMode.write,
      );
      var downloadedBytes = existingBytes;
      onProgress(downloadedBytes, expectedBytes);
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        downloadedBytes += chunk.length;
        if (downloadedBytes > expectedBytes) {
          throw const ModelInstallException(
            'The voice engine download was larger than expected.',
            retryable: false,
          );
        }
        sink.add(chunk);
        onProgress(downloadedBytes, expectedBytes);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (downloadedBytes != expectedBytes) {
        throw ModelInstallException(
          'The voice engine download stopped early. '
          '${_formatMegabytes(downloadedBytes)} of '
          '${_formatMegabytes(expectedBytes)} received.',
        );
      }
    } on ModelInstallException {
      rethrow;
    } on TimeoutException {
      throw const ModelInstallException(
        'The voice engine download timed out. Try again when the connection '
        'is stable.',
      );
    } on SocketException {
      throw const ModelInstallException(
        'The voice engine could not be downloaded. Check your connection and '
        'try again.',
      );
    } on FileSystemException {
      throw const ModelInstallException(
        'The voice engine could not be written. Check available storage.',
      );
    } finally {
      await sink?.close();
      client.close(force: true);
    }
  }

  bool _rangeStartsAt(HttpHeaders headers, int expectedStart) {
    final contentRange = headers.value(HttpHeaders.contentRangeHeader);
    return contentRange?.startsWith('bytes $expectedStart-') ?? false;
  }
}

abstract interface class ModelArchiveExtractor {
  Future<void> extract(File archive, Directory destination);

  /// Removes reusable partial artifacts (e.g. a decompressed tar kept for
  /// resume) once installation has fully succeeded or been removed.
  Future<void> cleanupPartialArtifacts(File archive);
}

class TarBz2ModelArchiveExtractor implements ModelArchiveExtractor {
  const TarBz2ModelArchiveExtractor();

  @override
  Future<void> extract(File archive, Directory destination) {
    // Capture only immutable path strings so nothing unsendable can leak
    // into the isolate message.
    final paths = (archive.path, destination.path);
    return Isolate.run(() => extractPocketTtsArchiveSync(paths));
  }

  @override
  Future<void> cleanupPartialArtifacts(File archive) async {
    final tar = File(_decompressedTarPath(archive.path));
    final marker = File('${tar.path}.ok');
    if (await marker.exists()) await marker.delete();
    if (await tar.exists()) await tar.delete();
  }

  static String _decompressedTarPath(String archivePath) => '$archivePath.tar';
}

class PocketTtsModelRepository {
  PocketTtsModelRepository({
    required this.supportDirectory,
    this.manifest = pocketTtsModel,
    ModelArchiveDownloader? downloader,
    ModelArchiveExtractor? extractor,
  }) : _modelsDirectory = Directory(
         path.join(supportDirectory.path, 'models', manifest.id),
       ),
       _downloader = downloader ?? const HttpModelArchiveDownloader(),
       _extractor = extractor ?? const TarBz2ModelArchiveExtractor();

  final PocketTtsModelManifest manifest;
  final Directory supportDirectory;
  final Directory _modelsDirectory;
  final ModelArchiveDownloader _downloader;
  final ModelArchiveExtractor _extractor;

  Directory get _installedDirectory =>
      Directory(path.join(_modelsDirectory.path, manifest.version));
  Directory get _stagingDirectory => Directory(
    path.join(_modelsDirectory.path, '.installing-${manifest.version}'),
  );
  File get _archiveFile => File(
    path.join(_modelsDirectory.path, '${manifest.version}.tar.bz2.part'),
  );

  /// True when the engine archive is installed AND the optional FP32 decoder
  /// is present with its pinned byte length.
  Future<bool> hasFp32Decoder({
    PinnedModelFile pin = pocketTtsFp32Decoder,
  }) async {
    if (!await _isValidInstallation(_installedDirectory)) return false;
    final file = File(path.join(_installedDirectory.path, pin.name));
    return await file.exists() && await file.length() == pin.bytes;
  }

  /// Downloads and verifies the FP32 decoder into an already-installed engine
  /// directory. Resumable, integrity-checked, and activated atomically.
  Future<void> ensureFp32Decoder({
    void Function(int downloadedBytes, int totalBytes)? onProgress,
    PinnedModelFile pin = pocketTtsFp32Decoder,
  }) async {
    final destinationFile = File(path.join(_installedDirectory.path, pin.name));
    final stagedFile = File('${destinationFile.path}.part');
    if (!await _isValidInstallation(_installedDirectory)) {
      throw const ModelInstallException(
        'Install the voice engine before adding the high-fidelity decoder.',
        retryable: true,
      );
    }
    try {
      await _downloader.download(
        source: Uri.parse(pin.uri),
        destination: stagedFile,
        expectedBytes: pin.bytes,
        onProgress: (downloaded, total) => onProgress?.call(downloaded, total),
      );
      onProgress?.call(pin.bytes, pin.bytes);
      final digest = await sha256FilePath(stagedFile.path);
      if (digest != pin.sha256) {
        await stagedFile.delete();
        throw const ModelInstallException(
          'The high-fidelity decoder failed its integrity check. Please '
          'download it again.',
          retryable: true,
        );
      }
      if (await destinationFile.exists()) await destinationFile.delete();
      await stagedFile.rename(destinationFile.path);
    } on ModelInstallException {
      rethrow;
    } on FileSystemException {
      throw const ModelInstallException(
        'The high-fidelity decoder could not be written. Check available '
        'storage.',
      );
    }
  }

  Future<void> removeFp32Decoder({
    PinnedModelFile pin = pocketTtsFp32Decoder,
  }) async {
    final destinationFile = File(path.join(_installedDirectory.path, pin.name));
    final stagedFile = File('${destinationFile.path}.part');
    if (await destinationFile.exists()) await destinationFile.delete();
    if (await stagedFile.exists()) await stagedFile.delete();
  }

  Future<ModelInstallState> inspect() async {
    await _modelsDirectory.create(recursive: true);
    await _removeStaleStaging();
    if (await _isValidInstallation(_installedDirectory)) {
      return ModelInstallState(
        phase: ModelInstallPhase.ready,
        downloadedBytes: manifest.archiveBytes,
        paths: PocketTtsModelPaths(_installedDirectory.path),
      );
    }
    if (await _installedDirectory.exists()) {
      await _installedDirectory.delete(recursive: true);
    }
    final partialBytes = await _archiveFile.exists()
        ? await _archiveFile.length()
        : 0;
    return ModelInstallState(
      phase: ModelInstallPhase.absent,
      downloadedBytes: partialBytes.clamp(0, manifest.archiveBytes),
    );
  }

  Future<PocketTtsModelPaths> install({
    required void Function(ModelInstallState state) onState,
  }) async {
    await _modelsDirectory.create(recursive: true);
    final existing = await inspect();
    if (existing.paths case final paths?) return paths;

    try {
      await _downloader.download(
        source: Uri.parse(manifest.archiveUri),
        destination: _archiveFile,
        expectedBytes: manifest.archiveBytes,
        onProgress: (downloaded, total) => onState(
          ModelInstallState(
            phase: ModelInstallPhase.downloading,
            downloadedBytes: downloaded,
            totalBytes: total,
          ),
        ),
      );

      onState(
        ModelInstallState(
          phase: ModelInstallPhase.verifying,
          downloadedBytes: manifest.archiveBytes,
        ),
      );
      final archivePath = _archiveFile.path;
      final digest = await sha256FilePath(archivePath);
      if (digest != manifest.archiveSha256) {
        await _archiveFile.delete();
        throw const ModelInstallException(
          'The downloaded voice engine failed its integrity check. Please '
          'download it again.',
          retryable: true,
        );
      }

      onState(
        ModelInstallState(
          phase: ModelInstallPhase.installing,
          downloadedBytes: manifest.archiveBytes,
        ),
      );
      await _extractVerifiedArchive();
      await _writeInstallMetadata(_stagingDirectory);

      if (await _installedDirectory.exists()) {
        await _installedDirectory.delete(recursive: true);
      }
      await _stagingDirectory.rename(_installedDirectory.path);
      await _archiveFile.delete();
      await _extractor.cleanupPartialArtifacts(_archiveFile);
      await _clearFailureDetail();
      return PocketTtsModelPaths(_installedDirectory.path);
    } on ModelInstallException catch (error) {
      await _removeStaleStaging();
      await _recordFailureDetail(error);
      rethrow;
    } on Object catch (error, stackTrace) {
      await _removeStaleStaging();
      final wrapped = ModelInstallException(
        'The voice engine archive could not be installed.',
        detail: _describe(error, stackTrace),
      );
      await _recordFailureDetail(wrapped);
      throw wrapped;
    }
  }

  Future<void> remove() async {
    if (await _installedDirectory.exists()) {
      await _installedDirectory.delete(recursive: true);
    }
    if (await _archiveFile.exists()) await _archiveFile.delete();
    await _extractor.cleanupPartialArtifacts(_archiveFile);
    await _removeStaleStaging();
  }

  Future<String> createGenerationOutputPath() async {
    final directory = Directory(
      path.join(supportDirectory.path, 'generations'),
    );
    await directory.create(recursive: true);
    return path.join(
      directory.path,
      'generation-${DateTime.now().microsecondsSinceEpoch}.wav',
    );
  }

  Future<void> _removeStaleStaging() async {
    if (await _stagingDirectory.exists()) {
      await _stagingDirectory.delete(recursive: true);
    }
  }

  File get _failureDetailFile =>
      File(path.join(_modelsDirectory.path, 'last_install_error.txt'));

  Future<void> _recordFailureDetail(ModelInstallException error) async {
    try {
      await _modelsDirectory.create(recursive: true);
      await _failureDetailFile.writeAsString(
        '${DateTime.now().toUtc().toIso8601String()} '
        'version=${manifest.version}\n'
        '${error.detail ?? error.message}\n',
        flush: true,
      );
    } on Object {
      // Diagnostics must never mask the original failure.
    }
  }

  Future<void> _clearFailureDetail() async {
    try {
      if (await _failureDetailFile.exists()) {
        await _failureDetailFile.delete();
      }
    } on Object {
      // Ignore; a stale diagnostic file is harmless.
    }
  }

  static String _describe(Object error, StackTrace stackTrace) {
    final stackLines = stackTrace.toString().split('\n').take(8).join('\n');
    return '${error.runtimeType}: $error\n$stackLines';
  }

  Future<void> _extractVerifiedArchive() async {
    const attempts = 3;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      await _removeStaleStaging();
      await _stagingDirectory.create(recursive: true);
      try {
        await _extractor.extract(_archiveFile, _stagingDirectory);
        await _validateExtractedFiles(_stagingDirectory);
        return;
      } on ModelInstallException catch (error) {
        if (!error.retryable || attempt == attempts) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 400));
      } on Object {
        if (attempt == attempts) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
  }

  Future<bool> _isValidInstallation(Directory directory) async {
    final metadata = File(path.join(directory.path, 'install.json'));
    if (!await metadata.exists()) return false;
    try {
      final decoded = jsonDecode(await metadata.readAsString());
      if (decoded is! Map<String, Object?> ||
          decoded['model'] != manifest.id ||
          decoded['version'] != manifest.version ||
          decoded['archive_sha256'] != manifest.archiveSha256) {
        return false;
      }
      for (final name in manifest.requiredFiles) {
        final file = File(path.join(directory.path, name));
        if (!await file.exists() || await file.length() == 0) return false;
      }
      final demoReference = File(
        path.join(directory.path, 'demo_reference.wav'),
      );
      if (!await demoReference.exists() || await demoReference.length() == 0) {
        return false;
      }
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _validateExtractedFiles(Directory directory) async {
    for (final name in manifest.requiredFiles) {
      final file = File(path.join(directory.path, name));
      if (!await file.exists() || await file.length() == 0) {
        throw ModelInstallException(
          'The voice engine archive is missing $name.',
          retryable: false,
        );
      }
    }
    final demoReference = File(path.join(directory.path, 'demo_reference.wav'));
    if (!await demoReference.exists() || await demoReference.length() == 0) {
      throw const ModelInstallException(
        'The voice engine archive is missing its test reference audio.',
        retryable: false,
      );
    }
  }

  Future<void> _writeInstallMetadata(Directory directory) async {
    final file = File(path.join(directory.path, 'install.json'));
    await file.writeAsString(
      jsonEncode({
        'model': manifest.id,
        'version': manifest.version,
        'archive_sha256': manifest.archiveSha256,
      }),
      flush: true,
    );
  }
}

final pocketTtsModelRepositoryProvider = Provider<PocketTtsModelRepository>((
  ref,
) {
  throw StateError('PocketTtsModelRepository must be supplied at bootstrap.');
});

/// Whether the optional FP32 decoder is installed for the current engine.
final fp32DecoderProvider = FutureProvider<bool>((ref) {
  return ref.watch(pocketTtsModelRepositoryProvider).hasFp32Decoder();
});

class ModelInstallController extends AsyncNotifier<ModelInstallState> {
  @override
  Future<ModelInstallState> build() async {
    final repository = ref.watch(pocketTtsModelRepositoryProvider);
    final inspected = await repository.inspect();
    if (inspected.phase == ModelInstallPhase.absent &&
        inspected.downloadedBytes == repository.manifest.archiveBytes) {
      final paths = await repository.install(onState: (_) {});
      return ModelInstallState(
        phase: ModelInstallPhase.ready,
        downloadedBytes: repository.manifest.archiveBytes,
        totalBytes: repository.manifest.archiveBytes,
        paths: paths,
      );
    }
    return inspected;
  }

  Future<void> install() async {
    if (state.value?.phase
        case ModelInstallPhase.downloading ||
            ModelInstallPhase.verifying ||
            ModelInstallPhase.installing) {
      return;
    }
    final repository = ref.read(pocketTtsModelRepositoryProvider);
    state = const AsyncData(
      ModelInstallState(phase: ModelInstallPhase.downloading),
    );
    try {
      final paths = await repository.install(
        onState: (next) => state = AsyncData(next),
      );
      state = AsyncData(
        ModelInstallState(
          phase: ModelInstallPhase.ready,
          downloadedBytes: pocketTtsModel.archiveBytes,
          paths: paths,
        ),
      );
    } on ModelInstallException catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> remove() async {
    state = const AsyncLoading();
    try {
      await ref.read(pocketTtsModelRepositoryProvider).remove();
      state = const AsyncData(
        ModelInstallState(phase: ModelInstallPhase.absent),
      );
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

final modelInstallControllerProvider =
    AsyncNotifierProvider<ModelInstallController, ModelInstallState>(
      ModelInstallController.new,
    );

/// Synchronous archive-to-files worker. Public so tests can exercise the
/// exact production file logic without an isolate boundary.
void extractPocketTtsArchiveSync((String, String) arguments) {
  final (archivePath, destinationPath) = arguments;
  final archiveFile = File(archivePath);
  final destination = Directory(destinationPath)..createSync(recursive: true);

  // The decompressed tar is a reusable sidecar: if a previous attempt was
  // killed mid-install (e.g. aggressive battery managers freezing long
  // isolates), a completed marker lets the next attempt skip the ~90s bzip2
  // stage entirely instead of looping forever.
  final tarFile = File(
    TarBz2ModelArchiveExtractor._decompressedTarPath(archivePath),
  );
  final tarMarker = File('${tarFile.path}.ok');
  final hasCompletedTar =
      tarMarker.existsSync() &&
      tarFile.existsSync() &&
      tarFile.lengthSync() > 0;

  InputFileStream? compressedInput;
  OutputFileStream? tarOutput;
  InputFileStream? tarInput;
  try {
    if (!hasCompletedTar) {
      if (tarMarker.existsSync()) tarMarker.deleteSync();
      if (tarFile.existsSync()) tarFile.deleteSync();
      compressedInput = InputFileStream(archiveFile.path);
      tarOutput = OutputFileStream(tarFile.path);
      final decoded = BZip2Decoder().decodeStream(
        compressedInput,
        tarOutput,
        verify: true,
      );
      if (!decoded) {
        throw const ModelInstallException(
          'The voice engine archive is not valid bzip2 data.',
          retryable: false,
        );
      }
      tarOutput.closeSync();
      tarOutput = null;
      compressedInput.closeSync();
      compressedInput = null;
      // Written only after a fully verified decode; process death before this
      // point leaves no marker, forcing a clean redo next time.
      tarMarker.writeAsStringSync('ok', flush: true);
    }

    tarInput = InputFileStream(tarFile.path);
    final entries = TarDecoder().decodeStream(tarInput, verify: true);
    final wanted = {...pocketTtsModel.requiredFiles, 'bria.wav'};
    final extracted = <String>{};
    // NOTE: tarInput must stay open until all entries are written; entry
    // contents are lazy views over this stream.
    for (final entry in entries) {
      if (!entry.isFile || entry.isSymbolicLink) continue;
      final basename = path.posix.basename(entry.name);
      if (!wanted.contains(basename) || !extracted.add(basename)) continue;
      final outputName = basename == 'bria.wav'
          ? 'demo_reference.wav'
          : basename;
      final output = OutputFileStream(path.join(destination.path, outputName));
      try {
        entry.writeContent(output);
      } finally {
        output.closeSync();
      }
    }
    tarInput.closeSync();
    tarInput = null;
  } finally {
    tarInput?.closeSync();
    tarOutput?.closeSync();
    compressedInput?.closeSync();
  }
}

String _formatMegabytes(int bytes) =>
    '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
