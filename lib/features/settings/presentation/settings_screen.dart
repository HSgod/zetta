import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark || 
                   (themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Tryb Ciemny'),
            subtitle: Text(themeMode == ThemeMode.system ? 'Systemowy' : (isDark ? 'Włączony' : 'Wyłączony')),
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            value: isDark,
            onChanged: (value) {
              ref.read(themeModeProvider.notifier).setCheck(value);
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Źródła wideo'),
            subtitle: const Text('Wybierz serwisy (wkrótce)'),
            leading: const Icon(Icons.source),
            enabled: false, // Placeholder
          ),
          ListTile(
            title: const Text('O aplikacji'),
            subtitle: const Text('Zetta v1.0.0'),
            leading: const Icon(Icons.info),
          ),
        ],
      ),
    );
  }
}
