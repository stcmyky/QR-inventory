import 'storage_persistent_stub.dart'
    if (dart.library.html) 'storage_persistent_web.dart';

/// Returns true when persistent storage was granted (web only), false otherwise.
Future<bool> requestPersistentStorage() => requestPersistentStorageImpl();
