import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_scraper.dart';
import 'filman_scraper.dart';
import 'obejrzyj_to_scraper.dart';

class ScraperService {
  final List<BaseScraper> _scrapers = [
    ObejrzyjToScraper(),
    FilmanScraper(),
  ];

  Future<List<VideoSource>> findStream(String title, {int? season, int? episode}) async {
    // Czyścimy tytuł: usuwamy dwukropki, myślniki i bierzemy pierwszy człon przed znakiem ":"
    // Np. "F1: Film" stanie się "F1"
    String cleanTitle = title.split(':').first.split('-').first.trim();
    
    final query = season != null 
        ? '$cleanTitle S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}'
        : cleanTitle;

    print('Searching for clean query: $query');

    for (var scraper in _scrapers) {
      try {
        final results = await scraper.search(query);
        if (results.isNotEmpty) {
          // Na razie bierzemy pierwszy wynik i szukamy w nim źródeł
          final sources = await scraper.getSources(results.first.url);
          if (sources.isNotEmpty) {
            return sources;
          }
        }
      } catch (e) {
        print('Error in scraper ${scraper.name}: $e');
      }
    }

    // Jeśli nic nie znaleźliśmy, zwracamy pusto
    return [];
  }
}

final scraperServiceProvider = Provider((ref) => ScraperService());
