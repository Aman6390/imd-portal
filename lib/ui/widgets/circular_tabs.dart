import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/ai_circular_entry.dart';
import '../../models/dashboard_data.dart';
import '../../services/ai_circular_service.dart';
import '../../services/circular_service.dart';
import '../../services/storage_service.dart';
import 'glass_container.dart';

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
      badges.add(const _TopicBadge('Transfer', Color(0xFF007AFF)));
    }

    // 2. Promotion / MACP
    if (hasKeyword(['promotion', 'macp', 'modified acp', 'financial upgradation', 'पदोन्नति'])) {
      badges.add(const _TopicBadge('Promotion', Color(0xFF34C759)));
    }

    // 3. Seniority List
    if (hasKeyword(['seniority', 'gradation', 'वरिष्ठता'])) {
      badges.add(const _TopicBadge('Seniority', Color(0xFF5856D6)));
    }

    // 4. Training / WMO
    if (hasKeyword(['training', 'course', 'wmo', 'fellowship', 'प्रशिक्षण'])) {
      badges.add(const _TopicBadge('Training', Color(0xFF30B0C7)));
    }

    // 5. Exam / LDCE
    if (hasKeyword(['ldce', 'exam', 'examination', 'cutoff', 'परीक्षा'])) {
      badges.add(const _TopicBadge('Exam / LDCE', Color(0xFFFF9500)));
    }

    // 6. Active Deadline / Action Required
    if (aiMeta?.actionRequired == true ||
        hasKeyword(['deadline', 'representation', 'objection', 'calling for', 'proforma', 'last date', 'by 1700', 'अभ्यावेदन', 'आपत्ति', 'आवेदन'])) {
      badges.add(const _TopicBadge('Action Required', Color(0xFFFF3B30)));
    }

    return badges;
  }

  List<CircularItem> _applyFilter(List<CircularItem> list) {
    if (_selectedFilter == 'All') return list;
    if (_selectedFilter == 'Bookmarked') {
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
        case 'Deadlines':
          return aiMeta?.actionRequired == true ||
              hasKeyword(['deadline', 'representation', 'objection', 'apply', 'proforma', 'calling for', 'last date', 'by 1700', 'अभ्यावेदन', 'आपत्ति', 'action required']);
        case 'Transfers':
          return hasKeyword(['transfer', 'posting', 'working arrangement', 'lacd', 'station', 'स्थानांतरण', 'पदस्थापना']);
        case 'Promotions':
          return hasKeyword(['promotion', 'macp', 'modified acp', 'financial upgradation', 'पदोन्नति']);
        case 'Seniority':
          return hasKeyword(['seniority', 'gradation', 'वरिष्ठता']);
        case 'Training':
          return hasKeyword(['training', 'course', 'wmo', 'fellowship', 'प्रशिक्षण']);
        case 'Exams':
          return hasKeyword(['ldce', 'exam', 'examination', 'cutoff', 'परीक्षा']);
        case 'Met B':
          return cadre.contains('met b') || title.contains('met b') || title.contains('met-b');
        case 'Met A':
          return cadre.contains('met a') || title.contains('met a') || title.contains('met-a');
        case 'Scientific Assistant':
          return cadre.contains('sa') ||
              cadre.contains('scientific assistant') ||
              title.contains('scientific assistant');
        case 'Scientists':
          return cadre.contains('scientist') ||
              cadre.contains('sc-') ||
              cadre.contains('sc.') ||
              title.contains('scientist') ||
              title.contains('sc-') ||
              title.contains('sc.');
        case 'Clerks & Admin':
          return cadre.contains('clerk') ||
              cadre.contains('udc') ||
              cadre.contains('ldc') ||
              title.contains('clerk') ||
              title.contains('udc') ||
              title.contains('ldc') ||
              title.contains('लिपिक');
        case 'Technical':
          return cadre.contains('engineer') ||
              cadre.contains('tech') ||
              title.contains('workshop') ||
              title.contains('instrumentation') ||
              title.contains('telecom') ||
              title.contains('अभियंता') ||
              title.contains('तकनीकी');
        case 'Scientific Officer':
          return cadre.contains('so-') ||
              cadre.contains('so ') ||
              cadre.contains('scientific officer') ||
              title.contains('so-') ||
              title.contains('s.o.-') ||
              title.contains('scientific officer');
        case 'MTS':
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
      'Deadlines',
      'Transfers',
      'Promotions',
      'Seniority',
      'Training',
      'Exams',
      'Met B',
      'Met A',
      'Scientific Assistant',
      'Scientists',
      'Clerks & Admin',
      'Technical',
      'Scientific Officer',
      'MTS',
      'Bookmarked',
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedFilter = isSelected ? 'All' : filter;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF007AFF)
                    : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E5EA)),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF38BDF8).withOpacity(0.6)
                      : Colors.white.withOpacity(isDark ? 0.08 : 0.25),
                  width: 0.8,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? const Color(0xFFE5E5EA) : const Color(0xFF1C1C1E)),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
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
      return const Color(0xFF5856D6); // System Purple
    } else if (c.contains('scientific officer') || c.contains('so-') || c.contains('so ')) {
      return const Color(0xFF007AFF); // System Blue
    } else if (c.contains('met a') || c.contains('meteorologist a')) {
      return const Color(0xFF30B0C7); // System Cyan
    } else if (c.contains('met b') || c.contains('meteorologist b')) {
      return const Color(0xFF34C759); // System Green
    } else if (c.contains('scientific assistant') || c.contains('sa')) {
      return const Color(0xFF0A84FF); // System Electric Blue
    } else if (c.contains('clerk') || c.contains('udc') || c.contains('ldc')) {
      return const Color(0xFFFF9500); // System Orange
    } else if (c.contains('mts') || c.contains('attendant')) {
      return const Color(0xFFFF9F0A); // System Amber
    } else if (c.contains('engineering') || c.contains('tech')) {
      return const Color(0xFF64D2FF); // System Light Blue
    } else if (c.contains('finance') || c.contains('account')) {
      return const Color(0xFF32ADE6);
    }
    return const Color(0xFF8E8E93); // System Gray
  }

  String _getCadreEmoji(String cadre) {
    return ''; // Clean Apple typographic styling without emojis
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2538) : const Color(0xFFF2F5FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF007AFF).withOpacity(0.25),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF007AFF)),
              const SizedBox(width: 6),
              const Text(
                'AI SUMMARY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Color(0xFF007AFF),
                ),
              ),
              const Spacer(),
              Text(
                'View details',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            aiMeta.summaryEn,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? const Color(0xFFE5E5EA) : const Color(0xFF2C2C2E),
              height: 1.35,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2234) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF007AFF).withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded, size: 15, color: Color(0xFF007AFF)),
              const SizedBox(width: 6),
              const Text(
                'EXECUTIVE ANALYSIS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Color(0xFF007AFF),
                ),
              ),
              const Spacer(),
              Text(
                'Collapse',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            breakdown['meaning'] ?? aiMeta.summaryEn,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: aiMeta.actionRequired
                  ? const Color(0xFFFF3B30).withOpacity(0.08)
                  : const Color(0xFF007AFF).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: aiMeta.actionRequired
                    ? const Color(0xFFFF3B30).withOpacity(0.25)
                    : const Color(0xFF007AFF).withOpacity(0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  aiMeta.actionRequired ? Icons.priority_high_rounded : Icons.info_outline_rounded,
                  size: 16,
                  color: aiMeta.actionRequired ? const Color(0xFFFF3B30) : const Color(0xFF007AFF),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    breakdown['action'] ?? '',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: aiMeta.actionRequired
                          ? (isDark ? const Color(0xFFFF6961) : const Color(0xFFD70015))
                          : Theme.of(context).colorScheme.onSurface,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (breakdown['jargon'] != null && breakdown['jargon']!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA).withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 15,
                    color: isDark ? const Color(0xFFFFD60A) : const Color(0xFFB25000),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      breakdown['jargon']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 32,
            child: TextButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
              label: const Text('Open Original Document', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF007AFF),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cadreColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: cadreColor.withOpacity(0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        cadre,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cadreColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),

                  // 2. Specific Topic & Deadline Badges
                  for (final badge in topicBadges)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badge.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: badge.color.withOpacity(0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        badge.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badge.color,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),

                  // 3. Withdrawn Badge (if unavailable)
                  if (isUnavailable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFFF9500).withOpacity(0.4),
                          width: 0.8,
                        ),
                      ),
                      child: const Text(
                        'WITHDRAWN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF9500),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // Notice Title
              Text(
                item.title.isNotEmpty ? item.title : 'Untitled Circular',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  letterSpacing: -0.2,
                  color: isUnavailable ? Theme.of(context).disabledColor : null,
                  decoration: isUnavailable ? TextDecoration.lineThrough : null,
                ),
              ),

              // Interactive Expandable Summary Tab
              if (aiMeta != null && aiMeta.summaryEn.isNotEmpty) ...[
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (isSummaryExpanded) {
                        _expandedSummaryUrls.remove(item.link);
                      } else {
                        _expandedSummaryUrls.add(item.link);
                      }
                    });
                  },
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
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
            padding: const EdgeInsets.only(top: 6.0),
            child: Row(
              children: [
                Text(
                  'Uploaded ${item.date.isNotEmpty ? item.date : "Recent"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isUnavailable
                        ? '• Withdrawn'
                        : (isCached ? '• Offline Ready' : '• Tap to view / download'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isUnavailable || isCached ? FontWeight.w600 : FontWeight.normal,
                      color: isUnavailable
                          ? const Color(0xFFFF9500)
                          : (isCached
                              ? const Color(0xFF34C759)
                              : Theme.of(context).colorScheme.primary.withOpacity(0.85)),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Bookmark / Favorite Micro-Button (Top)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    HapticFeedback.lightImpact();
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
                          content: Text(newState ? 'Notice bookmarked' : 'Bookmark removed'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isBookmarked
                          ? const Color(0xFFFF9500).withOpacity(0.18)
                          : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isBookmarked
                            ? const Color(0xFFFF9500).withOpacity(0.4)
                            : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        size: 19,
                        color: isBookmarked
                            ? const Color(0xFFFF9500)
                            : (isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // 2. Download / View Micro-Button (Bottom)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _handleCircularTap(context, item),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isUnavailable
                          ? const Color(0xFFFF9500).withOpacity(0.14)
                          : (isCached
                              ? const Color(0xFF10B981).withOpacity(0.18)
                              : const Color(0xFF0284C7).withOpacity(0.14)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isUnavailable
                            ? const Color(0xFFFF9500).withOpacity(0.35)
                            : (isCached
                                ? const Color(0xFF10B981).withOpacity(0.4)
                                : const Color(0xFF0284C7).withOpacity(0.3)),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isUnavailable
                            ? Icons.info_outline_rounded
                            : (isCached ? Icons.check_circle_rounded : Icons.arrow_downward_rounded),
                        size: 19,
                        color: isUnavailable
                            ? const Color(0xFFFF9500)
                            : (isCached ? const Color(0xFF10B981) : const Color(0xFF0284C7)),
                      ),
                    ),
                  ),
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Apple iOS 27 Frosted Glass Segmented Control
          GlassContainer(
            borderRadius: 14,
            blur: 16,
            padding: const EdgeInsets.all(3),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderOpacity: 0.16,
            surfaceOpacity: 0.08,
            child: TabBar(
              indicator: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.18) : Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: Colors.white.withOpacity(isDark ? 0.25 : 0.6),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: isDark ? Colors.white : Colors.black,
              unselectedLabelColor: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: -0.2),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
              tabs: [
                Tab(
                  height: 34,
                  text: 'Curated For You (${widget.vipCirculars.length})',
                ),
                Tab(
                  height: 34,
                  text: 'All Notices (${widget.fomoCirculars.length})',
                ),
              ],
            ),
          ),
          SizedBox(
            height: 420,
            child: TabBarView(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    _buildFilterChips(),
                    const SizedBox(height: 6),
                    Expanded(
                      child: _buildList(
                        context,
                        filteredVip,
                        _selectedFilter == 'All'
                            ? 'No circulars found for your cadre in the last 30 days.'
                            : 'No circulars matching "$_selectedFilter".',
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
