import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_scraper.dart';
import 'obejrzyj_to_scraper.dart';

class ScraperService {
  final List<BaseScraper> _scrapers = [
    ObejrzyjToScraper(),
    _MockScraper(), // Fallback
  ];

  Future<List<VideoSource>> findStream(String title, {int? season, int? episode}) async {
    // Czyścimy tytuł
    String cleanTitle = title.split(':').first.split('-').first.trim();
    
    final query = season != null 
        ? '$cleanTitle S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}'
        : cleanTitle;

    print('Searching for clean query: $query');

    for (var scraper in _scrapers) {
      try {
        final results = await scraper.search(query);
        if (results.isNotEmpty) {
          final sources = await scraper.getSources(results.first.url);
          if (sources.isNotEmpty) {
            return sources;
          }
        }
      } catch (e) {
        print('Error in scraper ${scraper.name}: $e');
      }
    }
    return [];
  }
}

class _MockScraper extends BaseScraper {
  @override
  String get name => 'Test Source';

  @override
  Future<List<SearchResult>> search(String title) async {
    return [SearchResult(title: title, url: 'mock_url', sourceName: name)];
  }

  @override
  Future<List<VideoSource>> getSources(String url) async {
    await Future.delayed(const Duration(seconds: 1));
    return [
      VideoSource(
        url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        quality: 'Auto',
      ),
    ];
  }
}

final scraperServiceProvider = Provider((ref) => ScraperService());
