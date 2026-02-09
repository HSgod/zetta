import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/scraper/scraper_service.dart';
import '../../../core/scraper/base_scraper.dart';
import '../../../core/scraper/scraper_settings_provider.dart';
import '../../home/domain/media_item.dart';
import '../../home/domain/episode.dart';
import '../../home/data/tmdb_service.dart';
import '../../library/presentation/providers/library_provider.dart';
import '../../player/presentation/player_args.dart';
import '../../player/presentation/video_player_screen.dart';
import '../../settings/presentation/scraper_selection_screen.dart';

final tmdbServiceProvider = Provider((ref) => TmdbService());

class DetailsScreen extends ConsumerStatefulWidget {
  final MediaItem item;

  const DetailsScreen({super.key, required this.item});

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  List<VideoSource>? _sources;
  bool _isLoadingSources = false;
  String? _error;
  
  int? _selectedSeason;
  int? _selectedEpisode;
  List<Episode>? _episodes;
  int _totalSeasons = 0;
  bool _isLoadingTV = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.type == MediaType.series) {
      _loadTVDetails();
    } else {
      _fetchSources();
    }
  }

  Future<void> _loadTVDetails() async {
    setState(() => _isLoadingTV = true);
    try {
      final details = await ref.read(tmdbServiceProvider).getTVDetails(widget.item.id);
      if (mounted) {
        setState(() {
          _totalSeasons = details['number_of_seasons'] ?? 0;
          _isLoadingTV = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTV = false);
    }
  }

  Future<void> _loadEpisodes(int seasonNumber) async {
    setState(() {
      _selectedSeason = seasonNumber;
      _episodes = null;
      _selectedEpisode = null;
      _sources = null;
    });
    
    try {
      final episodes = await ref.read(tmdbServiceProvider).getSeasonEpisodes(widget.item.id, seasonNumber);
      if (mounted) {
        setState(() => _episodes = episodes);
      }
    } catch (e) {}
  }

  Future<void> _fetchSources({int? season, int? episode}) async {
    setState(() {
      _isLoadingSources = true;
      _sources = null;
      _error = null;
    });
    
    try {
      final sources = await ref.read(scraperServiceProvider).findStream(
        widget.item.title, 
        widget.item.type,
        season: season,
        episode: episode,
      );
      if (mounted) {
        setState(() {
          _sources = sources;
          _isLoadingSources = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoadingSources = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref.watch(favoritesProvider).any((i) => i.id == widget.item.id);
    final savedSource = ref.watch(sourceHistoryProvider)[widget.item.id];
    final settingsAsync = ref.watch(scraperSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, isFavorite),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetaInfo(),
                  const SizedBox(height: 24),
                  const Text('Opis', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(widget.item.description ?? "Brak opisu", style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  
                  if (widget.item.type == MediaType.series) ...[
                    const SizedBox(height: 24),
                    const Text('Sezony', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildSeasonSelector(),
                    if (_episodes != null) ...[
                      const SizedBox(height: 16),
                      const Text('Odcinki', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildEpisodeSelector(),
                    ],
                  ],

                  const SizedBox(height: 32),
                  const Text('Dost\u0119pne źr\u00f3d\u0142a', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const Divider(color: Colors.white24, height: 32),
                  
                  settingsAsync.when(
                    data: (config) {
                      final hasActive = config.enabledScrapers.values.any((v) => v == true);
                      if (!hasActive) {
                        return _buildNoScrapersWarning(context);
                      }
                      
                      if (_isLoadingSources) {
                        return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Colors.red)));
                      } else if (_error != null) {
                        return Center(child: Text('B\u0142\u0105d: $_error', style: const TextStyle(color: Colors.red)));
                      } else if (_sources != null && _sources!.isNotEmpty) {
                        return Column(children: _buildGroupedSources(context, savedSource));
                      } else if (_sources != null && _sources!.isEmpty) {
                        return const Center(child: Text('Nie znaleziono źr\u00f3de\u0142 dla tego wyboru.', style: TextStyle(color: Colors.white30)));
                      } else {
                        return const Center(child: Text('Wybierz odcinek, aby zobaczyć źr\u00f3d\u0142a', style: TextStyle(color: Colors.white30)));
                      }
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Text('B\u0142\u0105d ładowania ustawień', style: TextStyle(color: Colors.red)),
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoScrapersWarning(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          const Text(
            'BRAK AKTYWNYCH \u0179R\u00d3DE\u0141',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aby wyszukiwać filmy i seriale, musisz najpierw włączyć co najmniej jeden scraper w ustawieniach aplikacji.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ScraperSelectionScreen()),
              );
            },
            icon: const Icon(Icons.settings),
            label: const Text('ID\u0179 DO USTAWIEN'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedSources(BuildContext context, SavedSource? savedSource) {
    final Map<String, List<VideoSource>> grouped = {};
    for (var s in _sources!) {
      grouped.putIfAbsent(s.sourceName, () => []).add(s);
    }

    final List<Widget> widgets = [];
    grouped.forEach((sourceName, list) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.source_outlined, color: Colors.redAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                sourceName.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
              const SizedBox(width: 8),
              const Expanded(child: Divider(color: Colors.white10)),
            ],
          ),
        ),
      );
      widgets.addAll(list.map((s) => _buildSourceTile(context, s, savedSource)));
    });
    return widgets;
  }

  Widget _buildSeasonSelector() {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _totalSeasons,
        itemBuilder: (context, index) {
          final seasonNum = index + 1;
          final isSelected = _selectedSeason == seasonNum;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('Sezon $seasonNum'),
              selected: isSelected,
              onSelected: (val) => _loadEpisodes(seasonNum),
              selectedColor: Colors.redAccent,
              backgroundColor: Colors.grey[900],
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEpisodeSelector() {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _episodes!.length,
        itemBuilder: (context, index) {
          final ep = _episodes![index];
          final isSelected = _selectedEpisode == ep.episodeNumber;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('Odc. ${ep.episodeNumber}'),
              selected: isSelected,
              onSelected: (val) {
                setState(() => _selectedEpisode = ep.episodeNumber);
                _fetchSources(season: _selectedSeason, episode: ep.episodeNumber);
              },
              selectedColor: Colors.redAccent,
              backgroundColor: Colors.grey[900],
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isFavorite) {
    return SliverAppBar(
      expandedHeight: 400,
      pinned: true,
      backgroundColor: Colors.black,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.item.posterUrl != null)
              Image.network(
                widget.item.posterUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
              )
            else
              Container(color: Colors.grey[900]),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.white),
          onPressed: () => ref.read(favoritesProvider.notifier).toggleFavorite(widget.item),
        ),
      ],
    );
  }

  Widget _buildMetaInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.item.title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(widget.item.releaseDate?.split('-').first ?? "2024", style: const TextStyle(color: Colors.white70)),
            const SizedBox(width: 16),
            if (widget.item.rating != null) ...[
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(widget.item.rating!.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSourceTile(BuildContext context, VideoSource source, SavedSource? savedSource) {
    bool isSuggested = false;
    if (savedSource != null) {
      String cleanCurrent = source.url.split('?').first.replaceAll(RegExp(r'/$'), '');
      String cleanSaved = (savedSource.pageUrl ?? "").split('?').first.replaceAll(RegExp(r'/$'), '');
      
      if (source.url.contains('ekino-tv.pl')) {
        final p1 = Uri.tryParse(cleanCurrent)?.path ?? "---";
        final p2 = Uri.tryParse(cleanSaved)?.path ?? "===";
        isSuggested = p1 == p2 && p1 != "---";
      } else {
        isSuggested = cleanCurrent == cleanSaved;
      }
    }
    
    final primaryColor = Colors.greenAccent;

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSuggested 
            ? BorderSide(color: primaryColor.withOpacity(0.8), width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSuggested ? primaryColor : Colors.grey[800],
          child: Icon(
            isSuggested ? Icons.play_arrow_rounded : Icons.video_library_rounded,
            color: isSuggested ? Colors.black : Colors.white70,
          ),
        ),
        title: Text(source.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: isSuggested 
            ? Text('Źr\u00f3d\u0142o do kontynuowania ogl\u0105dania', style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w500))
            : Text(source.quality, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(
                args: PlayerArgs(
                  item: widget.item,
                  initialUrl: source.url,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}