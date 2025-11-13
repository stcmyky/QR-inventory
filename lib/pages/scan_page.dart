// Full replacement for lib/pages/scan_page.dart
// This ScanPage shows the list of items and provides safe helper methods
// (_setItemSorted and _updateItemCategory) that avoid mutating final fields.
// Copy-paste this entire file to replace your existing scan_page.dart.

import 'package:flutter/material.dart';
import 'package:qr_sorter/models/item.dart';
import 'package:qr_sorter/services/db_service.dart';
import 'package:qr_sorter/pages/add_item_page.dart';
import 'package:qr_sorter/widgets/qr_display.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({Key? key}) : super(key: key);

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final DBService db = DBService();

  List<Item> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    setState(() {
      _items = db.getItems();
    });
  }

  // --- Helper methods (safe, use copyWith + persist) ---
  // Use these instead of assigning to item.sorted or item.category directly.

  Future<void> _setItemSorted(Item item, bool sorted) async {
    final updated = item.copyWith(sorted: sorted);
    try {
      await db.addItem(updated); // persist the updated item
    } catch (e, st) {
      debugPrint('Failed to update item sorted: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update item: $e')));
      }
    }
    // Refresh UI
    if (mounted) {
      setState(() {
        _loadItems();
      });
    }
  }

  Future<void> _updateItemCategory(Item item, String category) async {
    final updated = item.copyWith(category: category);
    try {
      await db.addItem(updated);
    } catch (e, st) {
      debugPrint('Failed to update category: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update category: $e')));
      }
    }
    if (mounted) {
      setState(() {
        _loadItems();
      });
    }
  }

  // Small UI to prompt for a category value
  Future<void> _promptChangeCategory(Item item) async {
    final controller = TextEditingController(text: item.category);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Category'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Save')),
        ],
      ),
    );

    if (result == true) {
      final newCat = controller.text.trim();
      await _updateItemCategory(item, newCat);
    }
  }

  // Show item details (simple)
  void _showItemDialog(Item item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.description.isNotEmpty) Text(item.description),
            const SizedBox(height: 12),
            SizedBox(
              width: 160,
              height: 160,
              child: Center(
                child: Builder(builder: (_) {
                  try {
                    final data = item.qrData.isNotEmpty
                        ? item.qrData
                        : item.inventoryNumber;
                    return QrDisplay(data: data, size: 140);
                  } catch (e, st) {
                    debugPrint('QrDisplay error: $e\n$st');
                    return const Icon(Icons.broken_image,
                        size: 48, color: Colors.red);
                  }
                }),
              ),
            ),
            const SizedBox(height: 8),
            Text('Inventory: ${item.inventoryNumber}'),
            const SizedBox(height: 8),
            Text('Category: ${item.category.isEmpty ? "-" : item.category}'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _promptChangeCategory(item);
            },
            child: const Text('Edit category'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ensure items are fresh (you can remove if you prefer manual refresh only)
    _items = db.getItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan / Items'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadItems,
          )
        ],
      ),
      body: SafeArea(
        child: _items.isEmpty
            ? const Center(child: Text('No items yet'))
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final it = _items[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      leading: CircleAvatar(
                        backgroundColor:
                            it.sorted ? Colors.green[50] : Colors.purple[50],
                        child: Icon(
                          IconData(it.iconCodePoint,
                              fontFamily: it.iconFontFamily),
                          color: it.sorted ? Colors.green : Colors.purple,
                        ),
                      ),
                      title: Text(it.title,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(it.category.isEmpty
                          ? it.description
                          : '${it.description} • ${it.category}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip:
                                it.sorted ? 'Mark unsorted' : 'Mark sorted',
                            icon: Icon(
                                it.sorted ? Icons.check_circle : Icons.qr_code),
                            color: it.sorted ? Colors.green : Colors.grey,
                            onPressed: () async {
                              await _setItemSorted(it, !it.sorted);
                            },
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit_cat') {
                                await _promptChangeCategory(it);
                              } else if (v == 'show') {
                                _showItemDialog(it);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                  value: 'show', child: Text('Show')),
                              const PopupMenuItem(
                                  value: 'edit_cat',
                                  child: Text('Edit category')),
                            ],
                          ),
                        ],
                      ),
                      onTap: () {
                        _showItemDialog(it);
                      },
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'add_item',
            tooltip: 'Add item',
            child: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddItemPage()));
              _loadItems();
            },
          ),
        ],
      ),
    );
  }
}
