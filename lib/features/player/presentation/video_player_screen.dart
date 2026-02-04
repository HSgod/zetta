import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_args.dart';

class VideoPlayerScreen extends StatefulWidget {
  final PlayerArgs args;

  const VideoPlayerScreen({super.key, required this.args});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player player;
  late final VideoController controller;
  
  bool _isLoading = true;
  bool _isLocked = false;
  bool _showControls = true;
  String _loadingStatus = "Ładowanie...";
  Timer? _hideControlsTimer;
  Timer? _progressSaveTimer;
  
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft, 
      DeviceOrientation.landscapeRight
    ]);

    player = Player();
    controller = VideoController(player);

    _subscriptions.add(player.stream.playing.listen((playing) {
      if (playing && _isLoading && (player.state.width ?? 0) > 0) {
        setState(() => _isLoading = false);
        _startHideTimer();
        _startProgressTimer();
      }
    }));

    _subscriptions.add(player.stream.width.listen((width) {
      if ((width ?? 0) > 0 && player.state.playing && _isLoading) {
        setState(() => _isLoading = false);
        _startHideTimer();
        _startProgressTimer();
      }
    }));

    final url = widget.args.videoUrl.toLowerCase();
    if (url.contains('.m3u8') || url.contains('.mp4')) {
      _startPlayback(widget.args.videoUrl);
    }
  }

  void _startProgressTimer() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _saveProgress();
    });
  }

  Future<void> _saveProgress() async {
    if (_isLoading) return;
    final prefs = await SharedPreferences.getInstance();
    final key = "progress_${widget.args.item.title}";
    await prefs.setInt(key, player.state.position.inSeconds);
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final key = "progress_${widget.args.item.title}";
    final savedSeconds = prefs.getInt(key);
    if (savedSeconds != null && savedSeconds > 10) {
      player.seek(Duration(seconds: savedSeconds));
    }
  }

  void _startPlayback(String streamUrl) {
    if (!mounted) return;
    print("🎬 SNIFFER CAUGHT STREAM: $streamUrl");
    
    setState(() {
      _loadingStatus = "Inicjalizacja strumienia...";
    });

    player.open(Media(streamUrl, httpHeaders: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
      'Referer': 'https://play.ekino.link/',
    })).then((_) => _loadProgress());
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isLocked) setState(() => _showControls = false);
    });
  }

  @override
  void dispose() {
    _saveProgress();
    _hideControlsTimer?.cancel();
    _progressSaveTimer?.cancel();
    for (var s in _subscriptions) {
      s.cancel();
    }
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp, 
      DeviceOrientation.portraitDown
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    player.dispose();
    super.dispose();
  }

  void _onDoubleTap(TapDownDetails details, double screenWidth) {
    if (_isLocked) return;
    final isRightSide = details.globalPosition.dx > screenWidth / 2;
    if (isRightSide) {
      player.seek(player.state.position + const Duration(seconds: 10));
    } else {
      player.seek(player.state.position - const Duration(seconds: 10));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() => _showControls = !_showControls);
          if (_showControls) _startHideTimer();
        },
        onDoubleTapDown: (details) => _onDoubleTap(details, screenWidth),
        child: Stack(
          children: [
            // WEBVIEW SNIFFER (UKRYTY)
            if (_isLoading)
              Opacity(
                opacity: 0.01,
                child: _buildDiagnosticSniffer(),
              ),

            // PLAYER
            Positioned.fill(
              child: Video(
                controller: controller,
                controls: NoVideoControls,
              ),
            ),

            // CUSTOM UI OVERLAY
            if (_showControls || _isLocked)
              _buildCustomControls(),

            // LOADING OVERLAY
            if (_isLoading)
              _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            const SizedBox(height: 24),
            Text(
              _loadingStatus,
              style: const TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomControls() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: _isLocked ? Colors.transparent : Colors.black38,
        ),
        child: Column(
          children: [
            // TOP BAR
            if (!_isLocked)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.args.item.title,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            const Expanded(child: SizedBox()),

            // LOCK BUTTON (SIDE)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: IconButton(
                  icon: Icon(_isLocked ? Icons.lock : Icons.lock_open, color: Colors.white70, size: 28),
                  onPressed: () => setState(() => _isLocked = !_isLocked),
                ),
              ),
            ),

            const Expanded(child: SizedBox()),

            // BOTTOM CONTROLS
            if (!_isLocked)
              _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<Duration>(
            stream: player.stream.position,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = player.state.duration;
              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: position.inSeconds.toDouble().clamp(0, duration.inSeconds.toDouble() > 0 ? duration.inSeconds.toDouble() : 1.0),
                      max: duration.inSeconds.toDouble() > 0 ? duration.inSeconds.toDouble() : 1.0,
                      onChanged: (val) => player.seek(Duration(seconds: val.toInt())),
                      activeColor: Colors.redAccent,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(_formatDuration(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white, size: 32),
                onPressed: () => player.seek(player.state.position - const Duration(seconds: 10)),
              ),
              const SizedBox(width: 32),
              StreamBuilder<bool>(
                stream: player.stream.playing,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data ?? false;
                  return IconButton(
                    icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white, size: 64),
                    onPressed: () => player.playOrPause(),
                  );
                },
              ),
              const SizedBox(width: 32),
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
                onPressed: () => player.seek(player.state.position + const Duration(seconds: 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds";
  }

  Widget _buildDiagnosticSniffer() {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(widget.args.videoUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
          'Referer': 'https://ekino-tv.pl/',
        },
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: """
            (function() {
              function attemptAutoClick() {
                var playBtns = ['.vjs-big-play-button', '.jw-display-icon-container', '.play-button', 'button[aria-label="Play"]', 'a[href*="play.ekino.link"]', '.buttonprch'];
                for (var i = 0; i < playBtns.length; i++) {
                  var btn = document.querySelector(playBtns[i]);
                  if (btn && btn.offsetParent !== null) { 
                    btn.click();
                    return; 
                  }
                }
                var video = document.querySelector('video');
                if (video && video.paused) video.play();
              }
              setInterval(attemptAutoClick, 1500);
            })();
          """,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useShouldInterceptRequest: true,
        preferredContentMode: UserPreferredContentMode.DESKTOP,
      ),
      shouldInterceptRequest: (controller, request) async {
        final reqUrl = request.url.toString();
        if (reqUrl.contains('.m3u8') || reqUrl.contains('.mp4')) {
          _startPlayback(reqUrl);
        }
        return null;
      },
    );
  }
}