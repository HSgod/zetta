import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/home/domain/media_item.dart';
import 'base_scraper.dart';
import 'ekino_scraper.dart';
import 'obejrzyj_to_scraper.dart';
import 'scraper_settings_provider.dart';

class ScraperService {
  final Ref _ref;
  final List<BaseScraper> _scrapers = [
    EkinoScraper(),
    ObejrzyjToScraper(),
  ];

  ScraperService(this._ref);

  Future<bool> isAvailable(String title, MediaType type) async {
    String cleanTitle = title.split(':').first.split('-').first.trim().toLowerCase();
    
    if (_scrapers.isEmpty) return false;

    final List<Future<bool>> checks = _scrapers.map((scraper) async {
      try {
        final searchResults = await scraper.search(cleanTitle, type);
        return searchResults.any((r) => r.title.toLowerCase().contains(cleanTitle));
      } catch (e) {
        return false;
      }
    }).toList();

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
    final settingsValue = await _ref.read(scraperSettingsProvider.future);
    
    String cleanTitle = title.split(':').first.trim();
    final query = cleanTitle;

    debugPrint('Zetta Scraper: Szukam "$query" (typ: $type)');

    List<VideoSource> allSources = [];
    
    final activeScrapers = _scrapers.where((s) {
      // Bardziej elastyczne dopasowanie nazwy z ustawień
      final isEnabled = settingsValue.enabledScrapers.entries.any(
        (e) => e.key.toLowerCase().contains(s.name.toLowerCase()) && e.value == true
      );
      return isEnabled;
    }).toList();

    debugPrint('Zetta Scraper: Aktywne scrapery: ${activeScrapers.map((s) => s.name).join(', ')}');

    if (activeScrapers.isEmpty) {
      debugPrint('Zetta Scraper: Brak aktywnych scraper\u00f3w w ustawieniach!');
      return [];
    }

    final results = await Future.wait(activeScrapers.map((scraper) async {
      try {
        final searchResults = await scraper.search(query, type);
        debugPrint('Zetta Scraper: ${scraper.name} znalaz\u0142 ${searchResults.length} wynik\u00f3w wyszukiwania');
        
        if (searchResults.isNotEmpty) {
          // Szukamy najlepszego dopasowania
          final bestMatch = searchResults.firstWhere(
            (r) => r.title.toLowerCase().contains(query.toLowerCase()) || query.toLowerCase().contains(r.title.toLowerCase()),
            orElse: () => searchResults.first,
          );

          debugPrint('Zetta Scraper: ${scraper.name} wybiera wynik: ${bestMatch.title}');
          return await scraper.getSources(bestMatch, season: season, episode: episode);
        }
      } catch (e) {
        debugPrint('Zetta Scraper: B\u0142\u0105d w ${scraper.name}: $e');
      }
      return <VideoSource>[];
    }));

    for (var sourceList in results) {
      allSources.addAll(sourceList);
    }

    debugPrint('Zetta Scraper: Razem znaleziono ${allSources.length} źr\u00f3de\u0142');
    return allSources;
  }
}

final scraperServiceProvider = Provider((ref) => ScraperService(ref));