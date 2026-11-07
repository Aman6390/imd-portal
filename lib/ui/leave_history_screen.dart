import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/dashboard_data.dart';
import 'widgets/glass_container.dart';

/// Apple iOS 27 Chronological Monthly Grouped Leave Records Screen.
/// Displays official MetNet leave history grouped by month and year in descending order,
/// featuring status badges, station leaving permissions (SLP), approving officer remarks,
/// summary Bento pods, and instant filtering.
class LeaveHistoryScreen extends StatefulWidget {
  final List<LeaveHistoryItem> leaveHistory;
  final Map<String, String> balances;
  final Future<void> Function()? onRefresh;

  const LeaveHistoryScreen({
    Key? key,
    required this.leaveHistory,
    required this.balances,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  String _selectedFilter = 'All'; // 'All', 'Availed', 'Cancelled', 'Casual Leave', 'RH'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isRefreshing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (widget.onRefresh == null || _isRefreshing) return;
    setState(() => _isRefreshing = true);
    HapticFeedback.mediumImpact();
    try {
      await widget.onRefresh!();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  List<LeaveHistoryItem> get _filteredLeaves {
    return widget.leaveHistory.where((item) {
      // 1. Filter Chip Matching
      if (_selectedFilter == 'Availed' && !item.isApproved) return false;
      if (_selectedFilter == 'Cancelled' && !item.isCancelled) return false;
      if (_selectedFilter == 'Casual Leave' &&
          !item.leaveType.toLowerCase().contains('casual')) {
        return false;
      }
      if (_selectedFilter == 'RH' &&
          !item.leaveType.toLowerCase().contains('restricted')) {
        return false;
      }

      // 2. Search Query Matching
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesReason = item.reason.toLowerCase().contains(q);
        final matchesOfficer = item.actionBy.toLowerCase().contains(q);
        final matchesRemarks = (item.actionRemarks ?? '').toLowerCase().contains(q);
        final matchesSlp = (item.slpAddress ?? '').toLowerCase().contains(q);
        final matchesDate = item.leaveDate.contains(q) || item.applicationDate.contains(q);
        if (!matchesReason &&
            !matchesOfficer &&
            !matchesRemarks &&
            !matchesSlp &&
            !matchesDate) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Groups items by Year and Month, sorted in descending chronological order
  Map<String, List<LeaveHistoryItem>> get _groupedByMonth {
    final filtered = _filteredLeaves;

    // Sort items chronologically descending by leaveDate
    final sorted = List<LeaveHistoryItem>.from(filtered)..sort((a, b) {
      final da = a.parsedLeaveDate;
      final db = b.parsedLeaveDate;
      if (da == null && db == null) return b.slNo.compareTo(a.slNo);
      if (da == null) return 1;
      if (db == null) return -1;
      final cmp = db.compareTo(da);
      return cmp != 0 ? cmp : b.slNo.compareTo(a.slNo);
    });

    final map = <String, List<LeaveHistoryItem>>{};
    for (final item in sorted) {
      final dt = item.parsedLeaveDate;
      String monthKey;
      if (dt != null) {
        monthKey = DateFormat('MMMM yyyy').format(dt);
      } else {
        monthKey = 'Other / Unspecified Date';
      }
      map.putIfAbsent(monthKey, () => []).add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Metrics for Bento header
    final totalAvailed = widget.leaveHistory.where((l) => l.isApproved).length;
    final totalCancelled = widget.leaveHistory.where((l) => l.isCancelled).length;
    final clBalance = widget.balances['Casual Leave (CL)'] ?? '0';

    final grouped = _groupedByMonth;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0F14) : const Color(0xFFF6F8FC),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: const Color(0xFF00C7FF),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // 1. Frosted Translucent Apple App Bar
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: isDark
                    ? const Color(0xFF0C0F14).withOpacity(0.85)
                    : const Color(0xFFF6F8FC).withOpacity(0.85),
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Leave Records',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Chronological Monthly Timeline',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                centerTitle: true,
                actions: [
                  if (widget.onRefresh != null)
                    IconButton(
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.black.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                      onPressed: _handleRefresh,
                    ),
                  const SizedBox(width: 8),
                ],
              ),

              // 2. Bento Summary Grid (Availed, Balance, Cancelled)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      // Availed Pod
                      Expanded(
                        child: _buildBentoPod(
                          title: 'AVAILED',
                          count: '$totalAvailed Days',
                          subtitle: 'Approved & Used',
                          color: const Color(0xFF10B981), // Emerald
                          icon: Icons.check_circle_rounded,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Casual Balance Pod
                      Expanded(
                        child: _buildBentoPod(
                          title: 'CL BALANCE',
                          count: '$clBalance Days',
                          subtitle: 'Available Now',
                          color: const Color(0xFF00C7FF), // Cyan
                          icon: Icons.account_balance_wallet_rounded,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Cancelled Pod
                      Expanded(
                        child: _buildBentoPod(
                          title: 'CANCELLED',
                          count: '$totalCancelled Days',
                          subtitle: 'Self / Auto Revoked',
                          color: const Color(0xFFFF453A), // Apple Coral Red
                          icon: Icons.cancel_rounded,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by reason, officer, or SLP address...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 19,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                      },
                    ),
                  ),
                ),
              ),

              // 4. Horizontal Filter Segmented Pills
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildFilterPill('All', widget.leaveHistory.length, isDark),
                        const SizedBox(width: 8),
                        _buildFilterPill('Availed', totalAvailed, isDark),
                        const SizedBox(width: 8),
                        _buildFilterPill('Cancelled', totalCancelled, isDark),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          'Casual Leave',
                          widget.leaveHistory
                              .where((l) => l.leaveType.toLowerCase().contains('casual'))
                              .length,
                          isDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. Month Grouped Chronological Timeline
              if (grouped.isEmpty)
                SliverToBoxAdapter(
                  child: _buildEmptyState(isDark),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final monthKey = grouped.keys.elementAt(index);
                      final leavesInMonth = grouped[monthKey]!;
                      return _buildMonthSection(monthKey, leavesInMonth, isDark);
                    },
                    childCount: grouped.keys.length,
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 60),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact Top Bento Metric Pod
  Widget _buildBentoPod({
    required String title,
    required String count,
    required String subtitle,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.25 : 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.08 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: color,
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            count,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Filter Capsule Pill
  Widget _buildFilterPill(String filterName, int count, bool isDark) {
    final isSelected = _selectedFilter == filterName;
    const activeColor = Color(0xFF00C7FF);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedFilter = filterName);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(isDark ? 0.22 : 0.15)
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor.withOpacity(0.6)
                : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
            width: isSelected ? 1.2 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              filterName,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF007AFF))
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withOpacity(isDark ? 0.35 : 0.25)
                    : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF007AFF))
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Month Group Header & Leaves List
  Widget _buildMonthSection(
    String monthTitle,
    List<LeaveHistoryItem> leaves,
    bool isDark,
  ) {
    // Total days in this month
    final availedCount = leaves.where((l) => l.isApproved).length;
    final cancelledCount = leaves.where((l) => l.isCancelled).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: const Color(0xFF00C7FF),
                ),
                const SizedBox(width: 6),
                Text(
                  monthTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '•  ${leaves.length} ${leaves.length == 1 ? "entry" : "entries"}'
                  '${availedCount > 0 ? " ($availedCount availed" : ""}'
                  '${cancelledCount > 0 ? ", $cancelledCount cancelled)" : availedCount > 0 ? ")" : ""}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Leave Cards for this Month
          ...leaves.map((item) => _buildLeaveCard(item, isDark)).toList(),
        ],
      ),
    );
  }

  /// Apple Glass Leave Record Card
  Widget _buildLeaveCard(LeaveHistoryItem item, bool isDark) {
    final parsedDate = item.parsedLeaveDate;
    final dayNum = parsedDate != null ? DateFormat('dd').format(parsedDate) : '--';
    final dayName = parsedDate != null ? DateFormat('EEE').format(parsedDate).toUpperCase() : '';
    final monthShort = parsedDate != null ? DateFormat('MMM').format(parsedDate).toUpperCase() : '';

    final isAvailed = item.isApproved;
    final isCancelled = item.isCancelled;

    final badgeColor = isAvailed
        ? const Color(0xFF10B981) // Emerald
        : isCancelled
            ? const Color(0xFFFF453A) // Apple Coral Red
            : const Color(0xFFFF9F0A); // Apple Amber

    final badgeIcon = isAvailed
        ? Icons.check_circle_rounded
        : isCancelled
            ? Icons.cancel_rounded
            : Icons.hourglass_top_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassContainer(
        borderRadius: 18,
        blur: 16,
        padding: const EdgeInsets.all(12),
        borderOpacity: isDark ? 0.15 : 0.08,
        surfaceOpacity: isDark ? 0.05 : 0.55,
        onTap: () {
          HapticFeedback.lightImpact();
          _showLeaveDetailModal(context, item, isDark);
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Date Pill Block
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    dayNum,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    monthShort,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Middle & Right Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Leave Type + Status Badge
                  Row(
                    children: [
                      // Type Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C7FF).withOpacity(isDark ? 0.18 : 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.leaveType} • ${item.duration}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Status Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(isDark ? 0.16 : 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: badgeColor.withOpacity(0.3),
                            width: 0.6,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, size: 10, color: badgeColor),
                            const SizedBox(width: 3.5),
                            Text(
                              item.status,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Reason Title
                  Text(
                    item.reason,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),

                  // Station Leaving Permission (SLP) Address badge if present
                  if (item.slpAddress != null && item.slpAddress!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF38BDF8).withOpacity(0.08)
                            : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF0284C7).withOpacity(0.2),
                          width: 0.6,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 11,
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'SLP: ${item.slpAddress}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),

                  // Officer & Remarks
                  Row(
                    children: [
                      Icon(
                        isCancelled ? Icons.person_off_rounded : Icons.person_rounded,
                        size: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${item.actionBy}${item.actionRemarks != null ? " • ${item.actionRemarks}" : ""}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'App: ${item.applicationDate}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Empty state display
  Widget _buildEmptyState(bool isDark) {
    final hasSearch = _searchQuery.isNotEmpty || _selectedFilter != 'All';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearch ? Icons.filter_alt_off_rounded : Icons.history_rounded,
                size: 38,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch ? 'No Matching Leave Records' : 'No Leave History Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasSearch
                  ? 'Try clearing search or changing the filter chip above.'
                  : 'Pull down to refresh or sync with MetNet to download your official leave history records.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            if (hasSearch) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                    _selectedFilter = 'All';
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset All Filters', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C7FF),
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Detailed Bottom Sheet Inspection Modal
  void _showLeaveDetailModal(
    BuildContext context,
    LeaveHistoryItem item,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141923) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Grab Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Modal Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C7FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.description_rounded,
                        size: 20,
                        color: Color(0xFF00C7FF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.leaveType,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Sl. #${item.slNo} • ${item.duration} Duration',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (item.isApproved
                                ? const Color(0xFF10B981)
                                : item.isCancelled
                                    ? const Color(0xFFFF453A)
                                    : const Color(0xFFFF9F0A))
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: item.isApproved
                              ? const Color(0xFF10B981)
                              : item.isCancelled
                                  ? const Color(0xFFFF453A)
                                  : const Color(0xFFFF9F0A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Key Value Bento Details
                _buildModalDetailRow(
                  label: 'Leave Date',
                  value: item.leaveDate,
                  icon: Icons.event_rounded,
                  isDark: isDark,
                ),
                _buildModalDetailRow(
                  label: 'Date of Application',
                  value: item.applicationDate,
                  icon: Icons.edit_calendar_rounded,
                  isDark: isDark,
                ),
                _buildModalDetailRow(
                  label: 'Reason for Leave',
                  value: item.reason,
                  icon: Icons.chat_bubble_outline_rounded,
                  isDark: isDark,
                ),
                if (item.slpAddress != null && item.slpAddress!.isNotEmpty)
                  _buildModalDetailRow(
                    label: 'SLP Station Leaving Address',
                    value: item.slpAddress!,
                    icon: Icons.home_rounded,
                    isDark: isDark,
                    canCopy: true,
                  ),
                _buildModalDetailRow(
                  label: item.isCancelled ? 'Cancelled By' : 'Action By Officer',
                  value: item.actionBy,
                  icon: Icons.badge_rounded,
                  isDark: isDark,
                ),
                if (item.actionRemarks != null && item.actionRemarks!.isNotEmpty)
                  _buildModalDetailRow(
                    label: 'Remarks / Comments',
                    value: item.actionRemarks!,
                    icon: Icons.comment_rounded,
                    isDark: isDark,
                  ),

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0),
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalDetailRow({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    bool canCopy = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF00C7FF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          if (canCopy)
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16),
              tooltip: 'Copy Address',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('SLP address copied to clipboard!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
