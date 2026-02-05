import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

Future<void> _clearAppCache() async {
  try {
    final tempDir = await getTemporaryDirectory();
    if (tempDir.existsSync()) {
      // Usuwamy zawartość asynchronicznie, aby nie blokować startu aplikacji
      await tempDir.delete(recursive: true);
    }
  } catch (e) {
    debugPrint("Błąd podczas czyszczenia cache: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  MediaKit.ensureInitialized();
  
  // Czyścimy cache w tle po starcie, aby nie blokować ładowania danych
  _clearAppCache();
  
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
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
    final useMaterialYou = ref.watch(materialYouProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (lightDynamic != null && darkDynamic != null && useMaterialYou) {
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          lightColorScheme = AppTheme.light.colorScheme;
          darkColorScheme = AppTheme.dark.colorScheme;
        }

        return MaterialApp.router(
          title: 'Zetta',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light.copyWith(colorScheme: lightColorScheme),
          darkTheme: AppTheme.dark.copyWith(colorScheme: darkColorScheme),
          themeMode: themeMode,
          routerConfig: appRouter,
        );
      },
    );
  }
}
