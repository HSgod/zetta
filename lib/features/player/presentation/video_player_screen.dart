import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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
  String _loadingStatus = "Ładowanie...";
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

    player = Player();
    controller = VideoController(player);

    // Słuchamy stanu odtwarzacza, aby wiedzieć kiedy faktycznie zaczął grać
    _subscriptions.add(player.stream.playing.listen((playing) {
      final width = player.state.width;
      if (playing && _isLoading && width != null && width > 0) {
        setState(() => _isLoading = false);
      }
    }));

    // Słuchamy też zmian wymiarów, bo klatka wideo może pojawić się chwilę po 'playing'
    _subscriptions.add(player.stream.width.listen((width) {
      if (width != null && width > 0 && player.state.playing && _isLoading) {
        setState(() => _isLoading = false);
      }
    }));

    final url = widget.args.videoUrl.toLowerCase();
    if (url.contains('.m3u8') || url.contains('.mp4')) {
      _startPlayback(widget.args.videoUrl);
    }
  }

  void _startPlayback(String streamUrl) {
    if (!mounted) return;
    print("🎬 SUCCESS! SNIFFER CAUGHT STREAM: $streamUrl");
    
    setState(() {
      _loadingStatus = "Uruchamianie strumienia...";
    });

    player.open(Media(streamUrl, httpHeaders: {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro Build/UQ1A.231205.015; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/120.0.6099.144 Mobile Safari/537.36',
      'Referer': 'https://play.ekino.link/',
      'Origin': 'https://play.ekino.link',
    }));
  }

  @override
  void dispose() {
    for (var s in _subscriptions) {
      s.cancel();
    }
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // WEBVIEW - Ukryte, ale działające w tle (tylko podczas ładowania)
          if (_isLoading)
            Opacity(
              opacity: 0.01,
              child: _buildDiagnosticSniffer(),
            ),

          // PLAYER - Zawsze w drzewie, ale pod spodem nakładki
          Positioned.fill(
            child: Video(
              controller: controller, 
              controls: MaterialVideoControls,
            ),
          ),
            
          // JEDNOLITY EKRAN ŁADOWANIA
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 20),
                    Text(
                      _loadingStatus,
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 16, 
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // PRZYCISK ZAMKNIĘCIA
          Positioned(
            top: 10, left: 10,
            child: SafeArea(
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticSniffer() {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(widget.args.videoUrl),
        headers: {'Referer': 'https://ekino-tv.pl/'},
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: """
            (function() {
              window.hCaptchaCallback = function() { console.log('JS: CF Callback'); };

              function tryClick() {
                var btn = document.querySelector('.buttonprch') || 
                          document.querySelector('.warning-msg a') ||
                          document.querySelector('a[href*="play.ekino.link"]');

                if (btn) {
                  if (window._zettaDone) return;
                  window._zettaDone = true;
                  
                  btn.target = "_self";
                  btn.scrollIntoView({behavior: 'instant', block: 'center'});

                  setTimeout(function() {
                    btn.focus();
                    btn.click();
                    ['mousedown', 'mouseup'].forEach(function(t) {
                      btn.dispatchEvent(new MouseEvent(t, {view: window, bubbles: true, cancelable: true, buttons: 1}));
                    });
                  }, 1000);
                  return;
                }

                if (window.location.hostname.includes('ekino-tv.pl') && !window.location.href.includes('player')) {
                  if (window._zettaInit) return;

                  var players = document.querySelectorAll('.players li a');
                  if (players.length > 0 && !players[0].parentElement.classList.contains('active')) {
                    players[0].click();
                    return;
                  }

                  var img = document.querySelector('img[src*="kliknij_aby_obejrzec"]');
                  if (img) {
                    window._zettaInit = true;
                    img.click();
                    if (img.parentElement && img.parentElement.tagName === 'A') img.parentElement.click();
                  }
                }
              }
              setInterval(tryClick, 2000);
            })();
          """,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useShouldInterceptRequest: true,
        mediaPlaybackRequiresUserGesture: false,
        domStorageEnabled: true,
        supportMultipleWindows: false,
        userAgent: "Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro Build/UQ1A.231205.015; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/120.0.6099.144 Mobile Safari/537.36",
      ),
      onConsoleMessage: (controller, msg) => print("[JS DEBUG] ${msg.message}"),
      shouldInterceptRequest: (controller, request) async {
        final reqUrl = request.url.toString();
        if (reqUrl.contains('.m3u8') || reqUrl.contains('.mp4') || (reqUrl.contains('master') && reqUrl.contains('m3u8'))) {
          _startPlayback(reqUrl);
        }
        return null;
      },
      onLoadStop: (controller, currentUrl) async {
        setState(() => _loadingStatus = "Ładowanie...");
      },
    );
  }
}
