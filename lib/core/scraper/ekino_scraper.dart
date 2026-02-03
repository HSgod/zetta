import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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
    } catch (e) { print('Search error: $e'); }
    return [];
  }

  @override
  Future<List<VideoSource>> getSources(String movieUrl) async {
    print('[$name] Loading movie page: $movieUrl');
    
    Completer<List<VideoSource>> completer = Completer();
    HeadlessInAppWebView? headlessWebView;
    int stage = 0;

    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(movieUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptCanOpenWindowsAutomatically: false,
        javaScriptEnabled: true,
        useShouldInterceptRequest: true,
      ),
      onReceivedServerTrustAuthRequest: (controller, challenge) async {
        return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
      },
      shouldInterceptRequest: (controller, request) async {
        if (stage == 2) {
          String url = request.url.toString();
          if (url.contains('.m3u8') || url.contains('.mp4')) {
             print('[$name] 🎯 SNIFFED VIDEO URL: $url');
             if (!completer.isCompleted) {
               completer.complete([
                 VideoSource(
                   url: url,
                   quality: 'Auto',
                   headers: {
                     'Referer': 'https://ekino-tv.pl/',
                     'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                   }
                 )
               ]);
               Future.delayed(Duration.zero, () => headlessWebView?.dispose());
             }
          }
        }
        return null;
      },
      onConsoleMessage: (controller, message) async {
        if (message.message.startsWith('FOUND_LINK:')) {
          final nextUrl = message.message.substring(11);
          print('[$name] 🟡 Level 1 Complete. Moving to: $nextUrl');
          stage = 2;
          controller.loadUrl(urlRequest: URLRequest(url: WebUri(nextUrl)));
        }
      },
      onLoadStop: (controller, currentUrl) async {
        print('[$name] Page loaded. Stage: $stage');
        
        if (stage == 0) {
          await controller.evaluateJavascript(source: """
            (async function() {
              var players = document.querySelectorAll('.players li a');
              if (players.length > 0) players[0].click();
              await new Promise(r => setTimeout(r, 1000));
              var startImg = document.querySelector('img[src*="kliknij_aby_obejrzec"]');
              if (startImg) { startImg.click(); if (startImg.parentElement) startImg.parentElement.click(); }
              for (var i = 0; i < 20; i++) {
                await new Promise(r => setTimeout(r, 500));
                var btn = document.querySelector('.buttonprch');
                if (!btn && document.getElementById('iframes')) {
                   try { btn = document.getElementById('iframes').contentDocument.querySelector('.buttonprch'); } catch(e){}
                }
                if (btn && btn.href && btn.href.includes('http')) {
                  console.log('FOUND_LINK:' + btn.href);
                  return;
                }
              }
            })();
          """);
        } else if (stage == 2) {
          // Dłuższy skrypt dla playera - klika co sekundę przez 5 sekund
          await controller.evaluateJavascript(source: """
             (async function() {
                for(var i=0; i<5; i++) {
                   var playBtn = document.querySelector('.play-button, .video-js, button[title="Play"]');
                   if (playBtn) playBtn.click();
                   await new Promise(r => setTimeout(r, 1000));
                }
             })();
          """);
        }
      },
    );

    try {
      await headlessWebView.run();
    } catch (e) {
      if (!completer.isCompleted) completer.complete([]);
    }

    return completer.future.timeout(const Duration(seconds: 40), onTimeout: () => []);
  }
}