import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../home/domain/media_item.dart';

class VideoPlayerScreen extends StatefulWidget {
  final MediaItem item;

  const VideoPlayerScreen({super.key, required this.item});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player player;
  late final VideoController controller;

  @override
  void initState() {
    super.initState();
    
    // Inicjalizacja playera
    player = Player();
    controller = VideoController(player);

    // Na razie użyjemy testowego wideo (Big Buck Bunny), bo nie mamy jeszcze scrapera
    player.open(Media('https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4'));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.item.title),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Video(
          controller: controller,
          controls: MaterialVideoControls, // Używamy domyślnych kontrolek Material
        ),
      ),
    );
  }
}
