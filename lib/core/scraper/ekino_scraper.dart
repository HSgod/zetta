import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import '../../features/home/domain/media_item.dart';
import 'base_scraper.dart';

class EkinoScraper extends BaseScraper {
  @override
  String get name => 'Ekino-TV';

  final String _baseUrl = 'https://ekino-tv.pl';
  
  final Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Referer': 'https://ekino-tv.pl/',
  };

  @override
  Future<List<SearchResult>> search(String title, MediaType type) async {
    final cleanQuery = Uri.encodeComponent(title);
    final searchUrl = '$_baseUrl/search/qf/?q=$cleanQuery';
    
    try {
      final response = await http.get(Uri.parse(searchUrl), headers: _headers);
      if (response.statusCode != 200) return [];

      final document = parse(response.body);
      final results = <SearchResult>[];

      final movieElements = document.querySelectorAll('.movies-list-item, .list-item, .movie-item');
      
      for (var element in movieElements) {
        final titleElement = element.querySelector('.title a, .name a, h2 a');
        var url = titleElement?.attributes['href'];
        final displayTitle = titleElement?.text.trim();

        if (displayTitle != null && url != null) {
          if (!url.startsWith('http')) url = '$_baseUrl$url';
          results.add(SearchResult(
            title: displayTitle,
            url: url,
            sourceName: name,
          ));
        }
      }

      return results;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<VideoSource>> getSources(SearchResult result, {int? season, int? episode}) async {
    String originalUrl = result.url;
    String fetchUrl = originalUrl;
    
    if (season != null && episode != null) {
      final pathParts = originalUrl.split('/show/').last.split('/');
      String slug = pathParts.first;
      
      if (RegExp(r'^\d+$').hasMatch(slug) && pathParts.length > 1) {
        slug = pathParts[1];
      }
      
      if (slug.endsWith('/')) slug = slug.substring(0, slug.length - 1);
      
      fetchUrl = '$_baseUrl/serie/watch/$slug+season[$season]+episode[$episode]+';
    }

    try {
      final response = await http.get(Uri.parse(fetchUrl), headers: _headers);
      if (response.statusCode != 200) return [];

      final body = response.body;
      final document = parse(body);
      final sources = <VideoSource>[];

      final playerElements = document.querySelectorAll('.players li, .player-item, [data-id]');
      for (var el in playerElements) {
        final id = el.attributes['data-id'];
        final nameAttr = el.attributes['data-name'];
        var sName = el.text.trim().split('\n').first.trim();

        if (id != null && id.length > 5) {
          final serverName = (nameAttr ?? sName).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (serverName.contains('mix') || serverName.contains('upzone') || serverName.contains('voe')) continue;

          final url = '$_baseUrl/watch/f/$serverName/$id';
          if (!sources.any((s) => s.url == url)) {
            sources.add(VideoSource(
              url: url,
              title: sName.toUpperCase(),
              quality: 'HD',
              sourceName: name,
              isWebView: true,
            ));
          }
        }
      }

      final showPlayerRegex = RegExp("ShowPlayer\\s*\\(\\s*['\\\"]([^'\\\"]+)['\\\"]\\s*,\\s*['\\\"]([^'\\\"]+)['\\\"]\\s*\\)", caseSensitive: false);
      final spMatches = showPlayerRegex.allMatches(body);
      for (var m in spMatches) {
        final sName = m.group(1)!;
        final id = m.group(2)!;
        
        final lowerName = sName.toLowerCase();
        if (lowerName.contains('mix') || lowerName.contains('upzone') || lowerName.contains('voe')) continue;
        
        final url = '$_baseUrl/watch/f/$lowerName/$id';
        if (!sources.any((s) => s.url == url)) {
          sources.add(VideoSource(
            url: url, 
            title: sName.toUpperCase(), 
            quality: 'HD', 
            sourceName: name, 
            isWebView: true,
          ));
        }
      }

      if (sources.isEmpty) {
        String bypassUrl = fetchUrl.replaceFirst('/show/', '/watch/');
        sources.add(VideoSource(
          url: bypassUrl,
          title: 'DOMYŚLNY PLAYER',
          quality: 'Auto',
          sourceName: name,
          isWebView: true,
        ));
      }

      return sources;
    } catch (e) {
      debugPrint('Ekino Scraper Error: $e');
      return [];
    }
  }
}
