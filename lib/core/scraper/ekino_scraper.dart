import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'base_scraper.dart';

import '../../features/home/domain/media_item.dart';

class EkinoScraper extends BaseScraper {
  @override
  String get name => 'Ekino-TV';

  final String _baseUrl = 'https://ekino-tv.pl';

  Map<String, String> get _headers => {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7',
    'Referer': 'https://ekino-tv.pl/',
  };

  @override
  Future<List<SearchResult>> search(String title, MediaType type) async {
    final searchUrl = '$_baseUrl/search/qf/?q=${Uri.encodeComponent(title)}';
    try {
      final response = await http.get(Uri.parse(searchUrl), headers: _headers);
      if (response.statusCode == 200) {
        var document = parse(response.body);
        var items = document.querySelectorAll('.movies-list-item, .movie-item, .item-list');
        List<SearchResult> results = [];
        for (var element in items) {
          var link = element.querySelector('a');
          var titleElement = element.querySelector('.title, h2, .name, .movie-title');
          var href = link?.attributes['href'];
          if (href != null) {
            // Filtrowanie po typie
            final isMovieLink = href.contains('/movie/') || href.contains('/film/');
            final isSerieLink = href.contains('/serie/') || href.contains('/tv-show/');
            
            if (type == MediaType.movie && !isMovieLink && isSerieLink) continue;
            if (type == MediaType.series && !isSerieLink && isMovieLink) continue;

            if (!href.startsWith('http')) href = '$_baseUrl$href';
            results.add(SearchResult(
              title: titleElement?.text.trim() ?? 'Film Ekino',
              url: href,
              sourceName: name,
            ));
          }
        }
        if (results.isEmpty && document.body?.text.contains('Brak wyników') == false) {
          // Spróbujmy jeszcze raz z innym selektorem dla linków
          var allLinks = document.querySelectorAll('a[href*="/movie/show/"], a[href*="/serie/show/"]');
          for (var link in allLinks) {
            var href = link.attributes['href']!;
            if (!href.startsWith('http')) href = '$_baseUrl$href';
            var title = link.text.trim();
            if (title.length > 2) {
              results.add(SearchResult(
                title: title,
                url: href,
                sourceName: name,
              ));
            }
          }
        }
        return results;
      }
    } catch (e) { /* error */ }
    return [];
  }

  @override
  Future<List<VideoSource>> getSources(SearchResult result, {int? season, int? episode}) async {
    String targetUrl = result.url;

    try {
      if (season != null && episode != null && result.url.contains('/serie/show/')) {
        final slug = result.url.split('/show/').last.replaceAll('/', '');
        targetUrl = '$_baseUrl/serie/watch/$slug+season[$season]+episode[$episode]+';
      }

      final response = await http.get(Uri.parse(targetUrl), headers: _headers);
      if (response.statusCode == 200) {
        var document = parse(response.body);
        
        bool hasPlayer = document.querySelector('.players') != null || 
                         document.querySelector('img[src*="kliknij_aby_obejrzec"]') != null ||
                         document.querySelector('.buttonprch') != null ||
                         document.querySelector('.warning_ch') != null ||
                         document.body?.text.contains('wybierz odtwarzacz') == true;

        if (!hasPlayer) return [];

        return [
          VideoSource(
            url: targetUrl,
            title: result.title,
            quality: 'Auto',
            sourceName: name,
            isWebView: true,
            headers: _headers,
          )
        ];
      }
    } catch (e) {
      print('Ekino getSources error: $e');
    }
    return [];
  }
}
