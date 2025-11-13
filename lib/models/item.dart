// lib/models/item.dart
// Hive-annotated Item model. Run build_runner to generate item.g.dart.

import 'package:hive/hive.dart';

part 'item.g.dart';

@HiveType(typeId: 1)
enum AssetStatus {
  @HiveField(0)
  available,
  @HiveField(1)
  reserved,
  @HiveField(2)
  inService,
  @HiveField(3)
  broken,
  // legacy / app-specific states
  @HiveField(4)
  vacant,
  @HiveField(5)
  loaned,
  @HiveField(6)
  damaged,
  @HiveField(7)
  writtenOff,
}

@HiveType(typeId: 0)
class Item extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String category;

  @HiveField(4)
  final String qrData;

  @HiveField(5)
  final String inventoryNumber;

  @HiveField(6)
  final bool sorted;

  @HiveField(7)
  final AssetStatus status;

  // Persistence / details
  @HiveField(8)
  final DateTime? createdAt;

  @HiveField(9)
  final DateTime? dateOfPurchase;

  @HiveField(10)
  final double? price;

  @HiveField(11)
  final String location;

  @HiveField(12)
  final String note;

  // Icon support
  @HiveField(13)
  final int iconCodePoint;

  @HiveField(14)
  final String? iconFontFamily;

  Item({
    required this.id,
    required this.title,
    this.description = '',
    this.category = '',
    this.qrData = '',
    this.inventoryNumber = '',
    this.sorted = false,
    this.status = AssetStatus.available,
    this.createdAt,
    this.dateOfPurchase,
    this.price,
    this.location = '',
    this.note = '',
    this.iconCodePoint = 0xe87a, // default to qr_code
    this.iconFontFamily,
  });

  Item copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? qrData,
    String? inventoryNumber,
    bool? sorted,
    AssetStatus? status,
    DateTime? createdAt,
    DateTime? dateOfPurchase,
    double? price,
    String? location,
    String? note,
    int? iconCodePoint,
    String? iconFontFamily,
  }) {
    return Item(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      qrData: qrData ?? this.qrData,
      inventoryNumber: inventoryNumber ?? this.inventoryNumber,
      sorted: sorted ?? this.sorted,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dateOfPurchase: dateOfPurchase ?? this.dateOfPurchase,
      price: price ?? this.price,
      location: location ?? this.location,
      note: note ?? this.note,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
    );
  }

  // JSON helpers (if you use JSON persistence somewhere)
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'qrData': qrData,
        'inventoryNumber': inventoryNumber,
        'sorted': sorted,
        'status': status.index,
        'createdAt': createdAt?.toIso8601String(),
        'dateOfPurchase': dateOfPurchase?.toIso8601String(),
        'price': price,
        'location': location,
        'note': note,
        'iconCodePoint': iconCodePoint,
        'iconFontFamily': iconFontFamily,
      };

  factory Item.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(Object? v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v as String);
      } catch (_) {
        return null;
      }
    }

    final statusIndex = (json['status'] is int) ? (json['status'] as int) : 0;
    AssetStatus safeStatus = AssetStatus.available;
    if (statusIndex >= 0 && statusIndex < AssetStatus.values.length) {
      safeStatus = AssetStatus.values[statusIndex];
    }

    return Item(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      qrData: json['qrData'] as String? ?? '',
      inventoryNumber: json['inventoryNumber'] as String? ?? '',
      sorted: json['sorted'] as bool? ?? false,
      status: safeStatus,
      createdAt: parseDt(json['createdAt']),
      dateOfPurchase: parseDt(json['dateOfPurchase']),
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : null,
      location: json['location'] as String? ?? '',
      note: json['note'] as String? ?? '',
      iconCodePoint: json['iconCodePoint'] as int? ?? 0xe87a,
      iconFontFamily: json['iconFontFamily'] as String?,
    );
  }
}
