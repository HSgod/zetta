import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../home/domain/media_item.dart';
import '../../../../core/theme/theme_provider.dart';

// Klasa pomocnicza do konwersji MediaItem na JSON
extension MediaItemJson on MediaItem {
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'posterUrl': posterUrl,
      'description': description,
      'rating': rating,
      'type': type == MediaType.movie ? 'movie' : 'series',
      'releaseDate': releaseDate,
    };
  }

  static MediaItem fromMap(Map<String, dynamic> map) {
    return MediaItem(
      id: map['id'],
      title: map['title'],
      posterUrl: map['posterUrl'],
      description: map['description'],
      rating: map['rating'],
      type: map['type'] == 'movie' ? MediaType.movie : MediaType.series,
      releaseDate: map['releaseDate'],
    );
  }
}

class FavoritesNotifier extends Notifier<List<MediaItem>> {
  static const _key = 'favorites';

  @override
  List<MediaItem> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final jsonList = prefs.getStringList(_key) ?? [];
    return jsonList.map((s) => MediaItemJson.fromMap(json.decode(s))).toList();
  }

  void toggleFavorite(MediaItem item) {
    final prefs = ref.read(sharedPreferencesProvider);
    final exists = state.any((e) => e.id == item.id);
    
    if (exists) {
      state = state.where((e) => e.id != item.id).toList();
    } else {
      state = [...state, item];
    }

    final jsonList = state.map((e) => json.encode(e.toMap())).toList();
    prefs.setStringList(_key, jsonList);
  }

  bool isFavorite(String id) {
    return state.any((e) => e.id == id);
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, List<MediaItem>>(FavoritesNotifier.new);

class HistoryNotifier extends Notifier<List<MediaItem>> {
  static const _key = 'history';

  @override
  List<MediaItem> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final jsonList = prefs.getStringList(_key) ?? [];
    return jsonList.map((s) => MediaItemJson.fromMap(json.decode(s))).toList();
  }
  
  void addToHistory(MediaItem item) {
    final prefs = ref.read(sharedPreferencesProvider);
    final newList = [item, ...state.where((e) => e.id != item.id)].take(20).toList();
    state = newList;

    final jsonList = state.map((e) => json.encode(e.toMap())).toList();
    prefs.setStringList(_key, jsonList);
  }

  void removeFromHistory(String id) {
    final prefs = ref.read(sharedPreferencesProvider);
    state = state.where((e) => e.id != id).toList();
    final jsonList = state.map((e) => json.encode(e.toMap())).toList();
    prefs.setStringList(_key, jsonList);
  }

  void clearHistory() {
    final prefs = ref.read(sharedPreferencesProvider);
    state = [];
    prefs.remove(_key);
  }
}

final historyProvider = NotifierProvider<HistoryNotifier, List<MediaItem>>(HistoryNotifier.new);

class ContinueWatchingNotifier extends Notifier<List<MediaItem>> {
  static const _key = 'continue_watching';

  @override
  List<MediaItem> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final jsonList = prefs.getStringList(_key) ?? [];
    return jsonList.map((s) => MediaItemJson.fromMap(json.decode(s))).toList();
  }

  void addToContinue(MediaItem item) {
    final prefs = ref.read(sharedPreferencesProvider);
    final newList = [item, ...state.where((e) => e.id != item.id)].take(10).toList();
    state = newList;

    final jsonList = state.map((e) => json.encode(e.toMap())).toList();
    prefs.setStringList(_key, jsonList);
  }

  void removeFromContinue(String id) {
    final prefs = ref.read(sharedPreferencesProvider);
    state = state.where((e) => e.id != id).toList();
    final jsonList = state.map((e) => json.encode(e.toMap())).toList();
    prefs.setStringList(_key, jsonList);

    prefs.remove('progress_$id');
    prefs.remove('source_$id');
  }
}

final continueWatchingProvider = NotifierProvider<ContinueWatchingNotifier, List<MediaItem>>(ContinueWatchingNotifier.new);

class SavedSource {
  final String url;
  final String? pageUrl;
  final Map<String, String>? headers;
  final String? automationScript;

  SavedSource({required this.url, this.pageUrl, this.headers, this.automationScript});

  Map<String, dynamic> toMap() => {
    'url': url,
    'pageUrl': pageUrl,
    'headers': headers,
    'automationScript': automationScript,
  };

  factory SavedSource.fromMap(Map<String, dynamic> map) => SavedSource(
    url: map['url'],
    pageUrl: map['pageUrl'],
    headers: map['headers'] != null ? Map<String, String>.from(map['headers']) : null,
    automationScript: map['automationScript'],
  );
}

// KLUCZOWA POPRAWKA: Provider musi być reaktywny (Map), aby DetailsScreen wiedzia\u0142 o zmianie
class SourceHistoryNotifier extends Notifier<Map<String, SavedSource>> {
  @override
  Map<String, SavedSource> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final Map<String, SavedSource> results = {};
    
    // Wczytujemy wszystkie zapisane źr\u00f3d\u0142a z SharedPreferences
    for (String key in prefs.getKeys()) {
      if (key.startsWith('source_')) {
        final id = key.replaceFirst('source_', '');
        final data = prefs.getString(key);
        if (data != null) {
          results[id] = SavedSource.fromMap(json.decode(data));
        }
      }
    }
    return results;
  }

  void saveSource(String mediaId, SavedSource source) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString('source_$mediaId', json.encode(source.toMap()));
    // Aktualizujemy stan, co wymusi przebudowanie UI
    state = {...state, mediaId: source};
  }

  SavedSource? getSource(String mediaId) {
    return state[mediaId];
  }
}

final sourceHistoryProvider = NotifierProvider<SourceHistoryNotifier, Map<String, SavedSource>>(SourceHistoryNotifier.new);