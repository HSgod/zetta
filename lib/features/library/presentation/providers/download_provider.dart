import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../home/domain/media_item.dart';
import '../../domain/downloaded_item.dart';
import '../../presentation/providers/library_provider.dart';
import '../../../../core/theme/theme_provider.dart';

class DownloadNotifier extends Notifier<List<DownloadedItem>> {
  final ReceivePort _port = ReceivePort();

  @override
  List<DownloadedItem> build() {
    _bindBackgroundIsolate();
    
    final prefs = ref.watch(sharedPreferencesProvider);
    final data = prefs.getStringList('downloads') ?? [];
    return data.map((e) => DownloadedItem.fromJson(jsonDecode(e))).toList();
  }

  void _bindBackgroundIsolate() {
    final isSuccess = IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'downloader_send_port',
    );
    if (!isSuccess) {
      IsolateNameServer.removePortNameMapping('downloader_send_port');
      IsolateNameServer.registerPortWithName(
        _port.sendPort,
        'downloader_send_port',
      );
    }
    _port.listen((dynamic data) {
      final taskId = data[0] as String;
      final status = data[1] as int;
      final progress = data[2] as int;
      updateStatus(taskId, status, progress);
    });
  }

  // Notifier doesn't have a dispose method like StateNotifier, 
  // but we can use ref.onDispose in build if needed.
  // However, since this is a global provider, we might just leave it.

  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);
  }

  Future<void> _saveToPrefs() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final data = state.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('downloads', data);
  }

  Future<void> startDownload({
    required MediaItem item,
    required String url,
    int? season,
    int? episode,
    Map<String, String>? headers,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${dir.path}/downloads');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    // Wygeneruj unikalną nazwę pliku
    String fileName = "${item.id}";
    if (season != null && episode != null) {
      fileName += "_s${season}e$episode";
    }
    fileName += ".mp4";

    final taskId = await FlutterDownloader.enqueue(
      url: url,
      savedDir: downloadsDir.path,
      fileName: fileName,
      showNotification: true,
      openFileFromNotification: false,
      headers: headers ?? {},
    );

    if (taskId != null) {
      final newItem = DownloadedItem(
        mediaItem: item,
        filePath: '${downloadsDir.path}/$fileName',
        taskId: taskId,
        status: 1, // running
        season: season,
        episode: episode,
      );
      state = [...state, newItem];
      await _saveToPrefs();
    }
  }

  void updateStatus(String taskId, int status, int progress) {
    state = [
      for (final item in state)
        if (item.taskId == taskId)
          DownloadedItem(
            mediaItem: item.mediaItem,
            filePath: item.filePath,
            taskId: item.taskId,
            status: status,
            progress: progress,
            season: item.season,
            episode: item.episode,
          )
        else
          item
    ];
    _saveToPrefs();
  }

  Future<void> removeDownload(String taskId) async {
    await FlutterDownloader.remove(taskId: taskId, shouldDeleteContent: true);
    state = state.where((e) => e.taskId != taskId).toList();
    await _saveToPrefs();
  }
}

final downloadProvider = NotifierProvider<DownloadNotifier, List<DownloadedItem>>(DownloadNotifier.new);

