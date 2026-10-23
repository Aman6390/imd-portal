import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/ai_circular_entry.dart';
import '../../models/dashboard_data.dart';
import '../../services/ai_circular_service.dart';
import '../../services/circular_service.dart';
import '../../services/storage_service.dart';

class _TopicBadge {
  final String label;
  final Color color;
  const _TopicBadge(this.label, this.color);
}

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
  Set<String> _bookmarkedUrls = {};
  Set<String> _expandedSummaryUrls = {};
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    AiCircularService.onIndexUpdated.addListener(_onAiUpdated);
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = await StorageService.loadBookmarkedUrls();
    if (mounted) {
      setState(() {
        _bookmarkedUrls = bookmarks;
      });
    }
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

  List<_TopicBadge> _getTopicBadges(CircularItem item, AiCircularEntry? aiMeta) {
    final t = item.title.toLowerCase();
    final reasons = (aiMeta?.vipReasons ?? []).map((r) => r.toLowerCase()).toList();
    final List<_TopicBadge> badges = [];

    bool hasKeyword(List<String> keywords) {
      return keywords.any((k) => t.contains(k) || reasons.any((r) => r.contains(k)));
    }

    // 1. Transfer / Posting
    if (hasKeyword(['transfer', 'posting', 'working arrangement', 'lacd', 'station', 'स्थानांतरण', 'पदस्थापना'])) {
      badges.add(const _TopicBadge('🚚 Transfer', Color(0xFF38BDF8)));
    }

    // 2. Promotion / MACP
    if (hasKeyword(['promotion', 'macp', 'modified acp', 'financial upgradation', 'पदोन्नति'])) {
      badges.add(const _TopicBadge('📈 Promotion / MACP', Color(0xFF34D399)));
    }

    // 3. Seniority List
    if (hasKeyword(['seniority', 'gradation', 'वरिष्ठता'])) {
      badges.add(const _TopicBadge('📜 Seniority', Color(0xFFA78BFA)));
    }

    // 4. Training / WMO
    if (hasKeyword(['training', 'course', 'wmo', 'fellowship', 'प्रशिक्षण'])) {
      badges.add(const _TopicBadge('🎓 Training', Color(0xFF2DD4BF)));
    }

    // 5. Exam / LDCE
    if (hasKeyword(['ldce', 'exam', 'examination', 'cutoff', 'परीक्षा'])) {
      badges.add(const _TopicBadge('📝 Exam / LDCE', Color(0xFFFB923C)));
    }

    // 6. Active Deadline / Action Required
    if (aiMeta?.actionRequired == true ||
        hasKeyword(['deadline', 'representation', 'objection', 'calling for', 'proforma', 'last date', 'by 1700', 'अभ्यावेदन', 'आपत्ति', 'आवेदन'])) {
      badges.add(const _TopicBadge('⏳ Active Deadline', Color(0xFFFBBF24)));
    }

    return badges;
  }

  List<CircularItem> _applyFilter(List<CircularItem> list) {
    if (_selectedFilter == 'All') return list;
    if (_selectedFilter == '🔖 Bookmarked') {
      return list.where((item) => _bookmarkedUrls.contains(item.link)).toList();
    }
    return list.where((item) {
      final aiMeta = AiCircularService.getMetadata(item.link, item.title);
      final cadre = (aiMeta?.targetCadre ?? '').toLowerCase();
      final title = item.title.toLowerCase();
      final reasons = (aiMeta?.vipReasons ?? []).map((r) => r.toLowerCase()).toList();

      bool hasKeyword(List<String> keywords) {
        return keywords.any((k) => title.contains(k) || reasons.any((r) => r.contains(k)));
      }

      switch (_selectedFilter) {
        case '⏳ Active Deadline':
          return aiMeta?.actionRequired == true ||
              hasKeyword(['deadline', 'representation', 'objection', 'apply', 'proforma', 'calling for', 'last date', 'by 1700', 'अभ्यावेदन', 'आपत्ति', 'action required']);
        case '🚚 Transfers':
          return hasKeyword(['transfer', 'posting', 'working arrangement', 'lacd', 'station', 'स्थानांतरण', 'पदस्थापना']);
        case '📈 Promotions':
          return hasKeyword(['promotion', 'macp', 'modified acp', 'financial upgradation', 'पदोन्नति']);
        case '📜 Seniority':
          return hasKeyword(['seniority', 'gradation', 'वरिष्ठता']);
        case '🎓 Training':
          return hasKeyword(['training', 'course', 'wmo', 'fellowship', 'प्रशिक्षण']);
        case '📝 Exams':
          return hasKeyword(['ldce', 'exam', 'examination', 'cutoff', 'परीक्षा']);
        case '⛅ Met B':
          return cadre.contains('met b') || title.contains('met b') || title.contains('met-b');
        case '🌤️ Met A':
          return cadre.contains('met a') || title.contains('met a') || title.contains('met-a');
        case '🔬 SA':
          return cadre.contains('sa') ||
              cadre.contains('scientific assistant') ||
              title.contains('scientific assistant');
        case '🧪 Scientists':
          return cadre.contains('scientist') ||
              cadre.contains('sc-') ||
              cadre.contains('sc.') ||
              title.contains('scientist') ||
              title.contains('sc-') ||
              title.contains('sc.');
        case '📋 Clerks':
          return cadre.contains('clerk') ||
              cadre.contains('udc') ||
              cadre.contains('ldc') ||
              title.contains('clerk') ||
              title.contains('udc') ||
              title.contains('ldc') ||
              title.contains('लिपिक');
        case '🛠️ Tech':
          return cadre.contains('engineer') ||
              cadre.contains('tech') ||
              title.contains('workshop') ||
              title.contains('instrumentation') ||
              title.contains('telecom') ||
              title.contains('अभियंता') ||
              title.contains('तकनीकी');
        case '👔 SO':
          return cadre.contains('so-') ||
              cadre.contains('so ') ||
              cadre.contains('scientific officer') ||
              title.contains('so-') ||
              title.contains('s.o.-') ||
              title.contains('scientific officer');
        case '🧹 MTS':
          return cadre.contains('mts') ||
              cadre.contains('attendant') ||
              title.contains('mts') ||
              title.contains('peon') ||
              title.contains('परिचारक');
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildFilterChips() {
    final filters = [
      'All',
      '⏳ Active Deadline',
      '🚚 Transfers',
      '📈 Promotions',
      '📜 Seniority',
      '🎓 Training',
      '📝 Exams',
      '⛅ Met B',
      '🌤️ Met A',
      '🔬 SA',
      '🧪 Scientists',
      '📋 Clerks',
      '🛠️ Tech',
      '👔 SO',
      '🧹 MTS',
      '🔖 Bookmarked',
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return ChoiceChip(
            label: Text(
              filter,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            selected: isSelected,
            selectedColor: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            visualDensity: VisualDensity.compact,
            onSelected: (selected) {
              setState(() {
                _selectedFilter = selected ? filter : 'All';
              });
            },
          );
        },
      ),
    );
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
    final isBookmarked = _bookmarkedUrls.contains(item.link);
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
                leading: Icon(
                  isBookmarked ? Icons.bookmark_remove_rounded : Icons.bookmark_add_rounded,
                  color: isBookmarked ? Colors.amber : Colors.tealAccent,
                ),
                title: Text(
                  isBookmarked ? 'Remove from Bookmarks' : 'Save to Bookmarks',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final newState = await StorageService.toggleBookmark(item.link);
                  setState(() {
                    if (newState) {
                      _bookmarkedUrls.add(item.link);
                    } else {
                      _bookmarkedUrls.remove(item.link);
                    }
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(newState ? '🔖 Saved to Bookmarks!' : 'Removed from Bookmarks'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
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

  Widget _buildCollapsedSummary(
    BuildContext context,
    CircularItem item,
    AiCircularEntry aiMeta,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 12, color: Colors.amber.shade400),
              const SizedBox(width: 5),
              Text(
                'IN BRIEF',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                'Tap to expand',
                style: TextStyle(
                  fontSize: 9.5,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            aiMeta.summaryEn,
            style: TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedSummary(
    BuildContext context,
    CircularItem item,
    AiCircularEntry aiMeta,
  ) {
    final breakdown = AiCircularService.getPlainLanguageBreakdown(aiMeta, item.title);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, size: 14, color: Colors.blueAccent),
              const SizedBox(width: 5),
              Text(
                'PLAIN WORDS EXPLANATION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                'Tap to collapse',
                style: TextStyle(
                  fontSize: 9.5,
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            breakdown['meaning'] ?? aiMeta.summaryEn,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('👉 ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Text(
                  breakdown['action'] ?? '',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: aiMeta.actionRequired
                        ? Colors.amberAccent
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          if (breakdown['jargon'] != null && breakdown['jargon']!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡 ', style: TextStyle(fontSize: 10)),
                  Expanded(
                    child: Text(
                      breakdown['jargon']!,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            height: 28,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
              label: const Text('Open Original Document', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _handleCircularTap(context, item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<CircularItem> items,
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
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Theme.of(context).dividerColor.withOpacity(0.2),
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final isUnavailable = item.isUnavailable;
        final isCached = item.cachedPath != null;
        final isBookmarked = _bookmarkedUrls.contains(item.link);
        final isSummaryExpanded = _expandedSummaryUrls.contains(item.link);
        final aiMeta = AiCircularService.getMetadata(item.link, item.title);

        final cadre = aiMeta?.targetCadre ?? '';
        final cadreColor = _getCadreColor(cadre);
        final cadreEmoji = _getCadreEmoji(cadre);
        final topicBadges = _getTopicBadges(item, aiMeta);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          // Leading star icon removed as requested to maximize horizontal reading space
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cadre, Topic, Action, and Withdrawn Badges
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  // 1. Cadre Badge
                  if (cadre.isNotEmpty)
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

                  // 2. Specific Topic & Deadline Badges
                  for (final badge in topicBadges)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: badge.color.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: badge.color.withOpacity(0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        badge.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badge.color,
                        ),
                      ),
                    ),

                  // 3. Withdrawn Badge (if unavailable)
                  if (isUnavailable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.orangeAccent.withOpacity(0.5),
                          width: 0.8,
                        ),
                      ),
                      child: const Text(
                        '⚠️ Withdrawn',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orangeAccent,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),

              // Notice Title (Full width without leading icon)
              Text(
                item.title.isNotEmpty ? item.title : 'Untitled Circular',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: isUnavailable ? Theme.of(context).disabledColor : null,
                  decoration: isUnavailable ? TextDecoration.lineThrough : null,
                ),
              ),

              // Interactive Expandable Summary Tab
              if (aiMeta != null && aiMeta.summaryEn.isNotEmpty) ...[
                const SizedBox(height: 5),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() {
                      if (isSummaryExpanded) {
                        _expandedSummaryUrls.remove(item.link);
                      } else {
                        _expandedSummaryUrls.add(item.link);
                      }
                    });
                  },
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: isSummaryExpanded
                        ? _buildExpandedSummary(context, item, aiMeta)
                        : _buildCollapsedSummary(context, item, aiMeta),
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
                        ? '• Withdrawn on Portal'
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bookmark / Favorite Button
              IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 21,
                  color: isBookmarked ? Colors.amber : Theme.of(context).colorScheme.outline,
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: isBookmarked ? 'Bookmarked' : 'Add to bookmarks',
                onPressed: () async {
                  final newState = await StorageService.toggleBookmark(item.link);
                  setState(() {
                    if (newState) {
                      _bookmarkedUrls.add(item.link);
                    } else {
                      _bookmarkedUrls.remove(item.link);
                    }
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(newState ? '🔖 Notice bookmarked!' : 'Bookmark removed'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
              // Download / View Button
              IconButton(
                icon: Icon(
                  isUnavailable
                      ? Icons.info_outline
                      : (isCached ? Icons.check_circle_outline : Icons.download_for_offline_outlined),
                  size: 21,
                  color: isUnavailable
                      ? Colors.orangeAccent
                      : (isCached ? Colors.greenAccent : null),
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: isUnavailable
                    ? 'Notice Withdrawn'
                    : (isCached ? 'Available Offline' : 'Download / View'),
                onPressed: () => _handleCircularTap(context, item),
              ),
            ],
          ),
          onTap: () => _handleCircularTap(context, item),
          onLongPress: () => _showCircularOptionsSheet(context, item, aiMeta),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredVip = _applyFilter(widget.vipCirculars);

    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(
                icon: const Icon(Icons.auto_awesome_rounded, color: Colors.amber),
                text: 'For You (${widget.vipCirculars.length})',
              ),
              Tab(
                icon: const Icon(Icons.article_outlined, color: Colors.lightBlueAccent),
                text: 'Other Notices (${widget.fomoCirculars.length})',
              ),
            ],
          ),
          SizedBox(
            height: 400,
            child: TabBarView(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    _buildFilterChips(),
                    const SizedBox(height: 4),
                    Expanded(
                      child: _buildList(
                        context,
                        filteredVip,
                        _selectedFilter == 'All'
                            ? 'No circulars found for you in the last 30 days.'
                            : 'No circulars found matching "$_selectedFilter".',
                      ),
                    ),
                  ],
                ),
                _buildList(
                  context,
                  widget.fomoCirculars,
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
