import 'package:flutter/material.dart';
import 'widgets/main_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "virustotal_api_key.env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'John the Hasher',
      theme: ThemeData(
        primaryColor: const Color.fromRGBO(240, 245, 249, 1),
        scaffoldBackgroundColor: const Color.fromRGBO(240, 245, 249, 1),
      ),
      home: const MainScreen(),
    );
  }
}
