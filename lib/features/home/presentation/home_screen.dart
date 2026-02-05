import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/media_item.dart';
import 'providers/search_provider.dart';
import 'widgets/media_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(homeCategoryProvider);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: false,
            centerTitle: true,
            title: Image.asset(
              'assets/images/logoapp.webp',
              height: 36,
              errorBuilder: (context, error, stackTrace) => const Text('Zetta'),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildCategorySelector(ref, context),
          ),
          if (selectedCategory == null)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MediaSection(
                    title: 'Trendujące teraz',
                    provider: trendingProvider,
                  ),
                  _MediaSection(
                    title: 'Popularne filmy',
                    provider: popularMoviesProvider,
                  ),
                  _MediaSection(
                    title: 'Popularne seriale',
                    provider: popularTVProvider,
                  ),
                  const SizedBox(height: 100),
                ],
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
      'Wszystko': null,
      'Filmy': 'movie',
      'Seriale': 'tv',
      'Akcja': '28',
      'Komedia': '35',
      'Horror': '27',
      'Sci-Fi': '878',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    // Prosta logika mapowania: jeśli 'movie' lub 'tv' to bez gatunku, jeśli liczba to gatunek filmu
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

class _MediaSection extends ConsumerWidget {
  final String title;
  final FutureProvider<List<MediaItem>> provider;

  const _MediaSection({
    required this.title,
    required this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMedia = ref.watch(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        SizedBox(
          height: 280,
          child: asyncMedia.when(
            data: (items) => ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 160,
                  child: MediaCard(item: items[index]),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Błąd: $err'),
            ),
          ),
        ),
      ],
    );
  }
}
