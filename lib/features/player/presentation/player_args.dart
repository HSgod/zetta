import '../../home/domain/media_item.dart';

class PlayerArgs {
  final MediaItem item;
  final String videoUrl;

  PlayerArgs({required this.item, required this.videoUrl});
}
