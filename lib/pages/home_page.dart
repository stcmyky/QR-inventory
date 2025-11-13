import 'dart:typed_data';
import 'dart:convert';

// Web helper for opening a print page (only used on web).
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_sorter/models/item.dart';
import 'package:qr_sorter/pages/add_item_page.dart';
import 'package:qr_sorter/pages/scan_page.dart';
import 'package:qr_sorter/pages/export_import_page.dart';
import 'package:qr_sorter/services/db_service.dart';
import 'package:qr_sorter/widgets/qr_display.dart';
import 'package:qr_sorter/utils/storage_persistent.dart';

// Printing & PDF widgets
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

// Barcode for SVG generation
import 'package:barcode/barcode.dart';

// Keep qr_flutter for on-screen QrDisplay widget (UI)
import 'package:qr_flutter/qr_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DBService db = DBService();

  List<Item> _items = [];

  // Selection mode state
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  // ICON PALETTE: tweak this list to include icons you prefer
  static final List<IconData> _iconPalette = [
    Icons.qr_code,
    Icons.inventory,
    Icons.folder,
    Icons.home,
    Icons.work,
    Icons.build,
    Icons.devices,
    Icons.label,
    Icons.devices_other,
    Icons.check_circle,
  ];

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

  Future<bool?> _confirmDelete(BuildContext context, Item item) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item'),
        content: Text('Delete "${item.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
  }

  List<Item> get _selectedItems =>
      _items.where((it) => _selectedIds.contains(it.id)).toList();

  void _enterSelectionMode({String? selectId}) {
    setState(() {
      _selectionMode = true;
      if (selectId != null) _selectedIds.add(selectId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _items.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_items.map((e) => e.id));
      }
    });
  }

  void _toggleSelection(Item item) {
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
  }

  // Apply an icon to a single item and save via db
  Future<void> _applyIconToItem(Item item, IconData icon) async {
    final updated = item.copyWith(
        iconCodePoint: icon.codePoint, iconFontFamily: icon.fontFamily);
    await db.addItem(updated); // your db.addItem should update item by id
    _loadItems();
  }

  // Bulk apply icon to currently selected items
  Future<void> _applyIconToSelected(IconData icon) async {
    final selected = _selectedItems;
    for (final it in selected) {
      final updated = it.copyWith(
          iconCodePoint: icon.codePoint, iconFontFamily: icon.fontFamily);
      await db.addItem(updated);
    }
    _loadItems();
    _exitSelectionMode();
  }

  // Show icon picker dialog (reusable)
  Future<IconData?> _showIconPicker(
      {required BuildContext context, IconData? initial}) {
    IconData? picked = initial;
    return showDialog<IconData>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose icon'),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _iconPalette.map((ic) {
              final selected = picked?.codePoint == ic.codePoint;
              return GestureDetector(
                onTap: () {
                  picked = ic;
                  // Give immediate feedback by closing with result
                  Navigator.of(ctx).pop(ic);
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.purple.withOpacity(.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: selected
                        ? Border.all(color: Colors.purple, width: 1.5)
                        : null,
                  ),
                  child: Icon(ic, size: 32, color: Colors.black87),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel')),
        ],
      ),
    );
  }

  // Print multiple selected items (quantity applies to each selected item).
  Future<void> _printSelected() async {
    final selected = _selectedItems;
    if (selected.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No items selected')));
      return;
    }

    // ask quantity per item
    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: '1');
        return AlertDialog(
          title: const Text('Print labels'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'How many copies of each selected label would you like to print?'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Quantity', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Text('Selected items: ${selected.length}'),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final v = int.tryParse(controller.text.trim()) ?? 1;
                Navigator.of(ctx).pop(v > 0 ? v : 1);
              },
              child: const Text('Print'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (qty == null || qty <= 0) return;

    await _printMultiple(selected, qty);
    // after printing, exit selection mode
    _exitSelectionMode();
  }

  // Print routine that accepts multiple items and copies-per-item
  Future<void> _printMultiple(List<Item> items, int copiesPerItem) async {
    try {
      // WEB PATH: build an HTML page with inline SVG QRs and open in new tab then call print()
      if (kIsWeb) {
        try {
          const double svgSizePx = 800.0;
          const HtmlEscape esc = HtmlEscape(HtmlEscapeMode.element);

          final StringBuffer labels = StringBuffer();
          for (final it in items) {
            final String qrSvg = Barcode.qrCode().toSvg(
                it.qrData.isNotEmpty ? it.qrData : it.inventoryNumber,
                width: svgSizePx,
                height: svgSizePx,
                drawText: false);
            final String titleEsc = esc.convert(it.title);
            final String invEsc = esc.convert(it.inventoryNumber);
            for (int c = 0; c < copiesPerItem; c++) {
              labels.write('''
<div class="label">
  <div class="qr-wrapper">
    $qrSvg
  </div>
  <div class="title">$titleEsc</div>
  <div class="inv">$invEsc</div>
</div>
''');
            }
          }

          final String htmlPage = '''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Print labels</title>
<style>
  @media print {
    @page { size: A4; margin: 8mm; }
    body { margin: 0; padding: 8mm; -webkit-print-color-adjust: exact; }
  }
  body {
    font-family: Arial, sans-serif;
    margin: 0;
    padding: 8mm;
    background: #fff;
    -webkit-print-color-adjust: exact;
  }
  .page { width: 210mm; }
  .label {
    width: 50mm;
    height: 30mm;
    box-sizing: border-box;
    border: 0.2mm solid #000;
    display: inline-block;
    margin: 2mm;
    padding: 2mm;
    text-align: center;
    vertical-align: top;
    overflow: hidden;
  }
  .qr-wrapper {
    width: 44mm;
    height: 18mm;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto 4px;
  }
  .qr-wrapper svg {
    width: 100%;
    height: 100%;
    display: block;
  }
  .title { font-size: 9px; line-height: 1; margin-top: 1px; }
  .inv { font-size: 8px; line-height: 1; color: #333; }
</style>
</head>
<body>
  <div class="page">
    ${labels.toString()}
  </div>
  <script>
    window.onload = function() {
      setTimeout(function() {
        window.focus();
        try { window.print(); } catch(e) {}
      }, 250);
    };
  </script>
</body>
</html>
''';

          final blob = html.Blob([htmlPage], 'text/html');
          final url = html.Url.createObjectUrlFromBlob(blob);
          try {
            html.window.open(url, '_blank');
          } catch (_) {
            // Some browsers or environments may block programmatic opens - ignore
          }
          return;
        } catch (e, st) {
          debugPrint(
              'Web HTML multi-print failed, falling back to PDF: $e\n$st');
          // fall through to PDF fallback
        }
      }

      // NON-WEB or fallback: create PDF with vector QR using pw.BarcodeWidget
      final doc = pw.Document();

      const double stickerWidthMm = 50.0;
      const double stickerHeightMm = 30.0;

      const PdfPageFormat pageFormat = PdfPageFormat.a4;
      final double pageWidth = pageFormat.width;
      final double pageHeight = pageFormat.height;

      const double stickerW = stickerWidthMm * PdfPageFormat.mm;
      const double stickerH = stickerHeightMm * PdfPageFormat.mm;

      final int perRow = (pageWidth / stickerW).floor().clamp(1, 100);
      final int perCol = (pageHeight / stickerH).floor().clamp(1, 100);
      final int perPage = perRow * perCol;

      // build a list of all labels = item repeated copiesPerItem times, in same order
      final List<Item> expanded = [];
      for (final it in items) {
        for (int i = 0; i < copiesPerItem; i++) {
          expanded.add(it);
        }
      }

      int remaining = expanded.length;

      while (remaining > 0) {
        final int thisPageCount = remaining >= perPage ? perPage : remaining;

        doc.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (context) {
              final rows = <pw.Widget>[];
              int placed = 0;
              for (int r = 0; r < perCol; r++) {
                final children = <pw.Widget>[];
                for (int c = 0; c < perRow; c++) {
                  if (placed < thisPageCount) {
                    final Item cur =
                        expanded[expanded.length - remaining + placed];
                    children.add(
                      pw.Container(
                        width: stickerW,
                        height: stickerH,
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Container(
                              width: stickerW - 12,
                              height: stickerW - 12,
                              child: pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: cur.qrData.isNotEmpty
                                    ? cur.qrData
                                    : cur.inventoryNumber,
                                drawText: false,
                                color: PdfColors.black,
                              ),
                            ),
                            pw.SizedBox(height: 3 * PdfPageFormat.mm),
                            pw.Text(cur.title,
                                style: const pw.TextStyle(fontSize: 9),
                                textAlign: pw.TextAlign.center),
                            pw.Text(cur.inventoryNumber,
                                style: const pw.TextStyle(fontSize: 8),
                                textAlign: pw.TextAlign.center),
                          ],
                        ),
                        decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                                color: PdfColors.black, width: .2)),
                      ),
                    );
                    placed++;
                  } else {
                    children
                        .add(pw.Container(width: stickerW, height: stickerH));
                  }
                }
                rows.add(pw.Row(
                    children: children,
                    mainAxisAlignment: pw.MainAxisAlignment.center));
              }
              return pw.Column(children: rows);
            },
          ),
        );

        remaining -= thisPageCount;
      }

      final pdfBytes = await doc.save();

      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes);
    } catch (e, st) {
      debugPrint('Multi-print failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Print failed: $e')));
      }
    }
  }

  // Single-item print preserved (keeps previous behavior)
  Future<void> _printSingle(Item item) async {
    await _printMultiple([item], 1);
  }

  // Inline edit dialog (adds department stored in location + asset status + icon)
  Future<void> _editItemDialog(Item item) async {
    final titleCtrl = TextEditingController(text: item.title);
    final descCtrl = TextEditingController(text: item.description);
    final qrCtrl = TextEditingController(text: item.qrData);
    final categoryCtrl = TextEditingController(text: item.category);
    final departmentCtrl = TextEditingController(text: item.location);
    final inventoryCtrl = TextEditingController(text: item.inventoryNumber);

    AssetStatus currentStatus = item.status;
    int currentIcon = item.iconCodePoint;
    String? currentFont = item.iconFontFamily;

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit item'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title required'
                        : null),
                const SizedBox(height: 8),
                TextFormField(
                    controller: descCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 8),
                TextFormField(
                    controller: qrCtrl,
                    decoration: const InputDecoration(labelText: 'QR data')),
                const SizedBox(height: 8),
                TextFormField(
                    controller: categoryCtrl,
                    decoration: const InputDecoration(labelText: 'Category')),
                const SizedBox(height: 8),
                TextFormField(
                    controller: inventoryCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Inventory number')),
                const SizedBox(height: 8),
                TextFormField(
                    controller: departmentCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Department / Responsible')),
                const SizedBox(height: 12),

                // Icon picker row
                Row(
                  children: [
                    const Text('Icon:'),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        final chosen = await _showIconPicker(
                            context: ctx,
                            initial:
                                IconData(currentIcon, fontFamily: currentFont));
                        if (chosen != null) {
                          currentIcon = chosen.codePoint;
                          currentFont = chosen.fontFamily;
                          // rebuild dialog UI (easy way is to pop and re-open, but that's disruptive).
                          // Instead we allow saving with the currentIcon value captured below.
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6)),
                        child: Icon(
                            IconData(currentIcon, fontFamily: currentFont),
                            size: 28),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                DropdownButtonFormField<AssetStatus>(
                  initialValue: currentStatus,
                  decoration: const InputDecoration(labelText: 'Asset status'),
                  items: AssetStatus.values.map((s) {
                    final name = s.toString().split('.').last;
                    return DropdownMenuItem(value: s, child: Text(name));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) currentStatus = v;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? true) {
                final updated = item.copyWith(
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  qrData: qrCtrl.text.trim(),
                  category: categoryCtrl.text.trim(),
                  inventoryNumber: inventoryCtrl.text.trim(),
                  location: departmentCtrl.text.trim(),
                  status: currentStatus,
                  iconCodePoint: currentIcon,
                  iconFontFamily: currentFont,
                );
                await db.addItem(updated);
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      _loadItems();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Item updated')));
    }
  }

  void _showItemDialog(Item item) {
    // Use a simple general dialog to avoid intrinsic sizing problems
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Item dialog',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder:
          (BuildContext ctx, Animation<double> anim1, Animation<double> anim2) {
        final mq = MediaQuery.of(ctx);
        final double maxWidth = mq.size.width * 0.9;
        final double dialogWidth = maxWidth.clamp(280.0, 700.0);
        final double maxHeight = mq.size.height * 0.9;

        return SafeArea(
          child: Builder(builder: (innerCtx) {
            return Center(
              child: Material(
                color: Theme.of(innerCtx).dialogBackgroundColor,
                elevation: 24,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: dialogWidth,
                    maxHeight: maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                  child: Text(item.title,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600))),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(innerCtx).pop(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if ((item.description).isNotEmpty) ...[
                            Text(item.description),
                            const SizedBox(height: 12),
                          ],
                          SizedBox(
                            width: 200,
                            height: 200,
                            child: Center(
                              child: Builder(builder: (_) {
                                try {
                                  final data = item.qrData.isNotEmpty
                                      ? item.qrData
                                      : item.inventoryNumber;
                                  return QrDisplay(data: data, size: 180);
                                } catch (e, st) {
                                  debugPrint('QrDisplay render error: $e\n$st');
                                  return const Icon(Icons.broken_image,
                                      size: 64, color: Colors.red);
                                }
                              }),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(item.inventoryNumber,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: dialogWidth),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.of(innerCtx).pop(),
                                      child: const Text('Close')),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.of(innerCtx).pop();
                                      await _printSingle(item);
                                    },
                                    child: const Text('Print'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.of(innerCtx).pop();
                                      await _editItemDialog(item);
                                    },
                                    child: const Text('Edit'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () async {
                                      final confirmed =
                                          await _confirmDelete(context, item);
                                      if (confirmed == true) {
                                        try {
                                          await db.deleteItem(item.id);
                                          _loadItems();
                                          if (mounted)
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text(
                                                        'Deleted "${item.title}"')));
                                        } catch (e, st) {
                                          debugPrint('Delete failed: $e\n$st');
                                          if (mounted)
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text(
                                                        'Delete failed: $e')));
                                        }
                                      }
                                      Navigator.of(innerCtx).pop();
                                    },
                                    child: const Text('Delete',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
            opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
            child: child);
      },
    );
  }

  // === Helper methods inserted here (inside _HomePageState, above build) ===

  void _showDbInfo() {
    try {
      final len = db.count();
      final keys = db.keys();
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('DB Info'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Box name: ${DBService.boxName}'),
                Text('Item count: $len'),
                const SizedBox(height: 8),
                const Text('Keys:'),
                for (final k in keys) Text(k),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'))
          ],
        ),
      );
    } catch (e, st) {
      debugPrint('Error showing DB info: $e\n$st');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error showing DB info: $e')));
    }
  }

  Future<void> _requestPersistence() async {
    try {
      final granted = await requestPersistentStorage();
      final msg = granted
          ? 'Persistent storage granted'
          : 'Persistent storage NOT granted';
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      debugPrint('Request persistent storage result: $granted');
    } catch (e, st) {
      debugPrint('Request persistence failed: $e\n$st');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Request storage failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    _items = db.getItems();

    return Scaffold(
      backgroundColor: const Color(0xFFFBF6F9),
      appBar: AppBar(
        title: const Text('QR Sorter'),
        elevation: 0.5,
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: 'Select all',
              icon: Icon(_selectedIds.length == _items.length
                  ? Icons.select_all
                  : Icons.select_all_outlined),
              onPressed: _toggleSelectAll,
            ),
            IconButton(
              tooltip: 'Change icon for selected',
              icon: const Icon(Icons.colorize),
              onPressed: () async {
                final chosen = await _showIconPicker(context: context);
                if (chosen != null) {
                  await _applyIconToSelected(chosen);
                }
              },
            ),
            IconButton(
              tooltip: 'Print selected',
              icon: const Icon(Icons.print),
              onPressed: _printSelected,
            ),
            IconButton(
              tooltip: 'Cancel selection',
              icon: const Icon(Icons.close),
              onPressed: _exitSelectionMode,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.import_export),
              tooltip: 'Export / Import',
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ExportImportPage()));
                _loadItems();
              },
            ),
            if (kDebugMode) ...[
              TextButton(
                  onPressed: _showDbInfo,
                  child:
                      const Text('DB', style: TextStyle(color: Colors.white))),
              TextButton(
                  onPressed: () async => await _requestPersistence(),
                  child: const Text('Storage',
                      style: TextStyle(color: Colors.white))),
            ],
            // Enter selection mode button
            IconButton(
              tooltip: 'Select items',
              icon: const Icon(Icons.check_box_outlined),
              onPressed: () => _enterSelectionMode(),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: _items.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox, size: 48, color: Colors.black26),
                      SizedBox(height: 12),
                      Text('No items yet', style: TextStyle(fontSize: 18)),
                      SizedBox(height: 8),
                      Text('Tap + to add one',
                          style: TextStyle(color: Colors.black45)),
                    ],
                  ),
                ),
              )
            : Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final Item it = _items[i];
                    final bool selected = _selectedIds.contains(it.id);
                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        leading: _selectionMode
                            ? SizedBox(
                                width: 40,
                                height: 40,
                                child: Center(
                                  child: Checkbox(
                                    value: selected,
                                    onChanged: (_) => _toggleSelection(it),
                                  ),
                                ),
                              )
                            : CircleAvatar(
                                backgroundColor: it.sorted
                                    ? Colors.green[50]
                                    : Colors.purple[50],
                                child: Icon(
                                  IconData(it.iconCodePoint,
                                      fontFamily: it.iconFontFamily),
                                  color:
                                      it.sorted ? Colors.green : Colors.purple,
                                ),
                              ),
                        title: Text(it.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(it.category.isEmpty
                            ? it.description
                            : '${it.description} • ${it.category}'),
                        trailing: _selectionMode
                            ? null
                            : Icon(
                                it.sorted ? Icons.check_circle : Icons.qr_code,
                                color: it.sorted ? Colors.green : Colors.grey),
                        onTap: () {
                          if (_selectionMode) {
                            _toggleSelection(it);
                          } else {
                            _showItemDialog(it);
                          }
                        },
                        onLongPress: () {
                          if (!_selectionMode) {
                            _enterSelectionMode(selectId: it.id);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'scan',
            tooltip: 'Scan / Manual input',
            mini: true,
            child: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              await Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ScanPage()));
              _loadItems();
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add',
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
