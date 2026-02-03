import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'base_scraper.dart';

class FilmanScraper extends BaseScraper {
  @override
  String get name => 'Filman';

  final String _baseUrl = 'https://filman.cc';

  @override
  Future<List<SearchResult>> search(String title) async {
    final searchUrl = '$_baseUrl/wyszukiwarka?phrase=${Uri.encodeComponent(title)}';
    
    try {
      final response = await http.get(Uri.parse(searchUrl));
      if (response.statusCode == 200) {
        var document = parse(response.body);
        // Szukamy elementów z klasą .item (standardowa dla wyszukiwarek opartych na tym silniku)
        var items = document.querySelectorAll('#result-container .item');
        
        return items.map((element) {
          var link = element.querySelector('a');
          var titleElement = element.querySelector('.title');
          
          return SearchResult(
            title: titleElement?.text.trim() ?? 'Brak tytułu',
            url: link?.attributes['href'] ?? '',
            sourceName: name,
          );
        }).toList();
      }
    } catch (e) {
      print('Filman Search Error: $e');
    }
    return [];
  }

  @override
  Future<List<VideoSource>> getSources(String url) async {
    // Tu będzie magia wyciągania linków z playerów (vshare, vider itd.)
    // Na razie zwracamy pusto, dopóki nie rozpracujemy ich systemu
    return [];
  }
}
