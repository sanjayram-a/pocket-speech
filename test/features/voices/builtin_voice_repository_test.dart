import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_speech/core/model/pocket_tts_model.dart';
import 'package:pocket_speech/features/voices/builtin_voice_repository.dart';

void main() {
  late Directory supportDirectory;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'builtin-voice-test-',
    );
  });

  tearDown(() async {
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });
  List<BuiltinVoice> testCatalog(List<String> ids) => [
    for (final id in ids) _voiceFor(id, wavBytes(id)),
  ];

  test('downloads missing voices and lists them installed', () async {
    final served = <String>[];
    final repository = _repo(supportDirectory, testCatalog(['a', 'b']), (id) {
      served.add(id);
    });

    final installed = await repository.ensureInstalled();

    expect(installed, hasLength(2));
    expect(installed.map((i) => i.voice.id), containsAll(['a', 'b']));
    expect(served, hasLength(2));
  });

  test('second pass skips voices that are present with exact size', () async {
    final repository = _repo(supportDirectory, testCatalog(['a']), (_) {});
    await repository.ensureInstalled();

    var downloads = 0;
    final again = await _repo(supportDirectory, testCatalog(['a']), (_) {
      downloads += 1;
    }).ensureInstalled();

    expect(downloads, 0);
    expect(again, hasLength(1));
  });

  test('re-downloads a corrupted file on the next pass', () async {
    final repository = _repo(supportDirectory, testCatalog(['a']), (_) {});
    await repository.ensureInstalled();
    final target = File('${supportDirectory.path}/builtin_voices/a.wav');
    await target.writeAsBytes(
      Uint8List.fromList(List.filled(target.lengthSync(), 0xAA)),
      flush: true,
    );

    var downloads = 0;
    final repaired = await _repo(supportDirectory, testCatalog(['a']), (_) {
      downloads += 1;
    }).ensureInstalled();

    expect(downloads, 1);
    expect(repaired, hasLength(1));
  });

  test('fails with a friendly message when download errors', () async {
    final repository = BuiltinVoiceRepository(
      supportDirectory: supportDirectory,
      downloader: const FailingDownloader(),
      catalog: testCatalog(['a']),
    );

    await expectLater(
      repository.ensureInstalled(),
      throwsA(isA<BuiltinVoiceException>()),
    );
  });
}

BuiltinVoiceRepository _repo(
  Directory dir,
  List<BuiltinVoice> catalog,
  void Function(String id)? onServed,
) => BuiltinVoiceRepository(
  supportDirectory: dir,
  catalog: catalog,
  downloader: ServingDownloader(onServed),
);

BuiltinVoice _voiceFor(String id, List<int> payload) {
  final digest = sha256.convert(payload).toString();
  return BuiltinVoice(
    id: id,
    label: 'Voice $id',
    remotePath: 'test/$id.wav',
    bytes: payload.length,
    sha256: digest,
    license: 'CC0',
  );
}

List<int> utf8Bytes(String s) => s.codeUnits;

/// Minimal valid mono PCM16 WAV wrapping the id payload so metadata parsing
/// succeeds in tests.
Uint8List wavBytes(String id) {
  final payload = Uint8List.fromList(utf8Bytes(id));
  final bytes = Uint8List(44 + payload.length);
  final data = ByteData.sublistView(bytes);
  void fourCc(int offset, String value) =>
      bytes.setRange(offset, offset + 4, value.codeUnits);
  fourCc(0, 'RIFF');
  data.setUint32(4, 36 + payload.length, Endian.little);
  fourCc(8, 'WAVE');
  fourCc(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 24000, Endian.little);
  data.setUint32(28, 48000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  fourCc(36, 'data');
  data.setUint32(40, payload.length, Endian.little);
  bytes.setRange(44, bytes.length, payload);
  return bytes;
}

class ServingDownloader implements ModelArchiveDownloader {
  ServingDownloader(this.onServed);

  final void Function(String id)? onServed;

  @override
  Future<void> download({
    required Uri source,
    required File destination,
    required int expectedBytes,
    required DownloadProgress onProgress,
  }) async {
    final id = source.pathSegments.last.split('.').first;
    onServed?.call(id);
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(wavBytes(id), flush: true);
    onProgress(expectedBytes, expectedBytes);
  }
}

class FailingDownloader implements ModelArchiveDownloader {
  const FailingDownloader();

  @override
  Future<void> download({
    required Uri source,
    required File destination,
    required int expectedBytes,
    required DownloadProgress onProgress,
  }) {
    throw const SocketException('offline');
  }
}
