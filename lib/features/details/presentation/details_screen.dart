import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../home/domain/media_item.dart';
import '../../home/domain/episode.dart';
import '../../home/presentation/providers/search_provider.dart';
import '../../../core/scraper/scraper_service.dart';
import '../../../core/scraper/base_scraper.dart';
import '../../player/presentation/player_args.dart';

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
      videoUrl: source.url,
    ));
  }

  void _showSourcePicker(List<VideoSource> sources) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Wybierz źródło',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sources.length,
                    itemBuilder: (context, index) {
                      final source = sources[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.language),
                        ),
                        title: Text(source.title),
                        subtitle: Text('${source.sourceName} • Jakość: ${source.quality}'),
                        trailing: const Icon(Icons.play_arrow),
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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: 400,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.item.title,
                style: const TextStyle(
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.item.posterUrl != null)
                    Image.network(
                      widget.item.posterUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_,__,___) => Container(color: Colors.grey),
                    )
                  else
                    Container(color: Theme.of(context).colorScheme.primaryContainer),
                  
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(isMovie ? 'Film' : 'Serial'),
                        avatar: Icon(
                          isMovie ? Icons.movie : Icons.tv,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (widget.item.rating != null)
                        Chip(
                          label: Text(widget.item.rating!.toStringAsFixed(1)),
                          avatar: const Icon(Icons.star, color: Colors.amber, size: 18),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Opis',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.item.description ?? 'Brak opisu.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  
                  if (isMovie)
                    FilledButton.icon(
                      onPressed: _isLoading ? null : () => _playMedia(),
                      icon: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow),
                      label: Text(_isLoading ? 'Szukam źródeł...' : 'Odtwórz Film'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    )
                  else
                    _buildSeasonSelector(),
                ],
              ),
            ),
          ),

          if (!isMovie) _buildEpisodeList(),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  Widget _buildSeasonSelector() {
    final tvDetails = ref.watch(tvDetailsProvider(widget.item.id));

    return tvDetails.when(
      data: (data) {
        final seasons = data['seasons'] as List;
        final regularSeasons = seasons.where((s) => s['season_number'] > 0).toList();

        if (regularSeasons.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sezony', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedSeason,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              items: regularSeasons.map<DropdownMenuItem<int>>((season) {
                return DropdownMenuItem(
                  value: season['season_number'],
                  child: Text(season['name'] ?? 'Sezon ${season['season_number']}'),
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
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Błąd pobierania sezonów: $e'),
    );
  }

  Widget _buildEpisodeList() {
    final episodes = ref.watch(seasonEpisodesProvider((id: widget.item.id, season: _selectedSeason)));

    return episodes.when(
      data: (episodeList) {
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final episode = episodeList[index];
              return ListTile(
                leading: episode.stillPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          '${dotenv.env['TMDB_IMAGE_BASE_URL']}${episode.stillPath}',
                          width: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_,__,___) => const Icon(Icons.tv),
                        ),
                      )
                    : const Icon(Icons.tv),
                title: Text('${episode.episodeNumber}. ${episode.name}'),
                subtitle: Text(
                  episode.overview != null && episode.overview!.isNotEmpty 
                    ? episode.overview! 
                    : 'Brak opisu odcinka',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_circle_outline),
                onTap: _isLoading ? null : () {
                  _playMedia(season: _selectedSeason, episode: episode.episodeNumber);
                },
              );
            },
            childCount: episodeList.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))),
      error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Błąd: $e'))),
    );
  }
}
