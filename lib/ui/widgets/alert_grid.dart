import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/dashboard_data.dart';
import '../month_calendar_screen.dart';

class AlertGrid extends StatelessWidget {
  final List<LapsingAlert> alerts;

  const AlertGrid({Key? key, required this.alerts}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.greenAccent.shade400),
            const SizedBox(width: 10),
            Text(
              'No active C-Offs expiring soon.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.outline,
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
      final borderColor = hasAlert ? Colors.amber : Colors.grey.withOpacity(0.3);
      final bgColor = hasAlert ? Colors.amber.withOpacity(0.12) : Colors.transparent;
      final titleColor = hasAlert ? Colors.amber : Theme.of(context).colorScheme.onSurfaceVariant;
      final countColor = hasAlert ? Colors.redAccent : Theme.of(context).colorScheme.outline;

      monthBoxes.add(
        InkWell(
          borderRadius: BorderRadius.circular(12),
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
          child: Container(
            width: 105,
            height: 105,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: hasAlert ? 1.5 : 1),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  monthLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasAlert ? '$count C-Off${count != 1 ? 's' : ''}' : '0',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: countColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'tap to view',
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
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
        Text(
          'Total active C-Offs tracked: $totalExpiring • Tap any month to open calendar view',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
