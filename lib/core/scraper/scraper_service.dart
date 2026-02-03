import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_scraper.dart';

// Tutaj będziemy rejestrować prawdziwe scrapery
class ScraperService {
  final List<BaseScraper> _scrapers = [
    // Tu dodamy np. FilmanScraper()
    _MockScraper(),
  ];

  Future<List<VideoSource>> findStream(String title, {int? season, int? episode}) async {
    // 1. Szukamy w serwisach
    // Na potrzeby demo, MockScraper od razu zwraca gotowe źródło
    
    final query = season != null 
        ? '$title S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}'
        : title;

    print('Szukam streamu dla: $query');

    // W prawdziwej implementacji:
    // for (var scraper in _scrapers) {
    //   var results = await scraper.search(query);
    //   if (results.isNotEmpty) {
    //      return await scraper.getSources(results.first.url);
    //   }
    // }

    // Mock implementation
    return _scrapers.first.getSources('');
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
    // Zwracamy testowy film (Big Buck Bunny)
    await Future.delayed(const Duration(seconds: 1)); // Symulacja sieci
    return [
      VideoSource(
        url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        quality: 'Auto',
      ),
    ];
  }
}

final scraperServiceProvider = Provider((ref) => ScraperService());
