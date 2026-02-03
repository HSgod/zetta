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

  MediaItem _mapToMediaItem(Map<String, dynamic> json) {
    final bool isMovie = json['media_type'] == 'movie' || json['title'] != null;
    return MediaItem(
      id: json['id'].toString(),
      title: (isMovie ? json['title'] : json['name']) ?? 'Brak tytułu',
      posterUrl: json['poster_path'] != null 
          ? '$_imageBaseUrl${json['poster_path']}' 
          : null,
      description: json['overview'] ?? '',
      rating: (json['vote_average'] as num?)?.toDouble(),
      type: isMovie ? MediaType.movie : MediaType.series,
      releaseDate: isMovie ? json['release_date'] : json['first_air_date'],
    );
  }
}
