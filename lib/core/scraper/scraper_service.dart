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

    List<VideoSource> allSources = [];
    
    // Szukamy równolegle we wszystkich scraperach
    final results = await Future.wait(_scrapers.map((scraper) async {
      try {
        final searchResults = await scraper.search(query);
        if (searchResults.isNotEmpty) {
          // Filtrujemy wyniki, aby tytuł się zgadzał (unikanie np. "Pomoc" zamiast "Pomoc domowa")
          final bestMatch = searchResults.firstWhere(
            (r) => r.title.toLowerCase().contains(cleanTitle.toLowerCase()),
            orElse: () => searchResults.first, // fallback do pierwszego jeśli filtr zawiedzie
          );

          if (!bestMatch.title.toLowerCase().contains(cleanTitle.toLowerCase())) {
             return <VideoSource>[];
          }

          return await scraper.getSources(bestMatch);
        }
      } catch (e) {
        // Ignorujemy błędy poszczególnych scraperów w wersji stabilnej
      }
      return <VideoSource>[];
    }));

    for (var sourceList in results) {
      allSources.addAll(sourceList);
    }

    return allSources;
  }
}

final scraperServiceProvider = Provider((ref) => ScraperService());
