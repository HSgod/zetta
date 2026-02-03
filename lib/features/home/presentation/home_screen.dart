import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/media_item.dart';
import 'providers/search_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);
    final trending = ref.watch(trendingProvider);
    final searchResults = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: searchQuery.isEmpty 
          ? const Text('Zetta') 
          : TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Szukaj filmów i seriali...',
                border: InputBorder.none,
              ),
              onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
            ),
        actions: [
          IconButton(
            onPressed: () {
              if (searchQuery.isNotEmpty) {
                ref.read(searchQueryProvider.notifier).state = '';
              } else {
                // Tu można dodać ikonę wyszukiwania jeśli TextField byłby ukryty
              }
            },
            icon: Icon(searchQuery.isEmpty ? Icons.search : Icons.close),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings)),
        ],
      ),
      body: searchQuery.isEmpty 
          ? _MediaGrid(asyncItems: trending, title: 'Popularne teraz')
          : _MediaGrid(asyncItems: searchResults, title: 'Wyniki wyszukiwania'),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  final AsyncValue<List<MediaItem>> asyncItems;
  final String title;

  const _MediaGrid({required this.asyncItems, required this.title});

  @override
  Widget build(BuildContext context) {
    return asyncItems.when(
      data: (items) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = (constraints.crossAxisExtent / 150).floor().clamp(2, 6);
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.65,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _MediaCard(item: items[index]),
                    childCount: items.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Błąd: $err')),
    );
  }
}

class _MediaCard extends StatelessWidget {
  final MediaItem item;
  const _MediaCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/details', extra: item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: item.posterUrl != null
                  ? Image.network(
                      item.posterUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      ),
                    )
                  : const Center(child: Icon(Icons.movie, size: 50)),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        item.rating?.toStringAsFixed(1) ?? 'N/A',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
