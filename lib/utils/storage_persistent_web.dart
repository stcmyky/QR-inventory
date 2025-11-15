// lib/utils/storage_persistent_web.dart
// Web implementation using the browser StorageManager (navigator.storage.persist()).
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<bool> requestPersistentStorage() async {
  try {
    final storage = html.window.navigator.storage;
    if (storage == null) return false;
    final result = storage.persist();
    if (result is Future) {
      final awaited = await result;
      return awaited == true;
    } else if (result is bool) {
      return result;
    } else {
      return false;
    }
  } catch (e) {
    return false;
  }
}
