import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScraperSettings {
  final Map<String, bool> enabledScrapers;
  ScraperSettings({required this.enabledScrapers});

  ScraperSettings copyWith({Map<String, bool>? enabledScrapers}) {
    return ScraperSettings(enabledScrapers: enabledScrapers ?? this.enabledScrapers);
  }
}

class ScraperSettingsNotifier extends AsyncNotifier<ScraperSettings> {
  static const String _prefKey = 'enabled_scrapers_list';

  @override
  Future<ScraperSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? enabledList = prefs.getStringList(_prefKey);
    
    if (enabledList != null) {
      return ScraperSettings(enabledScrapers: {
        'Ekino-TV': enabledList.contains('Ekino-TV'),
        'Obejrzyj.to': enabledList.contains('Obejrzyj.to'),
        'Zaluknij.cc': enabledList.contains('Zaluknij.cc'),
      });
    }

    // Domyślnie wszystkie wyłączone przy pierwszym uruchomieniu
    return ScraperSettings(enabledScrapers: {
      'Ekino-TV': false,
      'Obejrzyj.to': false,
      'Zaluknij.cc': false,
    });
  }

  Future<void> toggleScraper(String name, bool enabled) async {
    final currentSettings = state.value;
    if (currentSettings == null) return;

    final Map<String, bool> updated = Map.from(currentSettings.enabledScrapers);
    updated[name] = enabled;
    
    state = AsyncData(currentSettings.copyWith(enabledScrapers: updated));

    final prefs = await SharedPreferences.getInstance();
    final List<String> enabledList = updated.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    await prefs.setStringList(_prefKey, enabledList);
  }
}

final scraperSettingsProvider = AsyncNotifierProvider<ScraperSettingsNotifier, ScraperSettings>(() {
  return ScraperSettingsNotifier();
});