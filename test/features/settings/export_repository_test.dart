import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_speech/app/preferences.dart';
import 'package:pocket_speech/features/settings/export_repository.dart';
import 'package:saf_util/saf_util_platform_interface.dart' show SafDocumentFile;

void main() {
  late FakePreferences preferences;

  ExportRepository buildRepository({
    SafDocumentFile? picked,
    bool permissionGranted = true,
    void Function(String uri, String fileName)? onWrite,
  }) {
    final writes = <String>[];
    return ExportRepository(
      preferences: preferences,
      pickDirectory: () async => picked,
      hasPersistedPermission: (uri) async => permissionGranted,
      releasePersistedPermission: (_) async {},
      writeFileBytes: (directoryUri, fileName, mimeType, bytes) async {
        onWrite?.call(directoryUri, fileName);
        writes.add(fileName);
      },
    );
  }

  setUp(() {
    preferences = FakePreferences();
  });

  test('returns null and stays unset when no location was chosen', () async {
    final repository = buildRepository();

    expect(await repository.current(), isNull);
    expect(preferences.values['export_tree_uri'], isNull);
  });

  test('persists the picked folder and reports its name', () async {
    var repository = buildRepository(
      picked: SafDocumentFile(
        uri:
            'content://com.android.externalstorage.documents/tree/primary%3AMusic',
        name: 'Music',
        isDir: true,
        length: 0,
        lastModified: 0,
      ),
    );

    final destination = await repository.selectDestination();

    expect(destination?.name, 'Music');
    expect(
      preferences.values['export_tree_uri'],
      'content://com.android.externalstorage.documents/tree/primary%3AMusic',
    );
    expect((await repository.current())?.name, 'Music');

    // Selecting again replaces the previous destination.
    repository = buildRepository(
      picked: SafDocumentFile(
        uri: 'content://downloads/documents/tree/home%3AExports',
        name: 'Exports',
        isDir: true,
        length: 0,
        lastModified: 0,
      ),
    );
    await repository.selectDestination();
    expect((await repository.current())?.name, 'Exports');
  });

  test('keeps selection when the user cancels the picker', () async {
    preferences.setString('export_tree_uri', 'content://tree/keep%3Ame');
    final repository = buildRepository(picked: null);

    expect(await repository.selectDestination(), isNull);
    expect(preferences.values['export_tree_uri'], 'content://tree/keep%3Ame');
  });

  test('clears a revoked persisted permission', () async {
    preferences.setString('export_tree_uri', 'content://tree/old%3Afolder');
    final repository = buildRepository(permissionGranted: false);

    expect(await repository.current(), isNull);
    expect(preferences.values['export_tree_uri'], '');
  });

  test('export writes WAV bytes into the selected folder', () async {
    String? writtenUri;
    String? writtenName;
    final repository = buildRepository(
      picked: SafDocumentFile(
        uri: 'content://tree/exports',
        name: 'Exports',
        isDir: true,
        length: 0,
        lastModified: 0,
      ),
      onWrite: (uri, fileName) {
        writtenUri = uri;
        writtenName = fileName;
      },
    );
    final destination = await repository.selectDestination();
    if (destination == null) throw StateError('picker returned null');

    final savedName = await repository.exportWav(
      fileName: 'pocket-speech-20260822-1800.wav',
      bytes: Uint8List.fromList(const [1, 2, 3]),
      destination: destination,
    );

    expect(savedName, 'pocket-speech-20260822-1800.wav');
    expect(writtenName, savedName);
    expect(writtenUri, destination.uri);
  });
}

class FakePreferences implements AppPreferences {
  final Map<String, Object> values = {};

  @override
  bool? getBool(String key) => values[key] as bool?;

  @override
  String? getString(String key) => values[key] as String?;

  @override
  Future<bool> setBool(String key, bool value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }
}
