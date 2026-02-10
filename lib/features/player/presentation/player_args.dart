import '../../home/domain/media_item.dart';
import '../../../core/scraper/base_scraper.dart';

class PlayerArgs {
  final MediaItem item;
  final String? initialUrl;
  final String? videoUrl;
  final String? sourceName;
  final String? title;
  final int? season;
  final int? episode;
  final Map<String, String>? headers;
  final String? automationScript;
  final List<SubtitleSource>? subtitles;

  PlayerArgs({
    required this.item, 
    this.initialUrl,
    this.videoUrl, 
    this.sourceName,
    this.title,
    this.season,
    this.episode,
    this.headers,
    this.automationScript,
    this.subtitles,
  });
}