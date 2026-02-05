import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark || 
                   (themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final useMaterialYou = ref.watch(materialYouProvider);
    final useGestures = ref.watch(playerGesturesProvider);
    final preferredQuality = ref.watch(preferredQualityProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            title: const Text('Ustawienia'),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Wygląd'),
                _buildSettingsCard([
                  _buildSwitchTile(
                    title: 'Tryb Ciemny',
                    subtitle: themeMode == ThemeMode.system ? 'Podążaj za systemem' : 'Zawsze włączony/wyłączony',
                    icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    value: isDark,
                    onChanged: (val) => ref.read(themeModeProvider.notifier).setCheck(val),
                  ),
                  _buildSwitchTile(
                    title: 'Material You',
                    subtitle: 'Dynamiczne kolory z tapety (Android 12+)',
                    icon: Icons.palette_rounded,
                    value: useMaterialYou,
                    onChanged: (val) => ref.read(materialYouProvider.notifier).toggle(),
                  ),
                ]),

                _buildSectionHeader('Odtwarzacz'),
                _buildSettingsCard([
                  _buildSwitchTile(
                    title: 'Gesty wideo',
                    subtitle: 'Dwuklik aby przewijać o 10s',
                    icon: Icons.gesture_rounded,
                    value: useGestures,
                    onChanged: (val) => ref.read(playerGesturesProvider.notifier).toggle(),
                  ),
                ]),

                _buildSectionHeader('System'),
                _buildSettingsCard([
                  _buildListTile(
                    title: 'Wyczyść dane WebView',
                    subtitle: 'Może rozwiązać problem z ładowaniem filmu',
                    icon: Icons.delete_sweep_rounded,
                    onTap: () => _showClearCacheDialog(context),
                  ),
                ]),

                _buildSectionHeader('O aplikacji'),
                _buildSettingsCard([
                  _buildListTile(
                    title: 'Zetta v1.0.1',
                    subtitle: 'Wersja stabilna',
                    icon: Icons.verified_user_rounded,
                  ),
                  _buildListTile(
                    title: 'Twórca',
                    subtitle: 'HSgod',
                    icon: Icons.terminal_rounded,
                    onTap: () async {
                      final url = Uri.parse('https://github.com/HSgod');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ]),
                const SizedBox(height: 100), // Miejsce na pływający pasek
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      secondary: Icon(icon),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      leading: Icon(icon),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wyczyścić ciasteczka?'),
        content: const Text('Wszystkie ciasteczka WebView zostaną usunięte. To może pomóc, jeśli sniffer przestał działać.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
          FilledButton(
            onPressed: () async {
              await CookieManager.instance().deleteAllCookies();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ciasteczka zostały wyczyszczone')),
                );
              }
            },
            child: const Text('Wyczyść'),
          ),
        ],
      ),
    );
  }
}
