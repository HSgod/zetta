import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'base_scraper.dart';

class ObejrzyjToScraper extends BaseScraper {
  @override
  String get name => 'Obejrzyj.to';

  final String _baseUrl = 'https://obejrzyj.to';

  final Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
    'Accept-Language': 'pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7',
    'Cache-Control': 'max-age=0',
    'Sec-Ch-Ua': '"Not A(Brand";v="99", "Google Chrome";v="121", "Chromium";v="121"',
    'Sec-Ch-Ua-Mobile': '?0',
    'Sec-Ch-Ua-Platform': '"Windows"',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-User': '?1',
    'Upgrade-Insecure-Requests': '1',
  };

  @override
  Future<List<SearchResult>> search(String title) async {
    final searchUrl = '$_baseUrl/search/${Uri.encodeComponent(title.toLowerCase())}';
    print('[$name] Searching: $searchUrl');

    try {
      final response = await http.get(Uri.parse(searchUrl), headers: _headers);

      if (response.statusCode == 200) {
        var document = parse(response.body);
        
        var allLinks = document.querySelectorAll('a');
        List<SearchResult> results = [];

        for (var link in allLinks) {
          var href = link.attributes['href'];
          var title = link.text.trim();
          
          if (title.isEmpty) {
            title = link.querySelector('img')?.attributes['alt'] ?? '';
          }

          if (href != null && title.isNotEmpty) {
            // FIX: Szukamy linków pasujących do wzorca /titles/ (oraz starych /film/)
            if (href.contains('/titles/') || href.contains('/film/') || href.contains('/serial/')) {
              if (!href.startsWith('http')) {
                href = '$_baseUrl$href';
              }

              if (!results.any((r) => r.url == href)) {
                results.add(SearchResult(
                  title: title,
                  url: href,
                  sourceName: name,
                ));
              }
            }
          }
        }
        print('[$name] Found ${results.length} potential items');
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
        var body = response.body;
        List<VideoSource> sources = [];

        // 1. Szukamy standardowych iframe'ów
        var document = parse(body);
        var iframes = document.querySelectorAll('iframe');
        for (var iframe in iframes) {
          var src = iframe.attributes['src'] ?? iframe.attributes['data-src'];
          if (src != null) {
            _addSource(sources, src);
          }
        }

        // 2. Szukamy ukrytych linków do playerów w kodzie JS/HTML (Regex)
        // Szukamy linków do popularnych hostingów wideo
        final playerRegex = RegExp(r'(https?:\/\/(?:www\.)?(?:vider\.info|streamtape\.com|vidoza\.net|upstream\.to|mixdrop\.co|uqload\.to)\/[^"\s\x27\<\>]+)');
        
        var matches = playerRegex.allMatches(body);
        for (var match in matches) {
          var link = match.group(1);
          if (link != null) {
            // Usuwamy escape characters \/ -> /
            link = link.replaceAll(r'\/', '/');
            _addSource(sources, link);
          }
        }

        print('[$name] Found ${sources.length} sources');
        return sources;
      }
    } catch (e) {
      print('[$name] GetSources Exception: $e');
    }
    return [];
  }

  void _addSource(List<VideoSource> sources, String url) {
    if (url.startsWith('//')) url = 'https:$url';
    if (url.contains('facebook') || url.contains('google') || url.contains('twitter')) return;

    if (!sources.any((s) => s.url == url)) {
      print('[$name] Found player: $url');
      sources.add(VideoSource(
        url: url,
        quality: 'Embed',
        headers: {'Referer': _baseUrl},
      ));
    }
  }
}