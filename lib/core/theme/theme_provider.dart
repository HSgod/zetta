import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final isDark = prefs.getBool('isDarkMode');
    
    if (isDark == null) return ThemeMode.system;
    return isDark ? ThemeMode.dark : ThemeMode.light;
  }

  void setCheck(bool isDark) {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    _saveTheme(isDark);
  }
  
  void setMode(ThemeMode mode) {
    state = mode;
    if (mode == ThemeMode.system) {
      ref.read(sharedPreferencesProvider).remove('isDarkMode');
    } else {
      _saveTheme(mode == ThemeMode.dark);
    }
  }

  Future<void> _saveTheme(bool isDark) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('isDarkMode', isDark);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// Nowy Provider dla Material You
class MaterialYouNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool('useMaterialYou') ?? false; // Domyślnie wyłączone
  }

  void toggle() {
    state = !state;
    ref.read(sharedPreferencesProvider).setBool('useMaterialYou', state);
  }
}

final materialYouProvider = NotifierProvider<MaterialYouNotifier, bool>(MaterialYouNotifier.new);

// Provider dla gestów wideo
class PlayerGesturesNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool('playerGestures') ?? true;
  }

  void toggle() {
    state = !state;
    ref.read(sharedPreferencesProvider).setBool('playerGestures', state);
  }
}

final playerGesturesProvider = NotifierProvider<PlayerGesturesNotifier, bool>(PlayerGesturesNotifier.new);

// Provider dla preferowanej jakości
class PreferredQualityNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString('preferredQuality') ?? 'Max';
  }

  void setQuality(String quality) {
    state = quality;
    ref.read(sharedPreferencesProvider).setString('preferredQuality', quality);
  }
}

final preferredQualityProvider = NotifierProvider<PreferredQualityNotifier, String>(PreferredQualityNotifier.new);

// Provider dla reklam (Easter Egg)
class AdsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool('ads_enabled') ?? true;
  }

  void toggle() {
    state = !state;
    ref.read(sharedPreferencesProvider).setBool('ads_enabled', state);
  }
}

final adsEnabledProvider = NotifierProvider<AdsEnabledNotifier, bool>(AdsEnabledNotifier.new);
