import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/dashboard_data.dart';
import '../../services/circular_service.dart';

class CircularTabs extends StatefulWidget {
  final List<CircularItem> vipCirculars;
  final List<CircularItem> fomoCirculars;

  const CircularTabs({
    Key? key,
    required this.vipCirculars,
    required this.fomoCirculars,
  }) : super(key: key);

  @override
  State<CircularTabs> createState() => _CircularTabsState();
}

class _CircularTabsState extends State<CircularTabs> {
  Future<void> _handleCircularTap(BuildContext context, CircularItem item) async {
    // If the item has already been confirmed as unavailable/withdrawn, show explanation directly
    if (item.isUnavailable) {
      CircularService.showUnavailableDialog(context, item);
      return;
    }

    // Display non-blocking pre-flight progress indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          elevation: 8,
          margin: EdgeInsets.all(32),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Accessing document from MetNet...',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final status = await CircularService.openOrDownloadCircular(context, item);

    // Dismiss loading dialog safely
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!context.mounted) return;

    setState(() {});

    switch (status) {
      case CircularStatus.success:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening circular in PDF Viewer...'),
            duration: Duration(seconds: 2),
          ),
        );
        break;

      case CircularStatus.unavailable:
        CircularService.showUnavailableDialog(context, item);
        break;

      case CircularStatus.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open document locally.'),
            action: SnackBarAction(
              label: 'Copy Link',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: item.link));
              },
            ),
          ),
        );
        break;
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
        final isUnavailable = item.isUnavailable;
        final isCached = item.cachedPath != null;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Icon(
            isUnavailable ? Icons.warning_amber_rounded : icon,
            color: isUnavailable ? Colors.orangeAccent : iconColor,
          ),
          title: Text(
            item.title.isNotEmpty ? item.title : 'Untitled Circular',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isUnavailable ? Theme.of(context).disabledColor : null,
              decoration: isUnavailable ? TextDecoration.lineThrough : null,
            ),
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
                Expanded(
                  child: Text(
                    isUnavailable
                        ? '• ⚠️ Withdrawn on Portal'
                        : (isCached ? '• 💾 Offline Ready' : '• Tap to view / download'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isUnavailable || isCached ? FontWeight.w600 : FontWeight.normal,
                      color: isUnavailable
                          ? Colors.orangeAccent
                          : (isCached
                              ? Colors.greenAccent
                              : Theme.of(context).colorScheme.primary.withOpacity(0.8)),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          trailing: IconButton(
            icon: Icon(
              isUnavailable
                  ? Icons.info_outline
                  : (isCached ? Icons.check_circle_outline : Icons.download_for_offline_outlined),
              size: 20,
              color: isUnavailable
                  ? Colors.orangeAccent
                  : (isCached ? Colors.greenAccent : null),
            ),
            tooltip: isUnavailable
                ? 'Notice Withdrawn'
                : (isCached ? 'Available Offline' : 'Download / View'),
            onPressed: () => _handleCircularTap(context, item),
          ),
          onTap: () => _handleCircularTap(context, item),
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
                text: 'VIP Circulars (${widget.vipCirculars.length})',
              ),
              Tab(
                icon: const Icon(Icons.article, color: Colors.lightBlueAccent),
                text: 'Other Notices (${widget.fomoCirculars.length})',
              ),
            ],
          ),
          SizedBox(
            height: 340,
            child: TabBarView(
              children: [
                _buildList(
                  context,
                  widget.vipCirculars,
                  Icons.star,
                  Colors.amber,
                  'No VIP circulars found in the last 30 days.',
                ),
                _buildList(
                  context,
                  widget.fomoCirculars,
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
