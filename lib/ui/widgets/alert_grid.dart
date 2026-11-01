import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/dashboard_data.dart';
import '../month_calendar_screen.dart';
import 'glass_container.dart';

/// Apple Design System C-Off Expiry Alert Grid & Carousel.
/// Replaces generic neon rotating borders with refined Cupertino vibrancy,
/// tactile physical cards, Apple semantic status indicators, and clean typography.
class AlertGrid extends StatelessWidget {
  final List<LapsingAlert> alerts;

  const AlertGrid({Key? key, required this.alerts}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Color(0xFF34C759), size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'No active C-Offs expiring in the next 12 months.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

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

    final now = DateTime.now();
    final List<Widget> monthBoxes = [];

    for (int i = 0; i < 12; i++) {
      final targetMonth = DateTime(now.year, now.month + i, 1);
      final monthKey = DateFormat('yyyy-MM').format(targetMonth);
      final monthLabel = DateFormat('MMM yyyy').format(targetMonth);
      final count = monthCounts[monthKey] ?? 0;
      final hasAlert = count > 0;

      monthBoxes.add(
        _AppleMonthCard(
          targetMonth: targetMonth,
          monthLabel: monthLabel,
          count: count,
          hasAlert: hasAlert,
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: monthBoxes),
        ),
        const SizedBox(height: 8),
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
              Text(
                'Total active C-Offs expiring: $totalExpiring • Tap month for calendar view',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Refined Apple-style Month Card with tactile feedback and subtle ambient depth.
class _AppleMonthCard extends StatefulWidget {
  final DateTime targetMonth;
  final String monthLabel;
  final int count;
  final bool hasAlert;
  final bool isDark;
  final VoidCallback onTap;

  const _AppleMonthCard({
    Key? key,
    required this.targetMonth,
    required this.monthLabel,
    required this.count,
    required this.hasAlert,
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
    // Apple Semantic Color Palette
    final activeBorder = const Color(0xFFFF9500); // Apple SystemOrange
    final titleColor = widget.hasAlert
        ? (widget.isDark ? const Color(0xFFFFB020) : const Color(0xFFD97706))
        : (widget.isDark ? Colors.grey[300] : const Color(0xFF334155));

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
          tintColor: widget.hasAlert ? const Color(0xFFFF9500) : null,
          borderOpacity: widget.hasAlert ? 0.45 : 0.12,
          surfaceOpacity: widget.hasAlert ? 0.12 : 0.05,
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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.hasAlert
                      ? const Color(0xFFFF9500).withOpacity(0.22)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.hasAlert ? 'Expiring' : 'Clear',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.hasAlert
                        ? const Color(0xFFFF9500)
                        : (widget.isDark ? Colors.grey[500] : Colors.grey[400]),
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
