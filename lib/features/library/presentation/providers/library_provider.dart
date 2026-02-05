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

// Notifier dla Historii
class HistoryNotifier extends Notifier<List<MediaItem>> {
  @override
  List<MediaItem> build() => [];
  
  void addToHistory(MediaItem item) {
    state = [item, ...state.where((e) => e.id != item.id)];
  }
}

final historyProvider = NotifierProvider<HistoryNotifier, List<MediaItem>>(HistoryNotifier.new);

// Notifier dla Kontynuuj oglądanie
class ContinueWatchingNotifier extends Notifier<List<MediaItem>> {
  @override
  List<MediaItem> build() => [];
}

final continueWatchingProvider = NotifierProvider<ContinueWatchingNotifier, List<MediaItem>>(ContinueWatchingNotifier.new);
