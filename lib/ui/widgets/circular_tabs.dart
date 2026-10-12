import 'package:flutter/material.dart';
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
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open link: $url')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening link: $e')),
      );
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            'Uploaded: ${item.date.isNotEmpty ? item.date : "Unknown"}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          trailing: const Icon(Icons.open_in_new, size: 16),
          onTap: () => _launchUrl(context, item.link),
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
            tabs: const [
              Tab(
                icon: Icon(Icons.star, color: Colors.amber),
                text: 'VIP Circulars',
              ),
              Tab(
                icon: Icon(Icons.article, color: Colors.lightBlueAccent),
                text: 'Other Notifications',
              ),
            ],
          ),
          SizedBox(
            height: 320,
            child: TabBarView(
              children: [
                _buildList(
                  context,
                  vipCirculars,
                  Icons.star,
                  Colors.amber,
                  'No VIP circulars found.',
                ),
                _buildList(
                  context,
                  fomoCirculars,
                  Icons.article,
                  Colors.lightBlueAccent,
                  'No other notifications.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
