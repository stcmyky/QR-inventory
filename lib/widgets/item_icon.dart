import 'package:flutter/material.dart';
import 'package:qr_sorter/models/item.dart';

/// Widget to render an Item's icon safely with a fallback font family.
/// Use this instead of constructing IconData(..., fontFamily: item.iconFontFamily)
/// directly, because some platforms/web require a concrete font family.
class ItemIcon extends StatelessWidget {
  final Item item;
  final double size;
  final Color? color;

  const ItemIcon({
    Key? key,
    required this.item,
    this.size = 20,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use MaterialIcons as fallback when iconFontFamily is null or empty.
    final family = (item.iconFontFamily?.trim().isNotEmpty ?? false)
        ? item.iconFontFamily
        : 'MaterialIcons';

    return Icon(
      IconData(item.iconCodePoint, fontFamily: family),
      size: size,
      color: color,
    );
  }
}
