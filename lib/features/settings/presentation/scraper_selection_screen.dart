import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/scraper/scraper_settings_provider.dart';

class ScraperSelectionScreen extends ConsumerWidget {
  const ScraperSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(scraperSettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wybór scrapera'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildScraperTile(
            context,
            ref,
            'Ekino-TV',
            settings.enabledScrapers['Ekino-TV'] ?? false,
            true,
          ),
          _buildScraperTile(
            context,
            ref,
            'Obejrzyj.to',
            settings.enabledScrapers['Obejrzyj.to'] ?? false,
            true,
          ),
          const Divider(),
          _buildScraperTile(context, ref, 'Zaluknij.cc', false, false),
          _buildScraperTile(context, ref, 'Filman.cc', false, false),
          _buildScraperTile(context, ref, 'CDA-HD.cc', false, false),
          _buildScraperTile(context, ref, 'Zeriun.cc', false, false),
        ],
      ),
    );
  }

  Widget _buildScraperTile(
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
