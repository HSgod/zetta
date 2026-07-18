import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/media_item.dart';
import 'providers/search_provider.dart';
import 'widgets/media_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime? _lastPressed;
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  // Rotating slideshow for hero banner
  int _heroIndex = 0;
  Timer? _heroTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
    _startHeroTimer();
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        final trendingAsync = ref.read(trendingProvider);
        trendingAsync.whenData((items) {
          if (items.isNotEmpty) {
            setState(() {
              // Cycle through the top 5 trending items
              _heroIndex = (_heroIndex + 1) % (items.length.clamp(0, 5));
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _heroTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final trendingAsync = ref.watch(trendingProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // White icons on Android
        statusBarBrightness: Brightness.dark, // White icons on iOS
      ),
      child: PopScope(
        canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final now = DateTime.now();
        final maxDuration = const Duration(seconds: 2);
        
        if (_lastPressed == null || now.difference(_lastPressed!) > maxDuration) {
          _lastPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Naciśnij ponownie, aby wyjść'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              width: 250,
            ),
          );
          return;
        }
        
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              setState(() {
                _scrollOffset = _scrollController.offset;
              });
            }
            return true;
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Hero section with Parallax
              SliverToBoxAdapter(
                child: trendingAsync.when(
                  data: (items) {
                    if (items.isEmpty) return const SizedBox(height: 100);
                    final index = _heroIndex % items.length;
                    final heroItem = items[index];
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 800),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                      child: _HeroBanner(
                        key: ValueKey<String>(heroItem.id),
                        heroItem: heroItem, 
                        scrollOffset: _scrollOffset,
                      ),
                    );
                  },
                  loading: () => _BannerShimmer(),
                  error: (err, stack) => Container(
                    height: 200,
                    color: Colors.black,
                    child: Center(
                      child: Text(
                        'Nie udało się pobrać hitów dnia: $err',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Horizontal Rows of Media
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Spectacular "Top 10 w Polsce dzisiaj" Row
                    trendingAsync.when(
                      data: (items) {
                        if (items.isEmpty) return const SizedBox.shrink();
                        // Limit to 10 items
                        final top10Items = items.take(10).toList();
                        return _Top10Section(items: top10Items);
                      },
                      loading: () => const SizedBox(
                        height: 250,
                        child: Center(child: CircularProgressIndicator(color: Colors.red)),
                      ),
                      error: (err, stack) => const SizedBox.shrink(),
                    ),
                    
                    // Popular Movies
                    _MediaSectionWithProvider(
                      title: 'Popularne filmy',
                      provider: popularMoviesProvider,
                    ),
                    
                    // Popular TV Shows
                    _MediaSectionWithProvider(
                      title: 'Popularne seriale',
                      provider: popularTVProvider,
                    ),
                    
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

class _HeroBanner extends StatelessWidget {
  final MediaItem heroItem;
  final double scrollOffset;

  const _HeroBanner({
    super.key,
    required this.heroItem,
    required this.scrollOffset,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bannerHeight = screenWidth > 900 ? 620.0 : 560.0;
    
    // Mathematically safe parallax to avoid any gaps or clipping
    final double parallaxOffset = (scrollOffset * 0.15).clamp(0.0, 80.0);

    return Container(
      height: bannerHeight,
      width: double.infinity,
      child: Stack(
        children: [
          // Background Backdrop image with safe Parallax
          Positioned(
            top: -80.0 + parallaxOffset,
            bottom: -80.0,
            left: 0,
            right: 0,
            child: heroItem.backdropUrl != null
                ? Image.network(
                    heroItem.backdropUrl!,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                  )
                : (heroItem.posterUrl != null
                    ? Image.network(
                        heroItem.posterUrl!,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder()),
          ),
          
          // Gradient Overlay (fades into bottom black)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.65),
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.85),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.3, 0.6, 0.85, 1.0],
                ),
              ),
            ),
          ),
          
          // Content overlay
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Media Type Badge / HIT Logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'N O W O Ś Ć',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      heroItem.type == MediaType.movie ? 'FILM' : 'SERIAL',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Title
                Text(
                  heroItem.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        blurRadius: 12,
                        color: Colors.black87,
                        offset: Offset(0, 3),
                      )
                    ]
                  ),
                ),
                const SizedBox(height: 8),
                
                // Genre Tags — real TMDB data or rating/year fallback
                if (heroItem.genres != null && heroItem.genres!.isNotEmpty)
                  Text(
                    heroItem.genres!.join('  •  '),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                const SizedBox(height: 10),
                
                // Rating / Release Year
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (heroItem.rating != null && heroItem.rating! > 0) ...[
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        heroItem.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (heroItem.releaseDate != null && heroItem.releaseDate!.length >= 4) ...[
                      Text(
                        heroItem.releaseDate!.substring(0, 4),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                
                // Description (Short overview)
                if (heroItem.description != null && heroItem.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      heroItem.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        height: 1.3,
                        shadows: const [
                          Shadow(
                            blurRadius: 6,
                            color: Colors.black,
                            offset: Offset(0, 1),
                          )
                        ]
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                
                // SINGLE PLAY BUTTON with scale animation
                _AnimatedPlayButton(
                  onPressed: () => context.push('/details', extra: heroItem),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade900,
      child: const Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: Colors.white30,
          size: 64,
        ),
      ),
    );
  }
}

class _BannerShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -1.0, end: 2.0),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          height: 520,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(value - 1, 0),
              end: Alignment(value, 0),
              colors: [
                Colors.grey[900]!,
                Colors.grey[850]!,
                Colors.grey[900]!,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fake section title bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -1.0, end: 2.0),
            duration: const Duration(milliseconds: 1200),
            builder: (_, v, __) => Container(
              height: 18,
              width: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment(v - 1, 0),
                  end: Alignment(v, 0),
                  colors: [Colors.grey[900]!, Colors.grey[800]!, Colors.grey[900]!],
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 270,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: -1.0, end: 2.0),
                duration: Duration(milliseconds: 1200 + i * 80),
                builder: (_, v, __) => Container(
                  width: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment(v - 1, 0),
                      end: Alignment(v, 0),
                      colors: [Colors.grey[900]!, Colors.grey[850]!, Colors.grey[900]!],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AnimatedPlayButton extends StatefulWidget {

  final VoidCallback onPressed;
  const _AnimatedPlayButton({required this.onPressed});

  @override
  State<_AnimatedPlayButton> createState() => _AnimatedPlayButtonState();
}

class _AnimatedPlayButtonState extends State<_AnimatedPlayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
              SizedBox(width: 6),
              Text(
                'Odtwórz',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaSectionWithProvider extends ConsumerWidget {
  final String title;
  final FutureProvider<List<MediaItem>> provider;

  const _MediaSectionWithProvider({
    required this.title,
    required this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMedia = ref.watch(provider);

    return asyncMedia.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return _MediaSection(title: title, items: items);
      },
      loading: () => _SectionShimmer(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}

class _MediaSection extends StatelessWidget {
  final String title;
  final List<MediaItem> items;

  const _MediaSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(
          height: 270,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
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
  }
}

// Spectacular Netflix Top 10 Section with Giant Numbers
class _Top10Section extends StatelessWidget {
  final List<MediaItem> items;

  const _Top10Section({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            'Top 10 w Polsce dzisiaj',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 25),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isTen = index == 9;
              return Container(
                width: isTen ? 220 : 175,
                margin: const EdgeInsets.only(right: 16),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Giant Outline Number on the left
                    Positioned(
                      left: isTen ? -15 : -10,
                      bottom: -14,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 120,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          height: 0.9,
                          letterSpacing: isTen ? -4 : -6,
                          shadows: [
                            // White outline effect
                            Shadow(offset: const Offset(-1.5, -1.5), color: Colors.grey.shade400),
                            Shadow(offset: const Offset(1.5, -1.5), color: Colors.grey.shade400),
                            Shadow(offset: const Offset(1.5, 1.5), color: Colors.grey.shade400),
                            Shadow(offset: const Offset(-1.5, 1.5), color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    ),
                    
                    // Poster Card shifted to the right, overlapping the number
                    Positioned(
                      top: 4,
                      bottom: 4,
                      right: 0,
                      left: isTen ? 110 : 55, // Leaves room for number
                      child: MediaCard(item: item),
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
}
