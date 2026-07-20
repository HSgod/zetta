import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;
import '../../features/home/domain/media_item.dart';
import 'base_scraper.dart';
import 'cloudflare_bypass.dart';

class ZaluknijScraper extends BaseScraper {
  @override
  String get name => 'Zaluknij.cc';

  final String _baseUrl = 'https://zaluknij.cc';

  @override
  Future<List<SearchResult>> search(String title, MediaType type, {BuildContext? context}) async {
    final searchUrl = '$_baseUrl/wyszukiwarka?phrase=${Uri.encodeComponent(title)}';
    debugPrint('Zaluknij: Wyszukiwanie "$title" -> $searchUrl');

    try {
      String? html;
      if (context != null && context.mounted) {
        html = await CloudflareBypassDialog.fetch(context, searchUrl);
      } else {
        debugPrint('Zaluknij: brak kontekstu – pomijam');
        return [];
      }

      if (html == null || html.isEmpty) {
        debugPrint('Zaluknij: Brak HTML po CF bypass');
        return [];
      }

      final document = parse(html);
      final results = <SearchResult>[];
      final movieElements = document.querySelectorAll('#advanced-search a.item');

      if (movieElements.isEmpty) {
        final fallbackElements = document.querySelectorAll('.col-sm-4 a, .col-sm-2 a');
        for (var el in fallbackElements) {
          if (el.attributes['href']?.contains('/film/') == true ||
              el.attributes['href']?.contains('/serial-online/') == true) {
            movieElements.add(el);
          }
        }
      }

      for (var element in movieElements) {
        var url = element.attributes['href'];
        final displayTitle =
            element.querySelector('.title')?.text.trim() ??
            element.attributes['title']?.trim();

        if (displayTitle != null && url != null) {
          if (!url.startsWith('http')) url = '$_baseUrl$url';

          bool isSeries = url.contains('/serial-online/');

          if (type == MediaType.movie && isSeries) continue;
          if (type == MediaType.series && !isSeries) continue;

          results.add(SearchResult(
            title: displayTitle,
            url: url,
            sourceName: name,
          ));
        }
      }

      debugPrint('Zaluknij search: znaleziono ${results.length} wyników');
      return results;
    } catch (e) {
      debugPrint('Zaluknij search error: $e');
      return [];
    }
  }

  @override
  Future<List<VideoSource>> getSources(
    SearchResult result, {
    int? season,
    int? episode,
    BuildContext? context,
  }) async {
    if (context == null || !context.mounted) {
      debugPrint('Zaluknij getSources: brak kontekstu');
      return [];
    }

    String fetchUrl = result.url;

    if (season != null && episode != null) {
      try {
        final seriesHtml = await CloudflareBypassDialog.fetch(context, result.url);
        if (seriesHtml != null) {
          final doc = parse(seriesHtml);
          final episodeTag =
              '[s${season.toString().padLeft(2, '0')}e${episode.toString().padLeft(2, '0')}]';

          final episodeLinks = doc.querySelectorAll('#episode-list a');
          for (var link in episodeLinks) {
            if (link.text.contains(episodeTag)) {
              var epUrl = link.attributes['href'];
              if (epUrl != null) {
                if (!epUrl.startsWith('http')) epUrl = '$_baseUrl$epUrl';
                fetchUrl = epUrl;
                break;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Zaluknij episode find error: $e');
      }
    }

    if (!context.mounted) return [];

    try {
      final html = await CloudflareBypassDialog.fetch(context, fetchUrl);
      if (html == null || html.isEmpty) {
        debugPrint('Zaluknij: Brak HTML dla getSources');
        return [];
      }

      final document = parse(html);
      final sources = <VideoSource>[];
      final rows = document.querySelectorAll('table.table-bordered tbody tr');

      for (var row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.length < 3) continue;

        final linkElement = cells[1].querySelector('a');
        if (linkElement == null) continue;

        final iframeData = linkElement.attributes['data-iframe'];
        final version = cells[2].text.trim();
        final quality = cells.length > 3 ? cells[3].text.trim() : 'Auto';
        final hostName = linkElement.text.trim().toLowerCase();

        if (hostName.contains('voe') ||
            hostName.contains('savefiles') ||
            hostName.contains('ups2up') ||
            hostName.contains('veev') ||
            hostName.contains('lulu') ||
            hostName.contains('vdo') ||
            hostName.contains('dood')) continue;

        String? videoUrl;
        if (iframeData != null) {
          try {
            final decoded = utf8.decode(base64.decode(iframeData));
            final json = jsonDecode(decoded);
            videoUrl = json['src'];
          } catch (e) {
            debugPrint('Zaluknij base64 decode error: $e');
          }
        }

        videoUrl ??= linkElement.attributes['href'];

        if (videoUrl != null && videoUrl.isNotEmpty) {
          if (videoUrl.startsWith('//')) videoUrl = 'https:$videoUrl';

          final lowerUrl = videoUrl.toLowerCase();
          if (lowerUrl.contains('voe.sx') ||
              lowerUrl.contains('savefiles') ||
              lowerUrl.contains('ups2up') ||
              lowerUrl.contains('lulu') ||
              lowerUrl.contains('vdo') ||
              lowerUrl.contains('dood')) continue;

          sources.add(VideoSource(
            url: videoUrl,
            title: '${linkElement.text.trim()} ($version)',
            quality: quality,
            sourceName: name,
            isWebView: true,
            headers: {
              'Referer': fetchUrl,
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
            },
            automationScript: '''
              (function() {
                let attempts = 0;
                const maxAttempts = 100;
                
                function deepClick(el) {
                  if (!el) return;
                  ['mousedown', 'mouseup', 'click', 'touchstart', 'touchend'].forEach(evt => {
                    el.dispatchEvent(new MouseEvent(evt, { bubbles: true, cancelable: true, view: window }));
                  });
                }

                function run() {
                  if (attempts++ > maxAttempts) return;
                  
                  const vplayer = document.getElementById('vplayer');
                  if (vplayer && !vplayer.dataset.zettaClicked) {
                    vplayer.dataset.zettaClicked = "true";
                    deepClick(vplayer);
                    const videos = vplayer.querySelectorAll('video');
                    videos.forEach(v => { if (v.paused) v.play().catch(e => {}); });
                  }

                  const playSelectors = ['.vjs-big-play-button', '.play-button', '.play_icon', '.play-icon', '.overlay'];
                  playSelectors.forEach(s => {
                    document.querySelectorAll(s).forEach(el => {
                      if (el.offsetWidth > 0 && !el.dataset.zettaClicked) {
                        el.dataset.zettaClicked = "true";
                        deepClick(el);
                      }
                    });
                  });

                  setTimeout(run, 2000);
                }
                
                window.open = function() { return { focus: function() {} }; };
                setTimeout(run, 1500);
              })();
            ''',
          ));
        }
      }

      debugPrint('Zaluknij Scraper: Znaleziono ${sources.length} źródeł');
      return sources;
    } catch (e) {
      debugPrint('Zaluknij getSources error: $e');
      return [];
    }
  }
}
