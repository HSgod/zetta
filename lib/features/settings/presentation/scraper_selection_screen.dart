import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/scraper/scraper_settings_provider.dart';

class ScraperSelectionScreen extends ConsumerWidget {
  const ScraperSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(scraperSettingsProvider);
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.source_rounded, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text(
              'Wybór źródła',
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
      body: settingsAsync.when(
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            _buildSectionHeader('Aktywne źródła'),
            _buildSettingsCard([
              _buildSourceTile(
                context,
                ref,
                'Ekino-TV',
                settings.enabledScrapers['Ekino-TV'] ?? false,
                true,
              ),
              _buildSourceTile(
                context,
                ref,
                'Obejrzyj.to',
                settings.enabledScrapers['Obejrzyj.to'] ?? false,
                true,
              ),
              _buildSourceTile(
                context,
                ref,
                'Zaluknij.cc',
                settings.enabledScrapers['Zaluknij.cc'] ?? false,
                true,
              ),
            ]),
            const SizedBox(height: 16),
            _buildSectionHeader('W trakcie rozwoju'),
            Opacity(
              opacity: 0.4,
              child: _buildSettingsCard([
                _buildSourceTile(context, ref, 'Filman.cc', false, false),
                _buildSourceTile(context, ref, 'CDA-HD.cc', false, false),
                _buildSourceTile(context, ref, 'Zeriun.cc', false, false),
              ]),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.red)),
        error: (e, _) => Center(child: Text('Błąd: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
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

  Widget _buildSourceTile(
    BuildContext context,
    WidgetRef ref,
    String name,
    bool isEnabled,
    bool isAvailable,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(
        Icons.play_circle_rounded,
        color: isAvailable ? (isEnabled ? Colors.red : Colors.grey) : Colors.grey,
        size: 28,
      ),
      title: Text(
        name,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      subtitle: Text(
        isAvailable ? (isEnabled ? 'Aktywny' : 'Wyłączony') : 'W trakcie rozwoju',
        style: const TextStyle(color: Colors.white60, fontSize: 13),
      ),
      trailing: Switch(
        value: isEnabled,
        activeThumbColor: Colors.red,
        onChanged: isAvailable 
            ? (value) => ref.read(scraperSettingsProvider.notifier).toggleScraper(name, value)
            : null,
      ),
    );
  }
}
