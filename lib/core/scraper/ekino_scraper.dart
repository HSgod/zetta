import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'base_scraper.dart';

class EkinoScraper extends BaseScraper {
  @override
  String get name => 'Ekino-TV';

  final String _baseUrl = 'https://ekino-tv.pl';

  @override
  Future<List<SearchResult>> search(String title) async {
    final searchUrl = '$_baseUrl/search/qf/?q=${Uri.encodeComponent(title)}';
    try {
      final response = await http.get(Uri.parse(searchUrl));
      if (response.statusCode == 200) {
        var document = parse(response.body);
        var items = document.querySelectorAll('.movies-list-item');
        List<SearchResult> results = [];
        for (var element in items) {
          var link = element.querySelector('a');
          var titleElement = element.querySelector('.title, h2, .name');
          var href = link?.attributes['href'];
          if (href != null) {
            if (!href.startsWith('http')) href = '$_baseUrl$href';
            results.add(SearchResult(
              title: titleElement?.text.trim() ?? 'Film Ekino',
              url: href,
              sourceName: name,
            ));
          }
        }
        return results;
      }
    } catch (e) { /* error */ }
    return [];
  }

  @override
  Future<List<VideoSource>> getSources(SearchResult result) async {
    try {
      final response = await http.get(Uri.parse(result.url));
      if (response.statusCode == 200) {
        var document = parse(response.body);
        
        bool hasPlayer = document.querySelector('.players') != null || 
                         document.querySelector('img[src*="kliknij_aby_obejrzec"]') != null ||
                         document.querySelector('.buttonprch') != null;

        if (!hasPlayer) return [];

        return [
          VideoSource(
            url: result.url,
            title: result.title,
            quality: 'Auto',
            sourceName: name,
            isWebView: false,
          )
        ];
      }
    } catch (e) {
      /* error */
    }
    return [];
  }
}
