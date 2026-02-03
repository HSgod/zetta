import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Prosty notifier do zarządzania trybem motywu
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Domyślnie systemowy
    return ThemeMode.system;
  }

  void setCheck(bool isDark) {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }
  
  void setMode(ThemeMode mode) {
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
