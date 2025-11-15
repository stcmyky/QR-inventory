// lib/services/export_service_io.dart
// IO implementation: saves bytes to application documents directory and returns the saved path.

import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String?> triggerDownload(Uint8List bytes, String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
