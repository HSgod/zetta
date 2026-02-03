import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../home/domain/media_item.dart';
import '../../home/presentation/providers/search_provider.dart';
import '../../home/presentation/widgets/media_card.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchResults = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: const InputDecoration(
            hintText: 'Wpisz tytuł...',
            border: InputBorder.none,
          ),
          autofocus: true,
          onChanged: (value) => ref.read(searchQueryProvider.notifier).update(value),
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => ref.read(searchQueryProvider.notifier).update(''),
            ),
        ],
      ),
      body: query.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('Znajdź swój ulubiony film'),
                ],
              ),
            )
          : searchResults.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('Brak wyników'));
                }
                // Używamy siatki zamiast listy, tak jak na Home
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return MediaCard(item: items[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Błąd: $err')),
            ),
    );
  }
}