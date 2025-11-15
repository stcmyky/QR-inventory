// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemAdapter extends TypeAdapter<Item> {
  @override
  final int typeId = 0;

  @override
  Item read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Item(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      category: fields[3] as String,
      qrData: fields[4] as String,
      inventoryNumber: fields[5] as String,
      sorted: fields[6] as bool,
      status: fields[7] as AssetStatus,
      createdAt: fields[8] as DateTime?,
      dateOfPurchase: fields[9] as DateTime?,
      price: fields[10] as double?,
      location: fields[11] as String,
      note: fields[12] as String,
      iconCodePoint: fields[13] as int,
      iconFontFamily: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Item obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.qrData)
      ..writeByte(5)
      ..write(obj.inventoryNumber)
      ..writeByte(6)
      ..write(obj.sorted)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.dateOfPurchase)
      ..writeByte(10)
      ..write(obj.price)
      ..writeByte(11)
      ..write(obj.location)
      ..writeByte(12)
      ..write(obj.note)
      ..writeByte(13)
      ..write(obj.iconCodePoint)
      ..writeByte(14)
      ..write(obj.iconFontFamily);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AssetStatusAdapter extends TypeAdapter<AssetStatus> {
  @override
  final int typeId = 1;

  @override
  AssetStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AssetStatus.available;
      case 1:
        return AssetStatus.reserved;
      case 2:
        return AssetStatus.inService;
      case 3:
        return AssetStatus.broken;
      case 4:
        return AssetStatus.vacant;
      case 5:
        return AssetStatus.loaned;
      case 6:
        return AssetStatus.damaged;
      case 7:
        return AssetStatus.writtenOff;
      default:
        return AssetStatus.available;
    }
  }

  @override
  void write(BinaryWriter writer, AssetStatus obj) {
    switch (obj) {
      case AssetStatus.available:
        writer.writeByte(0);
        break;
      case AssetStatus.reserved:
        writer.writeByte(1);
        break;
      case AssetStatus.inService:
        writer.writeByte(2);
        break;
      case AssetStatus.broken:
        writer.writeByte(3);
        break;
      case AssetStatus.vacant:
        writer.writeByte(4);
        break;
      case AssetStatus.loaned:
        writer.writeByte(5);
        break;
      case AssetStatus.damaged:
        writer.writeByte(6);
        break;
      case AssetStatus.writtenOff:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
