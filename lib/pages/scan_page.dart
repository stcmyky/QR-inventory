// lib/pages/scan_page.dart
// Scanner-enabled Scan page with web webcam attempt and graceful fallback.
// Replace your current file with this content.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_sorter/models/item.dart';
import 'package:qr_sorter/services/db_service.dart';
import 'package:qr_sorter/pages/add_item_page.dart';
import 'package:qr_sorter/widgets/qr_display.dart';
import 'package:qr_sorter/widgets/item_icon.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({Key? key}) : super(key: key);

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final DBService db = DBService();
  final MobileScannerController _scannerController = MobileScannerController();

  List<Item> _items = [];
  bool _scannerActive = true;
  bool _scannedLock = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _loadItems() {
    setState(() {
      _items = db.getItems();
    });
  }

  Future<void> _setItemSorted(Item item, bool sorted) async {
    final updated = item.copyWith(sorted: sorted);
    try {
      await db.addItem(updated);
    } catch (e, st) {
      debugPrint('Failed to update item sorted: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update item: $e')));
      }
    }
    _loadItems();
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
    _loadItems();
  }

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
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save')),
        ],
      ),
    );

    if (!mounted) return;
    if (result == true) {
      final newCat = controller.text.trim();
      await _updateItemCategory(item, newCat);
    }
  }

  void _showItemDialog(Item item) {
    // This uses context synchronously; no await before using context here.
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
                  child: QrDisplay(
                      data: item.qrData.isNotEmpty
                          ? item.qrData
                          : item.inventoryNumber,
                      size: 140)),
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
              child: const Text('Edit category')),
        ],
      ),
    );
  }

  // Safe onDetect: stops scanner, checks mounted before any UI use, resumes scanner.
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scannedLock) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.trim().isEmpty) return;

    _scannedLock = true;
    final data = raw.trim();
    debugPrint('QR detected: $data');

    final found = db.findByQrData(data);

    // stop scanner early
    try {
      await _scannerController.stop();
    } catch (_) {}

    if (!mounted) {
      _scannedLock = false;
      return;
    }
    setState(() => _scannerActive = false);

    if (!mounted) {
      _scannedLock = false;
      return;
    }

    if (found != null) {
      final open = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(found.title),
          content:
              Text('Found item for QR: ${found.inventoryNumber}\n\nOpen item?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Open')),
          ],
        ),
      );

      if (!mounted) {
        _scannedLock = false;
        return;
      }

      if (open == true && mounted) {
        _showItemDialog(found);
      }
    } else {
      final add = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Unrecognized QR'),
          content: Text(
              'No existing item for "$data". Create a new item with this QR data?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Add')),
          ],
        ),
      );

      if (!mounted) {
        _scannedLock = false;
        return;
      }

      if (add == true && mounted) {
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddItemPage()));
        if (mounted) _loadItems();
      }
    }

    // resume scanner (guard mounted)
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      try {
        await _scannerController.start();
        setState(() => _scannerActive = true);
      } catch (_) {}
    }
    _scannedLock = false;
  }

  // This builder attempts to start camera on web and falls back cleanly if it fails.
  Widget _buildScannerOrFallback() {
    if (kIsWeb) {
      // Try to start the controller briefly to detect permission/HTTPS issues.
      return FutureBuilder<bool>(
        future: (() async {
          try {
            await _scannerController.start();
            return true;
          } catch (e) {
            debugPrint('Web camera start failed: $e');
            try {
              await _scannerController.stop();
            } catch (_) {}
            return false;
          }
        })(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final ok = snap.data == true;
          if (!ok) {
            // Fallback UI when camera unavailable on web (insecure origin or blocked)
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: Column(
                children: [
                  const Text(
                    'Camera not available in this browser session.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'To scan with camera on web you need an HTTPS site or localhost. For the demo you can add items manually.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add item manually'),
                    onPressed: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AddItemPage()));
                      if (mounted) _loadItems();
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      // Try to start the scanner (may throw if insecure origin)
                      try {
                        await _scannerController.start();
                        if (mounted) setState(() => _scannerActive = true);
                      } catch (e) {
                        debugPrint('Start scanner on web failed: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Camera not available on web')));
                        }
                      }
                    },
                    child: const Text('Try camera (may require HTTPS)'),
                  ),
                ],
              ),
            );
          }

          // Camera OK — show preview
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 320,
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (_scannerActive) {
                          try {
                            await _scannerController.stop();
                          } catch (_) {}
                          if (mounted) setState(() => _scannerActive = false);
                        } else {
                          try {
                            await _scannerController.start();
                          } catch (_) {}
                          if (mounted) setState(() => _scannerActive = true);
                        }
                      },
                      icon:
                          Icon(_scannerActive ? Icons.pause : Icons.play_arrow),
                      label: Text(_scannerActive ? 'Pause' : 'Start'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await _scannerController.toggleTorch();
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.flash_on),
                      label: const Text('Torch'),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: SizedBox()),
                    TextButton(
                        onPressed: _loadItems,
                        child: const Text('Refresh list')),
                  ],
                ),
              ),
            ],
          );
        },
      );
    }

    // Mobile / native preview
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 320,
          child: MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
            fit: BoxFit.cover,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  if (_scannerActive) {
                    try {
                      await _scannerController.stop();
                    } catch (_) {}
                    if (mounted) setState(() => _scannerActive = false);
                  } else {
                    try {
                      await _scannerController.start();
                    } catch (_) {}
                    if (mounted) setState(() => _scannerActive = true);
                  }
                },
                icon: Icon(_scannerActive ? Icons.pause : Icons.play_arrow),
                label: Text(_scannerActive ? 'Pause' : 'Start'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await _scannerController.toggleTorch();
                  } catch (_) {}
                },
                icon: const Icon(Icons.flash_on),
                label: const Text('Torch'),
              ),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
              TextButton(
                  onPressed: _loadItems, child: const Text('Refresh list')),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // ensure fresh items
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
        child: Column(
          children: [
            _buildScannerOrFallback(),
            const SizedBox(height: 8),
            Expanded(
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
                              backgroundColor: it.sorted
                                  ? Colors.green[50]
                                  : Colors.purple[50],
                              child: ItemIcon(
                                  item: it,
                                  size: 20,
                                  color:
                                      it.sorted ? Colors.green : Colors.purple),
                            ),
                            title: Text(it.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(it.category.isEmpty
                                ? it.description
                                : '${it.description} • ${it.category}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: it.sorted
                                      ? 'Mark unsorted'
                                      : 'Mark sorted',
                                  icon: Icon(it.sorted
                                      ? Icons.check_circle
                                      : Icons.qr_code),
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
                            onTap: () => _showItemDialog(it),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_item',
        tooltip: 'Add item',
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
              context, MaterialPageRoute(builder: (_) => const AddItemPage()));
          _loadItems();
        },
      ),
    );
  }
}
