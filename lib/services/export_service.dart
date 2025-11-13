// Web-first export/import helpers.
// - CSV generator
// - Simple DOC (RTF/plain) generator
// - PDF generator (uses the `pdf` package).
// - Downloads on web using anchor; on non-web it throws (you can extend it to save to filesystem).

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart'
    as pw; // ensure pdf package is in pubspec.yaml
import 'package:qr_sorter/models/item.dart';
import 'package:qr_sorter/services/db_service.dart';

// For web downloads: dart:html is only valid on web targets.
// Tell the analyzer to ignore the web-libraries warning for this import.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Main export utilities. Web-first implementation.
class ExportService {
  static Future<List<Item>> _fetchItems() async {
    // Use your existing DBService.getItems() (synchronous) if you don't have an async getAllItems().
    // Wrap in Future so callers can await uniformly.
    final list = DBService().getItems();
    return Future.value(list);
  }

  // CSV
  static String itemsToCsvString(List<Item> items) {
    final sb = StringBuffer();
    // header
    sb.writeln(
        'id,title,description,qrData,category,inventoryNumber,dateOfPurchase,price,location,status,note,createdAt');
    for (final it in items) {
      final date = it.dateOfPurchase?.toIso8601String() ?? '';
      final price = (it.price != null) ? it.price.toString() : '';
      final status = it.status.index;
      // Escape double quotes
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

  // DOC (simple RTF wrapper). Word can open .doc files saved as plain text or RTF.
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

  // PDF (simple table)
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

  // Trigger download (web)
  static Future<void> triggerDownload(Uint8List bytes, String filename) async {
    if (kIsWeb) {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = filename;
      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    } else {
      // Non-web: implement file saving using path_provider / File / share_plus, etc.
      // For simplicity we throw and you can add mobile/desktop saving later.
      throw Exception(
          'Download/save is only implemented for web in this version.');
    }
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
      // Map header -> cols
      final map = <String, String>{};
      for (var j = 0; j < header.length && j < cols.length; j++) {
        map[header[j]] = cols[j];
      }
      // Build Item (best effort)
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
      // Save to DB (uses your DBService API)
      await DBService().addItem(item);
      entries.add(item);
    }

    return entries;
  }

  // Very small CSV parser that respects quoted fields.
  static List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // escaped quote
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
