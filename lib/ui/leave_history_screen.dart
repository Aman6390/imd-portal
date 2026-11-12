import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/dashboard_data.dart';
import 'widgets/glass_container.dart';

/// Simplified, Apple-grade Unified Leave Records Screen.
/// Provides a direct, uncluttered chronological view of all leave types
/// (Casual Leave, Restricted Holiday, Compensatory Off, Earned Leave)
/// grouped cleanly by active months with instant filtering and search.
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
  String _selectedFilter = 'All'; // 'All', 'Casual', 'RH', 'C-Off', 'Availed', 'Cancelled'
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
      if (_selectedFilter == 'Casual' &&
          !item.leaveType.toLowerCase().contains('casual') &&
          !item.leaveType.toLowerCase().contains('cl')) {
        return false;
      }
      if (_selectedFilter == 'RH' &&
          !item.leaveType.toLowerCase().contains('restricted') &&
          !item.leaveType.toLowerCase().contains('rh')) {
        return false;
      }
      if (_selectedFilter == 'C-Off' &&
          !item.leaveType.toLowerCase().contains('compensatory') &&
          !item.leaveType.toLowerCase().contains('c-off') &&
          !item.leaveType.toLowerCase().contains('comp')) {
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
        final matchesType = item.leaveType.toLowerCase().contains(q);
        if (!matchesReason &&
            !matchesOfficer &&
            !matchesRemarks &&
            !matchesSlp &&
            !matchesDate &&
            !matchesType) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Groups items by Year and Month in chronological order (only months with activity)
  Map<String, List<LeaveHistoryItem>> get _groupedByMonth {
    final filtered = _filteredLeaves;

    // Sort items chronologically descending (newest first for daily convenience)
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
                title: Text(
                  'Leave Records',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
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

              // 2. Minimalist Summary Stats Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryIndicator(
                          label: 'Availed',
                          value: '$totalAvailed Days',
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                        Container(width: 1, height: 20, color: isDark ? Colors.white12 : Colors.black12),
                        _buildSummaryIndicator(
                          label: 'CL Balance',
                          value: '$clBalance Days',
                          color: const Color(0xFF00C7FF),
                          isDark: isDark,
                        ),
                        Container(width: 1, height: 20, color: isDark ? Colors.white12 : Colors.black12),
                        _buildSummaryIndicator(
                          label: 'Cancelled',
                          value: '$totalCancelled Days',
                          color: const Color(0xFFFF453A),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Compact Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.09) : Colors.black.withOpacity(0.08),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search date, reason, officer, or SLP...',
                        hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                      },
                    ),
                  ),
                ),
              ),

              // 4. Horizontal Filter Pills (CL, RH, C-Off, Availed, Cancelled)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildFilterPill('All', widget.leaveHistory.length, isDark),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          'Casual',
                          widget.leaveHistory.where((l) =>
                              l.leaveType.toLowerCase().contains('casual') ||
                              l.leaveType.toLowerCase().contains('cl')).length,
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          'RH',
                          widget.leaveHistory.where((l) =>
                              l.leaveType.toLowerCase().contains('restricted') ||
                              l.leaveType.toLowerCase().contains('rh')).length,
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          'C-Off',
                          widget.leaveHistory.where((l) =>
                              l.leaveType.toLowerCase().contains('compensatory') ||
                              l.leaveType.toLowerCase().contains('c-off') ||
                              l.leaveType.toLowerCase().contains('comp')).length,
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill('Availed', totalAvailed, isDark),
                        const SizedBox(width: 8),
                        _buildFilterPill('Cancelled', totalCancelled, isDark),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. Direct Grouped Leave Feed (No empty boxes, no drill-down maze!)
              if (grouped.isEmpty)
                SliverToBoxAdapter(
                  child: _buildEmptyState(isDark),
                )
              else
                ...grouped.entries.map((entry) {
                  final monthTitle = entry.key;
                  final leavesInMonth = entry.value;
                  final monthAvailed = leavesInMonth.where((l) => l.isApproved).length;

                  return SliverMainAxisGroup(
                    slivers: [
                      // Month Header Capsule
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_month_rounded, size: 13, color: Color(0xFF00C7FF)),
                                    const SizedBox(width: 6),
                                    Text(
                                      monthTitle.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '$monthAvailed Availed • ${leavesInMonth.length} ${leavesInMonth.length == 1 ? "Record" : "Records"}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Leaves in this month
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = leavesInMonth[index];
                              return _buildLeaveCard(item, isDark);
                            },
                            childCount: leavesInMonth.length,
                          ),
                        ),
                      ),
                    ],
                  );
                }),

              const SliverToBoxAdapter(
                child: SizedBox(height: 50),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact Apple Glass Leave Record Card (Direct, High-Scannability)
  Widget _buildLeaveCard(LeaveHistoryItem item, bool isDark) {
    final parsedDate = item.parsedLeaveDate;
    final dayNum = parsedDate != null ? DateFormat('dd').format(parsedDate) : item.leaveDate.split('-').first;
    final monthShort = parsedDate != null ? DateFormat('MMM').format(parsedDate) : '';
    final dayOfWeek = parsedDate != null ? DateFormat('EEE').format(parsedDate) : '';

    // Leave Type Styling
    final typeLower = item.leaveType.toLowerCase();
    final Color typeColor;
    final String typeShort;
    if (typeLower.contains('restricted') || typeLower.contains('rh')) {
      typeColor = const Color(0xFFA855F7); // Violet
      typeShort = 'Restricted (RH)';
    } else if (typeLower.contains('compensatory') || typeLower.contains('c-off') || typeLower.contains('comp')) {
      typeColor = const Color(0xFFF59E0B); // Amber
      typeShort = 'Comp-Off (C-Off)';
    } else if (typeLower.contains('earned') || typeLower.contains('el')) {
      typeColor = const Color(0xFF10B981); // Emerald
      typeShort = 'Earned (EL)';
    } else {
      typeColor = const Color(0xFF00C7FF); // Cyan
      typeShort = 'Casual (CL)';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassContainer(
        borderRadius: 18,
        blur: 16,
        padding: const EdgeInsets.all(14),
        borderOpacity: isDark ? 0.12 : 0.08,
        surfaceOpacity: isDark ? 0.05 : 0.55,
        onTap: () {
          HapticFeedback.lightImpact();
          _showLeaveDetailSheet(item);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Row: Date badge, Leave Type, and Status
            Row(
              children: [
                // Date Capsule
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dayNum,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (monthShort.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          '$monthShort ${dayOfWeek.isNotEmpty ? "• $dayOfWeek" : ""}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Leave Type Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: typeColor.withOpacity(0.35), width: 0.7),
                  ),
                  child: Text(
                    typeShort,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: typeColor,
                    ),
                  ),
                ),

                const Spacer(),

                // Status Badge
                _buildStatusPill(item),
              ],
            ),
            const SizedBox(height: 10),

            // Middle: Reason
            Text(
              item.reason.isNotEmpty ? item.reason : 'Leave Application',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // SLP Address Row (if available)
            if (item.slpAddress != null && item.slpAddress!.isNotEmpty) ...[
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1.5),
                    child: Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF00C7FF)),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.slpAddress!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF00C7FF),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 8),

            // Bottom Info: Duration & Approver
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                const SizedBox(width: 4),
                Text(
                  item.duration,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(width: 10),
                Text('•', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.actionBy.isNotEmpty ? item.actionBy : 'IMD Sanction',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(LeaveHistoryItem item) {
    if (item.isApproved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35), width: 0.6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 11, color: Color(0xFF10B981)),
            SizedBox(width: 3),
            Text(
              'Availed',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
            ),
          ],
        ),
      );
    }
    if (item.isCancelled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFF453A).withOpacity(0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFF453A).withOpacity(0.35), width: 0.6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close_rounded, size: 11, color: Color(0xFFFF453A)),
            SizedBox(width: 3),
            Text(
              'Cancelled',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFFF453A)),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35), width: 0.6),
      ),
      child: Text(
        item.status,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B)),
      ),
    );
  }

  Widget _buildSummaryIndicator({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill(String title, int count, bool isDark) {
    final isSelected = _selectedFilter == title;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedFilter = title);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00C7FF)
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00C7FF)
                : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.black.withOpacity(0.2)
                    : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_busy_rounded,
              size: 38,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No Matching Leaves Found' : 'No Leave History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search query or filters.'
                : 'No leave applications recorded on MetNet yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          if (_searchQuery.isNotEmpty || _selectedFilter != 'All') ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedFilter = 'All';
                });
              },
              child: const Text('Reset Filters', style: TextStyle(color: Color(0xFF00C7FF), fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }

  void _showLeaveDetailSheet(LeaveHistoryItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141923).withOpacity(0.95) : Colors.white.withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Row(
                  children: [
                    Text(
                      item.leaveType,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    _buildStatusPill(item),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSheetRow('Leave Date', item.leaveDate, isDark),
                _buildSheetRow('Application Date', item.applicationDate, isDark),
                _buildSheetRow('Duration', item.duration, isDark),
                _buildSheetRow('Reason', item.reason, isDark),
                if (item.slpAddress != null && item.slpAddress!.isNotEmpty)
                  _buildSheetRow('SLP Address', item.slpAddress!, isDark, isHighlight: true),
                _buildSheetRow('Action By', item.actionBy, isDark),
                if (item.actionRemarks != null && item.actionRemarks!.isNotEmpty)
                  _buildSheetRow('Remarks', item.actionRemarks!, isDark),
                const SizedBox(height: 18),
                if (item.slpAddress != null && item.slpAddress!.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Clipboard.setData(ClipboardData(text: item.slpAddress!));
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('📍 Station Leaving Address copied!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy SLP Address', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C7FF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetRow(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isHighlight
                  ? const Color(0xFF00C7FF)
                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
