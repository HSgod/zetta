import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../domain/media_item.dart';

class TmdbService {
  final String _apiKey = dotenv.env['TMDB_API_KEY'] ?? '';
  final String _baseUrl = dotenv.env['TMDB_BASE_URL'] ?? 'https://api.themoviedb.org/3';
  final String _imageBaseUrl = dotenv.env['TMDB_IMAGE_BASE_URL'] ?? 'https://image.tmdb.org/t/p/w500';

  Future<List<MediaItem>> getTrending() async {
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
    if (query.isEmpty) return [];
    
    final response = await http.get(
      Uri.parse('$_baseUrl/search/multi?api_key=$_apiKey&language=pl-PL&query=${Uri.encodeComponent(query)}'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      // Filtrujemy tylko filmy i seriale (TMDB multi search zwraca też osoby)
      return results
          .where((json) => json['media_type'] == 'movie' || json['media_type'] == 'tv')
          .map((json) => _mapToMediaItem(json))
          .toList();
    } else {
      throw Exception('Failed to search');
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
