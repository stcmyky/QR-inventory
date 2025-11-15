// lib/utils/storage_persistent.dart
// Platform-conditional export: use the web implementation on web, otherwise the stub/io implementation.

export 'storage_persistent_stub.dart'
    if (dart.library.html) 'storage_persistent_web.dart';
