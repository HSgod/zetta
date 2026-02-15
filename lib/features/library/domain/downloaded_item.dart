import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../home/domain/media_item.dart';

class DownloadedItem {
  final MediaItem mediaItem;
  final String filePath;
  final String? taskId;
  final int progress;
  final int status; // 0: pending, 1: running, 2: completed, 3: failed, 4: canceled
  final int? season;
  final int? episode;

  DownloadedItem({
    required this.mediaItem,
    required this.filePath,
    this.taskId,
    this.progress = 0,
    this.status = 0,
    this.season,
    this.episode,
  });

  Map<String, dynamic> toJson() => {
    'mediaItem': mediaItem.toJson(),
    'filePath': filePath,
    'taskId': taskId,
    'progress': progress,
    'status': status,
    'season': season,
    'episode': episode,
  };

  factory DownloadedItem.fromJson(Map<String, dynamic> json) => DownloadedItem(
    mediaItem: MediaItem.fromJson(json['mediaItem']),
    filePath: json['filePath'],
    taskId: json['taskId'],
    progress: json['progress'] ?? 0,
    status: json['status'] ?? 0,
    season: json['season'],
    episode: json['episode'],
  );
}
