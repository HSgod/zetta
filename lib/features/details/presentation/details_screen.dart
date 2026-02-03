import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../home/domain/media_item.dart';

class DetailsScreen extends StatelessWidget {
  final MediaItem item;

  const DetailsScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: 400,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.posterUrl != null)
                    Image.network(
                      item.posterUrl!,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(color: Theme.of(context).colorScheme.primaryContainer),
                  
                  // Gradient dla lepszej czytelności tekstu
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(item.type == MediaType.movie ? 'Film' : 'Serial'),
                        avatar: Icon(
                          item.type == MediaType.movie ? Icons.movie : Icons.tv,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (item.rating != null)
                        Chip(
                          label: Text(item.rating.toString()),
                          avatar: const Icon(Icons.star, color: Colors.amber, size: 18),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Opis',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description ?? 'Brak opisu.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      context.push('/player', extra: item);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Odtwórz teraz'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
