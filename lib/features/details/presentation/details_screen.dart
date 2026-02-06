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
import '../../../core/scraper/scraper_settings_provider.dart';

final tvDetailsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final service = ref.watch(tmdbServiceProvider);
  return service.getTVDetails(id);
});

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
    final settings = ref.read(scraperSettingsProvider);
    final hasActiveScraper = settings.enabledScrapers.values.any((v) => v);

    if (!hasActiveScraper) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Musisz włączyć co najmniej jedno źródło w ustawieniach.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final scraper = ref.read(scraperServiceProvider);
      final sources = await scraper.findStream(
        widget.item.title,
        widget.item.type,
        season: season,
        episode: episode,
      );

      if (sources.isNotEmpty && mounted) {
        final saved = ref.read(sourceHistoryProvider.notifier).getSource(widget.item.id);
        _showSourcePicker(sources, savedSource: saved);
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nie znaleziono aktywnych źródeł wideo dla tego tytułu.')),
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
      initialUrl: source.isWebView ? source.url : null,
      videoUrl: source.isWebView ? null : source.url,
      headers: source.headers,
      automationScript: source.automationScript,
    ));
  }

  void _showSourcePicker(List<VideoSource> sources, {SavedSource? savedSource}) {
    final List<VideoSource> sortedSources = List.from(sources);
    if (savedSource != null && savedSource.pageUrl != null) {
      final savedIdx = sortedSources.indexWhere((s) => s.url == savedSource.pageUrl);
      if (savedIdx != -1) {
        final saved = sortedSources.removeAt(savedIdx);
        sortedSources.insert(0, saved);
      }
    }

    final isWide = MediaQuery.of(context).size.width > 900;

    if (isWide) {
      showDialog(
        context: context,
        builder: (context) => Center(
          child: Container(
            width: 500,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Text(
                      'Wybierz źródło wideo',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: sortedSources.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                      itemBuilder: (context, index) => _buildSourceTile(context, sortedSources[index], savedSource, isTV: true),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
                ),
                Text('Wybierz źródło wideo', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sortedSources.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) => _buildSourceTile(context, sortedSources[index], savedSource, isTV: false),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildSourceTile(BuildContext context, VideoSource source, SavedSource? savedSource, {required bool isTV}) {
    final isSuggested = savedSource != null && source.url == savedSource.pageUrl;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      selected: isSuggested,
      selectedTileColor: Colors.green.withOpacity(0.1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: isSuggested ? Colors.green : colorScheme.primaryContainer,
        child: Icon(
          isSuggested ? Icons.history : (source.sourceName.toLowerCase().contains('ekino') ? Icons.movie_filter : Icons.language),
          color: isSuggested ? Colors.white : colorScheme.onPrimaryContainer,
          size: isTV ? 20 : 24,
        ),
      ),
      title: Text(
        source.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isSuggested ? FontWeight.bold : FontWeight.w600,
          color: isSuggested ? Colors.green : null,
          fontSize: isTV ? 14 : 16,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSuggested)
            const Text('ŹRÓDŁO DO KONTYNUOWANIA OGLĄDANIA', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
          Row(
            children: [
              Text(
                source.sourceName,
                style: TextStyle(
                  color: isSuggested ? Colors.green : colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: isTV ? 12 : 13,
                ),
              ),
              const SizedBox(width: 8),
              const Text('•', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 8),
              Text('Jakość: ${source.quality}', style: TextStyle(fontSize: isTV ? 12 : 13)),
            ],
          ),
        ],
      ),
      trailing: Icon(
        Icons.play_circle_fill,
        color: isSuggested ? Colors.green : colorScheme.primary,
        size: isTV ? 28 : 32,
      ),
      onTap: () {
        Navigator.pop(context);
        _navigateToPlayer(source);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMovie = widget.item.type == MediaType.movie;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          if (!isWide) _buildMobileAppBar(theme),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 60 : 20,
                vertical: isWide ? 40 : 20,
              ),
              child: isWide ? _buildWideLayout(theme, isMovie) : _buildMobileLayout(theme, isMovie),
            ),
          ),
          if (!isMovie) _buildEpisodeList(),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  Widget _buildMobileAppBar(ThemeData theme) {
    return SliverAppBar(
      expandedHeight: 400, pinned: true, stretch: true,
      leading: _buildBackButton(),
      actions: [_buildFavoriteButton()],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _buildPosterImage(),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black45, Colors.black], stops: [0.3, 0.7, 1.0]))),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout(ThemeData theme, bool isMovie) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(width: 220, child: AspectRatio(aspectRatio: 2/3, child: _buildPosterImage())),
        ),
        const SizedBox(width: 60),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(child: Text(widget.item.title, style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
                  _buildFavoriteButton(isLarge: true),
                ],
              ),
              const SizedBox(height: 12),
              _buildMetadataRow(theme, isMovie),
              const SizedBox(height: 24),
              if (isMovie) _buildPlayButton(theme),
              const SizedBox(height: 24),
              Text('Opis', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(widget.item.description ?? 'Brak opisu.', maxLines: 6, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7), height: 1.3)),
              const SizedBox(height: 24),
              if (!isMovie) _buildSeasonSelector(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ThemeData theme, bool isMovie) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.item.title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildMetadataRow(theme, isMovie),
        const SizedBox(height: 24),
        if (isMovie) _buildPlayButton(theme),
        const SizedBox(height: 24),
        Text('Opis', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(widget.item.description ?? 'Brak opisu.', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.8), height: 1.5)),
        const SizedBox(height: 32),
        if (!isMovie) _buildSeasonSelector(),
      ],
    );
  }

  Widget _buildMetadataRow(ThemeData theme, bool isMovie) {
    return Row(
      children: [
        if (widget.item.releaseDate != null) ...[
          Text(widget.item.releaseDate!.split('-')[0], style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('•')),
        ],
        Icon(isMovie ? Icons.movie_outlined : Icons.tv_outlined, size: 18, color: theme.colorScheme.outline),
        const SizedBox(width: 8),
        Text(isMovie ? 'Film' : 'Serial', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
        const Spacer(),
        if (widget.item.rating != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 6),
                Text(widget.item.rating!.toStringAsFixed(1), style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPlayButton(ThemeData theme) {
    return Consumer(
      builder: (context, ref, _) {
        final continueWatching = ref.watch(continueWatchingProvider);
        final isContinuing = continueWatching.any((e) => e.id == widget.item.id);
        return FilledButton.icon(
          onPressed: _isLoading ? null : () => _playMedia(),
          icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.play_arrow, size: 28),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_isLoading ? 'Szukam źródeł...' : (isContinuing ? 'Kontynuuj oglądanie' : 'Odtwórz'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          style: FilledButton.styleFrom(minimumSize: const Size(200, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        );
      },
    );
  }

  Widget _buildPosterImage() {
    final url = widget.item.posterUrl;
    if (url != null && url.isNotEmpty && url.startsWith('http')) {
      return Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder());
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.movie_filter_rounded, size: 64));
  }

  Widget _buildBackButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: CircleAvatar(backgroundColor: Colors.black.withOpacity(0.3), child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
    );
  }

  Widget _buildFavoriteButton({bool isLarge = false}) {
    return Consumer(
      builder: (context, ref, _) {
        final favorites = ref.watch(favoritesProvider);
        final isFav = favorites.any((e) => e.id == widget.item.id);
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            radius: isLarge ? 24 : 20,
            backgroundColor: isLarge ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.black.withOpacity(0.3),
            child: IconButton(icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : (isLarge ? null : Colors.white), size: isLarge ? 28 : 24), onPressed: () { HapticFeedback.mediumImpact(); ref.read(favoritesProvider.notifier).toggleFavorite(widget.item); }),
          ),
        );
      },
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
                Text('Odcinki', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButton<int>(
                    value: _selectedSeason, underline: const SizedBox(),
                    items: regularSeasons.map<DropdownMenuItem<int>>((season) => DropdownMenuItem(value: season['season_number'], child: Text(season['name'] ?? 'Sezon ${season['season_number']}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)))).toList(),
                    onChanged: (value) { if (value != null) setState(() => _selectedSeason = value); },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Błąd: $e'),
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
                    color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16), clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _isLoading ? null : () => _playMedia(season: _selectedSeason, episode: episode.episodeNumber),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(borderRadius: BorderRadius.circular(12), child: episode.stillPath != null ? Image.network('${dotenv.env['TMDB_IMAGE_BASE_URL'] ?? 'https://image.tmdb.org/t/p/w200'}${episode.stillPath}', width: 160, height: 90, fit: BoxFit.cover, errorBuilder: (_,__,___) => _buildEpisodePlaceholder()) : _buildEpisodePlaceholder()),
                                if (_isLoading) const CircularProgressIndicator(strokeWidth: 2) else Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle), child: const Icon(Icons.play_arrow, color: Colors.white, size: 24)),
                              ],
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${episode.episodeNumber}. ${episode.name}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 6),
                                  Text(episode.overview != null && episode.overview!.isNotEmpty ? episode.overview! : 'Brak opisu odcinka', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline), maxLines: 3, overflow: TextOverflow.ellipsis),
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
    return Container(width: 160, height: 90, color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.tv_rounded));
  }
}