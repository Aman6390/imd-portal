import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-App Authenticated MetNet WebView with Desktop Mode Support.
/// Loads the full desktop MetNet portal (welcome.php) with desktop User-Agent,
/// ensuring frameset layouts, modals, and password-change prompts render accurately.
/// Gives user full control via [ Done / Sync ] and a Desktop/Mobile toggle.
class NoticeResolverWebView extends StatefulWidget {
  final String username;
  final String password;
  final String noticeType; // 'password', 'email', 'notice'

  const NoticeResolverWebView({
    Key? key,
    required this.username,
    required this.password,
    this.noticeType = 'notice',
  }) : super(key: key);

  @override
  State<NoticeResolverWebView> createState() => _NoticeResolverWebViewState();
}

class _NoticeResolverWebViewState extends State<NoticeResolverWebView> {
  static const String desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
  static const String mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

  late final WebViewController _controller;
  bool _isLoading = true;
  String _currentUrl = '';
  bool _dashboardReached = false;
  bool _isDesktopMode = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_isDesktopMode ? desktopUserAgent : mobileUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
            _checkDashboardNavigation(url);
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            _checkDashboardNavigation(url);
            _applyDesktopViewport();
            _attemptAutoLogin(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://metnet.imd.gov.in/Welcome_to_Intra-IMD/welcome.php'));
  }

  void _applyDesktopViewport() {
    if (_isDesktopMode) {
      final js = '''
        (function() {
          var meta = document.querySelector('meta[name="viewport"]');
          if (!meta) {
            meta = document.createElement('meta');
            meta.name = 'viewport';
            document.getElementsByTagName('head')[0].appendChild(meta);
          }
          meta.content = 'width=1280, initial-scale=0.35, user-scalable=yes, maximum-scale=3.0, minimum-scale=0.2';
        })();
      ''';
      _controller.runJavaScript(js);
    }
  }

  void _toggleDesktopMode() {
    setState(() {
      _isDesktopMode = !_isDesktopMode;
    });
    _controller.setUserAgent(_isDesktopMode ? desktopUserAgent : mobileUserAgent);
    if (_isDesktopMode) {
      _controller.loadRequest(Uri.parse('https://metnet.imd.gov.in/Welcome_to_Intra-IMD/welcome.php'));
    } else {
      _controller.loadRequest(Uri.parse('https://metnet.imd.gov.in/phps/left1.php'));
    }
  }

  bool _isDashboardUrl(String url) {
    return url.contains('main2.php') ||
        url.contains('leave_1.php') ||
        url.contains('circulars_display_2.php');
  }

  void _checkDashboardNavigation(String url) {
    if (_isDashboardUrl(url)) {
      if (!_dashboardReached) {
        setState(() {
          _dashboardReached = true;
        });
      }
    }
  }

  void _attemptAutoLogin(String url) {
    final js = '''
      (function() {
        function tryFill(doc) {
          if (!doc) return false;
          var userField = doc.querySelector('input[name="login_username"]') || doc.querySelector('input#username');
          var passField = doc.querySelector('input[name="password"]') || doc.querySelector('input#password');
          var submitBtn = doc.querySelector('input[type="submit"]') || doc.querySelector('button[type="submit"]');
          if (userField && passField) {
            if (!userField.value || userField.value === 'username') {
              userField.value = "${widget.username}";
            }
            if (!passField.value || passField.value === 'password') {
              passField.value = "${widget.password}";
            }
            if (submitBtn && userField.value === "${widget.username}" && passField.value === "${widget.password}") {
              submitBtn.click();
              return true;
            }
          }
          return false;
        }

        if (!tryFill(document)) {
          var frames = document.querySelectorAll('iframe');
          for (var i = 0; i < frames.length; i++) {
            try {
              var fDoc = frames[i].contentDocument || frames[i].contentWindow.document;
              if (tryFill(fDoc)) break;
            } catch(e) {}
          }
        }
      })();
    ''';
    _controller.runJavaScript(js);
  }

  @override
  Widget build(BuildContext context) {
    final isPasswordMode = widget.noticeType == 'password';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPasswordMode ? 'MetNet Password Update' : 'MetNet Portal',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              isPasswordMode
                  ? 'Change password below, then tap Done / Sync'
                  : (_isDesktopMode ? 'Desktop Site View' : 'Mobile View'),
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isDesktopMode ? Icons.desktop_windows : Icons.phone_android),
            tooltip: _isDesktopMode ? 'Switch to Mobile View' : 'Switch to Desktop Site View',
            onPressed: _toggleDesktopMode,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Page',
            onPressed: () => _controller.reload(),
          ),
          TextButton.icon(
            icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            label: const Text(
              'Done / Sync',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
          if (isPasswordMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.amber.shade900,
                child: Row(
                  children: [
                    const Icon(Icons.vpn_key_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '💡 Tip: Tap [SKIP NOW] below to keep current password, or [PROCEED] to change it.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        'DONE',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_dashboardReached)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade800,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 16),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '🟢 Dashboard reached! All notices cleared?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        'SYNC NOW',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
