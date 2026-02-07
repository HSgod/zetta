import '../../features/home/domain/media_item.dart';

abstract class BaseScraper {
  String get name; // Nazwa serwisu np. "Filman"

  // Metoda szukająca filmu/serialu w serwisie
  // Zwraca listę URLi do podstron z wideo
  Future<List<SearchResult>> search(String title, MediaType type);

  // Metoda wyciągająca linki do wideo z konkretnej podstrony
  Future<List<VideoSource>> getSources(SearchResult result, {int? season, int? episode});
}

class SearchResult {
  final String title;
  final String url;
  final String sourceName;

  SearchResult({required this.title, required this.url, required this.sourceName});
}

class VideoSource {
  final String url;
  final String title; // Tytuł ze strony źródłowej
  final String quality; // np. "1080p", "720p"
  final String sourceName; // Nazwa scrapera (np. Ekino-TV)
  final Map<String, String>? headers; // Np. Referer, User-Agent
  final bool isWebView; // Czy źródło wymaga otwarcia w WebView (np. trudny player)
  final String? automationScript; // Opcjonalny skrypt JS do automatyzacji klikania
  final List<SubtitleSource>? subtitles; // Napisy

  VideoSource({
    required this.url,
    required this.title,
    required this.quality,
    required this.sourceName,
    this.headers,
    this.isWebView = false,
    this.automationScript,
    this.subtitles,
  });
}

class SubtitleSource {
  final String url;
  final String label; // Np. "Polski", "English"
  final String? language; // Np. "pl", "en"

  SubtitleSource({
    required this.url,
    required this.label,
    this.language,
  });
}
