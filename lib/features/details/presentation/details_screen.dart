import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../home/domain/media_item.dart';
import '../../home/domain/episode.dart';
import '../../home/presentation/providers/search_provider.dart';
import '../../../core/scraper/scraper_service.dart';
import '../../../core/scraper/base_scraper.dart';
import '../../player/presentation/player_args.dart';
import '../../home/presentation/widgets/media_card.dart';
import '../../library/presentation/providers/library_provider.dart';

// Provider dla detali serialu (liczba sezonów)
final tvDetailsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final service = ref.watch(tmdbServiceProvider);
  return service.getTVDetails(id);
});

// Provider dla odcinków konkretnego sezonu
final seasonEpisodesProvider = FutureProvider.family<List<Episode>, ({String id, int season})>((ref, arg) async {
  final service = ref.watch(tmdbServiceProvider);
  return service.getSeasonEpisodes(arg.id, arg.season);
});

class DetailsScreen extends ConsumerStatefulWidget {
  final MediaItem item;

  const DetailsScreen({super.key, required this.item});

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  int _selectedSeason = 1;
  bool _isLoading = false;

  Future<void> _playMedia({int? season, int? episode}) async {
    setState(() => _isLoading = true);
    
    try {
      final scraper = ref.read(scraperServiceProvider);
      
      final sources = await scraper.findStream(
        widget.item.title,
        season: season,
        episode: episode,
      );

      if (sources.isNotEmpty && mounted) {
        _showSourcePicker(sources);
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nie znaleziono aktywnych źródeł wideo.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToPlayer(VideoSource source) {
    context.push('/player', extra: PlayerArgs(
      item: widget.item, 
      initialUrl: source.url,
      headers: source.headers,
      automationScript: source.automationScript,
    ));
  }

  void _showSourcePicker(List<VideoSource> sources) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Wybierz źródło wideo',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sources.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final source = sources[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            source.sourceName.toLowerCase().contains('ekino') 
                              ? Icons.movie_filter 
                              : Icons.language,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          source.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              source.sourceName,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('•'),
                            const SizedBox(width: 8),
                            Text('Jakość: ${source.quality}'),
                          ],
                        ),
                        trailing: Icon(
                          Icons.play_circle_fill,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToPlayer(source);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMovie = widget.item.type == MediaType.movie;
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            stretch: true,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.3),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.3),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final favorites = ref.watch(favoritesProvider);
                      final isFav = favorites.any((e) => e.id == widget.item.id);
                      return IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.red : Colors.white,
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          ref.read(favoritesProvider.notifier).toggleFavorite(widget.item);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster with safe loading
                  Builder(
                    builder: (context) {
                      final url = widget.item.posterUrl;
                      if (url != null && url.isNotEmpty && url.startsWith('http')) {
                        return Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        );
                      }
                      return _buildPlaceholder();
                    },
                  ),
                  // Gradient overlay
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black45,
                          Colors.black,
                        ],
                        stops: [0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (widget.item.releaseDate != null) ...[
                        Text(
                          widget.item.releaseDate!.split('-')[0],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('•'),
                        ),
                      ],
                      Icon(
                        isMovie ? Icons.movie_outlined : Icons.tv_outlined,
                        size: 16,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMovie ? 'Film' : 'Serial',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const Spacer(),
                      if (widget.item.rating != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                widget.item.rating!.toStringAsFixed(1),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (isMovie)
                    Consumer(
                      builder: (context, ref, _) {
                        final continueWatching = ref.watch(continueWatchingProvider);
                        final isContinuing = continueWatching.any((e) => e.id == widget.item.id);
                        
                        return FilledButton.icon(
                          onPressed: _isLoading ? null : () async {
                            if (isContinuing) {
                              // Próbujemy odpalić bezpośrednio zapisane źródło
                              final saved = ref.read(sourceHistoryProvider.notifier).getSource(widget.item.id);
                              if (saved != null) {
                                context.push('/player', extra: PlayerArgs(
                                  item: widget.item, 
                                  videoUrl: saved.url,
                                  headers: saved.headers,
                                  automationScript: saved.automationScript,
                                ));
                                return;
                              }
                            }
                            // Jeśli nie ma zapisanego źródła lub to nowy seans, szukamy normalnie
                            _playMedia();
                          },
                          icon: _isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.play_arrow),
                          label: Text(_isLoading 
                            ? 'Szukam źródeł...' 
                            : (isContinuing ? 'Kontynuuj oglądanie' : 'Odtwórz')),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        );
                      },
                    )
                  else
                    const SizedBox.shrink(),
                  
                  const SizedBox(height: 24),
                  Text(
                    'Opis',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.item.description ?? 'Brak opisu.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  if (!isMovie) _buildSeasonSelector(),
                ],
              ),
            ),
          ),

          if (!isMovie) _buildEpisodeList(),
          
          SliverToBoxAdapter(
            child: _buildRecommendations(),
          ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    final recommendations = ref.watch(recommendationsProvider((id: widget.item.id, type: widget.item.type)));
    final theme = Theme.of(context);

    return recommendations.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: Text(
                'Podobne treści',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 260,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 150,
                    child: MediaCard(item: items[index]),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (err, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.movie_filter_rounded, size: 64),
    );
  }

  Widget _buildSeasonSelector() {
    final tvDetails = ref.watch(tvDetailsProvider(widget.item.id));
    final theme = Theme.of(context);

    return tvDetails.when(
      data: (data) {
        final seasons = data['seasons'] as List;
        final regularSeasons = seasons.where((s) => s['season_number'] > 0).toList();

        if (regularSeasons.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Odcinki',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<int>(
                    value: _selectedSeason,
                    underline: const SizedBox(),
                    items: regularSeasons.map<DropdownMenuItem<int>>((season) {
                      return DropdownMenuItem(
                        value: season['season_number'],
                        child: Text(
                          season['name'] ?? 'Sezon ${season['season_number']}',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedSeason = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Błąd pobierania sezonów: $e'),
    );
  }

  Widget _buildEpisodeList() {
    final episodes = ref.watch(seasonEpisodesProvider((id: widget.item.id, season: _selectedSeason)));
    final theme = Theme.of(context);

    return episodes.when(
      data: (episodeList) {
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final episode = episodeList[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _isLoading ? null : () {
                        _playMedia(season: _selectedSeason, episode: episode.episodeNumber);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: episode.stillPath != null
                                      ? Image.network(
                                          '${dotenv.env['TMDB_IMAGE_BASE_URL'] ?? 'https://image.tmdb.org/t/p/w200'}${episode.stillPath}',
                                          width: 120,
                                          height: 70,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_,__,___) => _buildEpisodePlaceholder(),
                                        )
                                      : _buildEpisodePlaceholder(),
                                ),
                                if (_isLoading)
                                  const CircularProgressIndicator(strokeWidth: 2)
                                else
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${episode.episodeNumber}. ${episode.name}',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    episode.overview != null && episode.overview!.isNotEmpty 
                                      ? episode.overview! 
                                      : 'Brak opisu odcinka',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: episodeList.length,
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))),
      error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Błąd: $e'))),
    );
  }

  Widget _buildEpisodePlaceholder() {
    return Container(
      width: 120,
      height: 70,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.tv_rounded),
    );
  }
}
