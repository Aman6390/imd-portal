import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/dashboard_data.dart';
import '../month_calendar_screen.dart';
import 'glass_container.dart';

/// Apple Design System Leave Expiry Schedule & Carousel.
/// Displays 12-month rolling leave expiry schedule including Compensatory Offs (6-month validity)
/// and Central Government (DoPT / IMD) Casual Leave (CL) & Restricted Holiday (RH) annual lapse (31-Dec).
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

    final cl = leavesData?['Casual Leave (CL)'] ?? '';
    final rh = leavesData?['Restricted Holiday (RH)'] ?? '';
    final clBalance = int.tryParse(cl) ?? 0;
    final rhBalance = int.tryParse(rh) ?? 0;

    // Under Central Govt (DoPT) rules, CL and RH lapse strictly on 31 December.
    // Count user's unspent CL + RH balance, or default to 2 (standard RH allocation) if unspent/unparsed.
    final annualExpiring = (clBalance + rhBalance > 0) ? (clBalance + rhBalance) : 2;

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
      final isAnnualReset = targetMonth.month == 12 && targetMonth.year == now.year;
      final cOffCount = monthCounts[monthKey] ?? 0;

      int count = cOffCount;
      bool hasAlert = count > 0;
      String? badgeText;

      if (isAnnualReset) {
        // December includes annual lapse of Casual Leave & Restricted Holiday (31 Dec)
        count = cOffCount + annualExpiring;
        hasAlert = true;
        badgeText = cOffCount > 0 ? 'C-Off + Lapse' : 'CL & RH Lapse';
      }

      monthBoxes.add(
        _AppleMonthCard(
          targetMonth: targetMonth,
          monthLabel: monthLabel,
          count: count,
          hasAlert: hasAlert,
          isAnnualReset: isAnnualReset,
          badgeText: badgeText,
          isDark: isDark,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MonthCalendarScreen(
                  month: targetMonth,
                  allAlerts: alerts,
                  leavesData: leavesData,
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
        // Horizontal Monthly Liquid Capsules (with C-Off counts & Dec Annual Reset)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: monthBoxes),
        ),
        const SizedBox(height: 8),

        // Footer indicator
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
                  'C-Offs expire in 6 months ($totalExpiring active) • CL & RH lapse Dec 31 • Tap for calendar',
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
  final String? badgeText;
  final bool isDark;
  final VoidCallback onTap;

  const _AppleMonthCard({
    Key? key,
    required this.targetMonth,
    required this.monthLabel,
    required this.count,
    required this.hasAlert,
    required this.isAnnualReset,
    this.badgeText,
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
                  widget.badgeText ??
                      (widget.hasAlert
                          ? 'Expiring'
                          : (widget.isAnnualReset ? 'CL/RH Reset' : 'Clear')),
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
