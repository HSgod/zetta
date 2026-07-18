import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/home/domain/media_item.dart';
import 'base_scraper.dart';
import 'ekino_scraper.dart';
import 'obejrzyj_to_scraper.dart';
import 'zaluknij_scraper.dart';
import 'scraper_settings_provider.dart';

class ScraperService {
  final Ref _ref;
  final List<BaseScraper> _scrapers = [
    EkinoScraper(),
    ObejrzyjToScraper(),
    ZaluknijScraper(),
  ];

  ScraperService(this._ref);

  Future<bool> isAvailable(String title, MediaType type) async {
    String cleanTitle = title.split(':').first.split('-').first.trim().toLowerCase();
    
    if (_scrapers.isEmpty) return false;

    final List<Future<bool>> checks = _scrapers.map((scraper) async {
      try {
        final searchResults = await scraper.search(cleanTitle, type).timeout(const Duration(seconds: 8));
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

  Future<List<VideoSource>> findStream(
    String title, 
    MediaType type, {
    int? season, 
    int? episode,
    void Function(String scraperName, String status)? onProgress,
  }) async {
    final settingsValue = await _ref.read(scraperSettingsProvider.future);
    
    String cleanTitle = title.split(':').first.trim();
    final query = cleanTitle;
    final activeScrapers = _scrapers.where((s) {
      final isEnabled = settingsValue.enabledScrapers[s.name] ?? false;
      return isEnabled;
    }).toList();

    List<VideoSource> allSources = [];

    if (activeScrapers.isEmpty) {
      return [];
    }

    final results = await Future.wait(activeScrapers.map((scraper) async {
      onProgress?.call(scraper.name, 'szukanie');
      try {
        final sources = await (() async {
          final searchResults = await scraper.search(query, type);
          
          if (searchResults.isNotEmpty) {
            String normalize(String text) => text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();
            final normalizedQuery = normalize(query);

            final matches = searchResults.where((r) {
              final normalizedResult = normalize(r.title);
              return normalizedResult == normalizedQuery || 
                     normalizedResult.startsWith('$normalizedQuery ') ||
                     normalizedResult.endsWith(' $normalizedQuery') ||
                     normalizedResult.contains(' $normalizedQuery ');
            }).toList();

            if (matches.isEmpty) {
              return <VideoSource>[];
            }

            matches.sort((a, b) => a.title.length.compareTo(b.title.length));
            final bestMatch = matches.first;

            return await scraper.getSources(bestMatch, season: season, episode: episode);
          }
          return <VideoSource>[];
        })().timeout(const Duration(seconds: 12));
        
        onProgress?.call(scraper.name, sources.isNotEmpty ? 'znaleziono' : 'brak');
        return sources;
      } on TimeoutException catch (_) {
        debugPrint('Zetta Scraper: Timeout (12s) przekroczony w ${scraper.name}');
        onProgress?.call(scraper.name, 'timeout');
      } catch (e) {
        debugPrint('Zetta Scraper: Błąd w ${scraper.name}: $e');
        onProgress?.call(scraper.name, 'błąd');
      }
      return <VideoSource>[];
    }));

    for (var sourceList in results) {
      allSources.addAll(sourceList);
    }

    return allSources;
  }
}

final scraperServiceProvider = Provider((ref) => ScraperService(ref));