import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/scraper/scraper_service.dart';
import '../../../core/scraper/base_scraper.dart';
import '../../../core/scraper/scraper_settings_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../home/domain/media_item.dart';
import '../../home/domain/episode.dart';
import '../../home/data/tmdb_service.dart';
import '../../library/presentation/providers/library_provider.dart';
import '../../library/presentation/providers/download_provider.dart';
import '../../player/presentation/player_args.dart';
import '../../player/presentation/video_player_screen.dart';
import '../../player/presentation/video_sniffer.dart';
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
  VideoSource? _sniffingSource;
  
  int? _selectedSeason;
  int? _selectedEpisode;
  List<Episode>? _episodes;
  int _totalSeasons = 0;
  bool _isLoadingTV = false;
  String? _trailerKey;
  bool _isLoadingTrailer = false;
  List<Map<String, dynamic>>? _cast;
  bool _isLoadingCast = false;
  final Map<String, String> _scraperProgress = {};

  @override
  void initState() {
    super.initState();
    _loadTrailer();
    _loadCredits();
    if (widget.item.type == MediaType.series) {
      _loadTVDetails();
    } else {
      _fetchSources();
    }
  }

  Future<void> _loadCredits() async {
    setState(() => _isLoadingCast = true);
    try {
      final credits = await ref.read(tmdbServiceProvider).getCredits(widget.item.id, widget.item.type);
      if (mounted) {
        setState(() {
          _cast = credits;
          _isLoadingCast = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCast = false);
    }
  }

  Future<void> _loadTrailer() async {
    setState(() => _isLoadingTrailer = true);
    try {
      final key = await ref.read(tmdbServiceProvider).getTrailerKey(widget.item.id, widget.item.type);
      if (mounted) {
        setState(() {
          _trailerKey = key;
          _isLoadingTrailer = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTrailer = false);
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
      _scraperProgress.clear();
    });
    
    try {
      final sources = await ref.read(scraperServiceProvider).findStream(
        widget.item.title, 
        widget.item.type,
        season: season,
        episode: episode,
        onProgress: (scraperName, status) {
          if (mounted) {
            setState(() {
              _scraperProgress[scraperName] = status;
            });
          }
        },
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
    
    // Klucz do zapisanego źródła (uwzględnia sezon i odcinek dla seriali)
    String storageId = widget.item.id;
    if (widget.item.type == MediaType.series && _selectedSeason != null && _selectedEpisode != null) {
      storageId = "${widget.item.id}_s${_selectedSeason}_e${_selectedEpisode}";
    }
    
    final savedSource = ref.watch(sourceHistoryProvider)[storageId];
    final settingsAsync = ref.watch(scraperSettingsProvider);
    final screenSize = MediaQuery.of(context).size;
    final isTV = screenSize.width > 900;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Rozmyte tło (Backdrop)
            _buildBackground(screenSize),
  
            // 2. Główna zawartość
            SafeArea(
              child: isTV 
                ? _buildTVLayout(context, isFavorite, savedSource, settingsAsync)
                : _buildMobileLayout(context, isFavorite, savedSource, settingsAsync),
            ),
          
          // Przycisk wstecz dla TV (w mobile mamy SliverAppBar ze strzałką)
          if (isTV)
            Positioned(
              top: 20,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),

          if (_sniffingSource != null)
            Positioned.fill(
              child: Offstage(
                offstage: true, // Całkowicie niewidoczne
                child: VideoSniffer(
                  initialUrl: _sniffingSource!.url,
                  headers: _sniffingSource!.headers,
                  automationScript: _sniffingSource!.automationScript,
                  onStreamCaught: (finalUrl) {
                    final source = _sniffingSource!;
                    setState(() => _sniffingSource = null);
                    
                    ref.read(downloadProvider.notifier).startDownload(
                      item: widget.item,
                      url: finalUrl,
                      season: _selectedSeason,
                      episode: _selectedEpisode,
                      headers: source.headers,
                    );
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link rozwiązany! Pobieranie rozpoczęte.'), backgroundColor: Colors.green),
                      );
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildBackground(Size size) {
    final hasBackdrop = widget.item.backdropUrl != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasBackdrop || widget.item.posterUrl != null)
          Image.network(
            hasBackdrop ? widget.item.backdropUrl! : widget.item.posterUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.black.withOpacity(0.75),
            ),
          ),
        ),
        // Gradient dla lepszej czytelności tekstu
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withOpacity(0.8),
                Colors.black.withOpacity(0.4),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTVLayout(BuildContext context, bool isFavorite, SavedSource? savedSource, AsyncValue settingsAsync) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lewa kolumna: Plakat
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(60, 40, 40, 40),
            child: Center(
              child: Hero(
                tag: 'poster-${widget.item.id}',
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: widget.item.posterUrl != null
                        ? Image.network(widget.item.posterUrl!, fit: BoxFit.contain)
                        : const Icon(Icons.movie, size: 200, color: Colors.white24),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Prawa kolumna: Informacje i źródła
        Expanded(
          flex: 3,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 60, 60, 60),
            physics: const ClampingScrollPhysics(),
            children: [
              _buildMainInfo(isFavorite),
              const SizedBox(height: 24),
              _buildDescription(),
              if (_cast != null && _cast!.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildCastSection(),
              ],
              const SizedBox(height: 32),
              
              if (widget.item.type == MediaType.series) ...[
                const Text('Sezony', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildSeasonSelector(),
                if (_episodes != null) ...[
                  const SizedBox(height: 24),
                  const Text('Odcinki', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildEpisodeSelector(),
                ],
                const SizedBox(height: 32),
              ],
              
              if (_trailerKey != null) ...[
                _buildTrailerButton(),
                const SizedBox(height: 32),
              ],
              const Text('Dostępne źródła', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white24, height: 32),
              
              _buildSourcesSection(context, settingsAsync, savedSource),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, bool isFavorite, SavedSource? savedSource, AsyncValue settingsAsync) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 250,
          pinned: true,
          backgroundColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                widget.item.backdropUrl != null 
                  ? Image.network(widget.item.backdropUrl!, fit: BoxFit.cover)
                  : (widget.item.posterUrl != null
                      ? Image.network(widget.item.posterUrl!, fit: BoxFit.cover)
                      : Container(color: Colors.grey[900])),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildMainInfo(isFavorite),
              const SizedBox(height: 20),
              _buildDescription(),
              if (_cast != null && _cast!.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildCastSection(),
              ],
              const SizedBox(height: 24),
              if (widget.item.type == MediaType.series) ...[
                const Text('Sezony', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildSeasonSelector(),
                if (_episodes != null) ...[
                  const SizedBox(height: 16),
                  const Text('Odcinki', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildEpisodeSelector(),
                ],
                const SizedBox(height: 24),
              ],
              if (_trailerKey != null) ...[
                _buildTrailerButton(),
                const SizedBox(height: 24),
              ],
              const Text('Źródła', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white24),
              _buildSourcesSection(context, settingsAsync, savedSource),
              const SizedBox(height: 50),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildMainInfo(bool isFavorite) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                widget.item.title, 
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 28, 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: -0.5
                ),
              ),
            ),
            IconButton(
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.white, size: 28),
              onPressed: () => ref.read(favoritesProvider.notifier).toggleFavorite(widget.item),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.item.releaseDate?.split('-').first ?? "2024", 
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.item.rating != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      widget.item.rating!.toStringAsFixed(1), 
                      style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
              ),
              child: Text(
                widget.item.type == MediaType.movie ? 'FILM' : 'SERIAL',
                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Text(
        widget.item.description ?? "Brak opisu", 
        style: const TextStyle(
          color: Colors.white70, 
          fontSize: 14, 
          height: 1.5, 
          fontWeight: FontWeight.w400
        ),
      ),
    );
  }

  Widget _buildSourcesSection(BuildContext context, AsyncValue settingsAsync, SavedSource? savedSource) {
    return settingsAsync.when(
      data: (config) {
        final hasActive = config.enabledScrapers.values.any((v) => v == true);
        if (!hasActive) {
          return _buildNoScrapersWarning(context);
        }
        
        if (_isLoadingSources) {
          return _buildScraperProgressWidget();
        } else if (_error != null) {
          return Center(child: Text('Błąd: $_error', style: const TextStyle(color: Colors.red)));
        } else if (_sources != null && _sources!.isNotEmpty) {
          return Column(children: _buildGroupedSources(context, savedSource));
        } else if (_sources != null && _sources!.isEmpty) {
          return _buildScraperProgressWidget(noResults: true);
        } else {
          return const Center(child: Text('Wybierz odcinek, aby zobaczyć źródła', style: TextStyle(color: Colors.white30, fontSize: 16)));
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Błąd ładowania ustawień', style: TextStyle(color: Colors.red)),
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
            'BRAK AKTYWNYCH ŹRÓDEŁ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ScraperSelectionScreen()));
            },
            icon: const Icon(Icons.settings),
            label: const Text('IDŹ DO USTAWIEŃ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
          padding: const EdgeInsets.only(top: 24, bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.bolt, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                sourceName.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
              const SizedBox(width: 16),
              const Expanded(child: Divider(color: Colors.white10)),
            ],
          ),
        ),
      );
      
      for (int i = 0; i < list.length; i++) {
        final source = list[i];
        final playerTitle = _formatPlayerTitle(source.title, i + 1);
        widgets.add(_buildSourceTile(context, source, savedSource, displayTitle: playerTitle));
      }
    });
    return widgets;
  }

  String _formatPlayerTitle(String title, int index) {
    // Wyciągamy zawartość nawiasów (np. Lektor, Napisy)
    final match = RegExp(r'\((.*?)\)').firstMatch(title);
    if (match != null) {
      return 'PLAYER $index (${match.group(1)})';
    }
    return 'PLAYER $index';
  }

  Widget _buildSeasonSelector() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _totalSeasons,
        itemBuilder: (context, index) {
          final seasonNum = index + 1;
          final isSelected = _selectedSeason == seasonNum;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _loadEpisodes(seasonNum),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.white10,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    'SEZON $seasonNum',
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEpisodeSelector() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _episodes!.length,
        itemBuilder: (context, index) {
          final ep = _episodes![index];
          final isSelected = _selectedEpisode == ep.episodeNumber;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedEpisode = ep.episodeNumber);
                _fetchSources(season: _selectedSeason, episode: ep.episodeNumber);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.red : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.red : Colors.white10,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    'ODC. ${ep.episodeNumber}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSourceTile(BuildContext context, VideoSource source, SavedSource? savedSource, {String? displayTitle}) {
    bool isSuggested = false;
    if (savedSource != null) {
      if (savedSource.sourceName != null && savedSource.title != null) {
        isSuggested = source.sourceName == savedSource.sourceName && 
                     source.title == savedSource.title;
      }
      if (!isSuggested) {
        String cleanCurrent = source.url.split('?').first.replaceAll(RegExp(r'/$'), '');
        String cleanSaved = (savedSource.pageUrl ?? "").split('?').first.replaceAll(RegExp(r'/$'), '');
        isSuggested = cleanCurrent == cleanSaved;
      }
    }
    
    final accentColor = isSuggested ? Colors.greenAccent : Colors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSuggested 
            ? Colors.green.withOpacity(0.06) 
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuggested 
              ? Colors.greenAccent.withOpacity(0.4) 
              : Colors.white.withOpacity(0.08),
          width: 1.0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSuggested 
                ? Colors.greenAccent.withOpacity(0.1) 
                : Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isSuggested ? Icons.play_circle_fill : Icons.play_arrow_rounded, 
            color: accentColor,
            size: 20,
          ),
        ),
        title: Text(
          displayTitle ?? source.title, 
          style: const TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold, 
            fontSize: 15,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  source.quality.toUpperCase(), 
                  style: const TextStyle(
                    color: Colors.white70, 
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                (_sniffingSource == source) ? Icons.hourglass_empty_rounded : Icons.download_for_offline_rounded, 
                color: (_sniffingSource == source) ? Colors.amber : Colors.white70,
                size: 22,
              ),
              onPressed: () {
                if (source.isWebView) {
                  setState(() => _sniffingSource = source);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Przygotowywanie linku do pobrania...'), duration: Duration(seconds: 3)),
                  );
                } else {
                  ref.read(downloadProvider.notifier).startDownload(
                    item: widget.item,
                    url: source.url,
                    season: _selectedSeason,
                    episode: _selectedEpisode,
                    headers: source.headers,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pobieranie rozpoczęte...'), duration: Duration(seconds: 2)),
                  );
                }
              },
            ),
            if (isSuggested) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'WZNÓW',
                  style: TextStyle(
                    color: Colors.greenAccent, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ] else 
              const Icon(Icons.chevron_right, color: Colors.white30, size: 20),
          ],
        ),
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(
                args: PlayerArgs(
                  item: widget.item,
                  initialUrl: source.url,
                  sourceName: source.sourceName,
                  title: source.title,
                  season: _selectedSeason,
                  episode: _selectedEpisode,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrailerButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            if (_trailerKey != null) {
              final youtubeUrl = Uri.parse('https://www.youtube.com/watch?v=$_trailerKey');
              if (await canLaunchUrl(youtubeUrl)) {
                await launchUrl(youtubeUrl, mode: LaunchMode.externalApplication);
              }
            }
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_fill_rounded, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text(
                'Odtwórz zwiastun',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCastSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Obsada', 
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 115,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _cast!.length,
            itemBuilder: (context, index) {
              final actor = _cast![index];
              return Container(
                width: 80,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      backgroundImage: actor['profileUrl'] != null 
                          ? NetworkImage(actor['profileUrl']) 
                          : null,
                      child: actor['profileUrl'] == null 
                          ? const Icon(Icons.person, color: Colors.white54, size: 24)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      actor['name'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      actor['character'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white38, fontSize: 9),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScraperProgressWidget({bool noResults = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (noResults)
                const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 18)
              else
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
                ),
              const SizedBox(width: 12),
              Text(
                noResults ? 'Brak dostępnych źródeł' : 'Wyszukiwanie źródeł wideo...',
                style: TextStyle(
                  color: noResults ? Colors.white38 : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_scraperProgress.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Inicjalizacja scraperów...',
                style: TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic),
              ),
            )
          else
            ..._scraperProgress.entries.map((entry) {
              final scraperName = entry.key;
              final status = entry.value;
              
              IconData statusIcon = Icons.hourglass_empty_rounded;
              Color statusColor = Colors.white38;
              String statusText = 'oczekiwanie';
              
              if (status == 'szukanie') {
                statusIcon = Icons.search_rounded;
                statusColor = Colors.amber;
                statusText = 'szukanie...';
              } else if (status == 'znaleziono') {
                statusIcon = Icons.check_circle_rounded;
                statusColor = Colors.greenAccent;
                statusText = 'gotowe';
              } else if (status == 'brak') {
                statusIcon = Icons.cancel_rounded;
                statusColor = Colors.white24;
                statusText = 'brak wyników';
              } else if (status == 'timeout') {
                statusIcon = Icons.timer_off_rounded;
                statusColor = Colors.redAccent;
                statusText = 'limit czasu';
              } else if (status == 'błąd') {
                statusIcon = Icons.error_outline_rounded;
                statusColor = Colors.redAccent;
                statusText = 'błąd';
              }
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      scraperName.toUpperCase(),
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const Spacer(),
                    Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
