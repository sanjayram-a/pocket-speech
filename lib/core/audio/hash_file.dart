import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

/// SHA-256 of a file, computed off the UI isolate. Captures only the path
/// string so nothing unsendable crosses the isolate boundary.
Future<String> sha256FilePath(String filePath) => Isolate.run(() async {
  final digest = await sha256.bind(File(filePath).openRead()).first;
  return digest.toString();
});
