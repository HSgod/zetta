import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'base_scraper.dart';

class ObejrzyjToScraper extends BaseScraper {
  @override
  String get name => 'Obejrzyj.to';

  // Główny URL (może ulec zmianie, warto trzymać w configu)
  final String _baseUrl = 'https://obejrzyj.to';

  // Nagłówki udające przeglądarkę (ważne!)
  final Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7',
  };

  @override
  Future<List<SearchResult>> search(String title) async {
    // Próba zgadnięcia endpointu wyszukiwarki. 
    // Często jest to /szukaj?q=... lub /wyszukiwarka?phrase=...
    // Spróbujmy standardowego query.
    final searchUrl = '$_baseUrl/szukaj?q=${Uri.encodeComponent(title)}';
    print('[$name] Searching: $searchUrl');

    try {
      final response = await http.get(Uri.parse(searchUrl), headers: _headers);

      if (response.statusCode == 200) {
        var document = parse(response.body);
        
        // LOGIKA PARSOWANIA HTML
        // Tutaj musimy trafić w odpowiednie klasy CSS serwisu.
        // Zakładam typową strukturę kafelkową.
        // Jeśli nie zadziała, będziemy musieli sprawdzić kod źródłowy strony.
        
        // Szukamy kontenera z wynikami (często .movie-item, .item, .col-md-2 etc.)
        // Przykładowy selektor (do weryfikacji):
        var items = document.querySelectorAll('.movie-item, .video-item, article'); 

        print('[$name] Found ${items.length} items in HTML');

        List<SearchResult> results = [];
        for (var element in items) {
          // Szukamy linku <a>
          var linkElement = element.querySelector('a');
          var href = linkElement?.attributes['href'];
          
          // Szukamy tytułu (często w alt obrazka lub w osobnym divie)
          var titleElement = element.querySelector('.title, h2, h3, .movie-title');
          var imgElement = element.querySelector('img');
          
          var foundTitle = titleElement?.text.trim() ?? imgElement?.attributes['alt'] ?? 'Bez tytułu';

          if (href != null) {
            // Często linki są relatywne (/film/tytul), trzeba dodać base url
            if (!href.startsWith('http')) {
              href = '$_baseUrl$href';
            }

            results.add(SearchResult(
              title: foundTitle,
              url: href,
              sourceName: name,
            ));
          }
        }
        return results;
      } else {
        print('[$name] Error: Status code ${response.statusCode}');
      }
    } catch (e) {
      print('[$name] Search Exception: $e');
    }
    return [];
  }

  @override
  Future<List<VideoSource>> getSources(String url) async {
    print('[$name] Getting sources form: $url');
    try {
      final response = await http.get(Uri.parse(url), headers: _headers);
      
      if (response.statusCode == 200) {
        var document = parse(response.body);
        
        // Tutaj szukamy iframe'ów z playerami
        var iframes = document.querySelectorAll('iframe');
        List<VideoSource> sources = [];

        for (var iframe in iframes) {
          var src = iframe.attributes['src'];
          if (src != null) {
            // Często src jest relatywny lub z protokołem //
            if (src.startsWith('//')) src = 'https:$src';
            
            print('[$name] Found iframe: $src');

            // Tutaj w przyszłości użyjemy "Extractora" (np. dla videra, mixdropa).
            // Na ten moment zwracamy ten link jako źródło "Web", 
            // Player media_kit może nie obsłużyć iframe html, ale spróbujmy.
            
            // Filtrujemy reklamy
            if (!src.contains('facebook') && !src.contains('google')) {
               sources.add(VideoSource(
                url: src, 
                quality: 'Embed',
                headers: {'Referer': _baseUrl} // Często wymagane
              ));
            }
          }
        }
        return sources;
      }
    } catch (e) {
      print('[$name] GetSources Exception: $e');
    }
    return [];
  }
}
