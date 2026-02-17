import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
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
    final items = data.map((e) => DownloadedItem.fromJson(jsonDecode(e))).toList();
    
    // Automatyczne wznawianie po kr\u00f3tkiej chwili od startu
    Future.microtask(() => _resumeInterruptedDownloads(items));
    
    return items;
  }

  void _resumeInterruptedDownloads(List<DownloadedItem> items) async {
    for (final item in items) {
      // Status 1 oznacza "running". Jeśli apka startuje, a status to 1, znaczy że pobieranie przerwano.
      if (item.status == 1) {
        if (item.taskId?.startsWith('hls_') ?? false) {
          debugPrint("DownloadNotifier: Wznawianie HLS: ${item.mediaItem.title}");
          _startHlsDownload(item.mediaItem, item.url!, item.filePath, item.season, item.episode, null, resumeFrom: item.lastSegment);
        } else if (item.taskId != null) {
          debugPrint("DownloadNotifier: Wznawianie MP4: ${item.mediaItem.title}");
          await FlutterDownloader.resume(taskId: item.taskId!);
        }
      }
    }
  }

  void _bindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');

    _port.listen((dynamic data) {
      final taskId = data[0] as String;
      final status = data[1] as int;
      final progress = data[2] as int;
      updateStatus(taskId, status, progress);
    });
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
    if (!await downloadsDir.exists()) await downloadsDir.create(recursive: true);

    String fileName = "${item.id}${season != null ? '_s${season}e$episode' : ''}.mp4";
    final filePath = '${downloadsDir.path}/$fileName';

    bool isHls = url.contains('.m3u8') || (url.contains('/hls/') && !url.contains('.mp4'));

    if (isHls) {
      _startHlsDownload(item, url, filePath, season, episode, headers);
    } else {
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
          filePath: filePath,
          taskId: taskId,
          status: 1,
          season: season,
          episode: episode,
          url: url,
        );
        state = [...state, newItem];
        await _saveToPrefs();
      }
    }
  }

  Future<void> _startHlsDownload(
    MediaItem item, 
    String url, 
    String filePath, 
    int? season, 
    int? episode,
    Map<String, String>? headers,
    {int resumeFrom = 0}
  ) async {
    final taskId = resumeFrom > 0 
        ? state.firstWhere((e) => e.filePath == filePath).taskId!
        : "hls_${DateTime.now().millisecondsSinceEpoch}";
    
    if (resumeFrom == 0) {
      final newItem = DownloadedItem(
        mediaItem: item,
        filePath: filePath,
        taskId: taskId,
        status: 1,
        season: season,
        episode: episode,
        url: url,
        lastSegment: 0,
      );
      state = [...state, newItem];
      await _saveToPrefs();
    }

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode != 200) throw Exception("Kod błędu: ${response.statusCode}");

      final body = response.body;
      if (!body.contains('#EXTM3U')) {
        final fileRes = await http.get(Uri.parse(url), headers: headers);
        if (fileRes.statusCode == 200) {
          await File(filePath).writeAsBytes(fileRes.bodyBytes);
          updateStatus(taskId, 3, 100);
          return;
        }
      }

      final lines = body.split('\n');
      final segmentUrls = <String>[];
      final baseUrl = url.substring(0, url.lastIndexOf('/') + 1);

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        segmentUrls.add(line.startsWith('http') ? line : baseUrl + line);
      }

      final outputFile = File(filePath);
      // Jeśli wznowienie - dopisujemy, jeśli nowe - czyścimy
      final sink = outputFile.openWrite(mode: resumeFrom > 0 ? FileMode.append : FileMode.write);

      int downloaded = resumeFrom;
      // Przeskakujemy już pobrane segmenty
      final remainingSegments = segmentUrls.skip(resumeFrom);

      for (var segUrl in remainingSegments) {
        if (!state.any((e) => e.taskId == taskId)) {
          await sink.close();
          return;
        }

        try {
          final segRes = await http.get(Uri.parse(segUrl), headers: headers).timeout(const Duration(seconds: 30));
          if (segRes.statusCode == 200) {
            sink.add(segRes.bodyBytes);
            downloaded++;
            
            if (downloaded % 5 == 0 || downloaded == segmentUrls.length) {
              int progress = ((downloaded / segmentUrls.length) * 100).toInt();
              _updateHlsProgress(taskId, progress, downloaded);
            }
          }
        } catch (e) {
          debugPrint("HLS: Błąd segmentu: $e");
        }
      }

      await sink.flush();
      await sink.close();
      updateStatus(taskId, 3, 100);

    } catch (e) {
      updateStatus(taskId, 4, 0);
    }
  }

  void _updateHlsProgress(String taskId, int progress, int lastSegment) {
    state = [
      for (final item in state)
        if (item.taskId == taskId)
          DownloadedItem(
            mediaItem: item.mediaItem,
            filePath: item.filePath,
            taskId: item.taskId,
            status: 1,
            progress: progress,
            season: item.season,
            episode: item.episode,
            url: item.url,
            lastSegment: lastSegment,
          )
        else
          item
    ];
    _saveToPrefs();
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
            url: item.url,
            lastSegment: item.lastSegment,
          )
        else
          item
    ];
    _saveToPrefs();
  }

  Future<void> removeDownload(String taskId) async {
    if (!taskId.startsWith("hls_")) {
      await FlutterDownloader.remove(taskId: taskId, shouldDeleteContent: true);
    }
    
    final index = state.indexWhere((e) => e.taskId == taskId);
    if (index != -1) {
      final item = state[index];
      state = state.where((e) => e.taskId != taskId).toList();
      await _saveToPrefs();
      final file = File(item.filePath);
      if (await file.exists()) await file.delete();
    }
  }
}

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
  send?.send([id, status, progress]);
}

final downloadProvider = NotifierProvider<DownloadNotifier, List<DownloadedItem>>(DownloadNotifier.new);
