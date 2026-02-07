import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_scraper.dart';
import '../../features/home/domain/media_item.dart';

class ObejrzyjToScraper extends BaseScraper {
  @override
  String get name => 'Obejrzyj.to';

  final String _baseUrl = 'https://obejrzyj.to';

  Map<String, String> get _headers => {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7',
    'Referer': 'https://obejrzyj.to/',
  };

  @override
  Future<List<SearchResult>> search(String title, MediaType type) async {
    final cleanTitle = title.split(' (').first.split(':').first.trim();
    final searchUrl = '$_baseUrl/search/${Uri.encodeComponent(cleanTitle.toLowerCase())}';
    
    try {
      final response = await http.get(Uri.parse(searchUrl), headers: _headers);
      if (response.statusCode != 200) return [];

      final data = _extractBootstrapData(response.body);
      final results = data?['loaders']?['searchPage']?['results'] as List?;
      if (results == null) return [];

      List<SearchResult> searchResults = [];
      for (var item in results) {
        final id = item['id'];
        final nameStr = item['name'] ?? '';
        final itemType = item['type'];
        final isSeries = item['is_series'] == true || itemType == 'series';
        
        if (type == MediaType.movie && isSeries) continue;
        if (type == MediaType.series && !isSeries) continue;

        if (nameStr.toLowerCase().contains(cleanTitle.toLowerCase()) || 
            cleanTitle.toLowerCase().contains(nameStr.toLowerCase())) {
          
          final slug = nameStr.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-');
          searchResults.add(SearchResult(
            title: nameStr,
            url: '$_baseUrl/titles/$id/$slug',
            sourceName: name,
          ));
        }
      }
      return searchResults;
    } catch (e) {
      print('ObejrzyjTo search error: $e');
    }
    return [];
  }

  @override
  Future<List<VideoSource>> getSources(SearchResult result, {int? season, int? episode}) async {
    String targetUrl = result.url;

    try {
      if (season != null && episode != null) {
        final cleanUrl = result.url.endsWith('/') ? result.url.substring(0, result.url.length - 1) : result.url;
        targetUrl = '$cleanUrl/season/$season/episode/$episode';
      }

      final response = await http.get(Uri.parse(targetUrl), headers: _headers);
      if (response.statusCode != 200) return [];
      
      final data = _extractBootstrapData(response.body);
      String? watchId;
      
      final episodePage = data?['loaders']?['episodePage']?['episode'];
      final titlePage = data?['loaders']?['titlePage']?['title'];
      final mediaData = episodePage ?? titlePage;
      
      if (mediaData != null && mediaData['videos'] != null && (mediaData['videos'] as List).isNotEmpty) {
        watchId = mediaData['videos'][0]['id'].toString();
      }

      if (watchId == null) {
        final htmlMatch = RegExp(r'\/watch\/(\d+)').firstMatch(response.body);
        watchId = htmlMatch?.group(1);
      }

      if (watchId == null) return [];

      final watchRes = await http.get(Uri.parse('$_baseUrl/watch/$watchId'), headers: _headers);
      if (watchRes.statusCode == 200) {
        return _parseWatchPage(watchRes.body);
      }
    } catch (e) {
      print('ObejrzyjTo getSources error: $e');
    }

    return [];
  }

  List<VideoSource> _parseWatchPage(String html) {
    List<VideoSource> sources = [];
    final data = _extractBootstrapData(html);
    final watchData = data?['loaders']?['watchPage'];
    if (watchData == null) return [];

    final mainVideo = watchData['video'];
    if (mainVideo != null) {
      final source = _mapJsonToSource(mainVideo);
      if (!source.title.toLowerCase().contains('ultrastream')) {
        sources.add(source);
      }
    }

    final alternatives = watchData['alternative_videos'] as List?;
    if (alternatives != null) {
      for (var v in alternatives) {
        if (v['id']?.toString() != mainVideo?['id']?.toString()) {
          final source = _mapJsonToSource(v);
          if (!source.title.toLowerCase().contains('ultrastream')) {
            sources.add(source);
          }
        }
      }
    }
    return sources;
  }

  VideoSource _mapJsonToSource(dynamic v) {
    final src = v['src'] ?? '';
    final nameStr = v['name'] ?? 'Obejrzyj.to';
    final quality = v['quality'] ?? 'Auto';
    final langType = v['language_type']?.toString() ?? '';
    
    String label = nameStr;
    if (langType.toLowerCase().contains('lektor')) label += ' (Lektor)';
    else if (langType.toLowerCase().contains('napisy')) label += ' (Napisy)';

    String origin = 'https://obejrzyj.to';
    try {
      if (src.isNotEmpty) {
        final uri = Uri.parse(src);
        origin = '${uri.scheme}://${uri.host}';
      }
    } catch (_) {}

    return VideoSource(
      url: src,
      title: label,
      quality: quality,
      sourceName: name,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': src,
        'Origin': src.startsWith('https://filemoon') ? 'https://filemoon.sx' : origin,
        'Accept': '*/*',
        'X-Requested-With': 'com.google.android.webview',
      },
      isWebView: true,
      automationScript: '''
        (function() {
          let attempts = 0;
          const maxAttempts = 30;
          function run() {
            if (attempts++ > maxAttempts) return;
            
            // Wyciszenie wszystkich video, aby unikn\u0105\u0107 blokady autoplay
            document.querySelectorAll('video').forEach(v => { v.muted = true; v.volume = 0; });

            const selectors = [
              '.vjs-big-play-button', 
              '.play-button', 
              '#play', 
              '#vjs_video_3', 
              '.play_icon', 
              'button[aria-label="Play"]',
              '.jw-display-icon-container',
              '#play-btn'
            ];
            
            let clicked = false;
            selectors.forEach(s => {
              const el = document.querySelector(s);
              if (el && el.offsetParent !== null && !el.dataset.clicked) {
                el.dataset.clicked = "true";
                el.click();
                clicked = true;
              }
            });

            // Jeśli nic nie kliknięto, spróbuj kliknąć w środek
            if (!clicked && attempts % 5 === 0) {
              const center = document.elementFromPoint(window.innerWidth/2, window.innerHeight/2);
              if (center) center.click();
            }

            setTimeout(run, 1500);
          }
          // Blokada otwierania nowych okien (reklam)
          window.open = function() { return { focus: function() {} }; };
          setTimeout(run, 1500);
        })();
      ''',
    );
  }

  Map<String, dynamic>? _extractBootstrapData(String html) {
    try {
      final match = RegExp(r'window\.bootstrapData\s*=\s*(\{.*?\});\s*<\/script>', dotAll: true).firstMatch(html);
      if (match != null) return jsonDecode(match.group(1)!);
      
      final simpleMatch = RegExp(r'window\.bootstrapData\s*=\s*(\{.*?\});', dotAll: true).firstMatch(html);
      if (simpleMatch != null) return jsonDecode(simpleMatch.group(1)!);
    } catch (e) {
      print('Bootstrap extraction error: $e');
    }
    return null;
  }
}