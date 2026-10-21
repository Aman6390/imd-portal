import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/dashboard_data.dart';

class CircularTabs extends StatelessWidget {
  final List<CircularItem> vipCirculars;
  final List<CircularItem> fomoCirculars;

  const CircularTabs({
    Key? key,
    required this.vipCirculars,
    required this.fomoCirculars,
  }) : super(key: key);

  Future<void> _launchUrl(BuildContext context, String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    try {
      final cleanUrl = Uri.encodeFull(trimmed);
      final uri = Uri.parse(cleanUrl);

      bool launched = false;

      // Attempt 1: Try launching in external application (Browser, Drive PDF Viewer, Adobe)
      try {
        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}

      // Attempt 2: If external launch didn't succeed, fallback to in-app webview
      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);
        } catch (_) {}
      }

      // Attempt 3: Platform default mode
      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (_) {}
      }

      if (!launched && context.mounted) {
        Clipboard.setData(ClipboardData(text: trimmed));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open link directly. Copied link to clipboard!'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Clipboard.setData(ClipboardData(text: trimmed));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot launch link ($e). Copied to clipboard!'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Widget _buildList(
    BuildContext context,
    List<CircularItem> items,
    IconData icon,
    Color iconColor,
    String emptyMessage,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Theme.of(context).dividerColor.withOpacity(0.2),
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Icon(icon, color: iconColor),
          title: Text(
            item.title.isNotEmpty ? item.title : 'Untitled Circular',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                Text(
                  'Uploaded: ${item.date.isNotEmpty ? item.date : "Recent"}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• Tap to view / download',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.download_for_offline_outlined, size: 20),
            tooltip: 'Download / View',
            onPressed: () => _launchUrl(context, item.link),
          ),
          onTap: () => _launchUrl(context, item.link),
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: item.link));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Circular link copied to clipboard!'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(
                icon: const Icon(Icons.star, color: Colors.amber),
                text: 'VIP Circulars (${vipCirculars.length})',
              ),
              Tab(
                icon: const Icon(Icons.article, color: Colors.lightBlueAccent),
                text: 'Other Notices (${fomoCirculars.length})',
              ),
            ],
          ),
          SizedBox(
            height: 340,
            child: TabBarView(
              children: [
                _buildList(
                  context,
                  vipCirculars,
                  Icons.star,
                  Colors.amber,
                  'No VIP circulars found in the last 30 days.',
                ),
                _buildList(
                  context,
                  fomoCirculars,
                  Icons.article,
                  Colors.lightBlueAccent,
                  'No other circulars found in the last 30 days.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
