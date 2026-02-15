import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _tapCount = 0;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark || 
                   (themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final useMaterialYou = ref.watch(materialYouProvider);
    final useGestures = ref.watch(playerGesturesProvider);
    final adsEnabled = ref.watch(adsEnabledProvider);

    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: double.infinity),
          child: CustomScrollView(
            slivers: [
              const SliverAppBar(
                floating: true,
                pinned: true,
                title: Text('Ustawienia'),
                centerTitle: true,
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Wygląd'),
                    _buildSettingsCard([
                      _buildSwitchTile(
                        title: 'Tryb ciemny',
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

                    _buildSectionHeader('Źródła'),
                    _buildSettingsCard([
                      _buildListTile(
                        title: 'Wybór źródła',
                        subtitle: 'Włącz lub wyłącz poszczególne serwisy',
                        icon: Icons.source_rounded,
                        onTap: () => context.push('/settings/scrapers'),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
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
                        title: 'Zetta v1.0.6',
                        subtitle: adsEnabled ? 'Wersja stabilna' : 'Wersja stabilna (Ads Disabled)',
                        icon: Icons.verified_user_rounded,
                        onTap: () {
                          _tapCount++;
                          if (_tapCount == 15) {
                            ref.read(adsEnabledProvider.notifier).toggle();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(adsEnabled ? 'REKLAMY WYŁĄCZONE' : 'REKLAMY WŁĄCZONE'),
                                backgroundColor: adsEnabled ? Colors.green : Colors.red,
                              ),
                            );
                            _tapCount = 0;
                          }
                        },
                      ),
                      _buildListTile(
                        title: 'Postaw mi kawę ☕',
                        subtitle: 'Wesprzyj rozwój aplikacji',
                        icon: Icons.coffee_rounded,
                        onTap: () async {
                          final url = Uri.parse('https://buymeacoffee.com/hsgod');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
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
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
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
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
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
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      secondary: Icon(icon, size: 22),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
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
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      leading: Icon(icon, size: 22),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wyczyścić ciasteczka?'),
        content: const Text('Wszystkie ciasteczka WebView zostaną usunięte. To może pomóc, jeśli odtwarzacz przestał działać.'),
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
