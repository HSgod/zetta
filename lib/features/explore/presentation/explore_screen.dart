import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:go_router/go_router.dart';
import '../../../core/ads/ad_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../home/domain/media_item.dart';
import '../../home/presentation/providers/search_provider.dart';
import '../../home/presentation/widgets/media_card.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  MediaType _selectedType = MediaType.movie;
  String? _selectedGenreId;
  final Map<int, BannerAd> _adInstances = {};

  @override
  void dispose() {
    for (var ad in _adInstances.values) {
      ad.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Odkrywaj'),
        centerTitle: true,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTypeSelector(),
                _buildGenreSelector(),
                Divider(
                  height: 1, 
                  indent: 20, 
                  endIndent: 20, 
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                ),
              ],
            ),
          ),
          _buildCategoryGrid(),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _TypeChip(
            label: 'Filmy',
            isSelected: _selectedType == MediaType.movie,
            onSelected: () => setState(() {
              _selectedType = MediaType.movie;
              _selectedGenreId = null; // Reset genre on type change
            }),
          ),
          const SizedBox(width: 8),
          _TypeChip(
            label: 'Seriale',
            isSelected: _selectedType == MediaType.series,
            onSelected: () => setState(() {
              _selectedType = MediaType.series;
              _selectedGenreId = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreSelector() {
    final genres = {
      'Wszystko': null,
      'Akcja': '28',
      'Komedia': '35',
      'Horror': '27',
      'Sci-Fi': '878',
      'Dramat': '18',
      'Animacja': '16',
      'Thriller': '53',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: genres.entries.map((genre) {
          final isSelected = _selectedGenreId == genre.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(genre.key),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedGenreId = val ? genre.value : null),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final genreId = _selectedGenreId != null ? int.tryParse(_selectedGenreId!) : null;
    final discoverData = ref.watch(discoverProvider((type: _selectedType, genreId: genreId)));
    final adsEnabled = ref.watch(adsEnabledProvider);

    return discoverData.when(
      data: (items) {
        if (!adsEnabled) {
          return SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 24,
                crossAxisSpacing: 16,
                childAspectRatio: 0.62,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => MediaCard(item: items[index]),
                childCount: items.length,
              ),
            ),
          );
        }

        const adInterval = 10;
        final totalCount = items.length + (items.length ~/ adInterval);

        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              mainAxisSpacing: 24,
              crossAxisSpacing: 16,
              childAspectRatio: 0.62,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if ((index + 1) % (adInterval + 1) == 0) {
                  // Pozycja reklamy
                  final adIndex = index;
                  if (!_adInstances.containsKey(adIndex)) {
                    _adInstances[adIndex] = adService.createListBannerAd();
                  }
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        const Center(child: Icon(Icons.ads_click, color: Colors.white10, size: 40)),
                        AdWidget(ad: _adInstances[adIndex]!),
                        Positioned(
                          top: 4, left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('AD', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Obliczanie realnego indeksu filmu (pomijając reklamy)
                final itemIndex = index - (index ~/ (adInterval + 1));
                if (itemIndex >= items.length) return null;
                return MediaCard(item: items[itemIndex]);
              },
              childCount: totalCount,
            ),
          ),
        );
      },
      loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
      error: (err, _) => SliverFillRemaining(child: Center(child: Text('Błąd: $err'))),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _TypeChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
