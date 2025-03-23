import 'dart:io';

import 'package:flutter/material.dart';
import 'package:myapp/screens/tabbed_main_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "virustotal_api_key.env");
  initDatabase();

  runApp(const MyApp());
}

void initDatabase() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Initialize FFI for desktop platforms
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Argus',
      theme: ThemeData(
        primaryColor: const Color.fromRGBO(240, 245, 249, 1),
        scaffoldBackgroundColor: const Color.fromRGBO(240, 245, 249, 1),
      ),
      home: const TabbedMainScreen(),
    );
  }
}
