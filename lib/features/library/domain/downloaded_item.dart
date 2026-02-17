import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../home/domain/media_item.dart';

class DownloadedItem {
  final MediaItem mediaItem;
  final String filePath;
  final String? taskId;
  final int progress;
  final int status; // 1: running, 3: completed, 4: failed, 5: paused
  final int? season;
  final int? episode;
  final String? url; // Przechowujemy URL do wznowienia
  final int lastSegment; // Dla HLS

  DownloadedItem({
    required this.mediaItem,
    required this.filePath,
    this.taskId,
    this.progress = 0,
    this.status = 0,
    this.season,
    this.episode,
    this.url,
    this.lastSegment = 0,
  });

  Map<String, dynamic> toJson() => {
    'mediaItem': mediaItem.toJson(),
    'filePath': filePath,
    'taskId': taskId,
    'progress': progress,
    'status': status,
    'season': season,
    'episode': episode,
    'url': url,
    'lastSegment': lastSegment,
  };

  factory DownloadedItem.fromJson(Map<String, dynamic> json) => DownloadedItem(
    mediaItem: MediaItem.fromJson(json['mediaItem']),
    filePath: json['filePath'],
    taskId: json['taskId'],
    progress: json['progress'] ?? 0,
    status: json['status'] ?? 0,
    season: json['season'],
    episode: json['episode'],
    url: json['url'],
    lastSegment: json['lastSegment'] ?? 0,
  );
}
