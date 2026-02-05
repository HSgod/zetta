import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/home/domain/media_item.dart';
import 'base_scraper.dart';
import 'ekino_scraper.dart';
import 'obejrzyj_to_scraper.dart';

class ScraperService {
  final List<BaseScraper> _scrapers = [
    EkinoScraper(),
    ObejrzyjToScraper(),
  ];

  Future<bool> isAvailable(String title, MediaType type) async {
    String cleanTitle = title.split(':').first.split('-').first.trim().toLowerCase();
    
    if (_scrapers.isEmpty) return false;

    // Tworzymy listę zadań sprawdzania dla każdego scrapera
    final List<Future<bool>> checks = _scrapers.map((scraper) async {
      try {
        final searchResults = await scraper.search(cleanTitle, type);
        return searchResults.any((r) => r.title.toLowerCase().contains(cleanTitle));
      } catch (e) {
        return false;
      }
    }).toList();

    // Specjalna logika: czekamy na pierwszy, który zwróci TRUE.
    // Jeśli wszystkie zwrócą FALSE, to zwracamy FALSE.
    int finished = 0;
    final completer = Completer<bool>();

    for (var check in checks) {
      check.then((found) {
        if (found && !completer.isCompleted) {
          completer.complete(true);
        }
        finished++;
        if (finished == checks.length && !completer.isCompleted) {
          completer.complete(false);
        }
      });
    }

    return completer.future;
  }

  Future<List<VideoSource>> findStream(String title, MediaType type, {int? season, int? episode}) async {
    String cleanTitle = title.split(':').first.split('-').first.trim();
    
    final query = season != null 
        ? '$cleanTitle S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}'
        : cleanTitle;

    List<VideoSource> allSources = [];
    
    // Szukamy równolegle we wszystkich scraperach
    final results = await Future.wait(_scrapers.map((scraper) async {
      try {
        final searchResults = await scraper.search(query, type);
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
