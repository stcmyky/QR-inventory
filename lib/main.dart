import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_sorter/pages/home_page.dart';
import 'package:qr_sorter/services/db_service.dart';
import 'package:qr_sorter/utils/storage_persistent.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = DBService();
  await db.init(); // IMPORTANT: register adapter and open box before runApp

  // If running on web, attempt to request persistent storage permission.
  if (kIsWeb) {
    try {
      final persisted = await requestPersistentStorage();
      debugPrint('Persistent storage granted: $persisted');
    } catch (e) {
      debugPrint('requestPersistentStorage() failed: $e');
    }
  }

  // Print box length to verify persisted data presence (debug)
  debugPrint('Items box length (after init): ${db.count()}');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Dark grey primary for buttons
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.grey,
      brightness: Brightness.light,
      primary: Colors.grey.shade800,
    );

    final Color buttonColor = Colors.grey.shade800; // dark grey
    const Color onButtonColor = Colors.white; // text/icon color on dark buttons

    return MaterialApp(
      title: 'QR Sorter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: const Color(0xFFFBF6F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
          centerTitle: false,
        ),

        // Floating Action Button
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: buttonColor,
          foregroundColor: onButtonColor,
        ),

        // Elevated buttons (primary buttons)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: onButtonColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),

        // Outlined buttons
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: buttonColor,
            side: BorderSide(color: Colors.grey.shade700),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),

        // Text buttons
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: buttonColor,
          ),
        ),

        // Icon theme (so icons inside buttons use correct color by default)
        iconTheme: const IconThemeData(color: onButtonColor),
      ),
      home: const HomePage(),
    );
  }
}
