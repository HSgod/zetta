import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/library_provider.dart';
import 'providers/download_provider.dart';
import '../../home/presentation/widgets/media_card.dart';
import '../../home/domain/media_item.dart';
import '../../player/presentation/player_args.dart';
import '../../player/presentation/video_player_screen.dart';
import 'downloads_list_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  void _showRemoveDialog(BuildContext context, WidgetRef ref, dynamic item, String listType) {
    final title = item is MediaItem ? item.title : item.mediaItem.title;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń?'),
        content: Text('Czy chcesz usunąć "$title"?'),
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
              } else if (listType == 'downloads') {
                ref.read(downloadProvider.notifier).removeDownload(item.taskId!);
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
    final downloads = ref.watch(downloadProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moja biblioteka'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: double.infinity),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildDownloadsSection(context, ref, downloads),
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
        ),
      ),
    );
  }

  Widget _buildDownloadsSection(BuildContext context, WidgetRef ref, List<dynamic> downloads) {
    if (downloads.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DownloadsListScreen()),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.download_done_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pobrane filmy i seriale',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Dostępne offline: ${downloads.length}',
                        style: TextStyle(color: theme.colorScheme.primary.withOpacity(0.7), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.primary.withOpacity(0.5)),
              ],
            ),
          ),
        ),
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

  