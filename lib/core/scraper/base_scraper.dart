import 'package:flutter/material.dart';
import '../../features/home/domain/media_item.dart';

abstract class BaseScraper {
  String get name;
  Future<List<SearchResult>> search(String title, MediaType type, {BuildContext? context});
  Future<List<VideoSource>> getSources(SearchResult result, {int? season, int? episode, BuildContext? context});
}

class SearchResult {
  final String title;
  final String url;
  final String sourceName;

  SearchResult({required this.title, required this.url, required this.sourceName});
}

class VideoSource {
  final String url;
  final String title;
  final String quality;
  final String sourceName;
  final Map<String, String>? headers;
  final bool isWebView;
  final String? automationScript;
  final List<SubtitleSource>? subtitles;

  VideoSource({
    required this.url,
    required this.title,
    required this.quality,
    required this.sourceName,
    this.headers,
    this.isWebView = false,
    this.automationScript,
    this.subtitles,
  });
}

class SubtitleSource {
  final String url;
  final String label;
  final String? language;

  SubtitleSource({
    required this.url,
    required this.label,
    this.language,
  });
}
