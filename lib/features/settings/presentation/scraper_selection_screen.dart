import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/scraper/scraper_settings_provider.dart';

class ScraperSelectionScreen extends ConsumerWidget {
  const ScraperSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(scraperSettingsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wybór źródła'),
      ),
      body: settingsAsync.when(
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
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
            const Divider(),
            _buildSourceTile(context, ref, 'Zaluknij.cc', false, false),
            _buildSourceTile(context, ref, 'Filman.cc', false, false),
            _buildSourceTile(context, ref, 'CDA-HD.cc', false, false),
            _buildSourceTile(context, ref, 'Zeriun.cc', false, false),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Błąd: $e')),
      ),
    );
  }

  Widget _buildSourceTile(
    BuildContext context,
    WidgetRef ref,
    String name,
    bool isEnabled,
    bool isAvailable,
  ) {
    return SwitchListTile(
      title: Text(
        name,
        style: TextStyle(
          color: isAvailable ? null : Theme.of(context).colorScheme.outline,
        ),
      ),
      subtitle: isAvailable 
          ? null 
          : const Text('w trakcie rozwoju', style: TextStyle(fontSize: 12)),
      value: isEnabled,
      onChanged: isAvailable 
          ? (value) => ref.read(scraperSettingsProvider.notifier).toggleScraper(name, value)
          : null,
    );
  }
}
