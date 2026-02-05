import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/tmdb_service.dart';
import '../../domain/media_item.dart';
import 'package:zetta/core/scraper/scraper_service.dart';

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

// Provider odkrywania treści
final discoverProvider = FutureProvider.family<List<MediaItem>, ({MediaType type, int? genreId})>((ref, arg) async {
  final service = ref.watch(tmdbServiceProvider);
  return service.getDiscover(type: arg.type, genreId: arg.genreId);
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

  

  

    final available = await scraper.isAvailable(item.title);

    return (item: item, available: available);

  }));



  // Zwracamy tylko te pozycje, które są dostępne chociaż na jednym scraperze.

  return availabilityChecks

      .where((result) => result.available)

      .map((result) => result.item)

      .toList();

});
