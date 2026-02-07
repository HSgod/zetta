import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'base_scraper.dart';

import '../../features/home/domain/media_item.dart';

class EkinoScraper extends BaseScraper {
  @override
  String get name => 'Ekino-TV';

  final String _baseUrl = 'https://ekino-tv.pl';

  Map<String, String> get _headers => {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7',
    'Referer': 'https://ekino-tv.pl/',
  };

  @override
  Future<List<SearchResult>> search(String title, MediaType type) async {
    final searchUrl = '$_baseUrl/search/qf/?q=${Uri.encodeComponent(title)}';
    try {
      final response = await http.get(Uri.parse(searchUrl), headers: _headers);
      if (response.statusCode == 200) {
        var document = parse(response.body);
        var items = document.querySelectorAll('.movies-list-item, .movie-item, .item-list');
        List<SearchResult> results = [];
        for (var element in items) {
          var link = element.querySelector('a');
          var titleElement = element.querySelector('.title, h2, .name, .movie-title');
          var href = link?.attributes['href'];
          if (href != null) {
            // Filtrowanie po typie
            final isMovieLink = href.contains('/movie/') || href.contains('/film/');
            final isSerieLink = href.contains('/serie/') || href.contains('/tv-show/');
            
            if (type == MediaType.movie && !isMovieLink && isSerieLink) continue;
            if (type == MediaType.series && !isSerieLink && isMovieLink) continue;

            if (!href.startsWith('http')) href = '$_baseUrl$href';
            results.add(SearchResult(
              title: titleElement?.text.trim() ?? 'Film Ekino',
              url: href,
              sourceName: name,
            ));
          }
        }
        if (results.isEmpty && document.body?.text.contains('Brak wyników') == false) {
          var allLinks = document.querySelectorAll('a[href*="/movie/show/"], a[href*="/serie/show/"]');
          for (var link in allLinks) {
            var href = link.attributes['href']!;
            if (!href.startsWith('http')) href = '$_baseUrl$href';
            var title = link.text.trim();
            if (title.length > 2) {
              results.add(SearchResult(
                title: title,
                url: href,
                sourceName: name,
              ));
            }
          }
        }
        return results;
      }
    } catch (e) { /* error */ }
    return [];
  }

  @override
  Future<List<VideoSource>> getSources(SearchResult result, {int? season, int? episode}) async {
    String targetUrl = result.url;

    try {
      if (season != null && episode != null && result.url.contains('/serie/show/')) {
        final slug = result.url.split('/show/').last.replaceAll('/', '');
        targetUrl = '$_baseUrl/serie/watch/$slug+season[$season]+episode[$episode]+';
      }

      final response = await http.get(Uri.parse(targetUrl), headers: _headers);
      if (response.statusCode == 200) {
        var document = parse(response.body);
        List<VideoSource> sources = [];

        var playerButtons = document.querySelectorAll('.players li, .player-list li, .player-item');
        
        if (playerButtons.isNotEmpty) {
          for (int i = 0; i < playerButtons.length; i++) {
            final btn = playerButtons[i];
            final nameText = btn.text.trim();
            if (nameText.isEmpty || nameText.toLowerCase().contains('bez limitów')) continue;

            final serverId = nameText.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
            final uniqueUrl = targetUrl.contains('#') 
                ? targetUrl.split('#').first + '#$serverId-$i' 
                : '$targetUrl#$serverId-$i';

            sources.add(VideoSource(
              url: uniqueUrl,
              title: nameText,
              quality: 'Auto',
              sourceName: name,
              isWebView: true,
              headers: {
                ..._headers,
                'Referer': 'https://ekino-tv.pl/',
              },
              automationScript: '''
                (function() {
                  var attempts = 0;
                  var maxAttempts = 100;
                  
                  function triggerClick(el) {
                    if (!el) return;
                    console.log('Ekino Automation: Clicking', el);
                    el.dataset.autoClicked = "true";
                    const events = ['mousedown', 'mouseup', 'click'];
                    events.forEach(evt => {
                      el.dispatchEvent(new MouseEvent(evt, {bubbles: true, cancelable: true, view: window}));
                    });
                    if (el.click) el.click();
                  }

                  function run() {
                    var currentUrl = window.location.href;
                    
                    if (currentUrl.includes('/player/') || currentUrl.includes('vshare.io') || currentUrl.includes('upstream')) {
                      console.log('Final player reached, stopping automation.');
                      return;
                    }

                    if (attempts++ > maxAttempts) return;
                    
                    document.querySelectorAll('div').forEach(el => {
                      if (parseInt(window.getComputedStyle(el).zIndex) > 100) {
                        el.remove();
                      }
                    });

                    if (currentUrl.includes('/movie/show/') || currentUrl.includes('/serie/show/') || currentUrl.includes('/serie/watch/')) {
                      var buttons = document.querySelectorAll('.players li, .player-list li');
                      if (buttons.length > $i) {
                        var link = buttons[$i].querySelector('a') || buttons[$i];
                        if (!link.dataset.autoClicked) {
                          console.log('Step 1: Selecting server');
                          triggerClick(link);
                          return;
                        }
                      }
                    }

                    var tabLink = document.querySelector('.tabpanel a, .tab-pane.active a, .warning_ch a');
                    if (tabLink && tabLink.offsetWidth > 0 && !tabLink.dataset.autoClicked) {
                      console.log('Step 2: Clicking watch link');
                      triggerClick(tabLink);
                      return;
                    }

                    var prchBtn = document.querySelector('.buttonprch, a.buttonprch');
                    if (prchBtn && prchBtn.offsetWidth > 0 && !prchBtn.dataset.autoClicked) {
                      console.log('Step 3: Clicking buttonprch');
                      var targetHref = prchBtn.href;
                      triggerClick(prchBtn);
                      
                      if (targetHref && targetHref !== '#' && !targetHref.startsWith('javascript')) {
                        setTimeout(function() {
                          if (window.location.href === currentUrl) {
                            console.log('Forcing navigation to:', targetHref);
                            window.location.href = targetHref;
                          }
                        }, 1000);
                      }
                      return;
                    }

                    setTimeout(run, 1500);
                  }
                  
                  window.open = function() { return null; };
                  setTimeout(run, 2000);
                })();
              ''',
            ));
          }
        }

        if (sources.isEmpty) {
          bool hasPlayer = document.querySelector('.players') != null || 
                           document.querySelector('img[src*="kliknij_aby_obejrzec"]') != null ||
                           document.querySelector('.buttonprch') != null ||
                           document.querySelector('.warning_ch') != null;

          if (hasPlayer) {
            sources.add(VideoSource(
              url: '$targetUrl#default',
              title: 'Domyślny Player',
              quality: 'Auto',
              sourceName: name,
              isWebView: true,
              headers: _headers,
            ));
          }
        }

        return sources;
      }
    } catch (e) {
      print('Ekino getSources error: $e');
    }
    return [];
  }
}