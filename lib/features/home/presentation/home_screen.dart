import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/media_item.dart';
import 'providers/search_provider.dart';
import 'widgets/media_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          ),
        ],
      ),
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
