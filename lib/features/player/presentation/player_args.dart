import '../../home/domain/media_item.dart';

class PlayerArgs {
  final MediaItem item;
  final String? initialUrl;
  final String? videoUrl;
  final Map<String, String>? headers;
  final String? automationScript;

  PlayerArgs({
    required this.item, 
    this.initialUrl,
    this.videoUrl, 
    this.headers,
    this.automationScript,
  });
}
