import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pocket_speech/core/model/pocket_tts_model.dart';

void main() {
  late Directory supportDirectory;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'pocket-tts-model-test-',
    );
  });

  tearDown(() async {
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test('installs only after download verification and extraction', () async {
    final bytes = List<int>.generate(128, (index) => index);
    final manifest = _manifest(bytes);
    final repository = PocketTtsModelRepository(
      supportDirectory: supportDirectory,
      manifest: manifest,
      downloader: MemoryDownloader(bytes),
      extractor: const FixtureExtractor(),
    );
    final phases = <ModelInstallPhase>[];

    final paths = await repository.install(
      onState: (state) => phases.add(state.phase),
    );

    expect(
      phases,
      containsAllInOrder([
        ModelInstallPhase.downloading,
        ModelInstallPhase.verifying,
        ModelInstallPhase.installing,
      ]),
    );
    expect(await File(paths.file('model.onnx')).readAsString(), 'model');
    expect((await repository.inspect()).phase, ModelInstallPhase.ready);
  });

  test('rejects and removes an archive with the wrong digest', () async {
    final expected = <int>[1, 2, 3];
    final repository = PocketTtsModelRepository(
      supportDirectory: supportDirectory,
      manifest: _manifest(expected),
      downloader: const MemoryDownloader([9, 9, 9]),
      extractor: const FixtureExtractor(),
    );

    await expectLater(
      repository.install(onState: (_) {}),
      throwsA(
        isA<ModelInstallException>().having(
          (error) => error.message,
          'message',
          contains('integrity'),
        ),
      ),
    );

    final files = await supportDirectory.list(recursive: true).toList();
    expect(files.where((entry) => entry.path.endsWith('.part')), isEmpty);
    expect((await repository.inspect()).phase, ModelInstallPhase.absent);
  });

  test(
    'retries extraction once when a verified archive fails transiently',
    () async {
      final bytes = List<int>.generate(32, (index) => index);
      final extractor = FlakyExtractor();
      final repository = PocketTtsModelRepository(
        supportDirectory: supportDirectory,
        manifest: _manifest(bytes),
        downloader: MemoryDownloader(bytes),
        extractor: extractor,
      );

      final paths = await repository.install(onState: (_) {});

      expect(extractor.calls, 2);
      expect(await File(paths.file('model.onnx')).exists(), isTrue);
    },
  );

  test(
    'retries extraction three times, then fails with persisted detail',
    () async {
      final bytes = List<int>.generate(32, (index) => index);
      var calls = 0;
      final repository = PocketTtsModelRepository(
        supportDirectory: supportDirectory,
        manifest: _manifest(bytes),
        downloader: MemoryDownloader(bytes),
        extractor: CountingExtractor(() {
          calls += 1;
          throw StateError('ENOSPC simulated');
        }),
      );
      final errorFile = File(
        path.join(
          supportDirectory.path,
          'models',
          'test-model',
          'last_install_error.txt',
        ),
      );

      await expectLater(
        repository.install(onState: (_) {}),
        throwsA(
          isA<ModelInstallException>()
              .having((error) => error.detail, 'detail', contains('StateError'))
              .having(
                (error) => error.detail,
                'detail',
                contains('ENOSPC simulated'),
              ),
        ),
      );
      expect(calls, 3);
      expect(await errorFile.readAsString(), contains('ENOSPC simulated'));
    },
  );

  test('clears persisted failure detail after a later success', () async {
    final bytes = List<int>.generate(32, (index) => index);
    var shouldFail = true;
    final repository = PocketTtsModelRepository(
      supportDirectory: supportDirectory,
      manifest: _manifest(bytes),
      downloader: MemoryDownloader(bytes),
      extractor: CountingExtractor(() {
        if (shouldFail) throw StateError('transient failure');
      }),
    );
    final errorFile = File(
      path.join(
        supportDirectory.path,
        'models',
        'test-model',
        'last_install_error.txt',
      ),
    );

    await expectLater(
      repository.install(onState: (_) {}),
      throwsA(isA<ModelInstallException>()),
    );
    expect(await errorFile.exists(), isTrue);

    shouldFail = false;
    await repository.install(onState: (_) {});

    expect(await errorFile.exists(), isFalse);
  });

  test('removes stale staging before reporting model state', () async {
    final manifest = _manifest(const [1]);
    final stale = Directory(
      path.join(
        supportDirectory.path,
        'models',
        manifest.id,
        '.installing-${manifest.version}',
      ),
    );
    await stale.create(recursive: true);
    await File(path.join(stale.path, 'partial')).writeAsString('partial');
    final repository = PocketTtsModelRepository(
      supportDirectory: supportDirectory,
      manifest: manifest,
    );

    expect((await repository.inspect()).phase, ModelInstallPhase.absent);
    expect(await stale.exists(), isFalse);
  });

  test('HTTP downloader resumes a partial file with a byte range', () async {
    final expected = List<int>.generate(64, (index) => index);
    final destination = File(path.join(supportDirectory.path, 'model.part'));
    await destination.writeAsBytes(expected.take(17).toList());
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requestHandled = server.first.then((request) async {
      expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=17-');
      request.response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes 17-63/${expected.length}',
        )
        ..add(expected.skip(17).toList());
      await request.response.close();
    });

    await const HttpModelArchiveDownloader().download(
      source: Uri.parse('http://127.0.0.1:${server.port}/model'),
      destination: destination,
      expectedBytes: expected.length,
      onProgress: (_, _) {},
    );
    await requestHandled;

    expect(await destination.readAsBytes(), expected);
  });

  test('tar.bz2 extractor writes only required flat model files', () async {
    final sourceArchive = Archive();
    for (final name in pocketTtsModel.requiredFiles) {
      sourceArchive.addFile(ArchiveFile('bundle/$name', 1, const [1]));
    }
    sourceArchive
      ..addFile(ArchiveFile('bundle/test_wavs/bria.wav', 1, const [2]))
      ..addFile(ArchiveFile('bundle/unneeded.txt', 1, const [3]));
    final compressed = BZip2Encoder().encodeBytes(
      TarEncoder().encodeBytes(sourceArchive),
    );
    final archiveFile = File(path.join(supportDirectory.path, 'model.tar.bz2'));
    await archiveFile.writeAsBytes(compressed, flush: true);
    final output = Directory(path.join(supportDirectory.path, 'output'));

    await const TarBz2ModelArchiveExtractor().extract(archiveFile, output);

    for (final name in pocketTtsModel.requiredFiles) {
      expect(await File(path.join(output.path, name)).readAsBytes(), [1]);
    }
    expect(
      await File(path.join(output.path, 'demo_reference.wav')).readAsBytes(),
      [2],
    );
    expect(
      await File(path.join(output.path, 'unneeded.txt')).exists(),
      isFalse,
    );
  });

  test('real extractor resumes from a completed decompressed tar', () async {
    // Build a valid archive, then simulate a prior run that died after fully
    // decoding bzip2: sidecar tar + .ok marker exist, archive bytes deleted.
    final sourceArchive = Archive();
    sourceArchive.addFile(ArchiveFile('bundle/vocab.json', 1, const [7]));
    final compressed = BZip2Encoder().encodeBytes(
      TarEncoder().encodeBytes(sourceArchive),
    );
    final archiveFile = File(path.join(supportDirectory.path, 'model.part'));
    await archiveFile.writeAsBytes(compressed, flush: true);
    final tarFile = File('${archiveFile.path}.tar');
    final marker = File('${tarFile.path}.ok');

    final firstOutput = Directory(path.join(supportDirectory.path, 'out1'));
    extractPocketTtsArchiveSync((archiveFile.path, firstOutput.path));
    expect(await marker.exists(), isTrue);
    expect(await tarFile.exists(), isTrue);

    await archiveFile.delete();
    final secondOutput = Directory(path.join(supportDirectory.path, 'out2'));
    extractPocketTtsArchiveSync((archiveFile.path, secondOutput.path));

    expect(
      await File(path.join(secondOutput.path, 'vocab.json')).readAsBytes(),
      [7],
    );
  });
}

