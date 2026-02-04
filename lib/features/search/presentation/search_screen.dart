import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/presentation/providers/search_provider.dart';
import '../../home/presentation/widgets/media_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
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
              onPressed: () {
                _controller.clear();
                ref.read(searchQueryProvider.notifier).update('');
              },
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
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.6,
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
