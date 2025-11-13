// Web implementation: uses the browser StorageManager.persist() API.
import 'dart:html' as html;

Future<bool> requestPersistentStorageImpl() async {
  try {
    final storage = html.window.navigator.storage;
    // If StorageManager exists, call persist()
    if (storage != null) {
      // Some browsers may not support persist() — guard against null
      final granted = await storage.persist();
      return granted == true;
    }
  } catch (e) {
    // ignore and fall through to false
  }
  return false;
}
