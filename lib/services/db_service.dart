// lib/services/db_service.dart
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:qr_sorter/models/item.dart'; // import the model library (not item.g.dart)

class DBService {
  static final DBService _instance = DBService._internal();
  factory DBService() => _instance;
  DBService._internal();

  static const String boxName = 'items_box';
  Box<Item>? _box;

  /// Initialize Hive and open the box. Call this once at app startup before
  /// using the DBService (for example from main()).
  Future<void> init() async {
    // Init Hive for Flutter
    await Hive.initFlutter();

    // Ensure the generated adapter is registered
    _ensureAdapters();

    // Open the box
    _box = await Hive.openBox<Item>(boxName);
    debugPrint('Opened Hive box "$boxName" (length=${_box?.length ?? 0})');
  }

  void _ensureAdapters() {
    try {
      // ItemAdapter is generated into item.g.dart as part of this library.
      // Because we import item.dart (which has `part 'item.g.dart'`), ItemAdapter
      // will be available here after generation.
      final adapter = ItemAdapter();
      final typeId = adapter.typeId;
      if (!Hive.isAdapterRegistered(typeId)) {
        Hive.registerAdapter(adapter);
        debugPrint('Registered ItemAdapter with typeId: $typeId');
      }
    } catch (e, st) {
      debugPrint('Failed to register ItemAdapter: $e\n$st');
    }
  }

  /// Return all items (or only sorted items if sortedOnly=true).
  /// Sort by createdAt safely (nulls treated as epoch).
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

  /// Add (upsert) an item
  Future<void> addItem(Item item) async {
    if (_box == null) {
      debugPrint('addItem: box is null; did you call DBService().init()?');
      return;
    }
    await _box!.put(item.id, item);
    debugPrint(
        'addItem: added/updated "${item.title}" key=${item.id}. box length=${_box!.length}');
  }

  Future<void> updateItem(Item item) async {
    if (_box == null) {
      debugPrint('updateItem: box is null; did you call DBService().init()?');
      return;
    }
    await _box!.put(item.id, item);
    debugPrint(
        'updateItem: updated "${item.title}". box length=${_box!.length}');
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
