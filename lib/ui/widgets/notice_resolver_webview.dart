import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-App Authenticated MetNet WebView.
/// Automatically handles login and allows the user to read, acknowledge,
/// or dismiss any interstitial notice, unread inbox message, or duty roster.
/// Includes a 4-second settling delay to ensure sequential unread emails or prompts
/// don't get interrupted if MetNet briefly redirects to main2.php before showing the next one.
class NoticeResolverWebView extends StatefulWidget {
  final String username;
  final String password;

  const NoticeResolverWebView({
    Key? key,
    required this.username,
    required this.password,
  }) : super(key: key);

  @override
  State<NoticeResolverWebView> createState() => _NoticeResolverWebViewState();
}

class _NoticeResolverWebViewState extends State<NoticeResolverWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _currentUrl = '';
  Timer? _settlingTimer;
  int _countdownSeconds = 4;
  bool _isSettling = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  @override
  void dispose() {
    _settlingTimer?.cancel();
    super.dispose();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
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
            _attemptAutoLogin(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow navigation to all pages freely so multiple sequential prompts can be handled
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://metnet.imd.gov.in/phps/left1.php'));
  }

  bool _isDashboardUrl(String url) {
    return url.contains('main2.php') ||
        url.contains('leave_1.php') ||
        url.contains('circulars_display_2.php');
  }

  void _checkDashboardNavigation(String url) {
    if (_isDashboardUrl(url)) {
      if (!_isSettling) {
        setState(() {
          _isSettling = true;
          _countdownSeconds = 4;
        });
        _settlingTimer?.cancel();
        _settlingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          if (_countdownSeconds <= 1) {
            timer.cancel();
            Navigator.of(context).pop(true);
          } else {
            setState(() {
              _countdownSeconds--;
            });
          }
        });
      }
    } else {
      // If MetNet redirected away from the dashboard (e.g. to a second email or notice),
      // cancel the settling timer immediately so the user can resolve the remaining prompts!
      if (_isSettling) {
        _settlingTimer?.cancel();
        _settlingTimer = null;
        setState(() {
          _isSettling = false;
        });
      }
    }
  }

  void _attemptAutoLogin(String url) {
    // If on login or left page, auto-fill credentials
    if (url.contains('left1.php') || url.contains('login') || url.contains('welcome')) {
      final js = '''
        (function() {
          var userField = document.querySelector('input[name="login_username"]') || document.querySelector('input#username');
          var passField = document.querySelector('input[name="password"]') || document.querySelector('input#password');
          var form = document.querySelector('form');
          if (userField && passField) {
            userField.value = "${widget.username}";
            passField.value = "${widget.password}";
            var submitBtn = document.querySelector('input[type="submit"]') || document.querySelector('button[type="submit"]');
            if (submitBtn) {
              submitBtn.click();
            } else if (form) {
              form.submit();
            }
          }
        })();
      ''';
      _controller.runJavaScript(js);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MetNet Intranet Viewer', style: TextStyle(fontSize: 16)),
            Text(
              'Clear emails/notices or change password',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
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
              _settlingTimer?.cancel();
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
          if (_isSettling)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '🟢 Dashboard reached! Settling in ${_countdownSeconds}s... (clearing remaining prompts)',
                        style: const TextStyle(
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
                      onPressed: () {
                        _settlingTimer?.cancel();
                        Navigator.of(context).pop(true);
                      },
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
