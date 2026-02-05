import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/domain/media_item.dart';
import '../../home/presentation/providers/search_provider.dart';
import '../../home/presentation/widgets/media_card.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(homeCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Odkrywaj'),
        centerTitle: true,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildCategorySelector(ref, context),
          ),
          if (selectedCategory == null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.movie_filter_outlined, 
                      size: 64, 
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text('Wybierz kategorię powyżej'),
                  ],
                ),
              ),
            )
          else
            _buildCategoryGrid(ref, selectedCategory),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(WidgetRef ref, BuildContext context) {
    final selected = ref.watch(homeCategoryProvider);
    final categories = {
      'Filmy': 'movie',
      'Seriale': 'tv',
      'Akcja': '28',
      'Komedia': '35',
      'Horror': '27',
      'Sci-Fi': '878',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: categories.entries.map((cat) {
          final isSelected = selected == cat.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat.key),
              selected: isSelected,
              onSelected: (val) {
                ref.read(homeCategoryProvider.notifier).setCategory(val ? cat.value : null);
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryGrid(WidgetRef ref, String category) {
    final isTv = category == 'tv';
    final isMovie = category == 'movie';
    final genreId = (!isTv && !isMovie) ? int.tryParse(category) : null;
    final type = isTv ? MediaType.series : MediaType.movie;

    final discoverData = ref.watch(discoverProvider((type: type, genreId: genreId)));

    return discoverData.when(
      data: (items) => SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            mainAxisSpacing: 24,
            crossAxisSpacing: 16,
            childAspectRatio: 0.6,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => MediaCard(item: items[index]),
            childCount: items.length,
          ),
        ),
      ),
      loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
      error: (err, _) => SliverFillRemaining(child: Center(child: Text('Błąd: $err'))),
    );
  }
}
