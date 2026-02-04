import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'base_scraper.dart';

class ObejrzyjToScraper extends BaseScraper {
  @override
  String get name => 'Obejrzyj.to';

  final String _baseUrl = 'https://obejrzyj.to';

  @override
  Future<List<SearchResult>> search(String title) async {
    final searchUrl = '$_baseUrl/search/${Uri.encodeComponent(title.toLowerCase())}';
    
    try {
        final response = await http.get(Uri.parse(searchUrl));
        if (response.statusCode == 200) {
            var document = parse(response.body);
            var allLinks = document.querySelectorAll('a');
            List<SearchResult> results = [];
            for (var link in allLinks) {
                var href = link.attributes['href'];
                var t = link.text.trim();
                if (t.isEmpty) t = link.querySelector('img')?.attributes['alt'] ?? '';
                if (href != null && t.isNotEmpty) {
                    if (href.contains('/titles/') || href.contains('/film/') || href.contains('/serial/')) {
                        if (!href.startsWith('http')) href = '$_baseUrl$href';
                        if (!results.any((r) => r.url == href)) {
                            results.add(SearchResult(title: t, url: href, sourceName: name));
                        }
                    }
                }
            }
            return results;
        }
    } catch(e) { /* error */ }
    return [];
  }

  @override
  Future<List<VideoSource>> getSources(SearchResult result) async {
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

  // Usuwamy nieużywaną już metodę _addSource
}
