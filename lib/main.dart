import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/library/presentation/providers/download_provider.dart';

Future<void> _clearAppCache() async {
  // Opóźniamy czyszczenie cache, aby nie konkurowało z zasobami przy starcie
  Future.delayed(const Duration(seconds: 10), () async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final List<FileSystemEntity> entities = await tempDir.list().toList();
        for (final entity in entities) {
          try {
            // Próbujemy usunąć tylko te pliki/foldery, które nie są zablokowane
            // i które prawdopodobnie należą do naszej aplikacji (np. zawierające 'flutter' w nazwie)
            if (entity.path.contains('flutter') || entity.path.contains('media_kit')) {
               await entity.delete(recursive: true);
            }
          } catch (_) {
            // Ignorujemy błędy dostępu do pojedynczych plików
          }
        }
        debugPrint("Czyszczenie specyficznego cache zakończone.");
      }
    } catch (e) {
      debugPrint("Błąd podczas czyszczenia cache: $e");
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Ładowanie zmiennych środowiskowych i inicjalizacja MediaKit równolegle
  await Future.wait([
    dotenv.load(fileName: ".env"),
    Future.sync(() => MediaKit.ensureInitialized()),
    MobileAds.instance.initialize(),
    FlutterDownloader.initialize(debug: true, ignoreSsl: true),
  ]);
  
  FlutterDownloader.registerCallback(downloadCallback);
  
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ZettaApp(),
    ),
  );

  // Czyścimy cache po uruchomieniu aplikacji i wyświetleniu UI
  _clearAppCache();
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
