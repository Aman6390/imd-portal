import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-App Authenticated MetNet WebView.
/// Automatically handles login and allows the user to read, acknowledge,
/// or dismiss any interstitial notice, unread inbox message, or duty roster.
/// When the user reaches or returns to main2.php, it automatically closes
/// and notifies the caller to trigger an immediate dashboard sync.
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
            if (_isDashboardUrl(request.url)) {
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://metnet.imd.gov.in/phps/left1.php'));
  }

  bool _isDashboardUrl(String url) {
    return url.contains('main2.php') || url.contains('leave_1.php') || url.contains('circulars_display_2.php');
  }

  void _checkDashboardNavigation(String url) {
    if (_isDashboardUrl(url) && mounted) {
      Navigator.of(context).pop(true);
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
            // If submit button or login button exists, click it
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
              'Read/Dismiss notice to continue',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: () => _controller.reload(),
          ),
          TextButton.icon(
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('Done / Sync', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(context).pop(true),
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
        ],
      ),
    );
  }
}
