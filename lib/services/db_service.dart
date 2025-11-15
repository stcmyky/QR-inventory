// lib/services/db_service.dart
// DBService: registers generated Hive adapters with explicit generic types,
// opens the typed box, and performs a defensive cleanup of non-Item entries.
//
// Important: import item.dart (not item.g.dart). item.dart contains `part 'item.g.dart'`
// so generated adapter classes are available after build_runner generation.
//
// After pasting this file: run `flutter clean`, `flutter pub get`, then `flutter run`.

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:qr_sorter/models/item.dart'; // import the model library (contains part 'item.g.dart')

class DBService {
  static final DBService _instance = DBService._internal();
  factory DBService() => _instance;
  DBService._internal();

  static const String boxName = 'items_box';
  Box<Item>? _box;

  /// Initialize Hive and open the box. Await this at app startup before using DBService.
  Future<void> init() async {
    await Hive.initFlutter();

    // Register generated adapters with explicit generic types so Hive knows
    // which adapter corresponds to which Dart type.
    _ensureAdapters();

    // Open the typed box
    _box = await Hive.openBox<Item>(boxName);
    debugPrint('Opened Hive box "$boxName" (length=${_box?.length ?? 0})');

    // Defensive cleanup: remove any entries that are not Item instances.
    await _removeNonItemEntriesIfAny();
  }

  void _ensureAdapters() {
    try {
      // Note: isAdapterRegistered accepts an int typeId (no generics).
      final itemAdapter = ItemAdapter();
      final statusAdapter = AssetStatusAdapter();

      if (!Hive.isAdapterRegistered(itemAdapter.typeId)) {
        Hive.registerAdapter<Item>(itemAdapter);
        debugPrint('Registered ItemAdapter with typeId: ${itemAdapter.typeId}');
      } else {
        debugPrint('ItemAdapter already registered.');
      }

      if (!Hive.isAdapterRegistered(statusAdapter.typeId)) {
        Hive.registerAdapter<AssetStatus>(statusAdapter);
        debugPrint(
            'Registered AssetStatusAdapter with typeId: ${statusAdapter.typeId}');
      } else {
        debugPrint('AssetStatusAdapter already registered.');
      }
    } catch (e, st) {
      debugPrint('Failed to register Hive adapters: $e\n$st');
    }
  }

  Future<void> _removeNonItemEntriesIfAny() async {
    if (_box == null) return;
    try {
      final badKeys = <dynamic>[];
      for (final key in _box!.keys) {
        final val = _box!.get(key);
        if (val is! Item) {
          badKeys.add(key);
        }
      }
      if (badKeys.isNotEmpty) {
        debugPrint(
            'DBService: Found ${badKeys.length} non-Item entries in box. Removing them.');
        for (final k in badKeys) {
          try {
            await _box!.delete(k);
            debugPrint('  Removed non-Item value at key=$k');
          } catch (e, st) {
            debugPrint('  Failed to remove key=$k: $e\n$st');
          }
        }
        debugPrint(
            'DBService: Cleanup complete. Box length=${_box?.length ?? 0}');
      }
    } catch (e, st) {
      debugPrint('DBService: Diagnostic cleanup failed: $e\n$st');
    }
  }

  /// Return all items (or only sorted items if sortedOnly=true).
  List<Item> getItems({bool sortedOnly = false}) {
    final items = _box?.values.toList() ?? [];
    if (sortedOnly) return items.where((i) => i.sorted).toList();

    items.sort((a, b) {
      final aDt = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDt.compareTo(aDt); // newest first
    });
    return items;
  }

  /// Add or replace an item (upsert). Logs diagnostics if Hive write fails.
  Future<void> addItem(Item item) async {
    if (_box == null) {
      const msg =
          'addItem: box is null; did you call and await DBService().init()?';
      debugPrint(msg);
      throw StateError(msg);
    }

    debugPrint(
        'addItem called with runtimeType=${item.runtimeType}, id=${item.id}');
    try {
      await _box!.put(item.id, item);
      debugPrint(
          'addItem: success for key=${item.id}. box length=${_box!.length}');
    } catch (e, st) {
      debugPrint('addItem: Hive put failed: $e\n$st');
      try {
        final types = _box!.values.map((v) => v.runtimeType).toSet();
        debugPrint('Current box value runtime types: $types');
      } catch (_) {
        debugPrint('Failed reading box values for diagnostics.');
      }
      rethrow;
    }
  }

  Future<void> updateItem(Item item) async {
    if (_box == null) {
      debugPrint('updateItem: box is null; did you call DBService().init()?');
      return;
    }
    try {
      await _box!.put(item.id, item);
      debugPrint(
          'updateItem: updated "${item.title}". box length=${_box!.length}');
    } catch (e, st) {
      debugPrint('updateItem failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteItem(String id) async {
    if (_box == null) {
      debugPrint('deleteItem: box is null; did you call DBService().init()?');
      return;
    }
    await _box!.delete(id);
    debugPrint('deleteItem: deleted key=$id. box length=${_box!.length}');
  }

  Item? findByQrData(String qrData) {
    try {
      return _box?.values.firstWhere((it) => it.qrData == qrData);
    } catch (_) {
      return null;
    }
  }

  int count() => _box?.length ?? 0;

  List<String> keys() => _box?.keys.map((k) => k.toString()).toList() ?? [];
}
