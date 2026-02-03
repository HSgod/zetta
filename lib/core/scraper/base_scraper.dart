abstract class BaseScraper {
  String get name; // Nazwa serwisu np. "Filman"

  // Metoda szukająca filmu/serialu w serwisie
  // Zwraca listę URLi do podstron z wideo
  Future<List<SearchResult>> search(String title);

  // Metoda wyciągająca linki do wideo z konkretnej podstrony
  Future<List<VideoSource>> getSources(String url);
}

class SearchResult {
  final String title;
  final String url;
  final String sourceName;

  SearchResult({required this.title, required this.url, required this.sourceName});
}

class VideoSource {
  final String url;
  final String quality; // np. "1080p", "720p"
  final Map<String, String>? headers; // Np. Referer, User-Agent
  final bool isWebView; // Czy źródło wymaga otwarcia w WebView (np. trudny player)

  VideoSource({
    required this.url,
    required this.quality,
    this.headers,
    this.isWebView = false,
  });
}
