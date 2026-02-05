import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/library_provider.dart';
import '../../home/presentation/widgets/media_card.dart';

import '../../home/domain/media_item.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  void _showRemoveDialog(BuildContext context, WidgetRef ref, MediaItem item, String listType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń z listy?'),
        content: Text('Czy chcesz usunąć "${item.title}" z tej sekcji?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              if (listType == 'continue') {
                ref.read(continueWatchingProvider.notifier).removeFromContinue(item.id);
              } else if (listType == 'history') {
                ref.read(historyProvider.notifier).removeFromHistory(item.id);
              } else if (listType == 'favorites') {
                ref.read(favoritesProvider.notifier).toggleFavorite(item);
              }
              Navigator.pop(context);
            },
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final history = ref.watch(historyProvider);
    final continueWatching = ref.watch(continueWatchingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moja biblioteka'),
        centerTitle: true,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSection(
            context,
            title: 'Kontynuuj oglądanie',
            items: continueWatching,
            emptyMessage: 'Nie masz rozpoczętych seansów',
            icon: Icons.play_circle_outline,
            onLongPress: (item) => _showRemoveDialog(context, ref, item, 'continue'),
          ),
          _buildSection(
            context,
            title: 'Ulubione',
            items: favorites,
            emptyMessage: 'Twoja lista ulubionych jest pusta',
            icon: Icons.favorite_border,
            onLongPress: (item) => _showRemoveDialog(context, ref, item, 'favorites'),
          ),
          _buildSection(
            context,
            title: 'Ostatnio oglądane',
            items: history,
            emptyMessage: 'Brak historii oglądania',
            icon: Icons.history,
            onLongPress: (item) => _showRemoveDialog(context, ref, item, 'history'),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

    Widget _buildSection(

      BuildContext context, {

      required String title,

      required List<MediaItem> items,

      required String emptyMessage,

      required IconData icon,

      void Function(MediaItem)? onLongPress,

    }) {

      final theme = Theme.of(context);

  

      return SliverToBoxAdapter(

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Padding(

              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),

              child: Text(

                title,

                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),

              ),

            ),

            if (items.isEmpty)

              Padding(

                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),

                child: Container(

                  padding: const EdgeInsets.all(24),

                  decoration: BoxDecoration(

                    color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.5),

                    borderRadius: BorderRadius.circular(20),

                  ),

                  child: Row(

                    children: [

                      Icon(icon, color: theme.colorScheme.outline, size: 32),

                      const SizedBox(width: 16),

                      Expanded(

                        child: Text(

                          emptyMessage,

                          style: theme.textTheme.bodyMedium?.copyWith(

                            color: theme.colorScheme.outline,

                          ),

                        ),

                      ),

                    ],

                  ),

                ),

              )

            else

              SizedBox(

                height: 260,

                child: ListView.separated(

                  scrollDirection: Axis.horizontal,

                  physics: const BouncingScrollPhysics(),

                  padding: const EdgeInsets.symmetric(horizontal: 20),

                  itemCount: items.length,

                  separatorBuilder: (context, index) => const SizedBox(width: 16),

                  itemBuilder: (context, index) {

                    return SizedBox(

                      width: 150,

                      child: MediaCard(

                        item: items[index],

                        onLongPress: onLongPress != null ? () => onLongPress(items[index]) : null,

                      ),

                    );

                  },

                ),

              ),

          ],

        ),

      );

    }

  }

  