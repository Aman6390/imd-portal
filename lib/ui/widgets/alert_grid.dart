import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/dashboard_data.dart';
import '../month_calendar_screen.dart';
import 'glass_container.dart';

/// Apple Design System Leave Expiry Schedule & Carousel.
/// Displays Central Government (DoPT / IMD) rules for Casual Leave (CL) & Restricted Holiday (RH)
/// annual lapse (31-Dec) alongside 6-month rolling Compensatory Off (C-Off) expiry schedule.
class AlertGrid extends StatelessWidget {
  final List<LapsingAlert> alerts;
  final Map<String, String>? leavesData;

  const AlertGrid({
    Key? key,
    required this.alerts,
    this.leavesData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final now = DateTime.now();
    final yearEnd = DateTime(now.year, 12, 31);
    final daysLeftInYear = yearEnd.difference(now).inDays.clamp(0, 365);

    final cl = leavesData?['Casual Leave (CL)'] ?? '';
    final rh = leavesData?['Restricted Holiday (RH)'] ?? '';
    final isYearEndUrgent = daysLeftInYear <= 60; // November / December urgency

    // Count expiring C-Offs per month (yyyy-MM)
    final monthCounts = <String, int>{};
    final inputFormat = DateFormat('dd-MM-yyyy');

    for (final alert in alerts) {
      try {
        final parsedDate = inputFormat.parse(alert.expiryDate);
        final key = DateFormat('yyyy-MM').format(parsedDate);
        monthCounts[key] = (monthCounts[key] ?? 0) + 1;
      } catch (_) {}
    }

    final List<Widget> monthBoxes = [];

    for (int i = 0; i < 12; i++) {
      final targetMonth = DateTime(now.year, now.month + i, 1);
      final monthKey = DateFormat('yyyy-MM').format(targetMonth);
      final monthLabel = DateFormat('MMM yyyy').format(targetMonth);
      final count = monthCounts[monthKey] ?? 0;
      final hasAlert = count > 0;
      final isAnnualReset = targetMonth.month == 12 && targetMonth.year == now.year;

      monthBoxes.add(
        _AppleMonthCard(
          targetMonth: targetMonth,
          monthLabel: monthLabel,
          count: count,
          hasAlert: hasAlert,
          isAnnualReset: isAnnualReset,
          isDark: isDark,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MonthCalendarScreen(
                  month: targetMonth,
                  allAlerts: alerts,
                ),
              ),
            );
          },
        ),
      );
    }

    final totalExpiring = monthCounts.values.fold(0, (sum, val) => sum + val);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Central Government Leave Expiry Rule Glass Banner
        GlassContainer(
          borderRadius: 18,
          blur: 16,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          borderOpacity: isYearEndUrgent ? 0.35 : 0.14,
          surfaceOpacity: isYearEndUrgent ? 0.1 : 0.05,
          tintColor: isYearEndUrgent ? const Color(0xFFFF9500) : const Color(0xFF0284C7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: (isYearEndUrgent ? const Color(0xFFFF9500) : const Color(0xFF0284C7)).withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.event_busy_rounded,
                      color: isYearEndUrgent ? const Color(0xFFFF9500) : const Color(0xFF0284C7),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CL & RH Annual Expiry Rule',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Casual Leave & RH lapse on 31 Dec (Central Govt Rule • Cannot carry over)',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isYearEndUrgent ? const Color(0xFFFF9500) : const Color(0xFF0284C7)).withOpacity(0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (isYearEndUrgent ? const Color(0xFFFF9500) : const Color(0xFF0284C7)).withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      '$daysLeftInYear Days Left',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isYearEndUrgent ? const Color(0xFFFF9500) : const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
              if (cl.isNotEmpty || rh.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isYearEndUrgent ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                        size: 14,
                        color: isYearEndUrgent ? const Color(0xFFFF9500) : const Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Current Active: ${cl.isNotEmpty ? "$cl Casual Leave" : ""}${cl.isNotEmpty && rh.isNotEmpty ? " • " : ""}${rh.isNotEmpty ? "$rh Restricted Holiday" : ""} (Lapse on 31 Dec)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // 2. Horizontal Monthly Liquid Capsules (with C-Off counts & Dec Annual Reset)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: monthBoxes),
        ),
        const SizedBox(height: 8),

        // 3. Footer indicator
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF9500),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'C-Offs expire strictly 6 months from credit date ($totalExpiring active) • Tap any month for calendar',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Refined Apple-style Month Card with tactile feedback, annual reset badges, and glowing numerals.
class _AppleMonthCard extends StatefulWidget {
  final DateTime targetMonth;
  final String monthLabel;
  final int count;
  final bool hasAlert;
  final bool isAnnualReset;
  final bool isDark;
  final VoidCallback onTap;

  const _AppleMonthCard({
    Key? key,
    required this.targetMonth,
    required this.monthLabel,
    required this.count,
    required this.hasAlert,
    required this.isAnnualReset,
    required this.isDark,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_AppleMonthCard> createState() => _AppleMonthCardState();
}

class _AppleMonthCardState extends State<_AppleMonthCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final activeBorder = const Color(0xFFFF9500);
    final titleColor = widget.hasAlert
        ? (widget.isDark ? const Color(0xFFFFB020) : const Color(0xFFD97706))
        : (widget.isAnnualReset
            ? const Color(0xFF0284C7)
            : (widget.isDark ? Colors.grey[300] : const Color(0xFF334155)));

    final countColor = widget.hasAlert
        ? (widget.isDark ? Colors.white : const Color(0xFFB45309))
        : (widget.isDark ? Colors.grey[500] : Colors.grey[400]);

    return AnimatedScale(
      scale: _isPressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: Container(
        width: 108,
        height: 108,
        margin: const EdgeInsets.only(right: 10),
        child: GlassContainer(
          borderRadius: 18,
          blur: 16,
          tintColor: widget.hasAlert
              ? const Color(0xFFFF9500)
              : (widget.isAnnualReset ? const Color(0xFF0284C7) : null),
          borderOpacity: widget.hasAlert
              ? 0.45
              : (widget.isAnnualReset ? 0.4 : 0.12),
          surfaceOpacity: widget.hasAlert
              ? 0.12
              : (widget.isAnnualReset ? 0.09 : 0.05),
          onTap: () {
            widget.onTap();
          },
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top month title
              Text(
                widget.monthLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                  letterSpacing: -0.2,
                ),
              ),

              // Center balance display with glowing numerals
              Text(
                widget.hasAlert ? '${widget.count}' : '0',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: widget.hasAlert
                      ? (widget.isDark ? const Color(0xFFFF9500) : const Color(0xFFD97706))
                      : countColor,
                  letterSpacing: -0.6,
                  shadows: widget.hasAlert && widget.isDark
                      ? [
                          BoxShadow(
                            color: activeBorder.withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
              ),

              // Bottom badge or status label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.hasAlert
                      ? const Color(0xFFFF9500).withOpacity(0.22)
                      : (widget.isAnnualReset
                          ? const Color(0xFF0284C7).withOpacity(0.18)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.hasAlert
                      ? (widget.isAnnualReset ? 'C-Off + Reset' : 'Expiring')
                      : (widget.isAnnualReset ? 'CL/RH Reset' : 'Clear'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: widget.hasAlert
                        ? const Color(0xFFFF9500)
                        : (widget.isAnnualReset
                            ? const Color(0xFF0284C7)
                            : (widget.isDark ? Colors.grey[500] : Colors.grey[400])),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
