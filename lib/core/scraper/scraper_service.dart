import 'dart:async';
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
    String cleanTitle = title.split(':').first.split('-').first.trim();
    final query = cleanTitle;

    List<VideoSource> allSources = [];
    
    final activeScrapers = _scrapers.where((s) {
      final name = s is EkinoScraper ? 'Ekino-TV' : (s is ObejrzyjToScraper ? 'Obejrzyj.to' : '');
      return settingsValue.enabledScrapers[name] ?? false;
    }).toList();

    if (activeScrapers.isEmpty) return [];

    final results = await Future.wait(activeScrapers.map((scraper) async {
      try {
        final searchResults = await scraper.search(query, type);
        if (searchResults.isNotEmpty) {
          final bestMatch = searchResults.firstWhere(
            (r) => r.title.toLowerCase().contains(cleanTitle.toLowerCase()),
            orElse: () => searchResults.first,
          );

          if (!bestMatch.title.toLowerCase().contains(cleanTitle.toLowerCase())) {
             return <VideoSource>[];
          }

          return await scraper.getSources(bestMatch, season: season, episode: episode);
        }
      } catch (e) {}
      return <VideoSource>[];
    }));

    for (var sourceList in results) {
      allSources.addAll(sourceList);
    }

    return allSources;
  }
}

final scraperServiceProvider = Provider((ref) => ScraperService(ref));