import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_sorter/services/export_service.dart';

class ExportImportPage extends StatefulWidget {
  const ExportImportPage({super.key});

  @override
  State<ExportImportPage> createState() => _ExportImportPageState();
}

class _ExportImportPageState extends State<ExportImportPage> {
  bool _busy = false;
  String _status = '';

  Future<void> _exportCsv() async {
    setState(() {
      _busy = true;
      _status = 'Generating CSV...';
    });
    try {
      final bytes = await ExportService.exportCsvBytes();
      await ExportService.triggerDownload(bytes, 'items.csv');
      setState(() => _status = 'CSV exported');
    } catch (e) {
      setState(() => _status = 'Export failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _exportDoc() async {
    setState(() {
      _busy = true;
      _status = 'Generating DOC...';
    });
    try {
      final bytes = await ExportService.exportDocBytes();
      await ExportService.triggerDownload(bytes, 'items.doc'); // plain/rtf
      setState(() => _status = 'DOC exported');
    } catch (e) {
      setState(() => _status = 'Export failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() {
      _busy = true;
      _status = 'Generating PDF...';
    });
    try {
      final bytes = await ExportService.exportPdfBytes();
      await ExportService.triggerDownload(bytes, 'items.pdf');
      setState(() => _status = 'PDF exported');
    } catch (e) {
      setState(() => _status = 'Export failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _importFile() async {
    setState(() {
      _busy = true;
      _status = 'Picking file...';
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _status = 'Import cancelled');
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _status = 'No data in file');
        return;
      }

      final text = utf8.decode(bytes);
      // We only implement CSV import for now.
      final imported = await ExportService.importCsvText(text);

      setState(() => _status = 'Imported ${imported.length} items');
    } catch (e) {
      setState(() => _status = 'Import failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Widget _buildButton(String label, VoidCallback onPressed, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton(
        onPressed: _busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: color != null && color.computeLuminance() < 0.5
              ? Colors.white
              : Colors.black87,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export / Import'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Export options',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            // Provide a light background so export buttons aren't rendered dark
            _buildButton('Export CSV', _exportCsv, color: Colors.grey.shade200),
            _buildButton('Export DOC (simple)', _exportDoc,
                color: Colors.grey.shade200),
            _buildButton('Export PDF', _exportPdf, color: Colors.grey.shade200),
            const Divider(height: 32),
            const Text('Import',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildButton('Import CSV / TXT', _importFile,
                color: const Color.fromARGB(255, 57, 167, 63)),
            const SizedBox(height: 12),
            if (_busy) const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text(_status),
          ],
        ),
      ),
    );
  }
}