PocketTtsModelManifest _manifest(List<int> bytes) => PocketTtsModelManifest(
  id: 'test-model',
  version: '1',
  archiveUri: 'https://example.invalid/model.tar.bz2',
  archiveBytes: bytes.length,
  archiveSha256: sha256.convert(bytes).toString(),
  requiredFiles: const {'model.onnx'},
);

class MemoryDownloader implements ModelArchiveDownloader {
  const MemoryDownloader(this.bytes);

  final List<int> bytes;

  @override
  Future<void> download({
    required Uri source,
    required File destination,
    required int expectedBytes,
    required DownloadProgress onProgress,
  }) async {
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(bytes, flush: true);
    onProgress(bytes.length, expectedBytes);
  }
}

class FixtureExtractor implements ModelArchiveExtractor {
  const FixtureExtractor();

  @override
  Future<void> extract(File archive, Directory destination) async {
    await File(
      path.join(destination.path, 'model.onnx'),
    ).writeAsString('model', flush: true);
    await File(
      path.join(destination.path, 'demo_reference.wav'),
    ).writeAsString('wave', flush: true);
  }

  @override
  Future<void> cleanupPartialArtifacts(File archive) async {}
}

class FlakyExtractor implements ModelArchiveExtractor {
  int calls = 0;

  @override
  Future<void> extract(File archive, Directory destination) async {
    calls += 1;
    if (calls == 1) throw StateError('Transient extraction failure');
    await const FixtureExtractor().extract(archive, destination);
  }

  @override
  Future<void> cleanupPartialArtifacts(File archive) async {}
}

class CountingExtractor implements ModelArchiveExtractor {
  CountingExtractor(this.onExtract);

  final void Function() onExtract;

  @override
  Future<void> extract(File archive, Directory destination) async {
    onExtract();
    await const FixtureExtractor().extract(archive, destination);
  }

  @override
  Future<void> cleanupPartialArtifacts(File archive) async {}
}
