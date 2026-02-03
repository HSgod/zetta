import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
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