import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/domain/media_item.dart';
import '../../home/presentation/providers/search_provider.dart';
import '../../home/presentation/widgets/explore_media_card.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  MediaType _selectedType = MediaType.movie;
  String? _selectedGenreId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final genreId = _selectedGenreId != null ? int.tryParse(_selectedGenreId!) : null;
      ref.read(discoverProvider((type: _selectedType, genreId: genreId)).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.explore_rounded, color: Colors.red, size: 22),
              SizedBox(width: 8),
              Text(
                'Odkrywaj',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: CustomScrollView(
          controller: _scrollController,
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
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: _buildCategoryGrid(),
              ),
            ),
          ],
        ),
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
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: genres.entries.map((genre) {
          final isSelected = _selectedGenreId == genre.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedGenreId = isSelected ? null : genre.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.red : Colors.grey[950],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.red : Colors.white.withValues(alpha: 0.08),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  genre.key,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final genreId = _selectedGenreId != null ? int.tryParse(_selectedGenreId!) : null;
    final discoverState = ref.watch(discoverProvider((type: _selectedType, genreId: genreId)));
    final key = ValueKey('$_selectedType-$_selectedGenreId');

    if (discoverState.error != null && discoverState.items.isEmpty) {
      return Container(
        key: key,
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        child: Text(
          'Błąd: ${discoverState.error}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (discoverState.isLoading && discoverState.items.isEmpty) {
      return Container(
        key: key,
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Colors.red),
      );
    }

    if (discoverState.items.isEmpty) {
      return Container(
        key: key,
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, color: Colors.white24, size: 48),
            SizedBox(height: 16),
            Text(
              'Brak wyników dla wybranego gatunku',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return Column(
      key: key,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            mainAxisSpacing: 24,
            crossAxisSpacing: 16,
            childAspectRatio: 0.62,
          ),
          itemCount: discoverState.items.length,
          itemBuilder: (context, index) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - value)),
                  child: child,
                ),
              ),
              child: ExploreMediaCard(item: discoverState.items[index]),
            );
          },
        ),
        if (discoverState.isLoading && discoverState.items.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator(color: Colors.red)),
          ),
      ],
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
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red : Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.red : Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}


