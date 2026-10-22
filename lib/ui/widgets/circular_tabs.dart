import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/ai_circular_entry.dart';
import '../../models/dashboard_data.dart';
import '../../services/ai_circular_service.dart';
import '../../services/circular_service.dart';
import '../../services/storage_service.dart';

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
  @override
  void initState() {
    super.initState();
    AiCircularService.onIndexUpdated.addListener(_onAiUpdated);
  }

  @override
  void dispose() {
    AiCircularService.onIndexUpdated.removeListener(_onAiUpdated);
    super.dispose();
  }

  void _onAiUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

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

  Color _getCadreColor(String cadre) {
    final c = cadre.toLowerCase();
    if (c.contains('scientist') || c.contains('sc-') || c.contains('sc.')) {
      return Colors.purple;
    } else if (c.contains('scientific officer') || c.contains('so-') || c.contains('so ')) {
      return Colors.deepPurpleAccent;
    } else if (c.contains('met a') || c.contains('meteorologist a')) {
      return Colors.cyan;
    } else if (c.contains('met b') || c.contains('meteorologist b')) {
      return Colors.teal;
    } else if (c.contains('scientific assistant') || c.contains('sa')) {
      return Colors.blue;
    } else if (c.contains('clerk') || c.contains('udc') || c.contains('ldc')) {
      return Colors.deepOrangeAccent;
    } else if (c.contains('mts') || c.contains('attendant')) {
      return Colors.orange;
    } else if (c.contains('engineering') || c.contains('tech')) {
      return Colors.indigo;
    } else if (c.contains('finance') || c.contains('account')) {
      return Colors.green;
    } else if (c.contains('administrative')) {
      return Colors.teal;
    }
    return Colors.blueGrey;
  }

  String _getCadreEmoji(String cadre) {
    final c = cadre.toLowerCase();
    if (c.contains('scientist') || c.contains('sc-')) {
      return '🧪 ';
    } else if (c.contains('scientific officer') || c.contains('so-') || c.contains('so ')) {
      return '🧭 ';
    } else if (c.contains('met a')) {
      return '🌤️ ';
    } else if (c.contains('met b')) {
      return '⛅ ';
    } else if (c.contains('scientific assistant') || c.contains('sa')) {
      return '🔬 ';
    } else if (c.contains('clerk') || c.contains('udc') || c.contains('ldc')) {
      return '📑 ';
    } else if (c.contains('mts') || c.contains('attendant')) {
      return '👥 ';
    } else if (c.contains('engineering') || c.contains('tech')) {
      return '⚙️ ';
    } else if (c.contains('finance') || c.contains('account')) {
      return '💼 ';
    } else if (c.contains('administrative')) {
      return '📝 ';
    }
    return '🏛️ ';
  }

  void _showCircularOptionsSheet(BuildContext context, CircularItem item, AiCircularEntry? aiMeta) async {
    final isUnlocked = await StorageService.isDiagnosticsUnlocked();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Uploaded: ${item.date.isNotEmpty ? item.date : "Recent"}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // AI Semantic Details Box
              if (aiMeta != null)
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.psychology_outlined, size: 20, color: Colors.blueAccent),
                          const SizedBox(width: 8),
                          Text(
                            'AI Semantic Analysis',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: aiMeta.source == 'gemini'
                                  ? Colors.green.withOpacity(0.15)
                                  : Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              aiMeta.source == 'gemini' ? 'Gemini 1.5 Cloud' : 'On-Device Engine',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: aiMeta.source == 'gemini' ? Colors.green : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '🤖 ${aiMeta.summaryEn}',
                        style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text('Target Cadre: ${aiMeta.targetCadre}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          Text('• Action Required: ${aiMeta.actionRequired ? "Yes" : "No"}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: aiMeta.actionRequired ? Colors.amberAccent : null,
                              )),
                          Text('• VIP: ${aiMeta.isVip ? "Yes" : "No"}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: aiMeta.isVip ? Colors.amber : null,
                              )),
                        ],
                      ),
                    ],
                  ),
                ),

              ListTile(
                leading: const Icon(Icons.open_in_new, color: Colors.blueAccent),
                title: const Text('Open / Download Document',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Download or launch in default PDF viewer',
                    style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleCircularTap(context, item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.grey),
                title: const Text('Copy Direct Link',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: item.link));
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Circular link copied to clipboard!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              if (isUnlocked)
                ListTile(
                  leading: const Icon(Icons.document_scanner_rounded, color: Colors.purpleAccent),
                  title: const Text('Inspect Scanned Text (Devanagari OCR)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('View recognized text & keyword matches',
                      style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    CircularService.inspectCircularOcr(context, item);
                  },
                ),
            ],
          ),
        ),
      ),
    );
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
              fontSize: 13,
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
        final aiMeta = AiCircularService.getMetadata(item.link, item.title);

        final cadre = aiMeta?.targetCadre ?? '';
        final cadreColor = _getCadreColor(cadre);
        final cadreEmoji = _getCadreEmoji(cadre);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          leading: Icon(
            isUnavailable
                ? Icons.warning_amber_rounded
                : (aiMeta?.isVip ?? false ? Icons.stars_rounded : icon),
            color: isUnavailable
                ? Colors.orangeAccent
                : (aiMeta?.isVip ?? false ? Colors.amber : iconColor),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cadre & Action Badges
              if (aiMeta != null && cadre.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: cadreColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: cadreColor.withOpacity(0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '$cadreEmoji$cadre',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: cadreColor,
                        ),
                      ),
                    ),
                    if (aiMeta.actionRequired)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.amberAccent.withOpacity(0.5),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          '⚠️ Action Required',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
              ],

              // Circular Title
              Text(
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

              // AI Semantic Summary Pill
              if (aiMeta != null && aiMeta.summaryEn.isNotEmpty) ...[
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🤖 ', style: TextStyle(fontSize: 11)),
                      Expanded(
                        child: Text(
                          aiMeta.summaryEn,
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
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
          onLongPress: () => _showCircularOptionsSheet(context, item, aiMeta),
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
