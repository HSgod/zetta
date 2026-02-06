import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScraperSettings {
  final Map<String, bool> enabledScrapers;
  ScraperSettings({required this.enabledScrapers});

  ScraperSettings copyWith({Map<String, bool>? enabledScrapers}) {
    return ScraperSettings(enabledScrapers: enabledScrapers ?? this.enabledScrapers);
  }
}

class ScraperSettingsNotifier extends Notifier<ScraperSettings> {
  static const String _prefKey = 'enabled_scrapers_list';

  @override
  ScraperSettings build() {
    // Domy\u015blny stan
    _loadInitial();
    return ScraperSettings(enabledScrapers: {
      'Ekino-TV': false,
      'Obejrzyj.to': false,
    });
  }

  Future<void> _loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? enabledList = prefs.getStringList(_prefKey);
    
    if (enabledList != null) {
      final Map<String, bool> loaded = {
        'Ekino-TV': enabledList.contains('Ekino-TV'),
        'Obejrzyj.to': enabledList.contains('Obejrzyj.to'),
      };
      state = state.copyWith(enabledScrapers: loaded);
    }
  }

  Future<void> toggleScraper(String name, bool enabled) async {
    final Map<String, bool> updated = Map.from(state.enabledScrapers);
    updated[name] = enabled;
    state = state.copyWith(enabledScrapers: updated);

    final prefs = await SharedPreferences.getInstance();
    final List<String> enabledList = updated.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    await prefs.setStringList(_prefKey, enabledList);
  }
}

final scraperSettingsProvider = NotifierProvider<ScraperSettingsNotifier, ScraperSettings>(() {
  return ScraperSettingsNotifier();
});
