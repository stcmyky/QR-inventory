// Updated AddItemPage: fixed null crash when building the AssetStatus dropdown
// (the original code used a map with missing keys and a forced `!` which could
// throw for enum values not present in the map).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_sorter/models/item.dart';
import 'package:qr_sorter/services/db_service.dart';

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _qrDataCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _inventoryCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  DateTime? _dateOfPurchase;
  AssetStatus _status = AssetStatus.vacant;

  @override
  void initState() {
    super.initState();
    // Auto-generate an inventory number (you can change this scheme)
    final generated = 'INV-${DateTime.now().millisecondsSinceEpoch}';
    _inventoryCtrl.text = generated;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _qrDataCtrl.dispose();
    _categoryCtrl.dispose();
    _inventoryCtrl.dispose();
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfPurchase ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        _dateOfPurchase = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final title = _titleCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    final qrData = _qrDataCtrl.text.trim();
    final category = _categoryCtrl.text.trim();
    final inventoryNumber = _inventoryCtrl.text.trim();
    final price =
        _priceCtrl.text.isEmpty ? null : double.tryParse(_priceCtrl.text);
    final location = _locationCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    final item = Item(
      id: id,
      title: title,
      description: description,
      qrData: qrData,
      category: category,
      sorted: false,
      createdAt: DateTime.now(),
      inventoryNumber: inventoryNumber,
      dateOfPurchase: _dateOfPurchase,
      price: price,
      location: location,
      status: _status,
      note: note,
    );

    try {
      await DBService().addItem(item);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Item saved')));
        Navigator.of(context).pop(true); // indicate saved
      }
    } catch (e) {
      debugPrint('Failed to save item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Not set';
    return DateFormat.yMMMd().format(d);
  }

  String _assetStatusLabel(AssetStatus s) {
    // Provide a label for every enum value. Use a fallback (enum name) if needed.
    switch (s) {
      case AssetStatus.available:
        return 'Available';
      case AssetStatus.reserved:
        return 'Reserved';
      case AssetStatus.inService:
        return 'In service';
      case AssetStatus.broken:
        return 'Broken';
      case AssetStatus.vacant:
        return 'Vacant';
      case AssetStatus.loaned:
        return 'Loaned';
      case AssetStatus.damaged:
        return 'Damaged';
      case AssetStatus.writtenOff:
        return 'Written off';
      default:
        return s.toString().split('.').last;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Item'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Title (required)
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Title', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter a title'
                    : null,
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                    labelText: 'Description', border: OutlineInputBorder()),
                minLines: 1,
                maxLines: 4,
              ),
              const SizedBox(height: 12),

              // QR data (optional)
              TextFormField(
                controller: _qrDataCtrl,
                decoration: const InputDecoration(
                    labelText: 'QR data', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),

              // Category
              TextFormField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(
                    labelText: 'Category', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),

              // Inventory number (auto-generated but editable)
              TextFormField(
                controller: _inventoryCtrl,
                decoration: const InputDecoration(
                    labelText: 'Inventory number',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),

              // Date of purchase
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Date of purchase',
                          border: OutlineInputBorder()),
                      child: Row(
                        children: [
                          Expanded(child: Text(_formatDate(_dateOfPurchase))),
                          TextButton(
                            onPressed: _pickDate,
                            child: const Text('Pick'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Price
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(
                    labelText: 'Price',
                    prefixText: '\$',
                    border: OutlineInputBorder()),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  return double.tryParse(v) == null
                      ? 'Enter a valid number'
                      : null;
                },
              ),
              const SizedBox(height: 12),

              // Location / Department / Responsible
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                    labelText: 'Department / Room / Responsible',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),

              // Status dropdown
              DropdownButtonFormField<AssetStatus>(
                initialValue: _status,
                decoration: const InputDecoration(
                    labelText: 'Asset status', border: OutlineInputBorder()),
                items: AssetStatus.values.map((s) {
                  final text = _assetStatusLabel(s);
                  return DropdownMenuItem(value: s, child: Text(text));
                }).toList(),
                onChanged: (v) =>
                    setState(() => _status = v ?? AssetStatus.vacant),
              ),
              const SizedBox(height: 12),

              // Note / Manufacturer / Type
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                    labelText: 'Note / Manufacturer / Type',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
