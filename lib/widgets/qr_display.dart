import 'package:flutter/material.dart';

/// Simple QR display that uses a public QR image generator service.
/// This avoids package conflicts and works on Android and Web.
/// Note: this requires network access to fetch the generated PNG.
class QrDisplay extends StatelessWidget {
  final String data;
  final double size;
  final Color? backgroundColor;

  const QrDisplay({
    super.key,
    required this.data,
    this.size = 200,
    this.backgroundColor,
  });

  String _qrImageUrl() {
    final int px = size.round();
    final encoded = Uri.encodeComponent(data);
    // Using api.qrserver.com which returns an image/png of the QR
    return 'https://api.qrserver.com/v1/create-qr-code/?size=${px}x$px&format=png&data=$encoded';
  }

  @override
  Widget build(BuildContext context) {
    final url = _qrImageUrl();
    return Container(
      color: backgroundColor ?? Colors.white,
      padding: const EdgeInsets.all(6),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        // a small placeholder while loading
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: size,
            height: size,
            child: Center(
              child: SizedBox(
                width: size * 0.25,
                height: size * 0.25,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // If the network request fails, show the raw text as fallback
          return Container(
            width: size,
            height: size,
            color: backgroundColor ?? Colors.white,
            alignment: Alignment.center,
            child: Text(
              data,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          );
        },
      ),
    );
  }
}
