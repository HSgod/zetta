import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider dla SharedPreferences (zainicjujemy go w main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Odczytujemy zapisany stan przy starcie
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