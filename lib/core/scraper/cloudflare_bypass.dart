import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Dialog z ukrytą WebView który przechodzi Cloudflare Turnstile.
/// Zamyka się automatycznie po pobraniu HTML lub po timeoucie.
class CloudflareBypassDialog extends StatefulWidget {
  final String url;
  final Completer<String?> completer;

  const CloudflareBypassDialog({
    super.key,
    required this.url,
    required this.completer,
  });

  /// Otwiera dialog, czeka na HTML i go zwraca. Zamyka się automatycznie.
  static Future<String?> fetch(BuildContext context, String url) async {
    final completer = Completer<String?>();
    // Przechwytujemy dialogCtx z buildera – zawsze wskazuje na właściwy
    // route dialogu, niezależnie od GoRouter / root navigator
    BuildContext? dialogCtx;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      useRootNavigator: true,
      builder: (ctx) {
        dialogCtx = ctx;
        return CloudflareBypassDialog(url: url, completer: completer);
      },
    );

    // Czekamy na wynik
    await completer.future;

    // Zamykamy dialog używając przechwyconego kontekstu buildera
    final ctx = dialogCtx;
    if (ctx != null && ctx.mounted) {
      Navigator.of(ctx, rootNavigator: true).pop();
    } else if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    return completer.future;
  }

  @override
  State<CloudflareBypassDialog> createState() => _CloudflareBypassDialogState();
}

class _CloudflareBypassDialogState extends State<CloudflareBypassDialog>
    with SingleTickerProviderStateMixin {
  InAppWebViewController? _controller;
  bool _done = false;
  int _checkCount = 0;
  static const int _maxChecks = 60; // 60 * 500ms = 30s
  late AnimationController _dotAnim;

  @override
  void initState() {
    super.initState();
    _dotAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Globalny timeout – jeśli przez 30s CF nie odpuści, kończymy z null
    Future.delayed(const Duration(seconds: 30), () {
      if (!_done && !widget.completer.isCompleted) {
        _done = true;
        widget.completer.complete(null);
      }
    });
  }

  @override
  void dispose() {
    _dotAnim.dispose();
    super.dispose();
  }

  Future<void> _checkAndExtract() async {
    if (_done || _controller == null || !mounted) return;

    if (_checkCount++ > _maxChecks) {
      _done = true;
      if (!widget.completer.isCompleted) widget.completer.complete(null);
      return;
    }

    try {
      final title = (await _controller!.getTitle()) ?? '';
      final html = (await _controller!.evaluateJavascript(
            source: 'document.documentElement.outerHTML',
          ) as String?) ??
          '';

      final isChallenge = title.toLowerCase().contains('just a moment') ||
          title.toLowerCase().contains('checking your browser') ||
          title.toLowerCase().contains('attention required') ||
          html.contains('cf_chl_opt') ||
          html.contains('challenge-error-text') ||
          html.length < 800;

      if (!isChallenge && html.isNotEmpty) {
        debugPrint(
            'CloudflareBypass: sukces dla ${widget.url} (${html.length} znaków)');
        _done = true;
        if (!widget.completer.isCompleted) widget.completer.complete(html);
        // Zamknięcie obsługuje fetch() przez await completer.future
      } else {
        debugPrint('CloudflareBypass: challenge aktywny (${_checkCount}x)');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) _checkAndExtract();
      }
    } catch (e) {
      debugPrint('CloudflareBypass check error: $e');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _checkAndExtract();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF12121F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 28),

            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E1E35),
                border: Border.all(
                    color: const Color(0xFFE50914).withValues(alpha: 0.4),
                    width: 2),
              ),
              child: const Icon(Icons.shield_outlined,
                  color: Color(0xFFE50914), size: 28),
            ),

            const SizedBox(height: 16),

            const Text(
              'Łączenie z Zaluknij.cc',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Weryfikacja bezpieczeństwa...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 20),

            const LinearProgressIndicator(
              value: null,
              backgroundColor: Color(0x1AFFFFFF),
              valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
              minHeight: 2,
            ),

            const SizedBox(height: 20),

            // WebView – opacity 0.01 i height 1 – niewidoczna ale renderowana
            SizedBox(
              width: double.infinity,
              height: 1,
              child: Opacity(
                opacity: 0.01,
                child: InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(widget.url),
                  ),
                  initialUserScripts: UnmodifiableListView<UserScript>([
                    UserScript(
                      source: r"""
                        Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
                        Object.defineProperty(navigator, 'languages', { get: () => ['pl-PL', 'pl', 'en-US', 'en'] });
                        Object.defineProperty(navigator, 'plugins', { get: () => [1, 2, 3, 4, 5] });
                        window.chrome = { runtime: {} };
                        Object.defineProperty(navigator, 'permissions', {
                          get: () => ({ query: () => Promise.resolve({ state: 'granted' }) })
                        });
                      """,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                      forMainFrameOnly: false,
                    ),
                  ]),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    userAgent:
                        'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) '
                        'AppleWebKit/537.36 (KHTML, like Gecko) '
                        'Chrome/124.0.6367.82 Mobile Safari/537.36',
                    javaScriptCanOpenWindowsAutomatically: false,
                    mediaPlaybackRequiresUserGesture: true,
                    mixedContentMode:
                        MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  ),
                  onWebViewCreated: (controller) {
                    _controller = controller;
                  },
                  onLoadStop: (controller, url) {
                    _checkAndExtract();
                  },
                  onReceivedServerTrustAuthRequest:
                      (controller, challenge) async {
                    return ServerTrustAuthResponse(
                        action: ServerTrustAuthResponseAction.PROCEED);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
