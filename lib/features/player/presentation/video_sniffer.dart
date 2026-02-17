import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../presentation/player_args.dart';

class VideoSniffer extends StatefulWidget {
  final String initialUrl;
  final Function(String) onStreamCaught;
  final PlayerArgs? args;
  final Map<String, String>? headers;
  final String? automationScript;

  const VideoSniffer({
    super.key, 
    required this.initialUrl, 
    required this.onStreamCaught,
    this.args,
    this.headers,
    this.automationScript,
  });

  @override
  State<VideoSniffer> createState() => _VideoSnifferState();
}

class _VideoSnifferState extends State<VideoSniffer> {
  @override
  Widget build(BuildContext context) {
    const mobileUA = 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';
    const desktopUA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

    String snifferUA = mobileUA;
    if (widget.initialUrl.contains('mixdrop') || widget.initialUrl.contains('voe')) {
      snifferUA = desktopUA;
    }

    final initialOrigin = widget.args?.initialUrl != null 
        ? Uri.parse(widget.args!.initialUrl!).origin 
        : (widget.initialUrl.startsWith('http') ? Uri.parse(widget.initialUrl).origin : 'https://ekino-tv.pl');
        
    final headers = widget.headers ?? widget.args?.headers ?? {
      'User-Agent': snifferUA,
      'Referer': widget.args?.initialUrl ?? widget.initialUrl,
      'Origin': initialOrigin,
    };

    final defaultScript = r"""
            (function() {
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

                document.querySelectorAll('a, button, .btn-play, .btn-primary, .warning_ch a, .buttonprch').forEach(el => {
                  const txt = el.textContent.toLowerCase();
                  if (txt.includes('odtwarzania') || txt.includes('oglądaj') || txt.includes('kliknij') || el.classList.contains('buttonprch')) {
                    if (!el.dataset.zettaClicked) {
                      el.dataset.zettaClicked = "true";
                      deepClick(el);
                      
                      if (el.classList.contains('buttonprch') && el.href && el.href !== '#' && !el.href.startsWith('javascript')) {
                        setTimeout(() => {
                           if (window.location.href === currentUrl) window.location.href = el.href;
                        }, 800);
                      }
                    }
                  }
                });

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
          source: widget.automationScript ?? widget.args?.automationScript ?? defaultScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: true, 
        useShouldInterceptRequest: false, 
        useOnLoadResource: true, 
        preferredContentMode: UserPreferredContentMode.MOBILE,
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
        
        // Ignoruj reklamy i analitykę
        if (reqUrl.contains('google.com') || reqUrl.contains('doubleclick') || 
            reqUrl.contains('adsystem') || reqUrl.contains('analytics')) return;

        bool isMp4 = reqUrl.contains('.mp4') || reqUrl.contains('mxcontent.net') || reqUrl.contains('mxdcontent.net') || reqUrl.contains('/pass_md5/');
        bool isHls = reqUrl.contains('.m3u8') || reqUrl.contains('/hls/') || reqUrl.contains('playlist.m3u8');

        if (isMp4) {
          debugPrint('Sniffer: Wykryto MP4: $reqUrl');
          widget.onStreamCaught(reqUrl);
          controller.loadUrl(urlRequest: URLRequest(url: WebUri('about:blank')));
        } else if (isHls) {
          debugPrint('Sniffer: Wykryto HLS: $reqUrl');
          // Jeśli to HLS, poczekajmy 2 sekundy czy nie pojawi się MP4
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              widget.onStreamCaught(reqUrl);
              controller.loadUrl(urlRequest: URLRequest(url: WebUri('about:blank')));
            }
          });
        }
      },
    );
  }
}
