import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Platform.isWindows ? null : AppBar(
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
                if (Platform.isWindows) const SizedBox(height: 24),
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
    final isWindows = Platform.isWindows;

    return discoverData.when(
      data: (items) {
        if (isWindows) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildWindowsListTile(items[index]),
                childCount: items.length,
              ),
            ),
          );
        }
        
        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
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
      },
      loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
      error: (err, _) => SliverFillRemaining(child: Center(child: Text('Błąd: $err'))),
    );
  }

  Widget _buildWindowsListTile(MediaItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 140,
      child: InkWell(
        onTap: () => context.push('/details', extra: item),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: item.posterUrl != null
                    ? Image.network(item.posterUrl!, fit: BoxFit.cover)
                    : Container(color: Colors.grey[900]),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.rating != null) ...[
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(item.rating!.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                      ],
                      Text(item.releaseDate?.split('-').first ?? '', style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
            const SizedBox(width: 16),
          ],
        ),
      ),
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
