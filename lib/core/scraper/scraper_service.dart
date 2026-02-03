import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_scraper.dart';
import 'ekino_scraper.dart';
import 'obejrzyj_to_scraper.dart';

class ScraperService {
  final List<BaseScraper> _scrapers = [
    EkinoScraper(),
    ObejrzyjToScraper(),
  ];

  Future<List<VideoSource>> findStream(String title, {int? season, int? episode}) async {
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

final scraperServiceProvider = Provider((ref) => ScraperService());
