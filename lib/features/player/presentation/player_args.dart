import '../../home/domain/media_item.dart';

class PlayerArgs {
  final MediaItem item;
  final String videoUrl;
  final Map<String, String>? headers;
  final String? automationScript;

  PlayerArgs({
    required this.item, 
    required this.videoUrl, 
    this.headers,
    this.automationScript,
  });
}
