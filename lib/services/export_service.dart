// lib/services/export_service.dart
// Cross-platform export/import helpers.
// Core generation logic (CSV, RTF, PDF, CSV import).
// The actual "download/save" action is delegated to a platform-specific
// implementation via conditional import so dart:html is only referenced on web
// and dart:io/path_provider only on non-web targets.

import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/widgets.dart'
    as pw; // ensure pdf package is in pubspec.yaml
import 'package:qr_sorter/models/item.dart';
import 'package:qr_sorter/services/db_service.dart';

// Conditional import: choose web implementation when dart.library.html is available,
// otherwise use the IO implementation.
import 'export_service_io.dart' if (dart.library.html) 'export_service_web.dart'
    as platform;

/// Main export utilities. Web/IO split done only for the final save/download step.
class ExportService {
  static Future<List<Item>> _fetchItems() async {
    final list = DBService().getItems();
    return Future.value(list);
  }

  // CSV
  static String itemsToCsvString(List<Item> items) {
    final sb = StringBuffer();
    sb.writeln(
        'id,title,description,qrData,category,inventoryNumber,dateOfPurchase,price,location,status,note,createdAt');
    for (final it in items) {
      final date = it.dateOfPurchase?.toIso8601String() ?? '';
      final price = (it.price != null) ? it.price.toString() : '';
      final status = it.status.index;
      String escape(String s) => '"${s.replaceAll('"', '""')}"';
      sb.writeAll([
        escape(it.id),
        escape(it.title),
        escape(it.description),
        escape(it.qrData),
        escape(it.category),
        escape(it.inventoryNumber),
        escape(date),
        escape(price),
        escape(it.location),
        escape(status.toString()),
        escape(it.note),
        escape(it.createdAt?.toIso8601String() ?? ''),
      ], ',');
      sb.writeln();
    }
    return sb.toString();
  }

  static Future<Uint8List> exportCsvBytes() async {
    final items = await _fetchItems();
    final csv = itemsToCsvString(items);
    return Uint8List.fromList(utf8.encode(csv));
  }

  // DOC (RTF)
  static Future<Uint8List> exportDocBytes() async {
    final items = await _fetchItems();
    final sb = StringBuffer();
    sb.writeln('{\\rtf1\\ansi');
    sb.writeln('\\b Items export \\b0\\par');
    for (final it in items) {
      sb.writeln('\\par');
      sb.writeln('\\b Title:\\b0 ${_escapeRtf(it.title)}\\par');
      sb.writeln('ID: ${_escapeRtf(it.id)}\\par');
      sb.writeln('Category: ${_escapeRtf(it.category)}\\par');
      sb.writeln('Inventory: ${_escapeRtf(it.inventoryNumber)}\\par');
      sb.writeln('Price: ${it.price ?? ''}\\par');
      sb.writeln('Location: ${_escapeRtf(it.location)}\\par');
      sb.writeln('\\par');
    }
    sb.writeln('}');
    return Uint8List.fromList(utf8.encode(sb.toString()));
  }

  static String _escapeRtf(String s) {
    return s
        .replaceAll('\\', r'\\')
        .replaceAll('{', r'\{')
        .replaceAll('}', r'\}');
  }

  // PDF
  static Future<Uint8List> exportPdfBytes() async {
    final items = await _fetchItems();
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(build: (context) {
        return [
          pw.Header(level: 0, child: pw.Text('Items export')),
          pw.Table.fromTextArray(
            headers: ['Title', 'Category', 'Inventory', 'Price', 'Location'],
            data: items
                .map((it) => [
                      it.title,
                      it.category,
                      it.inventoryNumber,
                      it.price?.toString() ?? '',
                      it.location
                    ])
                .toList(),
          ),
        ];
      }),
    );
    final bytes = await doc.save();
    return Uint8List.fromList(bytes);
  }

  // Platform-abstracted download/save. On web this triggers a browser download and
  // returns null, on IO it saves file and returns the saved file path as String.
  static Future<String?> triggerDownload(
      Uint8List bytes, String filename) async {
    return platform.triggerDownload(bytes, filename);
  }

  // Import CSV text (simple parser)
  static Future<List<Item>> importCsvText(String csvText) async {
    final lines = const LineSplitter().convert(csvText);
    if (lines.isEmpty) return [];

    final header = _splitCsvLine(lines.first);
    final entries = <Item>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cols = _splitCsvLine(line);
      final map = <String, String>{};
      for (var j = 0; j < header.length && j < cols.length; j++) {
        map[header[j]] = cols[j];
      }
      final item = Item(
        id: map['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        qrData: map['qrData'] ?? '',
        category: map['category'] ?? '',
        sorted: false,
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
        inventoryNumber: map['inventoryNumber'] ?? '',
        dateOfPurchase:
            map['dateOfPurchase'] != null && map['dateOfPurchase']!.isNotEmpty
                ? DateTime.tryParse(map['dateOfPurchase']!)
                : null,
        price: map['price'] != null && map['price']!.isNotEmpty
            ? double.tryParse(map['price']!)
            : null,
        location: map['location'] ?? '',
        status: (map['status'] != null && int.tryParse(map['status']!) != null)
            ? AssetStatus.values[int.parse(map['status']!)]
            : AssetStatus.vacant,
        note: map['note'] ?? '',
      );
      await DBService().addItem(item);
      entries.add(item);
    }

    return entries;
  }

  // CSV parsing helper that respects quoted fields.
  static List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        result.add(sb.toString());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    result.add(sb.toString());
    return result;
  }
}
