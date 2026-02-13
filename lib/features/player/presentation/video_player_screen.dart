import 'dart:async';
import 'dart:collection';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../home/domain/media_item.dart';
import '../../../core/theme/theme_provider.dart';
import '../../library/presentation/providers/library_provider.dart';
import 'player_args.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final PlayerArgs args;

  const VideoPlayerScreen({super.key, required this.args});

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late final Player player;
  late final VideoController controller;
  
  bool _isLoading = true;
  bool _hasError = false;
  bool _showControls = true;
  bool _showWebViewDebug = false; // Powrót do false
  bool _isExiting = false;
  Timer? _hideControlsTimer;
  Timer? _progressSaveTimer;
  Timer? _watchdogTimer; // Watchdog dla zaciętego odtwarzania
  Timer? _timeoutTimer;
  
  String? _gestureType; 
  Duration? _gestureSeekTarget;

  BoxFit _videoFill = BoxFit.contain;
  final List<StreamSubscription> _subscriptions = [];
  final FocusNode _playPauseFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _startTimeoutTimer();
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 50), () {
      if (mounted && _isLoading && !_isExiting) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        player.pause();
      }
    });
  }

  Future<void> _initPlayer() async {
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft, 
        DeviceOrientation.landscapeRight
      ]);
    }
    WakelockPlus.enable(); // Blokuj wygaszanie ekranu

    player = Player();
    
    // Opcje dla libmpv omijaj\u0105ce b\u0142\u0119dy handshake SSL na niekt\u00f3rych CDN
    if (player.platform is NativePlayer) {
      final native = player.platform as dynamic;
      native.setProperty('tls-verify', 'no');
      native.setProperty('http-proxy', ''); 
      native.setProperty('demuxer-lavf-o', 'protocol_whitelist=[file,rtp,tcp,udp,http,https,tls,tls_aes_128_gcm_sha256,tls_aes_256_gcm_sha384]');
      native.setProperty('tls-ca-file', ''); // Ignoruj systemowe CA je\u015bli s\u0105 przestarza\u0142e
      

    controller = VideoController(player);

    _subscriptions.add(player.stream.playing.listen((playing) {
      if (playing && _isLoading) {
        _onLoadSuccess();
      }
    }));

    _subscriptions.add(player.stream.width.listen((width) {
      if ((width ?? 0) > 0 && _isLoading) {
        _onLoadSuccess();
      }
    }));

    // Watchdog logic: detect stuck playback
    _subscriptions.add(player.stream.position.listen((pos) {
      if (!_isLoading && !_hasError && !_isExiting) {
        if (pos.inMilliseconds > 0) {
          _resetWatchdogTimer();
        }
      }
    }));

    if (widget.args.videoUrl != null) {
      _startPlayback(widget.args.videoUrl!);
    }
  }

  void _resetWatchdogTimer() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_isLoading && !_isExiting && player.state.playing) {
        // Jeśli film "gra" (playing=true), ale pozycja od 15s się nie zmienia
        debugPrint("Zetta Player: Watchdog detected stuck playback!");
        setState(() {
          _hasError = true;
        });
        player.pause();
      }
    });
  }

  void _onLoadSuccess() {
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted && _isLoading && !_isExiting) {
        _timeoutTimer?.cancel();
        _resetWatchdogTimer(); // Startujemy watchdog po załadowaniu
        setState(() {
          _isLoading = false;
          _hasError = false;
          _showWebViewDebug = false;
        });
        _startHideTimer();
        _startProgressTimer();
      }
    });
  }

  String get _storageId {
    if (widget.args.item.type == MediaType.series && widget.args.season != null && widget.args.episode != null) {
      return "${widget.args.item.id}_s${widget.args.season}_e${widget.args.episode}";
    }
    return widget.args.item.id;
  }

  String? _lastStreamUrl;
  void _startPlayback(String streamUrl) {
    if (!mounted || _isExiting) return;
    if (streamUrl == _lastStreamUrl) return;
    _lastStreamUrl = streamUrl;
    
    _startTimeoutTimer();

    Future.microtask(() {
      ref.read(historyProvider.notifier).addToHistory(widget.args.item);
      ref.read(continueWatchingProvider.notifier).addToContinue(widget.args.item);
      
      String cleanUrl = widget.args.initialUrl ?? streamUrl;
      if (cleanUrl.contains('ekino-tv.pl')) {
        cleanUrl = cleanUrl.split('?').first;
      }

      ref.read(sourceHistoryProvider.notifier).saveSource(
        _storageId,
        SavedSource(
          url: streamUrl, 
          pageUrl: cleanUrl,
          sourceName: widget.args.sourceName,
          title: widget.args.title,
          headers: widget.args.headers,
          automationScript: widget.args.automationScript,
        ),
      );
    });

    const mobileUA = 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';
    
    String referer = widget.args.initialUrl ?? 'https://ekino-tv.pl/';
    String origin = 'https://ekino-tv.pl';
    String finalUA = mobileUA;

    if (streamUrl.contains('r66nv9ed.com') || streamUrl.contains('filemoon') || streamUrl.contains('boosteradx')) {
      referer = widget.args.initialUrl ?? streamUrl;
    }

    final Map<String, String> headers = {
      'User-Agent': finalUA,
      'Accept': '*/*',
      'Accept-Language': 'pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7',
      'Accept-Encoding': 'gzip, deflate, br',
      'Referer': referer,
      'Origin': origin,
      'Connection': 'keep-alive',
    };

    // Dla Obejrzyj.to (Filemoon) usuwamy Origin i Sec-Fetch, bo s\u0105 zbyt rygorystyczne
    if (streamUrl.contains('r66nv9ed.com') || streamUrl.contains('filemoon') || streamUrl.contains('boosteradx')) {
      headers.remove('Origin');
    } else {
      headers['Sec-Fetch-Mode'] = 'cors';
      headers['Sec-Fetch-Site'] = 'cross-site';
      headers['Sec-Fetch-Dest'] = 'video';
    }

    if (widget.args.headers != null) {
      headers.addAll(widget.args.headers!);
    }

    player.stop().then((_) {
      if (_isExiting) return;
      
      final List<SubtitleTrack> externalSubtitles = [];
      if (widget.args.subtitles != null) {
        for (var sub in widget.args.subtitles!) {
          externalSubtitles.add(SubtitleTrack.uri(sub.url, title: sub.label, language: sub.language));
        }
      }

      player.open(
        Media(streamUrl, httpHeaders: headers),
        play: true,
      ).then((_) {
        if (externalSubtitles.isNotEmpty) {
          for (var track in externalSubtitles) {
            player.setSubtitleTrack(track);
          }
        }
        
        _loadProgress();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && player.state.playing && !_isExiting) {
            player.seek(player.state.position + const Duration(milliseconds: 100));
          }
        });
      });
    });
  }

  void _startProgressTimer() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _saveProgress();
    });
  }

  Future<void> _saveProgress() async {
    if (_isLoading || _hasError) return; // Usunięto _isExiting, bo chcemy zapisać przy wyjściu
    final prefs = await SharedPreferences.getInstance();
    final key = "progress_$_storageId";
    final position = player.state.position.inSeconds;
    final duration = player.state.duration.inSeconds;

    debugPrint('Zetta Player: Zapisuję postęp dla $key -> $position sek (duration: $duration)');
    await prefs.setInt(key, position);

    if (duration > 0 && position > duration * 0.9) {
      ref.read(continueWatchingProvider.notifier).removeFromContinue(widget.args.item.id);
    }
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final key = "progress_$_storageId";
    final savedSeconds = prefs.getInt(key);
    
    debugPrint('Zetta Player: Wczytuję postęp dla $key -> $savedSeconds sek');

    if (savedSeconds != null && savedSeconds > 10) {
      debugPrint('Zetta Player: Czekam na duration, aby wznowić od $savedSeconds sek');
      StreamSubscription? sub;
      sub = player.stream.duration.listen((duration) {
        if (duration.inSeconds > 0) {
          debugPrint('Zetta Player: Duration znane (${duration.inSeconds}s), wykonuję seek do $savedSeconds');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_isExiting) {
              player.seek(Duration(seconds: savedSeconds));
              debugPrint('Zetta Player: Seek wysłany');
            }
          });
          sub?.cancel();
        }
      });
      Future.delayed(const Duration(seconds: 20), () => sub?.cancel());
    }
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && player.state.playing) {
        setState(() => _showControls = false);
      }
    });
  }

  void _togglePlayPause() {
    if (_isExiting) return;
    player.playOrPause();
    if (!player.state.playing) {
      setState(() => _showControls = true);
      _playPauseFocusNode.requestFocus();
    } else {
      _startHideTimer();
    }
  }

  void _toggleControls() {
    if (_isExiting) return;
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _playPauseFocusNode.requestFocus();
      }
    });
    if (_showControls) _startHideTimer();
  }

  void _showControlsBriefly() {
    if (_isExiting) return;
    setState(() {
      _showControls = true;
      _playPauseFocusNode.requestFocus();
    });
    _startHideTimer();
  }

  Future<void> _handleBack() async {
    if (_isExiting) return;
    setState(() => _isExiting = true);
    
    await _saveProgress(); // Zapisujemy postęp przed wyjściem
    
    _hideControlsTimer?.cancel();
    _progressSaveTimer?.cancel();
    _timeoutTimer?.cancel();
    
    await player.stop();
    await player.dispose();
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable(); // Przywr\u00f3ć wygaszanie ekranu
    if (!_isExiting) {
      _saveProgress();
      _hideControlsTimer?.cancel();
      _progressSaveTimer?.cancel();
      _timeoutTimer?.cancel();
      player.dispose();
    }
    for (var s in _subscriptions) {
      s.cancel();
    }
    _playPauseFocusNode.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onDoubleTapDown(TapDownDetails details, double screenWidth) {
    if (_hasError || _isExiting) return;
    final gesturesEnabled = ref.read(playerGesturesProvider);
    if (!gesturesEnabled) return;

    final isRightSide = details.globalPosition.dx > screenWidth / 2;
    HapticFeedback.lightImpact();
    setState(() {
      _gestureType = 'forward';
      _gestureSeekTarget = isRightSide 
          ? player.state.position + const Duration(seconds: 10)
          : player.state.position - const Duration(seconds: 10);
    });
    player.seek(_gestureSeekTarget!);
    Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _gestureType = null);
    });
  }

  void _showSubtitlePicker() {
    _hideControlsTimer?.cancel();
    final tracks = player.state.tracks.subtitle;
    final current = player.state.track.subtitle;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.8),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Napisy', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  final isSelected = track == current;
                  return ListTile(
                    leading: Icon(Icons.subtitles, color: isSelected ? Colors.redAccent : Colors.white70),
                    title: Text(
                      track.title ?? track.language ?? (track.id == 'no' ? 'Wy\u0142\u0105czone' : 'Ście\u017cka ${index}'),
                      style: TextStyle(color: isSelected ? Colors.redAccent : Colors.white, fontWeight: isSelected ? FontWeight.bold : null),
                    ),
                    trailing: isSelected ? const Icon(Icons.check, color: Colors.redAccent) : null,
                    onTap: () {
                      player.setSubtitleTrack(track);
                      Navigator.pop(context);
                      _startHideTimer();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFill() {
    setState(() {
      if (_videoFill == BoxFit.contain) _videoFill = BoxFit.cover;
      else if (_videoFill == BoxFit.cover) _videoFill = BoxFit.fill;
      else _videoFill = BoxFit.contain;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isExiting) return const Scaffold(backgroundColor: Colors.black);
    
    final padding = MediaQuery.of(context).padding;
    
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.select): () => _togglePlayPause(),
        const SingleActivator(LogicalKeyboardKey.enter): () => _togglePlayPause(),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _showControlsBriefly(),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _showControlsBriefly(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          player.seek(player.state.position - const Duration(seconds: 10));
          _showControlsBriefly();
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          player.seek(player.state.position + const Duration(seconds: 10));
          _showControlsBriefly();
        },
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () => player.playOrPause(),
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.args.videoUrl == null && widget.args.initialUrl != null && !_isExiting)
              Positioned.fill(
                child: Offstage(
                  offstage: !_showWebViewDebug,
                  child: VideoSniffer(
                    initialUrl: widget.args.initialUrl!,
                    onStreamCaught: _startPlayback,
                    args: widget.args,
                  ),
                ),
              ),

            if (!_hasError && !_isExiting)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: _isLoading && _showWebViewDebug,
                  child: GestureDetector(
                    onTap: _toggleControls,
                    onDoubleTapDown: (details) => _onDoubleTapDown(details, MediaQuery.of(context).size.width),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (!_isLoading)
                          Video(
                            controller: controller,
                            controls: NoVideoControls,
                            fit: _videoFill,
                          ),
                        if (_gestureType != null) _buildGestureOverlay(),
                        if (!_isLoading) _buildMD3Controls(context, padding),
                        if (_isLoading && !_showWebViewDebug)
                          Container(
                            color: Colors.black,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: Colors.white),
                                  SizedBox(height: 16),
                                  Text(
                                    "Łączenie ze źródłem",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (!_isLoading)
                          StreamBuilder<bool>(
                            stream: player.stream.buffering,
                            builder: (context, snapshot) {
                              if (snapshot.data == true) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),

            if (_hasError && !_isExiting)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
                        const SizedBox(height: 24),
                        const Text(
                          "PROBLEM ZE \u0179R\u00d3D\u0141EM",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Nie uda\u0142o si\u0119 za\u0142adować wideo.\nSpr\u00f3buj u\u017cyć innego \u017ar\u00f3d\u0142a.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 32),
                        OutlinedButton.icon(
                          onPressed: _handleBack,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text("WR\u00d3\u0106 DO WYBORU"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureOverlay() {
    final isForward = _gestureType == 'forward';
    return Center(
      child: Container(
        width: 120, height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded, color: Colors.white, size: 40),
            Text(isForward ? "+10s" : "-10s", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMD3Controls(BuildContext context, EdgeInsets padding) {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: RepaintBoundary(
        child: Stack(
          children: [
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 80 + padding.top,
                padding: EdgeInsets.fromLTRB(16 + padding.left, padding.top, 16 + padding.right, 0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    _buildPillButton(Icons.arrow_back_ios_new_rounded, _handleBack),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.args.item.title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildPillButton(Icons.aspect_ratio_rounded, _toggleFill),
                    if (widget.args.subtitles != null && widget.args.subtitles!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      _buildPillButton(Icons.subtitles_rounded, _showSubtitlePicker),
                    ],
                  ],
                ),
              ),
            ),

            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(20 + padding.left, 20, 20 + padding.right, 12 + padding.bottom),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModernSlider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPillButton(Icons.replay_10_rounded, () => player.seek(player.state.position - const Duration(seconds: 10)), small: true),
                        const SizedBox(width: 40),
                        StreamBuilder<bool>(
                          stream: player.stream.playing,
                          initialData: player.state.playing,
                          builder: (context, snapshot) {
                            final isPlaying = snapshot.data ?? false;
                            return IconButton(
                              focusNode: _playPauseFocusNode,
                              icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 54),
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                _togglePlayPause();
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 40),
                        _buildPillButton(Icons.forward_10_rounded, () => player.seek(player.state.position + const Duration(seconds: 10)), small: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSlider() {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        final dur = player.state.duration;
        final primaryColor = Theme.of(context).colorScheme.primary;

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                activeTrackColor: primaryColor,
                thumbColor: primaryColor,
                inactiveTrackColor: Colors.white.withOpacity(0.2),
                overlayColor: primaryColor.withOpacity(0.2),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                trackShape: const RectangularSliderTrackShape(),
              ),
              child: Slider(
                value: pos.inSeconds.toDouble().clamp(0.0, dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0),
                max: dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  player.seek(Duration(seconds: v.toInt()));
                },
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(pos), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                  Text(_formatDuration(dur), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPillButton(IconData icon, VoidCallback onPressed, {bool small = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: Colors.white.withOpacity(0.15),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          child: Padding(
            padding: EdgeInsets.all(small ? 10 : 12),
            child: Icon(icon, color: Colors.white, size: small ? 22 : 20),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds";
  }
}

class VideoSniffer extends StatefulWidget {
  final String initialUrl;
  final Function(String) onStreamCaught;
  final PlayerArgs args;

  const VideoSniffer({
    super.key, 
    required this.initialUrl, 
    required this.onStreamCaught,
    required this.args,
  });

  @override
  State<VideoSniffer> createState() => _VideoSnifferState();
}

class _VideoSnifferState extends State<VideoSniffer> {
  @override
  Widget build(BuildContext context) {
    const mobileUA = 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

    final initialOrigin = widget.args.initialUrl != null ? Uri.parse(widget.args.initialUrl!).origin : 'https://ekino-tv.pl';
    final headers = widget.args.headers ?? {
      'User-Agent': snifferUA,
      'Referer': widget.args.initialUrl ?? 'https://ekino-tv.pl/',
      'Origin': initialOrigin,
    };

    final defaultScript = r"""
            (function() {
              // Anti-AdBlock Bypass
              window.google_ad_client = "ca-pub-zetta";
              window.adsbygoogle = { push: function() {} };
              window.ga = function() {};
              window.ads = true;
              window.canRunAds = true;
              
              Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
              
              var attempts = 0;
              var maxAttempts = 150;
              
              function deepClick(el) {
                if (!el) return;
                ['mousedown', 'mouseup', 'click'].forEach(evt => {
                  el.dispatchEvent(new MouseEvent(evt, { bubbles: true, cancelable: true, view: window }));
                });
              }

              function attemptAutoClick() {
                if (attempts++ > maxAttempts) return;
                
                var currentUrl = window.location.href;

                // 1. Przyciski startowe (Ekino buttonprch, Obejrzyj.to itp)
                document.querySelectorAll('a, button, .btn-play, .btn-primary, .warning_ch a, .buttonprch').forEach(el => {
                  const txt = el.textContent.toLowerCase();
                  if (txt.includes('odtwarzania') || txt.includes('oglądaj') || txt.includes('kliknij') || el.classList.contains('buttonprch')) {
                    if (!el.dataset.zettaClicked) {
                      el.dataset.zettaClicked = "true";
                      deepClick(el);
                      
                      // Wymuś nawigację dla przycisków typu buttonprch
                      if (el.classList.contains('buttonprch') && el.href && el.href !== '#' && !el.href.startsWith('javascript')) {
                        setTimeout(() => {
                           if (window.location.href === currentUrl) window.location.href = el.href;
                        }, 800);
                      }
                    }
                  }
                });

                // 2. Playery (standardowe selektory)
                var playSelectors = [
                  '.play-icon', '.play-btn', '.vjs-big-play-button', 
                  'button[aria-label="Play"]', '#play-btn', '.jw-display-icon-container'
                ];
                
                for (var sel of playSelectors) {
                  var btn = document.querySelector(sel);
                  if (btn && btn.offsetParent !== null && !btn.dataset.zettaClicked) {
                    btn.dataset.zettaClicked = "true";
                    deepClick(btn);
                  }
                }

                document.querySelectorAll('video').forEach(v => { 
                  if (v.paused) v.play().catch(() => {});
                });

                // 3. Kliknięcie w środek ekranu jako ostateczność
                if (attempts % 15 === 0) {
                   const centerEl = document.elementFromPoint(window.innerWidth / 2, window.innerHeight / 2);
                   if (centerEl) deepClick(centerEl);
                }
              }
              setInterval(attemptAutoClick, 1500);
            })();
    """;

    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(widget.initialUrl),
        headers: headers,
      ),
      onCreateWindow: (controller, action) async {
        return false;
      },
      shouldOverrideUrlLoading: (controller, action) async {
        var url = action.request.url?.toString() ?? "";
        
        if (url.contains('adsterra') || url.contains('traff') || url.contains('onclick') || url.contains('ylx-7')) {
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: widget.args.automationScript ?? defaultScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: true, 
        useShouldInterceptRequest: false, 
        useOnLoadResource: true, 
        preferredContentMode: UserPreferredContentMode.MOBILE, // Powr\u00f3t do MOBILE dla Player
        mediaPlaybackRequiresUserGesture: false,
        domStorageEnabled: true,
        databaseEnabled: true,
        userAgent: snifferUA,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
      ),
      onReceivedServerTrustAuthRequest: (controller, challenge) async {
        return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
      },
      onLoadResource: (controller, resource) {
        final reqUrl = resource.url.toString();
        bool isStream = reqUrl.contains('.m3u8') || reqUrl.contains('.mp4') || 
                        reqUrl.contains('/hls/') || reqUrl.contains('mxcontent.net') ||
                        reqUrl.contains('mxdcontent.net') || reqUrl.contains('playlist.m3u8') ||
                        reqUrl.contains('/pass_md5/');

        if (isStream) {
          if (reqUrl.contains('google.com') || reqUrl.contains('doubleclick') || reqUrl.contains('adsystem')) return;
          debugPrint('Zetta Sniffer: Z\u0142apano stream -> $reqUrl');
          widget.onStreamCaught(reqUrl);
          controller.loadUrl(urlRequest: URLRequest(url: WebUri('about:blank')));
        }
      },
    );
  }
}
