import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart' show SafDocumentFile;

import '../../app/preferences.dart';

class ExportDestination {
  const ExportDestination({required this.uri, required this.name});

  final String uri;
  final String name;
}

class ExportException implements Exception {
  const ExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Persists a user-selected Android document tree and copies exported audio
/// into it through the Storage Access Framework. Canonical audio always stays
/// app-private; exports are copies.
class ExportRepository {
  ExportRepository({
    required this.preferences,
    Future<SafDocumentFile?> Function()? pickDirectory,
    Future<bool> Function(String uri)? hasPersistedPermission,
    Future<void> Function(String uri)? releasePersistedPermission,
    Future<void> Function(
      String directoryUri,
      String fileName,
      String mimeType,
      Uint8List bytes,
    )?
    writeFileBytes,
  }) : _pickDirectory =
           pickDirectory ??
           (() => SafUtil().pickDirectory(
             writePermission: true,
             persistablePermission: true,
           )),
       _hasPersistedPermission =
           hasPersistedPermission ??
           ((uri) => SafUtil().hasPersistedPermission(uri, checkWrite: true)),
       _releasePersistedPermission =
           releasePersistedPermission ??
           ((uri) => SafUtil().releasePersistedPermission(uri, write: true)),
       _writeFileBytes =
           writeFileBytes ??
           ((directoryUri, fileName, mimeType, bytes) => SafStream()
               .writeFileBytes(directoryUri, fileName, mimeType, bytes));

  static const _uriKey = 'export_tree_uri';

  final AppPreferences preferences;
  final Future<SafDocumentFile?> Function() _pickDirectory;
  final Future<bool> Function(String uri) _hasPersistedPermission;
  final Future<void> Function(String uri) _releasePersistedPermission;
  final Future<void> Function(
    String directoryUri,
    String fileName,
    String mimeType,
    Uint8List bytes,
  )
  _writeFileBytes;

  /// Returns the stored destination, or null when unset or when Android has
  /// revoked its persisted permission (for example after clearing app data).
  Future<ExportDestination?> current() async {
    final uri = preferences.getString(_uriKey);
    if (uri == null || uri.isEmpty) return null;
    try {
      if (!await _hasPersistedPermission(uri)) {
        await _forget(uri);
        return null;
      }
    } on Object {
      return null;
    }
    return ExportDestination(uri: uri, name: _displayName(uri));
  }

  /// Opens the system folder picker. Returns null when the user cancels.
  Future<ExportDestination?> selectDestination() async {
    final SafDocumentFile? document;
    try {
      document = await _pickDirectory();
    } on Object {
      throw const ExportException('The folder picker could not be opened.');
    }
    if (document == null) return null;
    await _forgetCurrent();
    final saved = await preferences.setString(_uriKey, document.uri);
    if (!saved) {
      throw const ExportException('The download location could not be saved.');
    }
    return ExportDestination(uri: document.uri, name: document.name);
  }

  Future<void> clearDestination() async {
    await _forgetCurrent();
    await preferences.setString(_uriKey, '');
  }

  /// Copies [bytes] into the selected folder and returns the created file
  /// name. Throws [ExportException] when the location was revoked.
  Future<String> exportWav({
    required String fileName,
    required Uint8List bytes,
    required ExportDestination destination,
  }) async {
    try {
      await _writeFileBytes(destination.uri, fileName, 'audio/wav', bytes);
      return fileName;
    } on ExportException {
      rethrow;
    } on Object {
      throw const ExportException(
        'Audio could not be exported. Re-select the download location in '
        'Settings and try again.',
      );
    }
  }

  Future<void> _forgetCurrent() async {
    final uri = preferences.getString(_uriKey);
    if (uri != null && uri.isNotEmpty) await _forget(uri);
  }

  Future<void> _forget(String uri) async {
    try {
      await _releasePersistedPermission(uri);
    } on Object {
      // Permission may already be gone; clearing the preference is enough.
    }
    await preferences.setString(_uriKey, '');
  }

  String _displayName(String uri) {
    final segment = Uri.tryParse(
      uri,
    )?.pathSegments.lastWhere((part) => part.isNotEmpty, orElse: () => '');
    if (segment == null || segment.isEmpty) return 'Selected folder';
    final decoded = Uri.decodeComponent(segment);
    final colon = decoded.indexOf(':');
    return colon >= 0 && colon + 1 < decoded.length
        ? decoded.substring(colon + 1)
        : decoded;
  }
}

final exportRepositoryProvider = Provider<ExportRepository>((ref) {
  return ExportRepository(preferences: ref.watch(appPreferencesProvider));
});

final exportDestinationProvider = FutureProvider<ExportDestination?>((ref) {
  return ref.watch(exportRepositoryProvider).current();
});
