import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

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
                      ]),

                      _buildSectionHeader('O aplikacji'),
                      _buildSettingsCard([
                        _buildListTile(
                          title: 'Zetta v1.0.6',
                          subtitle: 'Wersja stabilna',
                          icon: Icons.verified_user_rounded,
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
        color: Colors.grey[950],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
