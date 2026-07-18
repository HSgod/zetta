import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/tmdb_service.dart';
import '../../domain/media_item.dart';
import 'package:zetta/core/scraper/scraper_service.dart';
import '../../../../core/theme/theme_provider.dart';

final tmdbServiceProvider = Provider((ref) => TmdbService());

// Provider trendów
final trendingProvider = FutureProvider<List<MediaItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  return service.getTrending();
});

// Provider popularnych filmów
final popularMoviesProvider = FutureProvider<List<MediaItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  return service.getPopularMovies();
});

// Provider popularnych seriali
final popularTVProvider = FutureProvider<List<MediaItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  return service.getPopularTV();
});

// Provider rekomendacji (podobne treści)
final recommendationsProvider = FutureProvider.family<List<MediaItem>, ({String id, MediaType type})>((ref, arg) async {
  final service = ref.watch(tmdbServiceProvider);
  return service.getRecommendations(arg.id, arg.type);
});

class DiscoverState {
  final List<MediaItem> items;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  
  DiscoverState({
    required this.items,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });
  
  DiscoverState copyWith({List<MediaItem>? items, bool? isLoading, bool? hasMore, String? error}) {
    return DiscoverState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
    );
  }
}

class DiscoverNotifier extends Notifier<DiscoverState> {
  final ({MediaType type, int? genreId}) arg;
  late final TmdbService _service;
  late final MediaType _type;
  late final int? _genreId;
  int _page = 1;

  DiscoverNotifier(this.arg);

  @override
  DiscoverState build() {
    _service = ref.watch(tmdbServiceProvider);
    _type = arg.type;
    _genreId = arg.genreId;
    _page = 1;
    Future.microtask(() => _loadInitial());
    return DiscoverState(items: [], isLoading: true);
  }

  Future<void> _loadInitial() async {
    try {
      final items = await _service.getDiscover(type: _type, genreId: _genreId, page: _page);
      state = state.copyWith(items: items, isLoading: false, hasMore: items.isNotEmpty);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    try {
      _page++;
      final newItems = await _service.getDiscover(type: _type, genreId: _genreId, page: _page);
      if (newItems.isEmpty) {
        state = state.copyWith(isLoading: false, hasMore: false);
      } else {
        state = state.copyWith(items: [...state.items, ...newItems], isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      _page--;
    }
  }
}

final discoverProvider = NotifierProvider.family<DiscoverNotifier, DiscoverState, ({MediaType type, int? genreId})>((arg) {
  return DiscoverNotifier(arg);
});

// Stan wybranej kategorii (używamy Notifier dla Riverpod 3.x)
class HomeCategoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setCategory(String? category) {
    state = category;
  }
}

final homeCategoryProvider = NotifierProvider<HomeCategoryNotifier, String?>(HomeCategoryNotifier.new);

// Stan wyszukiwania (zaimplementowany jako Notifier)
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() {
    return '';
  }

  void update(String query) {
    state = query;
  }
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

// Stan historii wyszukiwania (zaimplementowany jako Notifier dla Riverpod 3.x)
class SearchHistoryNotifier extends Notifier<List<String>> {
  static const _key = 'search_history';

  @override
  List<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final historyJson = prefs.getString(_key);
    if (historyJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(historyJson);
        return decoded.cast<String>();
      } catch (_) {}
    }
    return [];
  }

  Future<void> addQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final prefs = ref.read(sharedPreferencesProvider);
    final newList = [trimmed, ...state.where((q) => q != trimmed)].take(8).toList();
    state = newList;
    await prefs.setString(_key, jsonEncode(newList));
  }

  Future<void> removeQuery(String query) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final newList = state.where((q) => q != query).toList();
    state = newList;
    await prefs.setString(_key, jsonEncode(newList));
  }

  Future<void> clearHistory() async {
    final prefs = ref.read(sharedPreferencesProvider);
    state = [];
    await prefs.remove(_key);
  }
}

final searchHistoryProvider = NotifierProvider<SearchHistoryNotifier, List<String>>(SearchHistoryNotifier.new);

// Provider wyników wyszukiwania

final searchResultsProvider = FutureProvider<List<MediaItem>>((ref) async {

  final query = ref.watch(searchQueryProvider);

  final service = ref.watch(tmdbServiceProvider);

  final scraper = ref.watch(scraperServiceProvider);

  

  if (query.isEmpty) {

    return [];

  }

  

    final tmdbResults = await service.search(query);

  

    

  

    // Ograniczamy do top 10 wyników, aby nie przeciążać scraperów i przyspieszyć wyszukiwanie

  

    final limitedResults = tmdbResults.take(10).toList();

  

    

  

    // Filtrujemy wyniki: pokazujemy tylko te, które faktycznie są na scraperach.

  

    final availabilityChecks = await Future.wait(limitedResults.map((item) async {

  

  

    final available = await scraper.isAvailable(item.title, item.type);

    return (item: item, available: available);

  }));



  // Zwracamy tylko te pozycje, które są dostępne chociaż na jednym scraperze.

  return availabilityChecks

      .where((result) => result.available)

      .map((result) => result.item)

      .toList();

});
