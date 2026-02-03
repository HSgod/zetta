import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/tmdb_service.dart';
import '../../domain/media_item.dart';

final tmdbServiceProvider = Provider((ref) => TmdbService());

// Provider trendów
final trendingProvider = FutureProvider<List<MediaItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  return service.getTrending();
});

// Stan wyszukiwania
final searchQueryProvider = StateProvider<String>((ref) => '');

// Provider wyników wyszukiwania
final searchResultsProvider = FutureProvider<List<MediaItem>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final service = ref.watch(tmdbServiceProvider);
  
  if (query.isEmpty) {
    return [];
  }
  
  // Mały debouncing (opcjonalnie, ale tu zrobimy prosto)
  return service.search(query);
});
