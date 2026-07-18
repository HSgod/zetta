import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../domain/media_item.dart';
import '../domain/episode.dart';

class TmdbService {
  final String _apiKey = dotenv.env['TMDB_API_KEY'] ?? '';
  final String _baseUrl = dotenv.env['TMDB_BASE_URL'] ?? 'https://api.themoviedb.org/3';
  final String _imageBaseUrl = dotenv.env['TMDB_IMAGE_BASE_URL'] ?? 'https://image.tmdb.org/t/p/w500';

  Future<List<MediaItem>> getTrending() async {
    // ... (bez zmian)
    final response = await http.get(
      Uri.parse('$_baseUrl/trending/all/day?api_key=$_apiKey&language=pl-PL'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      return results.map((json) => _mapToMediaItem(json)).toList();
    } else {
      throw Exception('Failed to load trending');
    }
  }

  Future<List<MediaItem>> search(String query) async {
    // ... (bez zmian)
    if (query.isEmpty) return [];
    
    final response = await http.get(
      Uri.parse('$_baseUrl/search/multi?api_key=$_apiKey&language=pl-PL&query=${Uri.encodeComponent(query)}'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      return results
          .where((json) => json['media_type'] == 'movie' || json['media_type'] == 'tv')
          .map((json) => _mapToMediaItem(json))
          .toList();
    } else {
      throw Exception('Failed to search');
    }
  }

  // Nowa metoda: Pobierz szczegóły serialu (liczba sezonów)
  Future<Map<String, dynamic>> getTVDetails(String id) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/tv/$id?api_key=$_apiKey&language=pl-PL'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load TV details');
    }
  }

  // Nowa metoda: Pobierz odcinki dla danego sezonu
  Future<List<Episode>> getSeasonEpisodes(String tvId, int seasonNumber) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/tv/$tvId/season/$seasonNumber?api_key=$_apiKey&language=pl-PL'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List episodes = data['episodes'];
      return episodes.map((e) => Episode.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load episodes');
    }
  }

  Future<List<MediaItem>> getPopularMovies() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/popular?api_key=$_apiKey&language=pl-PL'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      return results.map((json) => _mapToMediaItem(json, type: MediaType.movie)).toList();
    } else {
      throw Exception('Failed to load popular movies');
    }
  }

  Future<List<MediaItem>> getPopularTV() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/tv/popular?api_key=$_apiKey&language=pl-PL'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      return results.map((json) => _mapToMediaItem(json, type: MediaType.series)).toList();
    } else {
      throw Exception('Failed to load popular TV series');
    }
  }

  Future<List<MediaItem>> getRecommendations(String id, MediaType type) async {
    final endpoint = type == MediaType.movie ? 'movie' : 'tv';
    final response = await http.get(
      Uri.parse('$_baseUrl/$endpoint/$id/recommendations?api_key=$_apiKey&language=pl-PL'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      return results.map((json) => _mapToMediaItem(json, type: type)).toList();
    } else {
      throw Exception('Failed to load recommendations');
    }
  }

  Future<List<MediaItem>> getDiscover({required MediaType type, int? genreId}) async {
    final endpoint = type == MediaType.movie ? 'movie' : 'tv';
    final genreParam = genreId != null ? '&with_genres=$genreId' : '';
    
    final response = await http.get(
      Uri.parse('$_baseUrl/discover/$endpoint?api_key=$_apiKey&language=pl-PL&sort_by=popularity.desc$genreParam&page=1'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      return results.map((json) => _mapToMediaItem(json, type: type)).take(18).toList();
    } else {
      throw Exception('Failed to discover media');
    }
  }

  Future<String?> getTrailerKey(String id, MediaType type) async {
    final endpoint = type == MediaType.movie ? 'movie' : 'tv';
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$endpoint/$id/videos?api_key=$_apiKey&language=pl-PL'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        final trailer = results.firstWhere(
          (v) => v['site'] == 'YouTube' && v['type'] == 'Trailer',
          orElse: () => null,
        );
        if (trailer != null) return trailer['key'];
      }
      
      final engResponse = await http.get(
        Uri.parse('$_baseUrl/$endpoint/$id/videos?api_key=$_apiKey'),
      );
      if (engResponse.statusCode == 200) {
        final data = json.decode(engResponse.body);
        final List results = data['results'] ?? [];
        final trailer = results.firstWhere(
          (v) => v['site'] == 'YouTube' && v['type'] == 'Trailer',
          orElse: () => null,
        );
        if (trailer != null) return trailer['key'];
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> getCredits(String id, MediaType type) async {
    final endpoint = type == MediaType.movie ? 'movie' : 'tv';
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$endpoint/$id/credits?api_key=$_apiKey&language=pl-PL'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List cast = data['cast'] ?? [];
        return cast.take(12).map((c) => {
          'name': c['name'] ?? '',
          'character': c['character'] ?? '',
          'profileUrl': c['profile_path'] != null 
              ? 'https://image.tmdb.org/t/p/w185${c['profile_path']}'
              : null,
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static const Map<int, String> _genreNames = {
    28: 'Akcja', 12: 'Przygodowy', 16: 'Animacja', 35: 'Komedia',
    80: 'Kryminał', 99: 'Dokumentalny', 18: 'Dramat', 10751: 'Familijny',
    14: 'Fantasy', 36: 'Historyczny', 27: 'Horror', 10402: 'Muzyczny',
    9648: 'Tajemnica', 10749: 'Romans', 878: 'Sci-Fi', 10770: 'Film TV',
    53: 'Thriller', 10752: 'Wojenny', 37: 'Western',
    10759: 'Akcja i przygoda', 10762: 'Dla dzieci', 10763: 'Wiadomości',
    10764: 'Reality', 10765: 'Sci-Fi i fantasy', 10766: 'Telenowela',
    10767: 'Talk show', 10768: 'Polityczny',
  };

  MediaItem _mapToMediaItem(Map<String, dynamic> json, {MediaType? type}) {
    final bool isMovie = type == MediaType.movie || (type == null && (json['media_type'] == 'movie' || json['title'] != null));
    final List genreIds = json['genre_ids'] ?? [];
    final List<String> genres = genreIds
        .whereType<int>()
        .map((id) => _genreNames[id])
        .whereType<String>()
        .take(3)
        .toList();
    return MediaItem(
      id: json['id'].toString(),
      title: (isMovie ? json['title'] : json['name']) ?? 'Brak tytułu',
      posterUrl: json['poster_path'] != null 
          ? '$_imageBaseUrl${json['poster_path']}' 
          : null,
      backdropUrl: json['backdrop_path'] != null 
          ? 'https://image.tmdb.org/t/p/w780${json['backdrop_path']}' 
          : null,
      description: json['overview'] ?? '',
      rating: (json['vote_average'] as num?)?.toDouble(),
      type: isMovie ? MediaType.movie : MediaType.series,
      releaseDate: isMovie ? json['release_date'] : json['first_air_date'],
      genres: genres.isNotEmpty ? genres : null,
    );
  }
}
