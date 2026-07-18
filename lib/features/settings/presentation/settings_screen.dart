import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_provider.dart';
import '../../home/presentation/providers/search_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: double.infinity),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SliverAppBar(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  floating: true,
                  pinned: true,
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings_rounded, color: Colors.red, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Ustawienia',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                  centerTitle: true,
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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

                      _buildSectionHeader('System'),
                      _buildSettingsCard([
                        _buildListTile(
                          title: 'Wyczyść dane WebView',
                          subtitle: 'Może rozwiązać problem z ładowaniem filmu',
                          icon: Icons.delete_sweep_rounded,
                          onTap: () => _showClearCacheDialog(context),
                        ),
                        _buildListTile(
                          title: 'Wyczyść historię wyszukiwania',
                          subtitle: 'Może zwolnić miejsce i usunąć stare hasła',
                          icon: Icons.history_rounded,
                          onTap: () => _showClearSearchHistoryDialog(context),
                        ),
                        ListTile(
                          leading: const Icon(Icons.swipe_rounded, size: 22, color: Colors.white60),
                          title: const Text('Gesty odtwarzacza', style: TextStyle(fontSize: 15, color: Colors.white)),
                          subtitle: const Text('Przesuń pionowo: jasność/głośność | poziomo: przewijanie', style: TextStyle(fontSize: 12, color: Colors.white60)),
                          trailing: Switch(
                            value: ref.watch(playerGesturesProvider),
                            onChanged: (v) {
                              if (v != ref.read(playerGesturesProvider)) {
                                ref.read(playerGesturesProvider.notifier).toggle();
                              }
                            },
                            activeThumbColor: Colors.red,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                        ),
                      ]),

                      _buildSectionHeader('O aplikacji'),
                      _buildSettingsCard([
                        _buildListTile(
                          title: 'Zetta v1.0.6',
                          subtitle: 'Wersja stabilna',
                          icon: Icons.info_outline_rounded,
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
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.red,
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
        gradient: const LinearGradient(
          colors: [Color(0xFF1a1a1a), Color(0xFF111111)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(children: children),
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
      title: Text(title, style: const TextStyle(fontSize: 15, color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white60)),
      leading: Icon(icon, size: 22, color: Colors.white60),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white60) : null),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Wyczyścić ciasteczka?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Wszystkie ciasteczka WebView zostaną usunięte. To może pomóc, jeśli odtwarzacz przestał działać.',
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              try {
                await CookieManager.instance().deleteAllCookies();
              } catch (_) {}
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ciasteczka zostały wyczyszczone')),
                );
              }
            },
            child: const Text('Wyczyść', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showClearSearchHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Wyczyścić historię?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Wszystkie zapytania z historii wyszukiwania zostaną bezpowrotnie usunięte.',
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(searchHistoryProvider.notifier).clearHistory();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Historia wyszukiwania została wyczyszczona')),
                );
              }
            },
            child: const Text('Wyczyść', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
