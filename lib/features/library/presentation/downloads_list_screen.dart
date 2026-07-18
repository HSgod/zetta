import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/download_provider.dart';
import '../../player/presentation/player_args.dart';
import '../../player/presentation/video_player_screen.dart';

class DownloadsListScreen extends ConsumerWidget {
  const DownloadsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            'Pobrane filmy',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: downloads.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.download_for_offline_rounded,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Brak pobranych plików',
                      style: TextStyle(color: Colors.white60, fontSize: 16),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                physics: const BouncingScrollPhysics(),
                itemCount: downloads.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = downloads[index];
                  final isCompleted = item.status == 3;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[950],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 1.0,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      tileColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: item.mediaItem.posterUrl != null
                            ? Image.network(
                                item.mediaItem.posterUrl!,
                                width: 45,
                                height: 70,
                                fit: BoxFit.cover,
                                cacheWidth: 150,
                              )
                            : Container(
                                width: 45,
                                height: 70,
                                color: Colors.white.withValues(alpha: 0.05),
                                child: const Icon(Icons.movie_rounded, color: Colors.white24, size: 20),
                              ),
                      ),
                      title: Text(
                        item.mediaItem.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.season != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Sezon ${item.season} Odc. ${item.episode}',
                              style: const TextStyle(fontSize: 12, color: Colors.white54),
                            ),
                          ],
                          const SizedBox(height: 6),
                          if (!isCompleted)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: item.progress / 100,
                                color: Colors.red,
                                backgroundColor: Colors.white.withValues(alpha: 0.05),
                                minHeight: 4,
                              ),
                            )
                          else
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.green.withValues(alpha: 0.2), width: 0.5),
                                  ),
                                  child: const Text(
                                    'Gotowe do oglądania',
                                    style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.white30, size: 22),
                        onPressed: () => _showDeleteDialog(context, ref, item),
                      ),
                      onTap: () {
                        if (isCompleted) {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => VideoPlayerScreen(
                                args: PlayerArgs(
                                  item: item.mediaItem,
                                  videoUrl: item.filePath,
                                  sourceName: 'Pobrane',
                                  title: item.mediaItem.title,
                                  season: item.season,
                                  episode: item.episode,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, dynamic item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń plik?'),
        content: const Text('Plik wideo zostanie trwale usunięty z pamięci telefonu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
          FilledButton(
            onPressed: () {
              ref.read(downloadProvider.notifier).removeDownload(item.taskId!);
              Navigator.pop(context);
            },
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
  }
}
