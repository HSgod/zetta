import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Wczytanie zmiennych środowiskowych
  await dotenv.load(fileName: ".env");
  
  // Inicjalizacja biblioteki wideo
  MediaKit.ensureInitialized();

  // Inicjalizacja SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        // Wstrzykujemy instancję prefs do providera
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ZettaApp(),
    ),
  );
}

class ZettaApp extends ConsumerWidget {
  const ZettaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Zetta',
      debugShowCheckedModeBanner: false,
      
      // Temat Material Design 3
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,

      // Konfiguracja GoRouter
      routerConfig: appRouter,
    );
  }
}