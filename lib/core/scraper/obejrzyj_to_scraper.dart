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
      final source = _mapJsonToSource(mainVideo, 0);
      if (source.url.isNotEmpty && !source.title.toLowerCase().contains('ultrastream')) {
        sources.add(source);
      }
    }

    final alternatives = watchData['alternative_videos'] as List?;
    if (alternatives != null) {
      for (int i = 0; i < alternatives.length; i++) {
        final v = alternatives[i];
        if (v['id']?.toString() != mainVideo?['id']?.toString()) {
          final source = _mapJsonToSource(v, i + 1);
          if (source.url.isNotEmpty && !source.title.toLowerCase().contains('ultrastream')) {
            sources.add(source);
          }
        }
      }
    }
    return sources;
  }

  VideoSource _mapJsonToSource(dynamic v, int index) {
    final src = v['src'] ?? '';
    final quality = v['quality'] ?? 'Auto';
    
    // Zapewnienie unikalności URL dla historii
    final uniqueUrl = src.contains('#') ? src.split('#').first + '#$index' : '$src#$index';

    String hostName = 'Wideo';
    try {
      if (src.isNotEmpty) {
        final uri = Uri.parse(src);
        final parts = uri.host.split('.');
        if (parts.length >= 2) {
          final rawHost = parts[parts.length - 2];
          hostName = rawHost[0].toUpperCase() + rawHost.substring(1);
        }
      }
    } catch (_) {}

    final langLabel = v['language_label']?.toString() ?? '';
    final subLabel = v['subtitle_label']?.toString() ?? '';
    
    List<SubtitleSource>? subtitles;
    final subsJson = v['subtitles'] as List?;
    if (subsJson != null && subsJson.isNotEmpty) {
      subtitles = subsJson.map((s) {
        String subUrl = s['src'] ?? '';
        if (subUrl.startsWith('/')) {
          subUrl = 'https://obejrzyj.to$subUrl';
        }
        return SubtitleSource(
          url: subUrl,
          label: s['label'] ?? (s['language'] ?? 'Napisy'),
          language: s['language'],
        );
      }).where((s) => s.url.isNotEmpty).toList();
    }
    
    String label = hostName;
    List<String> tags = [];
    if (langLabel.isNotEmpty) tags.add(langLabel);
    if (subLabel.isNotEmpty && subLabel != langLabel) tags.add(subLabel);
    
    if (tags.isEmpty) {
      final langType = v['language_type']?.toString().toLowerCase() ?? '';
      if (langType.contains('lektor')) tags.add('Lektor');
      if (langType.contains('napisy')) tags.add('Napisy');
    }

    if (tags.isNotEmpty) {
      label += ' (${tags.join(' & ')})';
    }

    String origin = 'https://obejrzyj.to';
    try {
      if (src.isNotEmpty) {
        final uri = Uri.parse(src);
        origin = '${uri.scheme}://${uri.host}';
      }
    } catch (_) {}

    return VideoSource(
      url: uniqueUrl,
      title: label,
      quality: quality,
      sourceName: name,
      subtitles: subtitles,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
        'Referer': src,
        'Origin': origin,
        'Accept': '*/*',
      },
      isWebView: true,
      automationScript: '''
        (function() {
          let attempts = 0;
          const maxAttempts = 100;
          
          function deepClick(el) {
            if (!el) return;
            ['mousedown', 'mouseup', 'click'].forEach(evt => {
              el.dispatchEvent(new MouseEvent(evt, { bubbles: true, cancelable: true, view: window }));
            });
          }

          function run() {
            if (attempts++ > maxAttempts) return;
            
            // Wycisz wszystko co si\u0119 da
            document.querySelectorAll('video, audio').forEach(v => { 
              v.muted = true; 
              v.volume = 0; 
              if (v.paused) v.play().catch(() => {});
            });

            // Selektory przycisk\u00f3w play
            const selectors = [
              '.vjs-big-play-button', '.play-button', '#play', '.play_icon', 
              'button[aria-label="Play"]', '.jw-display-icon-container', 
              '#play-btn', '.buttonprch', '.warning_ch a'
            ];

            selectors.forEach(s => {
              document.querySelectorAll(s).forEach(el => {
                if (el && el.offsetParent !== null && !el.dataset.zettaClicked) {
                  el.dataset.zettaClicked = "true";
                  deepClick(el);
                }
              });
            });

            // Klikni\u0119cie w \u015brodek ekranu (cz\u0119sto wymagane przez hosty)
            if (attempts % 10 === 0) {
              const center = document.elementFromPoint(window.innerWidth/2, window.innerHeight/2);
              if (center) deepClick(center);
            }
            
            setTimeout(run, 1000);
          }
          
          // Blokuj wyskakuj\u0105ce okna
          window.open = function() { return { focus: function() {} }; };
          
          run();
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
