import 'dart:async';
import 'dart:collection';
import 'dart:ui';
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
  bool _showControls = true;
  Timer? _hideControlsTimer;
  Timer? _progressSaveTimer;
  
  String? _gestureType; 
  Duration? _gestureSeekTarget;

  BoxFit _videoFill = BoxFit.contain;
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
      if (playing && _isLoading) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted && _isLoading) {
            setState(() => _isLoading = false);
            _startHideTimer();
            _startProgressTimer();
          }
        });
      }
    }));

    _subscriptions.add(player.stream.width.listen((width) {
      if ((width ?? 0) > 0 && _isLoading) {
        setState(() => _isLoading = false);
        _startHideTimer();
        _startProgressTimer();
      }
    }));
  }

  String? _lastStreamUrl;
  void _startPlayback(String streamUrl) {
    if (!mounted) return;
    if (streamUrl == _lastStreamUrl) return;
    _lastStreamUrl = streamUrl;

    debugPrint("🎬 STARTING PLAYBACK: $streamUrl");
    player.open(Media(streamUrl, httpHeaders: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
      'Referer': 'https://play.ekino.link/',
    })).then((_) => _loadProgress());
  }

  void _startProgressTimer() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
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
      final duration = player.state.duration;
      if (duration.inSeconds > 0 && savedSeconds < duration.inSeconds - 10) {
        player.seek(Duration(seconds: savedSeconds));
      }
    }
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
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
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    player.dispose();
    super.dispose();
  }

  void _onDoubleTapDown(TapDownDetails details, double screenWidth) {
    final isRightSide = details.globalPosition.dx > screenWidth / 2;
    HapticFeedback.lightImpact();
    setState(() {
      _gestureType = isRightSide ? 'forward' : 'rewind';
      _gestureSeekTarget = isRightSide 
          ? player.state.position + const Duration(seconds: 10)
          : player.state.position - const Duration(seconds: 10);
    });
    player.seek(_gestureSeekTarget!);
    Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _gestureType = null);
    });
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
    final padding = MediaQuery.of(context).padding;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Hidden Sniffer
          if (_isLoading)
            Positioned.fill(
              child: Offstage(
                offstage: true, 
                child: VideoSniffer(
                  initialUrl: widget.args.videoUrl,
                  onStreamCaught: _startPlayback,
                ),
              ),
            ),

          // Player (Centered)
          if (!_isLoading)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() => _showControls = !_showControls);
                  if (_showControls) _startHideTimer();
                },
                onDoubleTapDown: (details) => _onDoubleTapDown(details, MediaQuery.of(context).size.width),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Video(
                      controller: controller,
                      controls: NoVideoControls,
                      fit: _videoFill,
                    ),
                    if (_gestureType != null) _buildGestureOverlay(),
                    _buildMD3Controls(context, padding),
                    StreamBuilder<bool>(
                      stream: player.stream.buffering,
                      builder: (context, snapshot) {
                        if (snapshot.data == true) {
                          return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Elegant Spinner Overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 40, height: 40,
                        child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 3),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "ŁĄCZENIE Z SERWEREM",
                        style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGestureOverlay() {
    final isForward = _gestureType == 'forward';
    return Center(
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: 120, height: 120,
            color: Colors.white.withOpacity(0.1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded, color: Colors.white, size: 40),
                Text(isForward ? "+10s" : "-10s", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMD3Controls(BuildContext context, EdgeInsets padding) {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: Stack(
        children: [
          // Top Bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 80 + padding.top,
              padding: EdgeInsets.fromLTRB(16 + padding.left, padding.top, 16 + padding.right, 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  _buildPillButton(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.args.item.title,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildPillButton(Icons.aspect_ratio_rounded, _toggleFill),
                ],
              ),
            ),
          ),

          // Bottom Bar (Glassmorphism MD3E)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20 + padding.left, 20, 20 + padding.right, 12 + padding.bottom),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
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
                            icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 54),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              player.playOrPause();
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
    );
  }

  Widget _buildModernSlider() {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        final dur = player.state.duration;
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0), // Ukryty thumb dla czystego wyglądu MD3
                activeTrackColor: Colors.redAccent,
                inactiveTrackColor: Colors.white.withOpacity(0.2),
                overlayShape: SliderComponentShape.noOverlay,
                trackShape: const RectangularSliderTrackShape(),
              ),
              child: Slider(
                value: pos.inSeconds.toDouble().clamp(0.0, dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0),
                max: dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0,
                onChanged: (v) => player.seek(Duration(seconds: v.toInt())),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(pos), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
                  Text(_formatDuration(dur), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
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
        color: Colors.white.withOpacity(0.1),
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

class VideoSniffer extends StatelessWidget {
  final String initialUrl;
  final Function(String) onStreamCaught;

  const VideoSniffer({super.key, required this.initialUrl, required this.onStreamCaught});

  @override
  Widget build(BuildContext context) {
    const desktopUA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36';
    
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(initialUrl),
        headers: {
          'User-Agent': desktopUA,
          'Referer': 'https://ekino-tv.pl/',
        },
      ),
      onConsoleMessage: (controller, message) {
        debugPrint("🌐 JS: ${message.message}");
      },
      onCreateWindow: (controller, action) async {
        if (action.request.url != null) {
          controller.loadUrl(urlRequest: action.request);
        }
        return true;
      },
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: r"""
            (function() {
              var clickInProgress = false;

              function attemptAutoClick() {
                if (clickInProgress) return;
                var currentUrl = window.location.href;
                
                if (document.querySelector('#cf-challenge') || document.querySelector('.cf-turnstile')) {
                  return;
                }

                var timer = document.querySelector('#timer, .timer, #countdown, [class*="countdown"]');
                if (timer) {
                  var timeTxt = timer.textContent.trim();
                  var isCounting = (timeTxt.includes(':') || (!isNaN(parseInt(timeTxt)) && parseInt(timeTxt) > 0));
                  if (isCounting && timeTxt !== '0' && timeTxt !== '00:00') {
                    console.log('⏳ Czekam na koniec odliczania: ' + timeTxt);
                    return; 
                  }
                }

                if (currentUrl.indexOf('ekino-tv.pl') !== -1) {
                  var targetBtn = document.querySelector('a.buttonprch') || 
                                  document.querySelector('.warning_ch a') ||
                                  document.querySelector('a[href*="play.ekino.link"]');

                  if (targetBtn && !targetBtn.dataset.automationClicked) {
                    var btnText = targetBtn.textContent.toLowerCase();
                    if (btnText === '' || btnText.indexOf('przejdź') !== -1 || btnText.indexOf('odtwarzania') !== -1 || targetBtn.classList.contains('buttonprch')) {
                      clickInProgress = true;
                      targetBtn.dataset.automationClicked = "true";
                      console.log('✅ Znaleziono przycisk przejścia (' + btnText + '). Klikam...');
                      
                      targetBtn.setAttribute('target', '_self');
                      if (targetBtn.href && targetBtn.href.indexOf('http') === 0) {
                        window.location.href = targetBtn.href;
                      } else {
                        var evt = new MouseEvent('click', { bubbles: true, cancelable: true, view: window });
                        targetBtn.dispatchEvent(evt);
                      }
                      
                      setTimeout(function() { clickInProgress = false; }, 3000);
                      return;
                    }
                  }

                  var imgEntry = document.querySelector('img[src*="kliknij_aby_obejrzec"]');
                  if (imgEntry && !imgEntry.dataset.automationClicked) {
                    var parentLink = imgEntry.closest('a');
                    if (parentLink) {
                      clickInProgress = true;
                      imgEntry.dataset.automationClicked = "true";
                      console.log('✅ Znaleziono obrazek wejściowy. Klikam...');
                      parentLink.setAttribute('target', '_self');
                      parentLink.click();
                      setTimeout(function() { clickInProgress = false; }, 3000);
                      return;
                    }
                  }
                } 
                
                if (currentUrl.indexOf('play.') !== -1 || currentUrl.indexOf('f16px.com') !== -1) {
                  var playSelectors = ['.vjs-big-play-button', '.play-button', 'button[aria-label="Play"]', '.jw-display-icon-container', '#play-btn', '.play_icon'];
                  for (var i = 0; i < playSelectors.length; i++) {
                    var btn = document.querySelector(playSelectors[i]);
                    if (btn && btn.offsetParent !== null && !btn.dataset.automationClicked) {
                      clickInProgress = true;
                      btn.dataset.automationClicked = "true";
                      console.log('✅ Klikam Play na stronie odtwarzacza');
                      btn.click();
                      setTimeout(function() { clickInProgress = false; }, 3000);
                      return;
                    }
                  }
                }
              }
              setInterval(attemptAutoClick, 1000);
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
        mediaPlaybackRequiresUserGesture: false,
        domStorageEnabled: true,
        databaseEnabled: true,
        useWideViewPort: true,
        userAgent: desktopUA,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
      ),
      shouldInterceptRequest: (controller, request) async {
        final reqUrl = request.url.toString();
        if (reqUrl.contains('.m3u8') || (reqUrl.contains('.mp4') && !reqUrl.contains('ads'))) {
          debugPrint("🌐 SNIFFER FOUND: " + reqUrl);
          onStreamCaught(reqUrl);
        }
        return null;
      },
    );
  }
}
