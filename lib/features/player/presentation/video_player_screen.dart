import 'dart:async';
import 'dart:collection';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _showWebViewDebug = false;
  bool _isExiting = false;
  Timer? _hideControlsTimer;
  Timer? _progressSaveTimer;
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
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft, 
      DeviceOrientation.landscapeRight
    ]);

    player = Player();
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

    if (widget.args.videoUrl != null) {
      _startPlayback(widget.args.videoUrl!);
    }
  }

  void _onLoadSuccess() {
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted && _isLoading && !_isExiting) {
        _timeoutTimer?.cancel();
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

  String? _lastStreamUrl;
  void _startPlayback(String streamUrl) {
    if (!mounted || _isExiting) return;
    if (streamUrl == _lastStreamUrl) return;
    _lastStreamUrl = streamUrl;
    
    _startTimeoutTimer();

    Future.microtask(() {
      ref.read(historyProvider.notifier).addToHistory(widget.args.item);
      ref.read(continueWatchingProvider.notifier).addToContinue(widget.args.item);
      
      ref.read(sourceHistoryProvider.notifier).saveSource(
        widget.args.item.id,
        SavedSource(
          url: streamUrl,
          pageUrl: widget.args.initialUrl,
          headers: widget.args.headers,
          automationScript: widget.args.automationScript,
        ),
      );
    });

    final desktopUA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
    
    final Map<String, String> headers = {
      'User-Agent': desktopUA,
      'Referer': widget.args.initialUrl ?? 'https://obejrzyj.to/',
    };

    if (widget.args.initialUrl != null) {
      try {
        final uri = Uri.parse(widget.args.initialUrl!);
        headers['Origin'] = '${uri.scheme}://${uri.host}';
      } catch (_) {}
    }

    if (widget.args.headers != null) {
      headers.addAll(widget.args.headers!);
    }

    player.stop().then((_) {
      if (_isExiting) return;
      player.open(Media(streamUrl, httpHeaders: headers)).then((_) {
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
    if (_isLoading || _hasError || _isExiting) return;
    final prefs = await SharedPreferences.getInstance();
    final key = "progress_${widget.args.item.id}";
    final position = player.state.position.inSeconds;
    final duration = player.state.duration.inSeconds;

    await prefs.setInt(key, position);

    if (duration > 0 && position > duration * 0.9) {
      ref.read(continueWatchingProvider.notifier).removeFromContinue(widget.args.item.id);
    }
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final key = "progress_${widget.args.item.id}";
    final savedSeconds = prefs.getInt(key);
    
    if (savedSeconds != null && savedSeconds > 10) {
      StreamSubscription? sub;
      sub = player.stream.buffer.listen((buffer) {
        if (buffer.inSeconds > 0) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_isExiting) {
              player.seek(Duration(seconds: savedSeconds));
            }
          });
          sub?.cancel();
        }
      });
      Future.delayed(const Duration(seconds: 15), () => sub?.cancel());
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
            if (widget.args.videoUrl == null && widget.args.initialUrl != null && !_hasError && !_isExiting)
              Positioned.fill(
                child: VideoSniffer(
                  initialUrl: widget.args.initialUrl!,
                  onStreamCaught: _startPlayback,
                  args: widget.args,
                ),
              ),

            if (!_isLoading && !_hasError && !_isExiting)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleControls,
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
                          "PROBLEM ZE ŹRÓDŁEM",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Nie udało się załadować wideo w wyznaczonym czasie.\nSpróbuj użyć innego źródła.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 32),
                        OutlinedButton.icon(
                          onPressed: _handleBack,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text("WRÓĆ DO WYBORU"),
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

            if (_isLoading && !_showWebViewDebug && !_isExiting)
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
    final desktopUA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
    
    final initialOrigin = widget.args.initialUrl != null ? Uri.parse(widget.args.initialUrl!).origin : 'https://ekino-tv.pl';
    final headers = widget.args.headers ?? {
      'User-Agent': desktopUA,
      'Referer': widget.args.initialUrl ?? 'https://ekino-tv.pl/',
      'Origin': initialOrigin,
    };

    final defaultScript = r"""
            (function() {
              var attempts = 0;
              var maxAttempts = 100;
              var ultraClicksDone = false;
              
              function attemptAutoClick() {
                if (attempts++ > maxAttempts) return;
                const bodyText = document.body.innerText;
                if (bodyText.includes('Verifying you are human') || 
                    bodyText.includes('Checking your browser') || 
                    document.querySelector('#cf-challenge')) return;

                var currentUrl = window.location.href;
                var isUltra = currentUrl.indexOf('ultrastream') !== -1 || currentUrl.indexOf('streamly') !== -1;

                if (isUltra || attempts % 5 === 0) {
                  document.querySelectorAll('div').forEach(el => {
                    const z = parseInt(window.getComputedStyle(el).zIndex);
                    if (z > 100 && !el.querySelector('video')) {
                      el.remove();
                    }
                  });
                }

                document.querySelectorAll('video').forEach(v => { 
                  v.muted = true; 
                  if (v.paused) v.play().catch(() => {});
                });
                
                if (currentUrl.indexOf('ekino-tv.pl') !== -1) {
                  var startImg = document.querySelector('img[src*="kliknij_aby_obejrzec"]');
                  if (startImg && !startImg.dataset.automationClicked) {
                    startImg.dataset.automationClicked = "true";
                    startImg.click();
                    if (startImg.parentElement && startImg.parentElement.tagName === 'A') startImg.parentElement.click();
                    return;
                  }

                  var playerLinks = document.querySelectorAll('.players a, a.buttonprch, .warning_ch a, a[href*="play.ekino.link"]');
                  for (var i = 0; i < playerLinks.length; i++) {
                    if (!playerLinks[i].dataset.automationClicked) {
                      playerLinks[i].dataset.automationClicked = "true";
                      playerLinks[i].setAttribute('target', '_self');
                      playerLinks[i].click();
                      window.location.href = playerLinks[i].href;
                      return;
                    }
                  }
                } 
                
                var playSelectors = [
                  '.player-button',
                  '.vjs-big-play-button', 
                  '.play-button', 
                  'button[aria-label="Play"]', 
                  '.jw-display-icon-container', 
                  '#play-btn', 
                  '.play_icon',
                  '#play',
                  '.click-to-play',
                  '.vjs-poster',
                  '#player_control_play'
                ];
                
                for (var i = 0; i < playSelectors.length; i++) {
                  var btn = document.querySelector(playSelectors[i]);
                  if (btn && btn.offsetParent !== null) {
                    if (isUltra && !ultraClicksDone) {
                      btn.click();
                      btn.dispatchEvent(new MouseEvent('mousedown', {bubbles: true}));
                      btn.dispatchEvent(new MouseEvent('mouseup', {bubbles: true}));
                      btn.dispatchEvent(new MouseEvent('click', {bubbles: true}));
                      ultraClicksDone = true;
                      return;
                    } else if (!isUltra && !btn.dataset.automationClicked) {
                      btn.dataset.automationClicked = "true";
                      btn.click();
                      return;
                    }
                  }
                }
                if (attempts % 15 === 0) {
                  const el = document.elementFromPoint(window.innerWidth/2, window.innerHeight/2);
                  if (el) el.click();
                }
              }
              window.open = function() { return { focus: function() {} }; };
              setInterval(attemptAutoClick, 1000);
            })();
    """;

    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(widget.initialUrl),
        headers: headers,
      ),
      onCreateWindow: (controller, action) async {
        if (action.request.url != null) {
          controller.loadUrl(urlRequest: action.request);
        }
        return true;
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
        useShouldInterceptRequest: false, 
        useOnLoadResource: true, 
        preferredContentMode: UserPreferredContentMode.DESKTOP,
        mediaPlaybackRequiresUserGesture: false,
        domStorageEnabled: true,
        databaseEnabled: true,
        userAgent: desktopUA,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
      ),
      onReceivedServerTrustAuthRequest: (controller, challenge) async {
        return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
      },
      onLoadResource: (controller, resource) {
        final reqUrl = resource.url.toString();
        if (reqUrl.contains('tracker') || reqUrl.contains('analytics') || reqUrl.contains('collect')) return;
        if (reqUrl.contains('.m3u8') || reqUrl.contains('.mp4') || reqUrl.contains('/hls/')) {
          if (reqUrl.contains('google.com') || reqUrl.contains('facebook.com') || reqUrl.contains('doubleclick')) return;
          widget.onStreamCaught(reqUrl);
          Future.delayed(const Duration(seconds: 30), () {
            if (mounted) {
              controller.loadUrl(urlRequest: URLRequest(url: WebUri('about:blank')));
            }
          });
        }
      },
    );
  }
}
