import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:media_kit/media_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Wczytanie zmiennych środowiskowych
  await dotenv.load(fileName: ".env");
  
  // Inicjalizacja biblioteki wideo
  MediaKit.ensureInitialized();

  runApp(
    const ProviderScope(
      child: ZettaApp(),
    ),
  );
}

class ZettaApp extends StatelessWidget {
  const ZettaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Zetta',
      debugShowCheckedModeBanner: false,
      
      // Temat Material Design 3
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      // Konfiguracja GoRouter
      routerConfig: appRouter,
    );
  }
}