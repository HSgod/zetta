import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../presentation/providers/download_provider.dart';
import '../../player/presentation/player_args.dart';
import '../../player/presentation/video_player_screen.dart';

class DownloadsListScreen extends ConsumerWidget {
  const DownloadsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pobrane filmy'),
      ),
      body: downloads.isEmpty
          ? const Center(child: Text('Brak pobranych plików', style: TextStyle(color: Colors.white54)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: downloads.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = downloads[index];
                final isCompleted = item.status == 3;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  tileColor: Colors.white.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: item.mediaItem.posterUrl != null
                        ? Image.network(item.mediaItem.posterUrl!, width: 45, height: 70, fit: BoxFit.cover)
                        : Container(width: 45, height: 70, color: Colors.grey),
                  ),
                  title: Text(item.mediaItem.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.season != null)
                        Text('Sezon ${item.season} Odc. ${item.episode}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                      const SizedBox(height: 4),
                      if (!isCompleted)
                        LinearProgressIndicator(value: item.progress / 100, color: Colors.redAccent, backgroundColor: Colors.white10)
                      else
                        const Text('Gotowe do oglądania', style: TextStyle(color: Colors.green, fontSize: 12)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white30),
                    onPressed: () => _showDeleteDialog(context, ref, item),
                  ),
                  onTap: () {
                    if (isCompleted) {
                      Navigator.push(
                        context,
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
                );
              },
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
