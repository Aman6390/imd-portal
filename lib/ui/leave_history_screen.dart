import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/dashboard_data.dart';
import 'widgets/glass_container.dart';

/// Individual day-by-day leave record for chronological breakdown.
class DayLeaveEntry {
  final DateTime date;
  final String leaveType;
  final String status;
  final bool isApproved;
  final bool isCancelled;
  final LeaveHistoryItem originalItem;
  final int dayIndex;
  final int totalDays;

  DayLeaveEntry({
    required this.date,
    required this.leaveType,
    required this.status,
    required this.isApproved,
    required this.isCancelled,
    required this.originalItem,
    this.dayIndex = 1,
    this.totalDays = 1,
  });
}

/// Leave History Screen implementing Mockup 4:
/// - Top-to-bottom vertical stack of tactile Apple Liquid Glass "Month Boxes"
///   from the current month descending down to all available months.
/// - Tapping any Month Box slides up a Frosted Liquid Glass Modal Sheet
///   displaying only the dates in chronological order and what type of leave was taken.
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
  late int _selectedYear;
  bool _isRefreshing = false;
  int? _expandedRowIndex; // for modal sheet inline row expansion

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
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

  /// Available years found in leave records plus current year
  List<int> get _availableYears {
    final years = <int>{DateTime.now().year};
    for (final item in widget.leaveHistory) {
      final dt = item.parsedLeaveDate ?? item.parsedApplicationDate;
      if (dt != null) years.add(dt.year);
    }
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  /// Generates the list of months for the selected year from current month down to all available months
  List<DateTime> get _monthsForSelectedYear {
    final now = DateTime.now();
    int maxMonth = (_selectedYear == now.year) ? now.month : 12;

    // Check if any leave in this year is recorded in a future month
    for (final item in widget.leaveHistory) {
      final dt = item.parsedLeaveDate ?? item.parsedApplicationDate;
      if (dt != null && dt.year == _selectedYear && dt.month > maxMonth) {
        maxMonth = dt.month;
      }
    }

    final months = <DateTime>[];
    for (int m = maxMonth; m >= 1; m--) {
      months.add(DateTime(_selectedYear, m, 1));
    }
    return months;
  }

  /// Expands a single LeaveHistoryItem into individual day-by-day calendar entries
  List<DayLeaveEntry> _expandItemToDays(LeaveHistoryItem item) {
    final leaveDateStr = item.leaveDate.trim();
    final durationStr = item.duration.trim();

    // 1. Check for range: "dd-MM-yyyy to dd-MM-yyyy" or "dd-MM-yyyy - dd-MM-yyyy"
    final rangeRegex = RegExp(r'(\d{2}-\d{2}-\d{4})\s*(?:to|-)\s*(\d{2}-\d{2}-\d{4})', caseSensitive: false);
    final rangeMatch = rangeRegex.firstMatch(leaveDateStr);
    if (rangeMatch != null) {
      try {
        final startDt = DateFormat('dd-MM-yyyy').parse(rangeMatch.group(1)!);
        final endDt = DateFormat('dd-MM-yyyy').parse(rangeMatch.group(2)!);
        final totalDays = endDt.difference(startDt).inDays + 1;
        final list = <DayLeaveEntry>[];
        DateTime curr = startDt;
        int idx = 1;
        while (!curr.isAfter(endDt) && list.length < 31) {
          list.add(DayLeaveEntry(
            date: curr,
            leaveType: item.leaveType,
            status: item.status,
            isApproved: item.isApproved,
            isCancelled: item.isCancelled,
            originalItem: item,
            dayIndex: idx++,
            totalDays: totalDays > 0 ? totalDays : 1,
          ));
          curr = curr.add(const Duration(days: 1));
        }
        return list;
      } catch (_) {}
    }

    // 2. Single date extraction
    final dateMatch = RegExp(r'\d{2}-\d{2}-\d{4}').firstMatch(leaveDateStr);
    if (dateMatch == null) {
      final appMatch = RegExp(r'\d{2}-\d{2}-\d{4}').firstMatch(item.applicationDate);
      if (appMatch == null) return [];
      try {
        final dt = DateFormat('dd-MM-yyyy').parse(appMatch.group(0)!);
        return [
          DayLeaveEntry(
            date: dt,
            leaveType: item.leaveType,
            status: item.status,
            isApproved: item.isApproved,
            isCancelled: item.isCancelled,
            originalItem: item,
          )
        ];
      } catch (_) {
        return [];
      }
    }

    try {
      final startDt = DateFormat('dd-MM-yyyy').parse(dateMatch.group(0)!);
      final durMatch = RegExp(r'(\d+)').firstMatch(durationStr);
      final numDays = durMatch != null ? (int.tryParse(durMatch.group(1)!) ?? 1) : 1;

      if (numDays <= 1) {
        return [
          DayLeaveEntry(
            date: startDt,
            leaveType: item.leaveType,
            status: item.status,
            isApproved: item.isApproved,
            isCancelled: item.isCancelled,
            originalItem: item,
          )
        ];
      }

      final list = <DayLeaveEntry>[];
      for (int i = 0; i < numDays && i < 31; i++) {
        list.add(DayLeaveEntry(
          date: startDt.add(Duration(days: i)),
          leaveType: item.leaveType,
          status: item.status,
          isApproved: item.isApproved,
          isCancelled: item.isCancelled,
          originalItem: item,
          dayIndex: i + 1,
          totalDays: numDays,
        ));
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Returns all day-by-day leave records falling into the given month, sorted chronologically ascending
  List<DayLeaveEntry> _getDayLeavesForMonth(DateTime month) {
    final result = <DayLeaveEntry>[];
    for (final item in widget.leaveHistory) {
      final days = _expandItemToDays(item);
      for (final day in days) {
        if (day.date.year == month.year && day.date.month == month.month) {
          result.add(day);
        }
      }
    }
    // Sort chronologically ascending (01-Mar -> 31-Mar)
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  /// Returns a concise summary text for a month card (e.g. "7 Leaves Taken (C-Off, CL)")
  String _getMonthSubtitle(List<DayLeaveEntry> dayLeaves) {
    if (dayLeaves.isEmpty) {
      return '0 Leaves Taken';
    }
    final types = <String>{};
    for (final d in dayLeaves) {
      final t = d.leaveType.toLowerCase();
      if (t.contains('compensatory') || t.contains('c-off') || t.contains('comp')) {
        types.add('C-Off');
      } else if (t.contains('restricted') || t.contains('rh')) {
        types.add('RH');
      } else if (t.contains('earned') || t.contains('el')) {
        types.add('EL');
      } else {
        types.add('CL');
      }
    }
    final count = dayLeaves.length;
    final plural = count == 1 ? 'Leave' : 'Leaves';
    return '$count $plural Taken (${types.join(', ')})';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalAvailed = widget.leaveHistory.where((l) => l.isApproved).length;
    final totalCancelled = widget.leaveHistory.where((l) => l.isCancelled).length;
    final clBalance = widget.balances['Casual Leave (CL)'] ?? '0';

    final months = _monthsForSelectedYear;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E17) : const Color(0xFFF6F8FC),
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
                    ? const Color(0xFF0A0E17).withOpacity(0.85)
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
                  'Leave History',
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

              // 2. Year Selector Capsule (< 2026 >)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.07) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                final years = _availableYears;
                                final currIdx = years.indexOf(_selectedYear);
                                if (currIdx < years.length - 1) {
                                  HapticFeedback.lightImpact();
                                  setState(() => _selectedYear = years[currIdx + 1]);
                                }
                              },
                              child: Icon(
                                Icons.chevron_left_rounded,
                                size: 20,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_selectedYear',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                final years = _availableYears;
                                final currIdx = years.indexOf(_selectedYear);
                                if (currIdx > 0) {
                                  HapticFeedback.lightImpact();
                                  setState(() => _selectedYear = years[currIdx - 1]);
                                }
                              },
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Minimalist Summary Stats Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
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

              // 4. Section Label: Month Boxes (Top to Bottom)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        'SELECT A MONTH TO VIEW LEAVES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${months.length} Months',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Month Boxes Stack (Top to Bottom from Current Month Downwards)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final month = months[index];
                      final isCurrentMonth = (_selectedYear == now.year && month.month == now.month);
                      final dayLeaves = _getDayLeavesForMonth(month);
                      final hasLeaves = dayLeaves.isNotEmpty;

                      return _buildMonthBox(
                        month: month,
                        dayLeaves: dayLeaves,
                        isCurrentMonth: isCurrentMonth,
                        hasLeaves: hasLeaves,
                        isDark: isDark,
                      );
                    },
                    childCount: months.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 50),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tactile Apple Liquid Glass Month Box Card (Main Screen)
  Widget _buildMonthBox({
    required DateTime month,
    required List<DayLeaveEntry> dayLeaves,
    required bool isCurrentMonth,
    required bool hasLeaves,
    required bool isDark,
  }) {
    final monthName = DateFormat('MMMM yyyy').format(month);
    final subtitle = _getMonthSubtitle(dayLeaves);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassContainer(
        borderRadius: 18,
        blur: 16,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderOpacity: isCurrentMonth ? 0.35 : (hasLeaves ? (isDark ? 0.20 : 0.14) : (isDark ? 0.09 : 0.06)),
        surfaceOpacity: isCurrentMonth ? 0.12 : (hasLeaves ? (isDark ? 0.08 : 0.65) : (isDark ? 0.04 : 0.45)),
        tintColor: isCurrentMonth ? const Color(0xFF00C7FF) : (hasLeaves ? const Color(0xFF10B981) : null),
        onTap: () {
          _showMonthDetailSheet(month, dayLeaves);
        },
        child: Row(
          children: [
            // Calendar icon / Month badge
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCurrentMonth
                    ? const Color(0xFF00C7FF).withOpacity(0.18)
                    : (hasLeaves
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04))),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                size: 20,
                color: isCurrentMonth
                    ? const Color(0xFF00C7FF)
                    : (hasLeaves
                        ? const Color(0xFF10B981)
                        : (isDark ? Colors.white38 : Colors.black38)),
              ),
            ),
            const SizedBox(width: 14),

            // Center: Month title and leave count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        monthName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (isCurrentMonth) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C7FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF00C7FF).withOpacity(0.5), width: 0.8),
                          ),
                          child: const Text(
                            'Current',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF00C7FF),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasLeaves
                          ? (isDark ? Colors.white70 : Colors.black87)
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                ],
              ),
            ),

            // Right side: Trailing Count or Chevron
            if (hasLeaves)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 0.8),
                ),
                child: Text(
                  '${dayLeaves.length} ${dayLeaves.length == 1 ? "Day" : "Days"}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),

            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  /// Mockup 4: Apple Liquid Glass Frosted Modal Sheet
  /// Displays ONLY date in chronological order and what type of leave was taken!
  void _showMonthDetailSheet(DateTime month, List<DayLeaveEntry> dayLeaves) {
    HapticFeedback.lightImpact();
    setState(() => _expandedRowIndex = null);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final monthTitle = DateFormat('MMMM yyyy').format(month);
        final availedCount = dayLeaves.where((d) => d.isApproved).length;
        final cancelledCount = dayLeaves.where((d) => d.isCancelled).length;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.82,
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111622).withOpacity(0.96)
                      : Colors.white.withOpacity(0.97),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Drag Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black26,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Header Row: Month Title, Subtitle & Close Button
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                monthTitle,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Chronological Leave Breakdown',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Close circular button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(ctx).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 3. Stats Summary Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${dayLeaves.length} ${dayLeaves.length == 1 ? "Record" : "Records"} Total',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          Row(
                            children: [
                              if (availedCount > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$availedCount Availed',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (cancelledCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF453A).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$cancelledCount Cancelled',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFF453A),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 4. Day-by-Day List (Chronological Order)
                    if (dayLeaves.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_available_rounded,
                              size: 42,
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Leaves in $monthTitle',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No leave records were availed or applied during this month.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: dayLeaves.length,
                          separatorBuilder: (context, i) => Divider(
                            height: 1,
                            thickness: 0.6,
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                          ),
                          itemBuilder: (context, i) {
                            final entry = dayLeaves[i];
                            final isExpanded = _expandedRowIndex == i;
                            return _buildDayRow(
                              entry: entry,
                              isExpanded: isExpanded,
                              isDark: isDark,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setSheetState(() {
                                  _expandedRowIndex = isExpanded ? null : i;
                                });
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Renders a single Day-by-Day Chronological row:
  /// Left: Date (e.g. 01-Mar-2026) • Connector Arrow ──▶ • Right: [C-Off] Compensatory Off
  Widget _buildDayRow({
    required DayLeaveEntry entry,
    required bool isExpanded,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final dateStr = DateFormat('dd-MMM-yyyy').format(entry.date);
    final dayOfWeek = DateFormat('EEE').format(entry.date);

    // Leave Type Styling
    final typeLower = entry.leaveType.toLowerCase();
    final Color badgeColor;
    final String badgeCode;
    final String badgeFull;

    if (typeLower.contains('compensatory') || typeLower.contains('c-off') || typeLower.contains('comp')) {
      badgeColor = const Color(0xFFF59E0B); // Amber
      badgeCode = 'C-Off';
      badgeFull = 'Compensatory Off';
    } else if (typeLower.contains('restricted') || typeLower.contains('rh')) {
      badgeColor = const Color(0xFFA855F7); // Violet
      badgeCode = 'RH';
      badgeFull = 'Restricted Holiday';
    } else if (typeLower.contains('earned') || typeLower.contains('el')) {
      badgeColor = const Color(0xFF10B981); // Emerald
      badgeCode = 'EL';
      badgeFull = 'Earned Leave';
    } else {
      badgeColor = const Color(0xFF00C7FF); // Cyan
      badgeCode = 'CL';
      badgeFull = 'Casual Leave';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 1. Date + Day of week
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        decoration: entry.isCancelled ? TextDecoration.lineThrough : null,
                        decorationColor: const Color(0xFFFF453A),
                        color: entry.isCancelled
                            ? (isDark ? Colors.white38 : Colors.black38)
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                    Text(
                      dayOfWeek,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 8),

                // 2. Connector Arrow (──▶)
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                        ),
                      ),
                      Icon(
                        Icons.arrow_right_alt_rounded,
                        size: 16,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),

                // 3. Right: Glowing Leave Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withOpacity(0.4), width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withOpacity(isDark ? 0.18 : 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '[$badgeCode]',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        badgeFull,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Status Indicator Tag (Cancelled strike or Availed check)
                if (entry.isCancelled) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF453A).withOpacity(0.16),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFF453A).withOpacity(0.3), width: 0.6),
                    ),
                    child: const Text(
                      '✕ Cancelled',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF453A),
                      ),
                    ),
                  ),
                ] else if (entry.isApproved) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: Color(0xFF10B981),
                  ),
                ],
              ],
            ),

            // Optional Expanded Details on Tap
            if (isExpanded) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.originalItem.reason.isNotEmpty)
                      _buildDetailRow('Reason', entry.originalItem.reason, isDark),
                    if (entry.originalItem.actionBy.isNotEmpty)
                      _buildDetailRow('Sanctioning Officer', entry.originalItem.actionBy, isDark),
                    if (entry.originalItem.slpAddress != null && entry.originalItem.slpAddress!.isNotEmpty) ...[
                      _buildDetailRow('SLP Address', entry.originalItem.slpAddress!, isDark, isHighlight: true),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Clipboard.setData(ClipboardData(text: entry.originalItem.slpAddress!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('📍 Station Leaving Address copied!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 12),
                          label: const Text('Copy SLP Address', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF00C7FF),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          text: '$label: ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
          children: [
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isHighlight
                    ? const Color(0xFF00C7FF)
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
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
}
