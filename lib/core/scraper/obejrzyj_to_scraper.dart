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
    print('[$name] Searching: $searchUrl');
    
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
    } catch(e) { print(e); }
    return [];
  }

  @override
  Future<List<VideoSource>> getSources(String url) async {
    print('[$name] Getting sources via WebView: $url');
    Completer<List<VideoSource>> completer = Completer();
    List<VideoSource> sources = [];

    HeadlessInAppWebView? headlessWebView;
    
    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      onLoadStop: (controller, currentUrl) async {
        print('[$name] Page loaded. Extracting players via JS...');
        
        await Future.delayed(const Duration(seconds: 2));
        
        // JS extraction strategy
        final result = await controller.evaluateJavascript(source: """
          (function() {
            var links = [];
            var iframes = document.getElementsByTagName('iframe');
            for (var i = 0; i < iframes.length; i++) {
              links.push(iframes[i].src || iframes[i].getAttribute('data-src'));
            }
            return links;
          })();
        """);

        if (result != null && result is List) {
          for (var link in result) {
            if (link != null && link is String) {
              _addSource(sources, link);
            }
          }
        }
        
        // HTML Regex strategy fallback
        if (sources.isEmpty) {
          var html = await controller.getHtml();
          if (html != null) {
            final playerRegex = RegExp(r'(https?:\/\/(?:www\.)?(?:vider\.info|streamtape\.com|vidoza\.net|upstream\.to|mixdrop\.co|uqload\.to)\/[^"\s\x27\<\>]+)');
            var matches = playerRegex.allMatches(html);
            for (var match in matches) {
              _addSource(sources, match.group(1)!.replaceAll(r'\/', '/'));
            }
          }
        }

        print('[$name] Final sources found: ${sources.length}');
        if (!completer.isCompleted) completer.complete(sources);
        
        Future.delayed(const Duration(milliseconds: 500), () {
          headlessWebView?.dispose();
        });
      },
    );

    try {
      await headlessWebView.run();
    } catch (e) {
      print('[$name] WebView Error: $e');
      if (!completer.isCompleted) completer.complete([]);
    }

    return completer.future.timeout(const Duration(seconds: 15), onTimeout: () => []);
  }

  void _addSource(List<VideoSource> sources, String url) {
    if (url.isEmpty) return;
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
