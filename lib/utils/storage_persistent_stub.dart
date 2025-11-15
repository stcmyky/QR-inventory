// lib/utils/storage_persistent_stub.dart
// Non-web (stub) implementation for requestPersistentStorage.

Future<bool> requestPersistentStorage() async {
  // Not applicable for non-web platforms. Return true to indicate "granted".
  return true;
}
