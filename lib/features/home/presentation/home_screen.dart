import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/search_provider.dart';
import 'widgets/media_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(trendingProvider);

    return Scaffold(
      body: trending.when(
        data: (items) => CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverAppBar(
              floating: true,
              pinned: true,
              title: Text('Zetta'),
              centerTitle: false,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Popularne teraz',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = (constraints.crossAxisExtent / 160).floor().clamp(2, 6);
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.6,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => MediaCard(item: items[index]),
                      childCount: items.length,
                    ),
                  );
                },
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Błąd: $err')),
      ),
    );
  }
}
