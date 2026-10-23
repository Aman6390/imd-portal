import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-App Authenticated MetNet WebView.
/// Automatically handles login and allows the user to read, acknowledge,
/// or dismiss any interstitial notice, unread inbox message, or change their password.
/// Gives user full control via [ Done / Sync ] with non-intrusive status banners.
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
  late final WebViewController _controller;
  bool _isLoading = true;
  String _currentUrl = '';
  bool _dashboardReached = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
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
      if (!_dashboardReached) {
        setState(() {
          _dashboardReached = true;
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
    final isPasswordMode = widget.noticeType == 'password';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPasswordMode ? 'MetNet Password Update' : 'MetNet Intranet Viewer',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              isPasswordMode
                  ? 'Change password below, then tap Done / Sync'
                  : 'Clear emails/notices, then tap Done / Sync',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
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
                        'Change your password on MetNet, then tap [Done / Sync] above.',
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
